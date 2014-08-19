#-----------------------------------------------------------------------
# FILE: sim.tcl
#
# Simulation Manager
#
# PACKAGE:
#   app_uram(n) -- mars_uram(1) implementation package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: sim
#
# The sim module manages the simulation proper: the uramdb(5)
# database input, the initialization of the URAM module, the passage
# of simulation time, and so forth.  Most of the <executive> commands
# relating to the simulation are defined here as well.

snit::type sim {
    pragma -hasinstances no
    
    #-------------------------------------------------------------------
    # Group: Notifier Events
    
    # Notifier Event: Load
    #
    # A new uramdb(5) database has been loaded.  A <Reset> is also sent.
    
    # Notifier Event: Reset
    #
    # The simulation has changed in some basic way; all dependent modules
    # should reset themselves.
    
    # Notifier Event: Unload
    #
    # The uramdb(5) data has been deleted and the simulation uninitialized.
    # A <Reset> is also sent.
    
    # Notifier Event: Time
    #
    # Simulation time has changed.

    #-------------------------------------------------------------------
    # Group: Type Components

    # Type Component: ram
    #
    # The current uram(n) instance, or <NullUram> if no uram(n)
    # instance currently exists.
    
    typecomponent ram

    #-------------------------------------------------------------------
    # Group: Type Variables
    
    # Type variable: info
    #
    # An array of information about the state of the simulation.  The
    # keys are as follows.
    #
    #   dbloaded - 1 if a uramdb(5) is loaded, and 0 otherwise
    #   dbfile   - Name of the loaded uramdb(5) file, or "" if none.
    
    typevariable info -array {
        time       0
        dbloaded   0
        dbfile     ""
    }

    #-------------------------------------------------------------------
    # Group: Initialization

    # Type method: init
    #
    # Initializes the module.  This is a simple task, as most things
    # can't be done until the user specifies a uramdb(5) file, and
    # we don't have it yet.  It _does_ set the ram component to
    # <NullUram>, so that <executive> commands delegated to URAM
    # will be rejected with a user-friendly error message.
    
    typemethod init {} {
        log normal sim "Initializing..."
        
        # Initialize the URAM component to NullUram, so that
        # commands delegated to it are handled before it is
        # created.
        
        set ram [myproc NullUram]
    }

    #-------------------------------------------------------------------
    # Group: Scenario Management

    # Type method: load 
    #
    # Loads the _dbfile_ and initializes URAM.  Sends <Load> and <Reset>.
    #
    # Syntax:
    #   sim load _dbfile_
    #
    #   dbfile - The name of a uramdb(5) database file.

    typemethod load {dbfile} {
        # FIRST, clean up the old simulation data.
        sim unload
        
        # NEXT, open a new log.
        log newlog load

        # NEXT, load the dbfile
        log normal sim "Loading uramdb $dbfile"
        uramdb loadfile $dbfile ::rdb
        set info(dbfile) $dbfile

        # NEXT, set the simulation clock
        set info(time) 0

        # NEXT, create and initialize the URAM.
        if {[catch {sim CreateUram} result]} {
            # Save the stack trace while we clean up
            set errInfo $::errorInfo
            sim unload

            return -code error -errorinfo $errInfo $result
        }

        set info(dbloaded) 1
        log normal sim "Loaded uramdb $dbfile"

        notifier send ::sim <Reset>
        notifier send ::sim <Load>
        return
    }

    # Type method: loadperf
    #
    # Creates a scenario for performance testing, and initializes URAM.
    # Sends <Load> and <Reset>.
    #
    # Syntax:
    #   sim loadperf ?_options..._?
    #
    #   options - uramdb(n)'s mkperfdb command.

    typemethod loadperf {args} {
        # FIRST, clean up the old simulation data.
        sim unload
        
        # NEXT, open a new log.
        log newlog load

        # NEXT, load the dbfile
        log normal sim "Creating performance scenario: $args"
        uramdb mkperfdb ::rdb {*}$args
        set info(dbfile) "perfdb"

        # NEXT, set the simulation clock
        set info(time) 0

        # NEXT, create and initialize the URAM.
        if {[catch {sim CreateUram} result]} {
            # Save the stack trace while we clean up
            set errInfo $::errorInfo
            sim unload

            return -code error -errorinfo $errInfo $result
        }

        set info(dbloaded) 1
        log normal sim "Loaded performance scenario"

        notifier send ::sim <Reset>
        notifier send ::sim <Load>
        return
    }

    # Type method: CreateUram
    #
    # Creates the uram(n) object, and initializes it using the currently
    # loaded uramdb(5) data.
    
    typemethod CreateUram {} {
        set ram [uram ::ram \
                     -rdb          ::rdb                            \
                     -logger       ::log                            \
                     -logcomponent uram                             \
                     -loadcmd      {::simlib::uramdb loader ::rdb}]
        profile "uram init" $ram init
    }
    
    # Type method: reset
    #
    # Reinitializes the simulation, setting the simulation time back to
    # 0.  Sends <Reset>.
    
    typemethod reset {} {
        set info(time) 0

        log newlog reset
        $ram init

        notifier send ::sim <Reset>
        return 
    }

    # Type method: unload
    #
    # Deletes the simulation objects, leaving the simulation
    # uninitialized.  Sends <Reset> and <Unload>
    
    typemethod unload {} {
        catch {$ram destroy}

        set ram [myproc NullUram]

        set info(dbloaded) 0
        set info(dbfile)   ""

        rdb clear
        rdb eval [readfile [file join $::app_uram::library gui_views.sql]]

        notifier send ::sim <Reset>
        notifier send ::sim <Unload>
    }
    
    #-------------------------------------------------------------------
    # Group: Simulation Control

    # Type method: step
    #
    # Runs the simulation forward one timestep.  Sends <Time>.
    #
    # Syntax:
    #   sim step _?ticks?_
    #
    #   ticks - Some positive number of simulation ticks, defaulting
    #           to 1.

    typemethod step {{ticks 1}} {
        while {$ticks > 0} {
            incr info(time)
            incr ticks -1
            profile "uram advance" $ram advance $info(time)
            notifier send ::sim <Time>
        }
        return
    }

    #-------------------------------------------------------------------
    # Group: Queries
    
    # Type method: dbfile 
    #
    # Returns the name of the loaded uramdb(5) file, or "" if not
    # <dbloaded>.

    typemethod dbfile {} {
        if {$info(dbloaded)} {
            return $info(dbfile)
        } else {
            return ""
        }
    }

    # Type method: dbloaded
    #
    # Returns 1 if URAM is initialized with a database, and
    # 0 otherwise.
    
    typemethod dbloaded {} {
        return $info(dbloaded)
    }

    # Type method: now
    #
    # Returns the current simulation time tick, or "" if no DB is
    # loaded.

    typemethod now {} {
        # Do we have a scenario?
        if {$info(dbloaded)} {
            return $info(time)
        } else {
            return ""
        }
    }

    #-------------------------------------------------------------------
    # Group: URAM Executive Commands
    #
    # These routines are the implementations for URAM-related
    # <executive> commands.  They are declared here, rather
    # than in <executive>, because they depend on the <ram> component.
   

    delegate typemethod {hrel *} to ram using {$c hrel %m}
    delegate typemethod {vrel *} to ram using {$c vrel %m}
    delegate typemethod {sat *}  to ram using {$c sat %m}
    delegate typemethod {coop *} to ram using {$c coop %m}
 
    delegate typemethod driver   to ram

    # hrel mass ?driver?
    #
    # driver - The driver ID; otherwise, a new one is used.
    #
    # Creates a mass of HREL inputs across the playbox, for
    # performance testing.

    typemethod {hrel mass} {{driver ""}} {
        profile "hrel mass" $type MassInput hrel $driver
    }

    # vrel mass ?driver?
    #
    # driver - The driver ID; otherwise, a new one is used.
    #
    # Creates a mass of VREL inputs across the playbox, for
    # performance testing.

    typemethod {vrel mass} {{driver ""}} {
        profile "vrel mass" $type MassInput vrel $driver
    }

    # sat mass ?driver?
    #
    # driver - The driver ID; otherwise, a new one is used.
    #
    # Creates a mass of satisfaction inputs across the playbox, for
    # performance testing.

    typemethod {sat mass} {{driver ""}} {
        profile "sat mass" $type MassInput sat $driver
    }

    # coop mass ?driver?
    #
    # driver - The driver ID; otherwise, a new one is used.
    #
    # Creates a mass of COOP inputs across the playbox, for
    # performance testing.

    typemethod {coop mass} {{driver ""}} {
        profile "coop mass" $type MassInput coop $driver
    }

    
    # MassInput ctype driver
    #
    # ctype    - hrel, vrel, sat, or coop
    # driver   - A driver ID, or ""
    #
    # Implements mass inputs for the given curve type.  A driver is
    # generated automatically if none is specified.
    #
    # All input have the same driver, and the related cause.  Satisfaction
    # and cooperation inputs are created with -p 1.0 and -q 1.0.

    typemethod MassInput {ctype driver} {
        # Get driver and cause
        if {$driver eq ""} {
            set driver [ram driver]
        }

        if {$ctype eq "hrel"} {
            rdb eval {
                SELECT f,g FROM uram_hrel
            } {
                ram hrel transient $driver "" $f $g 10.0
            }
        } elseif {$ctype eq "vrel"} {
            rdb eval {
                SELECT g,a FROM uram_vrel
            } {
                ram vrel transient $driver "" $g $a 10.0
            }
        } elseif {$ctype eq "sat"} {
            rdb eval {
                SELECT g,c FROM uram_sat
            } {
                ram sat transient $driver "" $g $c 10.0 \
                    -p 1.0 -q 1.0
            }
        } elseif {$ctype eq "coop"} {
            rdb eval {
                SELECT f, g FROM uram_coop
            } {
                ram coop transient $driver "" $f $g 10.0 \
                    -p 1.0 -q 1.0
            }
        }

        return $driver
    }


    #-------------------------------------------------------------------
    # Group: Utility Routines

    # Proc: profile
    #
    # Executes its arguments as a command in the global scope,
    # logs the execution time, and returns the result.  If
    # _logText_ is {}, the command is used as the log text.
    #
    # Syntax:
    #    profile _logText command..._

    proc profile {logText args} {
        set time [lindex [time {
            set result [{*}$args]  
        } 1] 0]

        if {$logText eq ""} {
            set logText $args
        }
        
        log normal sim "profile: $time usec, $logText"
            
        return $result
    }

    # Proc: NullUram
    #
    # Handles typemethods delegated to <ram> when not <dbloaded> by
    # throwing a user-readable error.  Any arguments are ignored.
    
    proc NullUram {args} {
        error "simulation uninitialized"
    }
}









