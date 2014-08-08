#-----------------------------------------------------------------------
# TITLE:
#   eventq.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   marsutil(n) simulation event queue manager.
#
#   The event queue is implemented as a single table in an SQLite3
#   run-time database, with an additional table for each type of event.  
#   A view that joins the queue with the event type table is defined 
#   for each event type, to make updating events easier.
#
#   Event handlers are procs that retrieve the event data from the RDB
#   and execute the event body.  Each event has its own list of
#   zero or more.
#
# SIMULATION TIME:
#   The eventq expresses simulated time in integer ticks, starting at
#   0.  The simulated time is updated as events execute, and is reset
#   to "just before" 0 on [eventq restart].  Events can be scheduled
#   at time 0, and the eventq can be advanced to 0.
#
# ADVANCING TIME:
#   eventq(n) is designed to provide discrete event capability within
#   a time-step simulation.  The "advance" method advances the eventq(n)
#   time up until the specified time; this can be called by the parent
#   simulation at each time step.  Hence, eventq does NOT use or update
#   a simclock(i); it presumes that the parent simulation will do that,
#   if need be.
#
#   eventq(n) could also be used for pure discrete event simulation;
#   in this case, it would be necessary to allow eventq(n) to advance
#   a simclock(i).
#
# NICE TO HAVE:
#   * Move lfilter to marsutil(n).
#   * Save pretty-printed args in the eventq_queue table, for browsing.
#     * Use a trigger to set them.
#   * Events should allow full proc argument list syntax.
#   * Should be possible to pass arguments to an event using a standard
#     argument list, or a dictionary.  This possibly needs to be set
#     when the event is defined.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export eventq
}

#-----------------------------------------------------------------------
# Event Queue

snit::type ::marsutil::eventq {
    pragma -hasinstances no -hastypeinfo no -hastypedestroy no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent rdb      ;# The run-time database (sqldocument(n))

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # FIRST, Define data types
        snit::stringtype eqidentifier -regexp {^[[:alpha:]]+\w*$}

        # NEXT, There is no RDB initially
        set rdb [myproc NullRDB]
    }

    #-------------------------------------------------------------------
    # sqlsection(i) implementation
    #
    # The following variables and routines implement the module's 
    # sqlsection(i) interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "eventq(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, if any.

    typemethod {sqlsection schema} {} {
        set schema [outdent {
            CREATE TABLE eventq_queue (
                id    INTEGER PRIMARY KEY,   -- Event ID
                t     INTEGER,               -- Activation Time
                etype TEXT                   -- Event Type
            );

            CREATE INDEX eventq_index_queue ON eventq_queue(t, id);
        }]

        foreach etype $etypes(names) {
            append schema "\n"
            append schema $etypes(schema-$etype)
        }

        return $schema
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, if any.

    typemethod {sqlsection tempschema} {} {
        return ""
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes

    typemethod {sqlsection functions} {} {
        return ""
    }

    #-------------------------------------------------------------------
    # Non-checkpointed Type Variables

    # etypes - general event info array
    #
    # names             List of event type names (identifiers)
    # eargs-$etype      List of argument names, by event type
    # handler-$etype    Name of event handler proc, by event type
    # schedule-$etype   Name of event scheduler proc, by event type
    # schema-$etype     SQL Schema definition, by event type
    
    typevariable etypes -array {
        names           {}
    }

    # flags
    #
    #   changed      1 if there's unchanged data in info(), and 0 o.w.

    typevariable flags -array {
        changed 0
    }

    #-------------------------------------------------------------------
    # Checkpointed Type Variables

    # info - General info array
    #
    # time              Current simulation time.  -1 means that time
    #                   has never been advanced.
    # eventCounter      Generated event IDs
    
    typevariable info -array {
        time            -1
        eventCounter    0
    }    

    #-------------------------------------------------------------------
    # Introspection Type Methods

    # etypes
    #
    # Returns a list of the names of the currently defined event types.
    
    typemethod etypes {} {
        return $etypes(names)
    }

    # now
    #
    # Returns current simulation time, in integer ticks.

    typemethod now {} {
        return $info(time)
    }

    # eventcount
    # 
    # Returns number of events to date

    typemethod eventcount {} {
        return $info(eventCounter)
    }

    # size
    #
    # Returns number of events in queue
    
    typemethod size {} {
        $rdb onecolumn {SELECT count(id) FROM eventq_queue}
    }

    #-------------------------------------------------------------------
    # Event Queue Control

    # init db
    #
    # db     The command name of an initialized sqldocument(n).
    #
    # Initialize the module.

    typemethod init {db} {
        # FIRST, make sure the schema is defined.
        require {$type in [$db sections]} \
            "eventq(n) is not registered with database $db"

        # NEXT, save the RDB
        set rdb $db
    }

    # advance max_t
    #
    # max_t     Time to advance to.
    #
    # Runs simulation until there are no more events with t <= max_t.
    #
    # TBD: This needs to catch errors in event handlers.

    typemethod advance {max_t} {
        EnsureTimeInFuture $max_t

        set t -1

        while {$t <= $max_t} {
            # FIRST, Get the next event
            set id 0

            $rdb eval {
                SELECT t, id, etype FROM eventq_queue
                WHERE t <= $max_t
                ORDER BY t, id
                LIMIT 1
            } {}

            if {$id == 0} {
                # No more events.
                set info(time) $max_t
                break
            }

            # Update the sim time
            set info(time) $t
            set flags(changed) 1

            # Execute the event handler
            if {[catch {
                $etypes(handler-$etype) $id
            } result]} {
                set data [$rdb eval "
                    SELECT * FROM eventq_queue_$etype
                    WHERE id=\$id
                "]
                bgerror "Error in event $etype $id:\nData: $data\nError: $result"
            }

            # Delete the event, unless it has been rescheduled
            # in the future.
            if {[$rdb onecolumn {
                SELECT t FROM eventq_queue WHERE id=$id
            }] <= $info(time)} {
                $rdb eval "
                    DELETE FROM eventq_etype_${etype} WHERE id=\$id;
                    DELETE FROM eventq_queue WHERE id=\$id;
                "
            }
        }
    }

    # reset
    #
    # Reset the event queue as of the current sim time, deleting 
    # any queued events.  The event counter, etc., are left alone;
    # event IDs will not be reused.

    typemethod reset {} {
        set query "DELETE FROM eventq_queue;\n"

        foreach etype $etypes(names) {
            append query "DELETE FROM eventq_etype_${etype};\n"
        }

        $rdb eval $query
    }

    # restart
    #
    # Restart the event queue, setting everything back to its state
    # as of time 0.  Event IDs will restart at 1.

    typemethod restart {} {
        # FIRST, reset the queue.
        $type reset
        
        # NEXT, reset the event counter
        set info(time)         -1
        set info(eventCounter) 0
        set flags(changed)     1
    }

    #-------------------------------------------------------------------
    # Defining and Manipulating Event Types


    # define etype eargs body
    #
    # etype       Event type name (an identifier)
    # eargs       Event argument list 
    # body        Event body: gets t, id, and eargs predefined.
    #
    # Defines a new event type.  Instances of the event type can
    # be scheduled with the specified arg list; when the event
    # executes, the body will be called as a proc.  The body's namespace
    # is that in which the event is defined.
    #
    # It is OK to redefine an event's body by calling this command
    # again; however, the arguments may not be changed.

    typemethod define {etype eargs body} {
        # FIRST, validate the event type.  If this is a new etype,
        # validate its name; otherwise, make sure we aren't redefining
        # the args.

        if {[lsearch -exact $etypes(names) $etype] == -1} {
            set newEvent 1

            eqidentifier validate $etype

            foreach argname $eargs {
                eqidentifier validate $argname
            }

            lappend etypes(names) $etype
            set etypes(eargs-$etype) $eargs
        } else {
            set newEvent 0

            # Verify that the argument list hasn't changed.
            require {$etypes(eargs-$etype) eq $eargs} \
                "redefined arguments for event \"$etype\" as \"$eargs\""
        }

        # NEXT, define the handler proc
        set ns [uplevel 1 {namespace current}]
        if {$ns eq "::"} {
            set ns ""
        }

        set etypes(handler-$etype) ${ns}::eventq_handler_${etype}

        proc $etypes(handler-$etype) {id} [tsubst {
            |<--
            # Retrieve the event data
            \$::marsutil::eventq::rdb eval {
                SELECT * FROM eventq_queue_${etype}
                WHERE id=\$id
            } {}

            # Execute the event handler.
            $body
        }]

        # NEXT, This is a new event; update the schema and define the
        # scheduler.

        if {$newEvent} {
            # FIRST, Save the schema for this event type
            set etypes(schema-$etype) [tsubst {
                |<--
                CREATE TABLE eventq_etype_${etype} (
                    -- Event ID
                    id    INTEGER PRIMARY KEY

                    -- Event arguments
                    [tif {[llength $etypes(eargs-$etype)] > 0} {
                        ,[join $etypes(eargs-$etype) ,]
                    }]
                );

                CREATE VIEW eventq_queue_${etype} AS
                SELECT * 
                FROM eventq_queue JOIN eventq_etype_${etype} USING (id)
                ORDER BY t, id;
            }]

            # NEXT, if we have an RDB already, go ahead and define it in
            # the RDB.
            if {$rdb ne [myproc NullRDB]} {
                $rdb eval $etypes(schema-$etype)
            }

            # NEXT, Define the scheduler proc
            set etypes(schedule-$etype) ${ns}::eventq_schedule_${etype}

            proc $etypes(schedule-$etype) [concat id $etypes(eargs-$etype)] \
                [tsubst {
                |<--
                \$::marsutil::eventq::rdb eval {
                    INSERT INTO eventq_etype_${etype}(id
                    [tif {[llength $etypes(eargs-$etype)] > 0} {
                        ,[join $etypes(eargs-$etype) ,]
                    }]
                    )                                  
                    VALUES(\$id
                    [tif {[llength $etypes(eargs-$etype)] > 0} {
                        ,\$[join $etypes(eargs-$etype) ,\$]
                    }]
                    );
                }
            }]
        }
    }


    # destroy pattern
    #
    # pattern      A glob pattern that matches 1 or more etype names
    #
    # Cancels all events of this type, and removes the event type
    # from the schema and from all datastructures

    typemethod destroy {pattern} {
        foreach etype [lfilter $etypes(names) $pattern] {
            # FIRST, remove all events of this type from the event queue,
            # and drop the tables and views related to this type.
            $rdb eval "
                DELETE FROM eventq_queue WHERE etype=\$etype;
                DROP VIEW  eventq_queue_${etype};
                DROP TABLE eventq_etype_${etype};
            "

            # NEXT, remove the event procs
            rename $etypes(handler-$etype) ""
            rename $etypes(schedule-$etype) ""

            # NEXT, remove all traces from the global data
            ldelete etypes(names) $etype

            array unset etypes *-$etype
        }
    }

    #-------------------------------------------------------------------
    # Scheduling and Cancelling Events

    # schedule etype t args...
    # 
    # etype     The event type
    # t         The sim time, > [eventq now]
    # args...   As defined by the event type
    #
    # Schedules an event as of time t, returning the event ID.
    
    typemethod schedule {etype t args} {
        return [$type ScheduleEvent "" $etype $t {*}$args]
    }


    # scheduleWithID id etype t args...
    # 
    # id        The ID of the event.
    # etype     The event type
    # t         The sim time, > [eventq now]
    # args...   As defined by the event type
    #
    # Schedules an event as of time t, using a previously
    # cancelled or executed event ID.
    #
    # This command is intended to allow an event cancellation to
    # be undone.
    
    typemethod scheduleWithID {id etype t args} {
        if {![string is integer -strict $id] 
            || $id < 1                          
            || $id > $info(eventCounter)
        } {
            error "event ID is out of range."
        }
        return [$type ScheduleEvent $id $etype $t {*}$args]
    }


    # ScheduleEvent id etype t args...
    # 
    # id        The ID of the event, or ""
    # etype     The event type
    # t         The sim time, > [eventq now]
    # args...   As defined by the event type
    #
    # Schedules an event as of time t, using a specific event ID,
    # which must be unused.
    #
    # This command is intended to allow an event cancellation to
    # be undone.
    
    typemethod ScheduleEvent {id etype t args} {
        # FIRST, error checking
        EnsureEventTypeExists $etype
        EnsureTimeInFuture    $t

        # NEXT, get the event ID; or, if it's specified, verify that
        # it doesn't exist.

        if {$id eq ""} {
            set id [incr info(eventCounter)]
            set flags(changed) 1
        } else {
            if {[$rdb exists {SELECT id FROM eventq_queue WHERE id=$id}]} {
                error "event already exists with ID: \"$id\""
            }
        }
        
        # Insert the event into the queue.
        $rdb eval {
            INSERT INTO eventq_queue(id,t,etype) 
            VALUES($id, $t, $etype);
        }

        # Insert the event args into the etype table
        uplevel \#0 [linsert $args 0 $etypes(schedule-$etype) $id]

        return $id
    }


    # reschedule id t
    #
    # id        The event ID
    # t         The sim time, > [eventq now]
    #
    # Reschedules the event to occur at the new time.  Note that
    # this may be done within the event type's event handler.

    typemethod reschedule {id t} {
        # Check for errors
        EnsureEventIdExists $id
        EnsureTimeInFuture  $t

        # Update the time
        $rdb eval {
            UPDATE eventq_queue
            SET t = $t
            WHERE id = $id
        }
    }

    # cancel id
    #
    # id      The event ID
    #
    # Cancel the event, deleting it from the event queue

    typemethod cancel {id} {
        # FIRST, verify that the event exists
        set etype {}
        $rdb eval {
            SELECT etype,t FROM eventq_queue
            WHERE id=$id
        } {}

        if {$etype eq ""} {
            error "no event with id: \"$id\""
        }

        # NEXT, get the undo information from the event type
        # table
        set eargs [$rdb eval "
            SELECT * FROM eventq_etype_${etype} WHERE id=\$id;
        "]

        # NEXT, delete it.
        $rdb eval "
            DELETE FROM eventq_etype_${etype} WHERE id=\$id;
            DELETE FROM eventq_queue WHERE id=\$id;
        "

        return [linsert $eargs 1 $etype $t]
    }

    # undo schedule
    #
    # Undoes the most recently scheduled event, decrementing the
    # event counter.

    typemethod {undo schedule} {} {
        if {$info(eventCounter) == 0} {
            error "No event has been scheduled"
        }

        if {![$rdb exists {
            SELECT id FROM eventq_queue WHERE id=$info(eventCounter)
        }]} {
            error "most recent scheduled event no longer exists"
        }

        $type cancel $info(eventCounter)
        incr info(eventCounter) -1
    }

    # undo cancel undoToken
    # 
    # undoToken   The data required to undo the cancellation.
    #
    # Reschedules a cancelled event.
    
    typemethod {undo cancel} {undoToken} {
        return [$type ScheduleEvent {*}$undoToken]
    }


    #-------------------------------------------------------------------
    # Checkpoint/Restore
    #
    # TBD: This code is non-optimal, as it only checkpoints the in-memory
    # data.  Modules that explicitly store data in the RDB should be able
    # to checkpoint themselves directly to the RDB.  We need a new 
    # protocol (possibly notifier(n)-based) for this.

    # checkpoint ?-saved?
    #
    # Return a copy of the module's state for later restoration.
    # Note that data stored in the RDB is presumed to be checkpointed
    # by the application.
    
    typemethod checkpoint {{option ""}} {
        if {$option eq "-saved"} {
            set flags(changed) 0
        }

        return [array get info]
    }

    # restore state ?-saved?
    #
    # state     Checkpointed state returned by the checkpoint method.
    #
    # Restores the checkpointed state; this is just the reverse of
    # "checkpoint".

    typemethod restore {state {option ""}} {
        # First, restore the state.
        array unset info
        array set info $state

        if {$option eq "-saved"} {
            set flags(changed) 0
        }
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.

    typemethod changed {} {
        return $flags(changed)
    }


    #-------------------------------------------------------------------
    # Null RDB

    # NullRDB ...
    #
    # This routine is called if the RDB is accessed and "init" has not
    # been called.

    proc NullRDB {args} {
        error "eventq(n) has not been initialized"
    }



    #-------------------------------------------------------------------
    # Validation Routines

    # EnsureEventTypeExists etype
    #
    # etype     A putative event type
    #
    # Throws an error if no such event type exists

    proc EnsureEventTypeExists {etype} {
        if {![info exists etypes(handler-$etype)]} {
            error "no such event type: \"$etype\""
        }
    }

    # EnsureEventIdExists id
    #
    # id        A putative event ID
    #
    # Throws an error if no such event exists

    proc EnsureEventIdExists {id} {
        if {![$rdb exists {SELECT id FROM eventq_queue WHERE id=$id}]} {
            error "no such event ID: \"$id\""
        }
    }

    # EnsureTimeInFuture t
    #
    # t     A putative sim time
    #
    # Verifies that t is a valid integer, and is in the future.

    proc EnsureTimeInFuture {t} {
        snit::integer validate $t

        if {$t <= $info(time)} {
            error "specified time not in future: \"$t\""

        }
    }


    #-------------------------------------------------------------------
    # Utility Routines

    # lfilter list pattern
    #
    # list       A list of values
    # pattern    A glob pattern
    #
    # Returns a list of the values that match the pattern, preserving
    # order.
    #
    # TBD: Add this to marsutil(n)!

    proc lfilter {list pattern} {
        set out [list]
        
        foreach value $list {
            if {[string match $pattern $value]} {
                lappend out $value
            }
        }

        return $out
    }


}



