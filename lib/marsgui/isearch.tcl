#-----------------------------------------------------------------------
# TITLE:
#    isearch.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n): Incremental Search for text widgets.  See isearch(n)
#    for usage details.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsgui:: {
    namespace export isearch
}

#-----------------------------------------------------------------------
# isearch

snit::type ::marsgui::isearch {
    pragma -hasinstances no
    
    #-------------------------------------------------------------------
    # Type Constructor
    
    typeconstructor {
        namespace import ::marsutil::*
        
        # FIRST, create the ISearch binding
        
        # The following events terminate the search process, and have
        # their normal effect as well.
        
        bind ::marsgui::ISearch <Button>   { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <FocusOut> { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Escape>   { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Up>       { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Down>     { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Left>     { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Right>    { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Tab>      { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Prior>    { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Next>     { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <Home>     { ::marsgui::isearch::End %W }
        bind ::marsgui::ISearch <End>      { ::marsgui::isearch::End %W }

        # Return should terminate the search, as it does for Emacs, but
        # having it insert a return key is jarring.
        bind ::marsgui::ISearch <Return>   {
            ::marsgui::isearch::End %W
            break
        }
        
        # While we're in the isearch mode, we want to ignore the following
        # key-combinations except in particular cases.  If we don't
        # do this, then (say) Control-C will be treated like "C".
        bind ::marsgui::ISearch <Control-Key>   break
        bind ::marsgui::ISearch <Meta-Key>      break
        bind ::marsgui::ISearch <Alt-Key>       break
        
        # Ignore Delete as well; there's nothing for it to do, and it
        # pretends to be a glyph.
        bind ::marsgui::ISearch <Delete>        break

        # On a normal keystroke that produces a visible character, try to
        # extend the current search in the current direction.
        bind ::marsgui::ISearch <Key> {
            ::marsgui::isearch::Extend %W %A
            break
        }
        
        # On Control-f or Control-r, search for the same thing in the
        # specified direction.
        bind ::marsgui::ISearch <Control-f> {
            ::marsgui::isearch::FindNext %W -forwards
            break
        }
        
        bind ::marsgui::ISearch <Control-F> {
            ::marsgui::isearch::FindNext %W -forwards
            break
        }
        
        bind ::marsgui::ISearch <Control-r> {
            ::marsgui::isearch::FindNext %W -backwards
            break
        }
        
        bind ::marsgui::ISearch <Control-R> {
            ::marsgui::isearch::FindNext %W -backwards
            break
        }
        
        # On Backspace, delete one character from the search target,
        # and jump back to the earliest occurrence of the new target
        # after the start point (taking direction into account).
        bind ::marsgui::ISearch <BackSpace> {
            ::marsgui::isearch::Backspace %W
            break
        }
    }
    
    #-------------------------------------------------------------------
    # Type Variables
    
    # The global logger command, or ""
    typevariable logger {}
    
    # info array: Key is a window name, or "all"; the value is a dictionary
    # with the following keys:
    #
    # For $w or all:
    #   _logger        Logging command for status info, or ""
    #   _oldbindings   Old ^F and ^R bindings
    #
    # For $w only:
    #   _direction     -forwards | -backwards 
    #   _target        The current search target
    #   _oldtarget     The previous search target
    
    typevariable info -array {
        all {_logger "" _oldbindings ""}
    }
    
    #-------------------------------------------------------------------
    # Public Typemethods
    
    # enable w
    #
    # w     A window name, or "all"
    #
    # Enables isearch on the specific window or on all Text widgets.
    
    typemethod enable {w} {
        # FIRST, create a dictionary for the window if need be
        if {![info exists info($w)]} {
            set info($w) {
                _logger      ""
                _oldbindings ""
                _direction   ""
                _target      ""
                _oldtarget   ""
            }
        }
        
        # NEXT, use the dictionary
        dict with info($w) {
            # FIRST, if we already have bindings, we're done.
            if {$_oldbindings ne ""} {
                return
            }
            
            # NEXT, get the bindtag for this window
            if {$w eq "all"} {
                set tag Text
            } else {
                set tag $w
            }

            foreach event {
                <Control-f>
                <Control-F>
                <Control-r>
                <Control-R>
            } {
                lappend _oldbindings $event [bind $tag $event]
            }
            
            bind $tag <Control-f> {::marsgui::isearch::Begin %W -forwards}
            bind $tag <Control-F> {::marsgui::isearch::Begin %W -forwards}
            bind $tag <Control-r> {::marsgui::isearch::Begin %W -backwards}
            bind $tag <Control-R> {::marsgui::isearch::Begin %W -backwards}
        }
    }

    # disable w
    #
    # w     A window name, or "all"
    #
    # Disables isearch on the specific window or on all Text widgets.
    
    typemethod disable {w} {
        # FIRST, if it's not been enabled, just return.
        if {![info exists info($w)]} {
            return
        }
        
        # NEXT, use the dictionary
        dict with info($w) {
            # FIRST, get the bindtag for this window
            if {$w eq "all"} {
                set tag Text
            } else {
                set tag $w
            }
            
            # NEXT, if the window exists, restore its bindings
            if {$w eq "all" || [winfo exists $w]} {
                foreach {event binding} $_oldbindings {
                    bind $tag $event $binding
                }
                
                set _oldbindings {}
            }
        }
        
        # NEXT, forget about the window
        if {$w ne "all"} {
            unset info($w)
        }
        
        return
    }
    
    # logger w ?cmd?
    #
    # w        A window for each isearch is enabled, or "all".
    # cmd      A logger command, taking one additional argument
    #
    # Sets/queries the logger command for the window.
    
    typemethod logger {w {cmd "*ISEARCH_QUERY*"}} {
        # FIRST, if we don't have such a window, it's an error.
        require {[info exists info($w)]} \
            "isearch is not enabled for window \"$w\""
        
        # NEXT, if it's not a query, set the logger
        if {$cmd ne "*ISEARCH_QUERY*"} {
            dict set info($w) _logger $cmd
        }
        
        # NEXT, return it
        dict get $info($w) _logger
    }
    
    #-------------------------------------------------------------------
    # Event Handlers
    
    # Begin w dir
    #
    # w      The isearch-enabled text widget
    # dir    -forwards|-backwards
    #
    # Begins the search process: puts the text widget into isearch mode,
    # defines the needed tags and marks, etc.
    
    proc Begin {w dir} {
        dict with info($w) {
            # FIRST, Install the isearch bind tag
            bindtags $w [linsert [bindtags $w] 0 ::marsgui::ISearch]
            
            # NEXT, add the isearch tags
            $w tag configure isearch_found \
                -background #FFFF88          \
                -foreground black
            
            $w tag configure isearch_here \
                -background purple          \
                -foreground white
        
            # NEXT, set up for this search.
            set _oldtarget $_target
            set _target    ""
            set _direction $dir
            
            $w mark set isearch_start insert
            $w mark set isearch_here  insert
            
            Log $w "Incremental Search: "
        }
    }
    
    # End w
    #
    # w      A text widget in isearch mode
    #
    # Ends the isearch process, deleting the relevant bindings,
    # tags and marks.
    
    proc End {w} {
        Log $w ""

        set tags [bindtags $w]
        ldelete tags ::marsgui::ISearch
        bindtags $w $tags
        
        $w tag delete isearch_here isearch_found
        $w mark unset isearch_start isearch_here
    }
    
    # Extend w unicode
    #
    # w         A text widget in isearch mode
    # unicode   A unicode character entered by the user
    #
    # Tries to extend the current search target in the current
    # direction.
    
    proc Extend {w unicode} {
        dict with info($w) {
            # FIRST, if the code is "", it's a special key and we can ignore
            # it.
            if {$unicode eq ""} {
                return
            }
            
            # NEXT, append the character to the target
            append _target $unicode
            
            # NEXT, clear the old target; it's history.
            set _oldtarget ""
        }
        
        # NEXT, see if we can find it.
        if {[dict get $info($w) _direction] eq "-forwards"} {
            # Search forwards from the beginning of the current match
            Search $w -forwards isearch_here
        } else {
            # Search backwards from the end of the current match
            Search $w -backwards insert
        }
    }
    
    # Backspace w
    #
    # w         A text widget in isearch mode
    #
    # Backs up in the search by deleting the last character in the
    # search target and searching in the current direction from
    # the start point.  If there's no target left, cleans up,
    # ready for a new Extend.

    proc Backspace {w} {
        dict with info($w) {
            # FIRST, delete the last character
            set _target [string range $_target 0 end-1]

            # NEXT, we're going to start the search over again from
            # start, using the current target.
            $w mark set insert isearch_start
            $w mark set isearch_here isearch_start
            
            # NEXT, if the target is empty, that's a special case.
            if {$_target eq ""} {
                $w see insert
                $w tag remove isearch_found 1.0 end
                $w tag remove isearch_here  1.0 end
                Log $w "Incremental Search:"
                return
            }
        }
        
        # NEXT, we've got a target; search forward or back
        if {[dict get $info($w) _direction] eq "-forwards"} {
            # Search forwards from the beginning of the current match
            Search $w -forwards isearch_here
        } else {
            # Search backwards from the end of the current match
            Search $w -backwards insert
        }
    }
    
    # FindNext w dir
    #
    # w    A text widget in isearch mode
    # dir  The direction of search
    #
    # This command is called when ^S or ^R is pressed during a search; it
    # jumps to the next occurrence of the current target, if any,
    # in the specified direction.  At the beginning of the search
    # process, it will pick up the old target, if any.  If there's no
    # target, it does nothing.
    
    proc FindNext {w dir} {
        # FIRST, get the target, and set the direction.
        dict with info($w) {
            set _direction $dir
            
            if {$_target eq ""} {
                set _target $_oldtarget
                
                if {$_target eq ""} {
                    return
                }
            }
        }
        
        # NEXT, see if we can find it.
        if {$dir eq "-forwards"} {
            # Search forward from the END of the current match, so that
            # we find the next one.
            Search $w -forwards insert
        } else {
            # Search forward from the BEGINNING of the current match,
            # so that we find the previous one.
            Search $w -backwards isearch_here
        }
    }
    
    #-------------------------------------------------------------------
    # Utility Procs

    # Log w message
    #
    # w        A text widget in isearch mode
    # message  The message to log
    #
    # Writes a log message to the client's log command, if any.
    
    proc Log {w message} {
        set cmd [dict get $info($w) _logger]
        
        if {$cmd eq ""} {
            set cmd [dict get $info(all) _logger]
        }
        
        if {$cmd ne ""} {
            {*}$cmd $message
        }
    }
    
    # Search w dir start
    #
    # w       A text widget in isearch mode
    # dir     The direction in which to search
    # start   The index at which to start searching.
    #
    # Searches in the specified direction for the target.
    # The target must not be "".
    
    proc Search {w dir start} {
        dict with info($w) {
            # FIRST, analyze the target.
            set len [string length $_target]
            
            if {[string is lower $_target]} {
                set nocase -nocase
            } else {
                set nocase ""
            }
        
            # NEXT, mark it everywhere
            set indices [$w search -exact {*}$nocase -all -- \
                            $_target 1.0 end]
        
            $w tag remove isearch_found 1.0 end

            foreach ndx $indices {
                $w tag add isearch_found $ndx "$ndx + $len chars"
            }
            
            # NEXT, see if we can find it.
            if {$dir eq "-forwards"} {
                # FIRST, search forwards
                set ndx [$w search -exact {*}$nocase -- \
                            $_target $start end]
                
                if {$ndx eq ""} {
                    Log $w "Not Found: $_target"
                    return
                }
                
                # NEXT, we found it; move to it and highlight it.
                Log $w "Incremental Search: $_target"
                
                if {[$w compare $ndx > isearch_here]} {
                    $w mark set isearch_here $ndx
                }
                
                $w mark set insert "$ndx + $len chars"
            } else {
                # FIRST, search backwards
                set ndx [$w search -backwards -exact {*}$nocase -- \
                            $_target $start 1.0]
                
                if {$ndx eq ""} {
                    Log $w "Not Found (backwards): $_target"
                    return
                }
                
                # NEXT, we found it; move to it and highlight it.
                Log $w "Incremental Search (backwards): $_target"
            
                set len [string length $_target]
                $w mark set isearch_here $ndx
                $w mark set insert "$ndx + $len chars"
            }
            
            # NEXT, mark this instance, and make sure the user can
            # see it.
            
            $w see insert
            $w tag remove isearch_here 1.0 end 
            $w tag add isearch_here isearch_here insert
        }
    }
}




