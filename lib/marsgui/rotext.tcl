#-----------------------------------------------------------------------
# TITLE:
#    rotext.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Read-only Text Widget
#
#    This widget provides a read-only text widget for displaying
#    arbitrary text.  The API is identical to the standard text
#    widget, with these exceptions:
#
#    * Use "ins" and "del" instead of "insert" and "delete" 
#    * Keyboard bindings are updated for browsing
#    * Supports <<SelectAll>> event.
#    * Supports the find/found protocol, so that finder(n) can search
#      it.  This code is based on Dave Jaffe's earlier finder(n)
#      implementation.
#
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export rotext
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ::marsgui::rotext {
    #-------------------------------------------------------------------
    # Inherit text behavior

    delegate option * to hull
    delegate method * to hull

    #-------------------------------------------------------------------
    # Other options

    # -font font
    #
    # Explicitly delegated to the hull; but also define a bolded
    # version of this font.  options(-font) is ignored.

    option -font -configuremethod ConfigureFont -cgetmethod CgetFont

    method ConfigureFont {option value} {
        # FIRST, pass the font to the hull.
        $hull configure -font $value

        # NEXT, create a bolded version
        set spec [font actual $value]
        catch {font delete $win.boldfont}
        eval font create $win.boldfont $spec
        font configure $win.boldfont -weight bold
    }

    method CgetFont {option} {
        $hull cget -font
    }

    # -foundcmd cmd
    #
    # A command prefix to call when the rotext is showing an instance
    # of a find target.  Two arguments will be appended to the prefix:
    # N, the number of instances found, and the index of the current
    # instance, 0 to N-1.

    option -foundcmd -default ""

    #-------------------------------------------------------------------
    # Instance variables

    # found    Array of data relating to found search targets
    #
    #   target        The search target, or ""
    #   targetType    The target type, or ""
    #   targetRegexp  The target expressed as a regexp, or ""
    #   count         Number of found instances; 0 if none or no search.
    #   instance      Index (0 to num-1) of the highlighted instance, or -1.
    #   lines         List of found line numbers.

    variable found -array {
        target       ""
        targetType   ""
        targetRegexp ""
        count        0
        instance     -1
        lines        {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the hull
        installhull [text $win \
                         -width 80 \
                         -height 24 \
                         -wrap none \
                         -insertwidth 0]

        # NEXT, set the default font.  Use $self configure, so that
        # the bolded version is created.
        $self configure -font codefont

        # NEXT, accept additional options
        $self configurelist $args

        # NEXT, define some key bindings
        bind $win <Prior>       [mymethod Prior]
        bind $win <Next>        [mymethod Next]
        bind $win <Home>        [mymethod Home]
        bind $win <End>         [mymethod End]
        bind $win <Up>          [mymethod Up]
        bind $win <Down>        [mymethod Down]
        bind $win <Left>        [mymethod Left]
        bind $win <Right>       [mymethod Right]

        bind $win <<SelectAll>> [mymethod selectAll]

        # NEXT, define some tags for marking found text
        # TBD: Document these tag names in rotext(n)!
        $hull tag configure FOUND \
            -font $win.boldfont   \
            -underline yes 

        $hull tag configure SHOWN \
            -background black     \
            -foreground white

        # NEXT, raise the selection tag above these
        $hull tag raise sel
    }

    #-------------------------------------------------------------------
    # Keyboard Navigation Methods

    # Prior
    #
    # Page up

    method Prior {} {
        $hull yview scroll -1 pages

        # Break, since we're overriding the default behavior
        return -code break
    }

    # Next
    #
    # Page down

    method Next {} {
        $hull yview scroll 1 pages

        # Break, since we're overriding the default behavior
        return -code break
    }

    # Up
    #
    # Scroll up

    method Up {} {
        $hull yview scroll -1 units

        # Break, since we're overriding the default behavior
        return -code break
    }

    # Down
    #
    # Scroll down

    method Down {} {
        $hull yview scroll 1 units

        # Break, since we're overriding the default behavior
        return -code break
    }

    # Left
    #
    # Scroll left

    method Left {} {
        $hull xview scroll -1 units

        # Break, since we're overriding the default behavior
        return -code break
    } 

    # Right
    #
    # Scroll right

    method Right {} {
        $hull xview scroll 1 units

        # Break, since we're overriding the default behavior
        return -code break
    }

    # Home
    #
    # See beginning of text

    method Home {} {
        $hull see 1.0

        # Break, since we're overriding the default behavior
        return -code break
    }

    # End
    #
    # See end of text

    method End {} {
        $hull see end

        # Break, since we're overriding the default behavior
        return -code break
    }

    #-------------------------------------------------------------------
    # General Public Methods

    # The new methods "ins" and "del" are delegated to the hull's
    # insert and delete methods.

    delegate method ins to hull as insert
    delegate method del to hull as delete

    # The insert and delete options are redefined as no-ops.
    method insert {args} {}
    method delete {args} {}

    # selectAll
    #
    # Selects all text in the widget

    method selectAll {} {
        $hull tag add sel 1.0 end
        update idletasks
    }

    #-------------------------------------------------------------------
    # "find" methods, public and private

    # find target targetType target
    #
    # targetType    exact, wildcard, or regexp
    # target        A search target of the specified type
    #
    # Finds all instances of the target, displays the final one,
    # and calls -foundcmd.  If target is "", the search is cleared.

    method {find target} {targetType target} {
        # FIRST, This is a new search; clear the display
        set found(count)        0
        set found(instance)     -1
        set found(lines)        {}

        $hull tag remove FOUND 1.0 end
        $hull tag remove SHOWN 1.0 end

        # NEXT, if the target is empty or just whitespace, do no search.
        if {[string is space $target]} {
            # FIRST, clear the search state
            set found(target)       ""
            set found(targetType)   ""
            set found(targetRegexp) ""

            # NEXT, notify clients that there are no search results.
            callwith $options(-foundcmd) 0 -1

            return
        }

        # NEXT, save the search target, converting it a regular
        # expression.
        set found(target)     $target
        set found(targetType) $targetType

        switch -exact $targetType {
            exact {
                # JLS: This syntax no longer works with 8.5!
                # See bug1647
                set found(targetRegexp) "***=$target"
            }
            wildcard {
                set found(targetRegexp) [::marsutil::wildToRegexp $target]
            }
            regexp {
                set found(targetRegexp) $target
            }
            default {
                error "invalid target type: \"$targetType\""
            }
        }

        # NEXT, Look for the target
        $self FindTarget
    }

    # find update ?force?
    #
    # ?force?    If true, will force the last match to be highlighted.
    #
    # Use this after modifying the text in the widget; it will update
    # the search
    
    method {find update} {{force 0}} {
        if {$found(target) ne ""} {
            $self FindTarget $force
        }
    }

    # FindTarget ?force?
    #
    # ?force?    If true, will force the last match to be highlighted.
    # 
    # Finds instances of the target.  Called when a new target is specified,
    # and when text is added or deleted.  In the latter case, the 
    # highlighted line will not change (unless the instance of the
    # target is deleted).

    method FindTarget {{force 0}} {
        # FIRST, is this a new search?
        if {$found(count) == 0} {
            set newSearch 1
        } else {
            set newSearch 0
        }

        # NEXT, we'll do a fresh search from scratch.
        set found(count) 0
        set found(lines) {}

        # NEXT, search through the text from the top.  We'll
        # break out of the loop when we're at the end.
        set index 1.0
        set lastLine -1

        while {1} {
            # FIRST, did we find it?
            set result [$hull search             \
                            -regexp              \
                            -count chars         \
                            --                   \
                            $found(targetRegexp) \
                            $index               \
                            end]

            if {$result eq ""} {
                break
            }

            # NEXT, highlight the match
            $hull tag add FOUND $result "$result + $chars chars"
            
            # NEXT, skip to the end of the line.
            set index "$result lineend"

            # NEXT, if the match is on a new line it counts as
            # a new instance.
            set line [lindex [split $result .] 0]

            if {$line != $lastLine} {
                lappend found(lines) $line
                set lastLine $line

                incr found(count)
            }
        }

        # NEXT, did we find anything?
        if {$found(count) == 0} {
            callwith $options(-foundcmd) 0 -1
            return
        }

        # NEXT, if this is an old search, see if the highlighted line
        # still has a match; if so, show it again.
        if {!$newSearch  && !$force} {
            set range [$hull tag nextrange SHOWN 1.0]
            if {$range ne ""} {
                set index [lindex $range 0]
                set line [lindex [split $index .] 0]

                set instance [lsearch -exact -integer $found(lines) $line]

                if {$instance != -1} {
                    $self find show $instance
                    return
                }
            }
        }

        # NEXT, since there's no previous instance show the last one
        $self find show end
    }

    # find count
    #
    # Returns the number of instances found.
    
    method {find count} {} {
        return $found(count)
    }

    # find instance
    #
    # Returns the index of the highlighted instance, or -1 if none.
    
    method {find instance} {} {
        return $found(instance)
    }

    # find show instance
    #
    # instance    The index of the instance to show, 0 to num-1, or "end".
    #
    # Highlights the chosen instance and scrolls the widget so that
    # it is visible.

    method {find show} {instance} {
        # FIRST, if the instance is "end", it's really count-1
        if {$instance eq "end"} {
            let instance {$found(count) - 1}
        }

        # NEXT, is this a valid instance?
        if {$instance < 0 || $instance >= $found(count)} {
            bell
            return
        }

        # NEXT, Save the instance number
        set found(instance) $instance

        # NEXT, update the SHOWN tag
        set line [lindex $found(lines) $instance]

        $hull tag remove SHOWN 1.0    end
        $hull tag add    SHOWN $line.0 "$line.0 + 1 lines linestart"

        # NEXT, move the highlighted line to the center of the text
        # window.

        set lastLine [lindex [split [$hull index "end linestart"] .] 0]
        let lineFraction {double($line)/$lastLine}

        set coords [$hull yview]
        let size  {[lindex $coords 1] - [lindex $coords 0]}

        # NOTE, yview is doing the rangechecking and clipping automatically.
        $hull yview moveto [expr {$lineFraction - $size/2}]

        # NEXT, notify the client
        callwith $options(-foundcmd) $found(count) $found(instance)
    }

    # find next
    #
    # Highlights the next instance after that currently shown, if any.

    method {find next} {} {
        # Note: if there's no next, find show will beep.
        $self find show [expr {$found(instance) + 1}]
    }

    # find prev
    #
    # Highlights the previous instance before that currently shown, if any.

    method {find prev} {} {
        # Note: if there's no prev, find show will beep.
        $self find show [expr {$found(instance) - 1}]
    }
}







