#-----------------------------------------------------------------------
# TITLE:
#    notifier.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) module: Notifier object
#
#    The notifier allows objects to bind callbacks to events sent by 
#    subjects. Each object can bind only once to a particular subject 
#    and event. When the subject sends the event, all bound callbacks
#    are called.  Any errors are handled by bgerror.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsutil:: {
    namespace export notifier
}

#-----------------------------------------------------------------------
# notifier

snit::type ::marsutil::notifier {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Components

    typecomponent db   ;# An in-memory SQLite3 table

    #-------------------------------------------------------------------
    # Type Variable

    # info array: Scalars
    #
    # tracecmd     Name of command to trace execution of events.

    typevariable info -array {
        tracecmd {}
    }



    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # FIRST, create the database.
        set db ${type}::db
        sqlite3 $db :memory:

        # NEXT, initialize it.
        $db eval {
            CREATE TABLE bindings (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                subject      TEXT,
                event        TEXT,
                object       TEXT,
                orig_binding TEXT,
                binding      TEXT,

                UNIQUE (subject, event, object)
            );

            CREATE INDEX binding_index ON bindings(binding);
        }

        $db function substitute [myproc Substitute]
    }

    #-------------------------------------------------------------------
    # Public Type Methods

    # bind subject ?event ?object ?binding???
    #
    # subject      An object name
    # event        An event name
    # object       An object name
    # binding      Optional.  A command prefix, or ""
    #
    # If called with just a subject, returns a list of events for which
    # bindings exist on this subject.
    #
    # If called with just a subject and event, returns a list of 
    # objects with bindings to the subject and event.
    #
    # If called with a subject, event, and object, returns the
    # binding bound to the subject, event, and object, or the empty
    # string if none.
    #
    # If called with all four arguments, and the binding is the empty
    # string, deletes any existing binding for the subject, event,
    # and object.  
    #
    # Otherwise, binds the object's binding to the 
    # subject and event, replacing any existing binding.
    # When the subject sends the event, all bindings to that subject and
    # object will be called.

    typemethod bind {args} {
        # FIRST, check the number of arguments
        set argc [llength $args]

        if {$argc > 4} {
            return -code error \
  "wrong # args: should be \"$type bind subject ?event ?object ?binding???\""
        }

        foreach {subject event object binding} $args { break }

        # NEXT, Case 1: Setting or deleting a binding
        if {$argc == 4} {
            # FIRST, if they are deleting a binding, do so.
            if {$binding eq ""} {
                $db eval {
                    DELETE FROM bindings
                    WHERE subject = $subject
                    AND   event   = $event
                    AND   object  = $object
                }
            } else {
                # NEXT, they are defining a binding.  Substitute %s and %o
                # into the binding.  If the binding already
                # exists, replace it.
                $db eval {
                    INSERT OR IGNORE INTO 
                    bindings(subject, event, object)
                    VALUES($subject, $event, $object);
                    
                    UPDATE bindings
                    SET   binding      = substitute($binding,subject,object),
                          orig_binding = $binding
                    WHERE subject  = $subject
                    AND   event    = $event
                    AND   object   = $object;
                }
            }

            return
        }

        # NEXT, Case 2: Retrieving a binding
        if {$argc == 3} {
            return [$db onecolumn {
                SELECT orig_binding FROM bindings
                WHERE subject = $subject
                AND   event   = $event
                AND   object  = $object
            }]
        }

        # NEXT, Case 3: Retrieving objects bound to an event.
        if {$argc == 2} {
            return [$db eval {
                SELECT object FROM bindings
                WHERE subject = $subject
                AND   event   = $event
            }]
        }

        # NEXT, Case 4: Retrieving events bound to a subject.
        if {$argc == 1} {
            return [$db eval {
                SELECT DISTINCT event FROM bindings
                WHERE subject = $subject
            }]
        }

        # NEXT, Case 5: Retrieving subjects with bindings.
        return [$db eval {SELECT DISTINCT subject FROM bindings}]
    }

    # forget object
    #
    # object          An object name
    #
    # Deletes any bindings in which the object is a subject or object.

    typemethod forget {object} {
        $db eval {
            DELETE FROM bindings
            WHERE subject=$object OR object=$object
        }
    }

    # rename object newname
    #
    # object         An object name
    # newname        The object's new name
    #
    # Renames the object where ever it appears, and re-creates the
    # binding from the orig_binding in each case.

    typemethod rename {object newname} {
        $db eval {
            UPDATE bindings
            SET subject = $newname,
                binding = ''
            WHERE subject=$object;

            UPDATE bindings
            SET object = $newname,
                binding = ''
            WHERE object=$object;

            UPDATE bindings
            SET binding = substitute(orig_binding,subject,object)
            WHERE binding = '';
        }
    }

    # trace ?cmd?
    #
    # cmd   A command prefix to be called to trace sent events.
    #
    # Sets/queries the trace command.  Set explicitly to "" to
    # delete the trace.  The command will receive four arguments,
    # the subject, the event, the arguments, and the objects which
    # will receive it.

    typemethod trace {{args}} {
        if {[llength $args] > 1} {
            error "wrong \# args: should be \"notifier trace ?cmd?\""
        }

        if {[llength $args] == 1} {
            set info(tracecmd) [lindex $args 0]
        }

        return $info(tracecmd)
    }
    

    # send subject event args
    #
    # subject    An object name
    # event      An event name
    # args       Arguments for this event from this object
    #
    # Calls the binding for each object wired to this event.
    
    typemethod send {subject event args} {
        if {$info(tracecmd) ne ""} {
            set objects [$db eval {
                SELECT object FROM bindings
                WHERE subject=$subject AND event=$event
            }]

            {*}$info(tracecmd) $subject $event $args $objects
        }
        
        $db eval {
            SELECT binding FROM bindings
            WHERE subject=$subject AND event=$event
        } {
            if {[catch {
                uplevel \#0 $binding $args
            } result]} {
                bgerror $result
            }
        }
    }

    #-------------------------------------------------------------------
    # Utility Procs

    proc Substitute {binding subject object} {
        string map [list %s [list $subject] %o [list $object]] $binding
    }
}


