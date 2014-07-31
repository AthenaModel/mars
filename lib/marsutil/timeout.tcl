#-----------------------------------------------------------------------
# TITLE:
#    timeout.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) timeout manager
#
#    This object encapsulates most of the logic associated with
#    implementing a cancellable timeout with Tcl's "after" command.
#    Timeouts can be singular or auto-repeating.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export timeout
}

snit::type ::marsutil::timeout {
    #-------------------------------------------------------------------
    # Options

    # -command
    #
    # The script to call when the timeout executes.

    option -command

    # -interval
    #
    # The timeout interval, in milliseconds, or "idle"
    
    option -interval -default 1000 -validatemethod ValidateInterval

    method ValidateInterval {option value} {
        if {$value ne "idle" &&
            (![string is integer -strict $value] ||
             $value <= 0)} {
            error "invalid option $option" 
        }
    }

    # -repetition
    #
    # Boolean flag: should the timeout reschedule automatically each
    # time -command is called, or should it wait for an explicit "schedule".
    
    option -repetition -default 0

    #-------------------------------------------------------------------
    # Instance Variables

    # The after handler ID, used to cancel the pending timeout.  It is
    # set to "" when the timeout is cancelled and just before the
    # -command is called.
    variable afterID ""

    # The "active" flag.  The timeout is "active" if there's a
    # timeout scheduled.  This variable set to 1 when the timeout
    # is scheduled and to 0 on cancel and after the -command is called
    # (unless -repetition is true).  Effectively, this gives the "cancel"
    # method a way to tell the object that repetition is cancelled from
    # within the -command itself.
    variable active 0

    #-------------------------------------------------------------------
    # Constructor

    # Default constructor is fine.

    destructor {
        catch {after cancel $afterID}
    }

    #-------------------------------------------------------------------
    # Private Methods

    # AfterHandler
    #
    # Calls the user's -command (if there is one), and reschedules if
    # -repetition is true and the -command doesn't cancel.

    method AfterHandler {} {
        # FIRST, clear the afterID; we've been called.
        set afterID ""

        # NEXT, call the user's callback using bgcatch.
        if {$options(-command) ne ""} {
            ::marsutil::bgcatch {
                uplevel \#0 $options(-command)
            }
        }

        # NEXT, if we're still active and repetition is enabled, reschedule.
        # otherwise, we're no longer active--but use -nocomplain, in case
        # the callback already called schedule.
        if {$active && $options(-repetition)} {
            $self schedule -nocomplain
        } else {
            set active 0
        }
    }


    #-------------------------------------------------------------------
    # Public methods

    # schedule ?-nocomplain?
    #
    # -nocomplain      If given, schedule doesn't complain if the timeout
    #                  is already scheduled.
    #
    # Schedules the timeout to execute after the -interval.  If the timeout
    # is already scheduled and -nocomplain is given, the timeout is not
    # rescheduled; it will fire at the originally scheduled time.

    method schedule {{opt ""}} {
        # FIRST, check the option
        if {$opt ne "" && $opt ne "-nocomplain"} {
            error "Invalid option: \"$opt\""
        }

        # NEXT, is a timeout already scheduled?
        if {$afterID ne ""} {
            if {$opt eq "-nocomplain"} {
                # So don't complain!
                return
            }

            # Otherwise, complain!
            error "timeout is already scheduled"
        }

        # NEXT, no timeout is already scheduled; so schedule the after handler
        set afterID [after $options(-interval) [mymethod AfterHandler]]
        set active 1
    }

    # cancel
    #
    # Cancels any scheduled timeout.

    method cancel {} {
        # FIRST, cancel the after handler, if it's scheduled.
        if {$afterID ne ""} {
            after cancel $afterID
            set afterID ""
        }

        # NEXT, clear the active flag in any event.  Note that if cancel
        # is called by the -command, afterID is "" but active is still 1.
        set active 0
    }

    # isScheduled
    #
    # Returns true if the timeout is scheduled, and false otherwise.

    method isScheduled {} {
        expr {$afterID ne ""}
    }
}




