#-----------------------------------------------------------------------
# TITLE:
#    subwin.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    subwin(n): Subordinate Window
#
#    A subwindow is a toplevel window which is subordinate to the
#    application's main window.  Subwindows have the following behavior:
#
#    * They can be popped up or down; when popped back up they remember
#      their location--even if the window manager likes to put them
#      somewhere else.
#
#    * Clicking the WM's close button pops the window down, but doesn't
#      destroy it.
#
#    * The existence of a subwindow doesn't keep the application from
#      terminating when the main window is closed--contrast this with
#      the behavior of an application with multiple main windows.
#
#    * They can be reconfigured.  The structure of subwindow content
#      often depends on data which can't be known at startup, and which
#      can change over time (e.g., after a checkpoint restore).  The
#      subwin type tracks all existing subwindows, and can pass the
#      reconfigure message along to all of them.  It's up to the
#      subwindow to acquire the data it needs to reconfigure.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export subwin
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::subwin {
    hulltype toplevel

    #-------------------------------------------------------------------
    # Type Variables

    typevariable windows {}     ;# List of existing windows.

    #-------------------------------------------------------------------
    # Type Methods

    # windows
    #
    # Lists the names of all existing subwindows.

    typemethod windows {} {
        return $windows
    }

    # hide
    #
    # Hides all existing subwindows
    
    typemethod hide {} {
        foreach w $windows {
            $w hide
        }
    }

    # show
    #
    # Shows all existing subwindows
    
    typemethod show {} {
        foreach w $windows {
            $w show
        }
    }

    # reconfigure
    #
    # Calls "reconfigure" for all existing subwindows.

    typemethod reconfigure {} {
        foreach w $windows {
            $w reconfigure
        }
    }

    #-------------------------------------------------------------------
    # Options

    # By default, all options go to the hull.
    delegate option * to hull

    #-------------------------------------------------------------------
    # Instance Variables

    variable position            ;# Saved window position, +x+y

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, save the options
        $self configurelist $args

        # NEXT, withdraw on close; don't exit.
        wm protocol $win WM_DELETE_WINDOW [mymethod WM_DELETE_WINDOW]

        # NEXT, track my existence
        lappend windows $win
    }

    destructor {
        # FIRST, Don't track me anymore
        ::marsutil::ldelete windows $win
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # WM_DELETE_WINDOW
    #
    # Just withdraw the window; don't destroy it or exit the program.
    
    method WM_DELETE_WINDOW {} {
        $self hide
    }

    #-------------------------------------------------------------------
    # Public Methods

    # show
    #
    # Pops the window up if it's been withdrawn.

    method show {} {
        if {[wm state $win] eq "withdrawn" ||
            [wm state $win] eq "iconic"} {
            wm deiconify $win
            wm geometry $win $position
        }
        raise $win
        focus $win
    }

    # hide
    #
    # Pops the window down.

    method hide {} {
        set geometry [wm geometry $win]
        set position [string range $geometry [string first + $geometry] end]
        wm withdraw $win
    }

    # reconfigure
    #
    # Reconfigures the window.  This is a no-op, to be overridden
    # by the user.

    method reconfigure {} {
        # By default, do nothing.
    }
}




