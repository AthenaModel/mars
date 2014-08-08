#-----------------------------------------------------------------------
# TITLE:
#    osgui.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Module for routines whose implementation is platform dependent.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export osgui
}

#-----------------------------------------------------------------------
# osgui type

snit::type osgui {
    pragma -hasinstances no

    # mktoolwindow w parent
    #
    # w      - A dialog window, usually a Tk toplevel
    # parent - The parent window, usually a Tk toplevel
    #
    # Makes window w a tool window: transient, positioned over its
    # parent, with minimal window decorations.
    #
    # On Linux and OS X, it's sufficient to mark the window transient.
    # On Windows, the window given the -toolwindow attribute, and is
    # explicitly positioned relative to its parent.

    typemethod mktoolwindow {w parent} {
        # FIRST, make sure we have toplevels.
        set w [winfo toplevel $w]
        set parent [winfo toplevel $parent]

        # NEXT, we need special handling on Windows
        if {[tk windowingsystem] eq "win32"} {
            # FIRST, it's a tool window
            wm attributes $w -toolwindow 1

            # NEXT, Get the parent's position on the screen.
            set px      [winfo rootx $parent]
            set py      [winfo rooty $parent]

            # NEXT, compute window's position
            set delta 100
            set wx [expr {$px + $delta}]
            set wy [expr {$py + $delta}]

            # NEXT, position the window
            wm geometry $w +$wx+$wy
        } else {
            # Just make it transient.

            # NOTE: [wm transient] makes sense on Windows as well...but
            # currently has a bug in it.  See Bug 3274 in the Athena
            # Bugzilla database.
            wm transient $w $parent
        }

        return
    }
}