#-----------------------------------------------------------------------
# TITLE:
#   finder.tcl
# 
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Finder widget.
# 
#   This widget provides a text search control for doing incremental, 
#   wildcard, and regular expression searches of a rotext(n) widget
#   (or any other widget which implements the compatible 
#   "find/-foundcmd" protocol.  It also provides navigation buttons.
#
#   TBD:
#
#   * Reorganize the methods properly in the file.
#   * I removed a number of incremental search optimizations during
#     the scrub; at some point I should reoptimize.
#   * The -loglist option should be replaced by a listfind/listfound
#     protocol. 
# 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export finder
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ::marsgui::finder {
    #-------------------------------------------------------------------
    # Type Constructor
    
    typeconstructor {
        # FIRST, create icons used just by this widget
        namespace eval ${type}::icon {}

        mkicon ${type}::icon::first {
            XX......X
            XX.....XX
            XX....XXX
            XX...XXXX
            XX..XXXXX
            XX.XXXXXX
            XX.XXXXXX
            XX..XXXXX
            XX...XXXX
            XX....XXX
            XX.....XX
            XX......X
        } { . trans X black } d { X gray }

        mkicon ${type}::icon::prev {
            .....X
            ....XX
            ...XXX
            ..XXXX
            .XXXXX
            XXXXXX
            XXXXXX
            .XXXXX
            ..XXXX
            ...XXX
            ....XX
            .....X
        } { . trans X black } d { X gray }

        mkicon ${type}::icon::next {
            X.....
            XX....
            XXX...
            XXXX..
            XXXXX.
            XXXXXX
            XXXXXX
            XXXXX.
            XXXX..
            XXX...
            XX....
            X.....
        } { . trans X black } d { X gray }

        mkicon ${type}::icon::last {
            X......XX
            XX.....XX
            XXX....XX
            XXXX...XX
            XXXXX..XX
            XXXXXX.XX
            XXXXXX.XX
            XXXXX..XX
            XXXX...XX
            XXX....XX
            XX.....XX
            X......XX
        } { . trans X black } d { X gray }

        mkicon ${type}::icon::prevlog {
            .....X.....
            ....XXX....
            ...XXXXX...
            ..XXXXXXX..
            .XXXXXXXXX.
            XXXXXXXXXXX
            ...........
            .....X.....
            ....XXX....
            ...XXXXX...
            ..XXXXXXX..
            .XXXXXXXXX.
            XXXXXXXXXXX
        } { . trans X black } d { X gray }

        mkicon ${type}::icon::nextlog {
            XXXXXXXXXXX
            .XXXXXXXXX.
            ..XXXXXXX..
            ...XXXXX...
            ....XXX....
            .....X.....
            ...........
            XXXXXXXXXXX
            .XXXXXXXXX.
            ..XXXXXXX..
            ...XXXXX...
            ....XXX....
            .....X.....
        } { . trans X black } d { X gray }

        mkicon ${type}::icon::stop {
            XXXXXXXX
            XXXXXXXX
            XXXXXXXX
            XXXXXXXX
            XXXXXXXX
            XXXXXXXX
            XXXXXXXX
            XXXXXXXX
        } { . trans X black } d { X gray }
    }
    

    #-------------------------------------------------------------------
    # Components
    
    component f    ;# The commandentry's frame
    
    #-------------------------------------------------------------------
    # Options

    # -findcmd cmd
    # 
    # The command to call when it's time to find some text.
    option -findcmd
    
    # -loglist
    #
    # The loglist component to search.
    option -loglist -default ""
    
    # -targettype
    #
    # The default search type: incremental, exact, wildcard, or regexp.
    # Defaults to incremental.
    option -targettype -default "exact" -configuremethod ConfigureTargetType

    method ConfigureTargetType {option value} {
        # FIRST, save the value.
        set options($option) $value

        # NEXT, trigger a search
        $self TargetTypeChanged
    }

    # -msgcmd    
    #     
    # A command for reporting messages, usually to the application's
    # message line.  It should take one additional argument.
    option -msgcmd -default ""

    # -multicol
    #     
    # When enabled, indicates that the target of searchback spans multiple
    # columns.  This is used to control -loglist's -formattext option.
    # This option has no effect if -loglist is not specified.
    option -multicol -type snit::boolean -default 0 \
        -configuremethod MultiColChanged
    
    # Delegate all other options to the hull
    delegate option * to hull
    
    #-------------------------------------------------------------------
    # Instance Variables

    # Status display string.
    variable status "0 of 0"
    
    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, Create the entry, options are delegated to it.
        installhull using ::marsgui::commandentry         \
            -clearbtn           yes                       \
            -changecmd          [mymethod TargetChanged]  \
            -returncmd          [mymethod DoSearch]       \

        # NEXT, Save the constructor options.
        $self configurelist $args
        
        # NEXT, get the commandentry's frame, so we can put stuff in it.
        install f using $hull frame
            
        # NEXT, Create the magnifying glass menu.
        set menu $f.type.menu
        ttk::menubutton $f.type                \
            -style   Entrybutton.Toolbutton    \
            -image   ::marsgui::icon::search   \
            -menu    $menu
        
        DynamicHelp::add $f.type \
            -text "Search Options Menu"
                
        menu $menu

        $menu add radio                              \
            -label      "Incremental"                \
            -variable   [myvar options(-targettype)] \
            -value      "incremental"                \
            -command    [mymethod TargetTypeChanged]
            
        $menu add radio                              \
            -label      "Exact"                      \
            -variable   [myvar options(-targettype)] \
            -value      "exact"                      \
            -command    [mymethod TargetTypeChanged]
            
        $menu add radio                              \
            -label      "Wildcard"                   \
            -variable   [myvar options(-targettype)] \
            -value      "wildcard"                   \
            -command    [mymethod TargetTypeChanged]
            
        $menu add radio                              \
            -label      "Regexp"                     \
            -variable   [myvar options(-targettype)] \
            -value      "regexp"                     \
            -command    [mymethod TargetTypeChanged]

        # If searchback will be enabled, provide the multi-column option
        if {$options(-loglist) ne ""} {
            $menu add separator

            $menu add checkbutton                      \
                -label      "Multi-column Searchback"  \
                -variable   [myvar options(-multicol)] \
                -command    [mymethod MultiColChanged] 
        }

        ttk::button $f.first                    \
            -style    Entrybutton.Toolbutton    \
            -image    [GetIcon first]           \
            -state    disabled                  \
            -command  [mymethod GoToFirst]

        ttk::button $f.prev                     \
            -style    Entrybutton.Toolbutton    \
            -image    [GetIcon prev]            \
            -state    disabled                  \
            -command  [mymethod GoToPrev]

        ttk::button $f.next                     \
            -style    Entrybutton.Toolbutton    \
            -image    [GetIcon next]            \
            -state    disabled                  \
            -command  [mymethod GoToNext]

        ttk::button $f.last                     \
            -style    Entrybutton.Toolbutton    \
            -image    [GetIcon last]            \
            -state    disabled                  \
            -command  [mymethod GoToLast]

        ttk::label $f.status                    \
            -background     white               \
            -anchor         center              \
            -textvariable   [varname status]    \
            -relief         flat                \
            -width          15                  \
            -state          disabled
        
        if {$options(-loglist) ne ""} {
            ttk::button $f.prevlog                      \
                -style    Entrybutton.Toolbutton        \
                -image    [GetIcon prevlog]             \
                -state    disabled                      \
                -command  [mymethod SearchLogs earlier]

            ttk::button $f.stop                         \
                -style    Entrybutton.Toolbutton        \
                -image    [GetIcon stop]                \
                -state    disabled                      \
                -command  [mymethod StopSearch]
            
            ttk::button $f.nextlog                      \
                -style    Entrybutton.Toolbutton        \
                -image    [GetIcon nextlog]             \
                -state    disabled                      \
                -command  [mymethod SearchLogs later]
        }     
    
        # NEXT, Lay out the components
        pack forget {*}[pack slaves $f]
        pack $f.type -side left

        pack $f.last   -side right -padx {0 2}
        pack $f.next   -side right
        pack $f.prev   -side right
        pack $f.first  -side right
        pack $f.status -side right
        
        # Add the loglist search controls if needed
        if {$options(-loglist) ne ""} {
            pack $f.nextlog -side right
            pack $f.stop    -side right
            pack $f.prevlog -side right -padx {4 0}
        }
        
        pack $f.clear -side right
        pack $f.entry -fill x -expand yes
        
        return
    }

    # GetIcon name
    #
    # name      root name of one of the icons defined above
    #
    # Returns a -image value for a ttk::button.
    proc GetIcon {name} {
        list ::marsgui::finder::icon::$name \
            disabled ::marsgui::finder::icon::${name}d
    }



    #-------------------------------------------------------------------
    # Private Methods

    # MultiColChanged
    #
    # Called when the -multicol is changed via the icon menu or via
    # configure.  Informs the -loglist of the change if -loglist is
    # defined.

    method MultiColChanged {} {
        if {$options(-loglist) ne ""} {
            $options(-loglist) configure -formattext $options(-multicol)
        }
    }

    # TargetTypeChanged
    #
    # Called when the -targettype is changed via the icon menu or via
    # configure.  Executes a new search.

    method TargetTypeChanged {} {
        $hull execute
    }

    # TargetChanged text
    #
    # text        Current content of the target entry
    #
    # Makes changes as the target string changes.

    method TargetChanged {text} {
        # FIRST, Check for emptiness.
        if {[string is space $text]} {
            $hull clear
            set text ""
        }

        # NEXT, Enable/disable the clear button and file search buttons.
        if {$options(-loglist) ne ""} {
            if {$text eq ""} {
                $f.prevlog  configure -state disabled
                $f.nextlog  configure -state disabled
            } else {
                $f.prevlog  configure -state normal
                $f.nextlog  configure -state normal
            }
        }

        # NEXT, If searching is incremental, or if the entry is now
        # clear, update the search state.
        if {$text eq "" || $options(-targettype) eq "incremental"} {
            $self DoSearch $text
        }
    }

    # DoSearch target
    #
    # target     A new target string
    #
    # Execute a search with the new target string.
    method DoSearch {target} {
        # FIRST, Ignore empty targets.
        if {[string is space $target]} {
            $hull clear

            set target ""
        }
                
        # NEXT, if the search type is regexp, check the target for
        # validity.
        if {$options(-targettype) eq "regexp"} {
            if {[catch {regexp -- $target dummy} result]} {
                $self Message "invalid regexp: \"[$hull get]\""
                bell
                return
            }
        }


        # NEXT, call the -findcmd.
        if {$options(-targettype) eq "incremental"} {
            set searchType "exact"
        } else {
            set searchType $options(-targettype)
        }

        callwith $options(-findcmd) target $searchType $target
    }

    # GoToFirst
    #
    # Highlight and center the first line matching the search target.
    method GoToFirst {} {
        callwith $options(-findcmd) show 0
    }
    
    # GoToLast
    #
    # Highlight and center the last line matching the search target.
    method GoToLast {} {
        callwith $options(-findcmd) show end
    }
    
    # GoToNext
    #
    # Highlight and center the next line matching the search target.
    method GoToNext {} {
        callwith $options(-findcmd) next
    }
    
    # GoToPrev
    #
    # Highlight and center the previous line matching the search target.
    method GoToPrev {} {
        callwith $options(-findcmd) prev
    }
    
    # SearchLogs direction
    #
    # direction "earlier" or "later"
    #
    # Executes the current search in the loglist in the specified direction.
    # If the search hits, execute the same search in the logdisplay.
    method SearchLogs {direction} {
        # Get the current target; return if it's empty.
        if {[set target [$hull get]] eq ""} {return}
        
        # Incremental searches are actually exact searches.
        if {$options(-targettype) eq "incremental"} {
    
            set searchType "exact"
        
        } else {
        
            set searchType $options(-targettype)
        }
        
        # If doing regexp check the target pattern validity first
        if {$options(-targettype) eq "regexp"} {
            if {[catch {regexp -- $target dummy} result]} {
                $self Message "invalid regexp: \"[$hull get]\""
                bell
                return
            }
        }

        # Enable the stop button; disable the search buttons.
        $f.stop     configure -state normal
        $f.prevlog  configure -state disabled
        $f.nextlog  configure -state disabled
        
        # Execute the search.
        if {[$options(-loglist) searchlogs $direction $target $searchType]} {
            $self DoSearch $target
        }
        
        # Disable the stop button; enable the search buttons.
        $f.stop     configure -state disabled 
        $f.prevlog  configure -state normal
        $f.nextlog  configure -state normal
    }
    
    # StopSearch
    #
    # Stop the current loglist search.
    method StopSearch {} {
        $options(-loglist) stopsearch
    }
    
    # SetNavButtons state
    #
    # state     normal or disabled
    #
    # Set the state of the navigation buttons.
    method SetNavButtons {state} {
        $f.first  configure -state $state
        $f.prev   configure -state $state
        $f.next   configure -state $state
        $f.last   configure -state $state
    }

    # Message msg
    #
    # msg   A message string
    #
    # Logs a message using the -msgcmd.
    method Message {msg} {
        callwith $options(-msgcmd) $msg
    }
    
    #-------------------------------------------------------------------
    # Public Methods
    
    # found count instance
    #
    # count     Number of lines found (or 0)
    # instance  Instances which is highlighted, 0 to count-1 (or -1)
    # 
    # Updates the display to reflect the results.  This is usually
    # called by a rotext(n) widget's -foundcmd.

    method found {count instance} {
        if {$count == 0} {
            set status "0 of 0"

            if {[$hull get] eq ""} {
                $f.status configure -state disabled

                if {$options(-loglist) ne ""} {
                    $f.prevlog configure -state disabled
                    $f.nextlog configure -state disabled
                }
            } else {
                $f.status configure -state normal
            }

            $self SetNavButtons disabled

        
        } else {
            let line {$instance + 1}
            set status "$line of $count"
            $f.status configure -state normal

            if {$count > 0} {
                $self SetNavButtons normal
            } else {
                $self SetNavButtons disabled
            }
        }
    }
}






