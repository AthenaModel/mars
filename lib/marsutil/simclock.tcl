#-----------------------------------------------------------------------
# TITLE:
#   simclock.tcl
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
#   Simulation Clock Module
#
#   This module defines a generic Simulation Clock type,
#   simclockType, and also an instance of that type, simclock.
#   It's expected that most applications will use simclock, but
#   multiple instances can be defined if needed.
#
#   Representation of Simulation Time
#
#   Sim time is represented as an integer number of ticks since 
#   time 0.  The tick size is specified using the -tick option, and
#   can be any integer number of minutes, hours, or days.  Time can
#   only be advanced by one or more ticks.
#
#   The simclock(n) can convert between ticks and minutes, hours, and 
#   days.  It can also convert the current sim time to the number of
#   minutes, hours, or days since time 0.
#
#   In addition, the -t0 option specifies the "start date", a 
#   zulu-time string for the specific time and date corresponding to
#   time 0.  Consequently, the simclock(n) can convert between
#   sim times in ticks and zulu-time strings.
#
#   This module also defines marsutil::ticktype, which is used to
#   validate -tick.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export simclockType simclock ticktype
}

#-----------------------------------------------------------------------
# Tick Type

snit::type ::marsutil::ticktype {
    #-------------------------------------------------------------------
    # Type Variables

    # List of valid units
    typevariable units {
        minute minutes
        hour   hours
        day    days
    }

    #-------------------------------------------------------------------
    # Type Methods

    # validate value
    #
    # value     A value to validate
    #
    # Throws an error if value is not a valid tick specification.

    typemethod validate {value} {
        # FIRST, get and validate the tick units and size
        set n [lindex $value 0]
        set u [lindex $value 1]

        if {[llength $value] != 2                ||
            ![string is integer -strict $n]      ||
            $n <= 0                              ||
            [lsearch -exact $units $u] == -1
        } {
            error "Invalid value: \"$value\""
        }
    }

    #-------------------------------------------------------------------
    # Instance methods

    # Delegate instance validate method to type.
    delegate method validate using {%t %m}
}


#-----------------------------------------------------------------------
# Simulation Clock Type

snit::type ::marsutil::simclockType {
    #-------------------------------------------------------------------
    # Type Variables

    # Base units conversion factors: an array keyed on $from,$to
    # where the value is the conversion from the $from units to the $to
    # units.
    typevariable factor


    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Import required names from other modules.
        namespace import ::marsutil::* 

        # Set up the base units conversion factors
        set factor(seconds,minutes) [expr {1/60.0}]
        set factor(seconds,hours)   [expr {1/3600.0}]
        set factor(seconds,days)    [expr {1/86400.0}]
        set factor(minutes,seconds) [expr {60}]
        set factor(minutes,minutes) [expr {1}]
        set factor(minutes,hours)   [expr {1/60.0}]
        set factor(minutes,days)    [expr {1/1440.0}]
        set factor(hours,seconds)   [expr {3600}]
        set factor(hours,minutes)   [expr {60}]
        set factor(hours,hours)     [expr {1}]
        set factor(hours,days)      [expr {1/24.0}]
        set factor(days,seconds)    [expr {86400}]
        set factor(days,minutes)    [expr {1440}]
        set factor(days,hours)      [expr {24}]
        set factor(days,days)       [expr {1}]
    }

    #-------------------------------------------------------------------
    # Options

    # -tick
    #
    # Sets the tick size as an integer number "minutes", "hours", or
    # "days", e.g., "-tick {1 minute}", "-tick {2 hours}"

    option -tick \
        -default         "1 minute"       \
        -type            ::marsutil::ticktype \
        -configuremethod CfgTick

    method CfgTick {opt val} {
        # FIRST, verify that the current time is 0.
        require {$tsim == 0} \
            "Sim time is not 0"

        # NEXT, save the value.
        set options($opt) $val

        # NEXT, get the tick units and size
        set tickSize [lindex $val 0]
        set units [lindex $val 1]

        # NEXT, make sure units ends in "s"
        if {[string index $units end] ne "s"} {
            append units "s"
        }
    }

    # -t0
    #
    # A Zulu-time string representing the simulation start date.
    
    option -t0 -default "010000ZJAN70" -configuremethod CfgT0

    method CfgT0 {opt val} {
        # First, set t0 in Unix seconds.  If this succeeds, the value
        # is valid.
        set t0 [zulu tosec $val]

        # Next, it's valid, so save it.
        set options($opt) $val

        # Next, update the -zuluvar accordingly
        $self SetSimTime $tsim
    }

    # -zuluvar
    #
    # A variable which receives the current sim time as a zulu(n)
    # time string whenever simtime is advanced.

    option -zuluvar -configuremethod CfgZuluVar

    method CfgZuluVar {opt val} {
        set options($opt) $val

        # Next, update the -zuluvar accordingly
        $self SetSimTime $tsim
    }

    # -advancecmd
    #
    # A command to call when simulation time is advanced.  The command
    # is called as is.  When it is called, the clock has already been
    # updated, and the actual game ratio has been measured.  Used only
    # when simclock's game ratio is driving the advance of simulated
    # time.
    option -advancecmd -default ""

    # -requestcmd
    #
    # A command to call when it's time to request a time advance.
    # If -requestcmd is not "", then time will only advance when
    # "grant" is called.  Used only when simclock's game ratio is driving
    # simulated time.
    option -requestcmd -default ""

    # -ratiovar
    #
    # Names a variable which will be updated with the current game
    # ratio whenever it changes.  Writes to the variable do not
    # affect the behavior of driver.
    option -ratiovar -configuremethod CfgRatioVar 

    method CfgRatioVar {opt val} {
        set options($opt) $val
        $self SetRatio $tm(ratio)
    }

    # -actualratiovar
    #
    # Names a variable which will be updated with the measured game
    # ratio whenever it changes.
    option -actualratiovar -configuremethod CfgActualRatioVar 

    method CfgActualRatioVar {opt val} {
        set options($opt) $val
        $self SetActualRatio $tm(actualRatio)
    }

    # -logger
    #
    # Sets name of application's logger(n) object.  The -logger is needed
    # only if time management is used.

    option -logger

    # -logcomponent
    #
    # Sets this object's "log component" name, to be used in log messages.

    option -logcomponent -default clock

    #-------------------------------------------------------------------
    # Instance variables

    variable t0    0            ;# Start date in Unix seconds.
    variable tsim  0            ;# Sim time, ticks since T0

    # Time tick data: 
    #
    # NOTE: This is set consistent with the default -tick value.

    variable units     "minutes"    ;# Default tick units
    variable tickSize  1            ;# Default tick size in tick units

    # tm -- time management array
    #
    # afterId            After handler ID, or ""
    # ratio              The requested game ratio; ratio >= 0.0
    # baseWallclock      The wallclock time, in decimal minutes, when
    #                    the game ratio was last set.
    # baseSimtime        The simclock time, in decimal minutes, when
    #                    the game ratio was last set.
    # grantWallclock     Wallclock time of the last advance grant
    # elapsedTimes       List of 0 to 20 elapsed times between grants.
    # actualRatio        The measured game ratio
    # advancePending     1 if a time advance grant is pending, and 0
    #                    otherwise.
    # advanceReceived    1 if a time advance grant was received, and 0 
    #                    otherwise.

    variable tm -array {
        afterId            ""
        ratio             0.0
        baseWallclock     0.0
        baseSimtime       0.0
        grantWallclock    0.0
        elapsedTimes      {}
        actualRatio       0.0
        advancePending    0
        advanceReceived   0
    }

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # No constructor is needed at this time.

    destructor {
        # Make sure the motor is stopped.
        $self stop
    }


    #-------------------------------------------------------------------
    # Public methods: Time Management

    delegate method asString using {%s asZulu}
    delegate method toString using {%s toZulu}

    # ratio ?rat?
    #
    # rat          The new game ratio.
    #
    # Sets/queries the game ratio, which is zero initially.

    method ratio {{rat ""}} {
        if {$rat ne ""} {
            if {$rat ne "auto"} {
                require {[string is double -strict $rat]} \
                    "Expected \"auto\" or number, got \"$rat\""
                require {$rat >= 0.0} \
                    "Requested ratio is negative: \"$rat\""
            }

            if {$rat eq "auto"} {
                $self ComputeActualRatio 0.0
            } elseif {$rat == 0.0} {
                $self SetActualRatio 0.0
            } elseif {$tm(ratio) == 0.0 && $rat > 0.0} {
                $self ComputeActualRatio 0.0
            }

            $self SetRatio $rat
            $self Log normal "ratio $tm(ratio)"
        }

        return $tm(ratio)
    }
    
    # actualratio
    #
    # Queries the measured game ratio.  Returns "???" if the actual
    # ratio hasn't yet been measured.

    method actualratio {} {
        return $tm(actualRatio)
    }


    # start ?ticks?
    #
    # ticks           A simulation time in ticks
    # advancePending  Allows an application using the simclock to 
    #                 indicate whether there is a time advance pending
    #
    # Starts the motor running, first setting the clock to ticks if
    # given.

    method start {{ticks ""} {advancePending 0}} {
        require {$tm(afterId) eq ""}  "simclock $self is already running."

        # FIRST, Advance time to the specified time.
        if {$ticks ne ""} {
            $self SetSimTime $ticks
        }

        # NEXT, Set the base times for the game ratio computation
        # Do NOT reset the game ratio.
        $self SetActualRatio    0.0
        set tm(baseWallclock)   [WallClock]
        set tm(grantWallclock)  $tm(baseWallclock)
        set tm(baseSimtime)     [$self asMinutes]
        set tm(elapsedTimes)    [list]
        set tm(advancePending)  $advancePending
        set tm(advanceReceived) 0

        # NEXT, Start the motor going.
        $self Log normal "started [$self asZulu] ($tsim)"

        # NEXT, Start the motor.
        $self Motor

        return
    }

    # stop
    #
    # Stops the Motor.

    method stop {} {
        $self Log normal "stop"

        # FIRST, if we're already stopped there's nothing more to do.
        if {$tm(afterId) eq ""} {
            return
        }

        # NEXT, stop the motor
        after cancel $tm(afterId)
        set tm(afterId) ""

        # NEXT, clear all of the time management variables.
        $self SetRatio          0.0
        $self SetActualRatio    0.0
        set tm(baseWallclock)   0.0
        set tm(baseSimtime)     0.0
        set tm(grantWallclock)  0.0
        set tm(elapsedTimes)    [list]
        set tm(advancePending)  0
        set tm(advanceReceived) 0
       
        return
    }

    # isactive
    #
    # Returns 1 if the simclock's motor is running, i.e., if it
    # is actively trying to advance time (possibly
    # at ratio 0.0) and 0 if the simclock is stopped.

    method isactive {} {
        expr {$tm(afterId) ne ""}
    }

    #-------------------------------------------------------------------
    # Protocol Methods, Time Management

    # grant ticks
    #
    # ticks     The time to which we can advance.
    #
    # Advance time to ticks; or, more precisely, to $tsim + 1, since 
    # that's what we requested.  This should only be called explicitly 
    # in immediate or eventual response to the -requestcmd.

    method grant {ticks} {
        # NEXT, advance to the specified time and clear the pending
        # flag.
        $self SetSimTime $ticks
        set tm(advancePending) 0
        $self Log normal "grant [$self asZulu] ($ticks)"

        # NEXT, compute the actual game ratio, if we're in active
        # mode.
        if {$tm(afterId) ne ""} {
            $self ComputeActualRatio [WallClock]
        }

        # NEXT, call the advance command, if any.
        if {$options(-advancecmd) ne ""} {
            if {[catch {uplevel \#0 $options(-advancecmd)} result]} {
                bgerror "-advancecmd: $result"
            }
        }

        return
    }

    #-------------------------------------------------------------------
    # Private Methods, Time Management

    # Motor
    #
    # This is the motor.  It keeps track of the
    # game ratio, and advances simulation time accordingly.
    #
    # WARNING: If this routine throws an error, it can break the 
    # timeout loop, and stop time from advancing. Be careful that 
    # all errors in code called from this method are caught 
    # appropriately.

    method Motor {} {
        # FIRST, schedule the next timeout.
        # TBD: the interval should really be an option!
        set tm(afterId) [after 10 [mymethod Motor]]

        # NEXT, We need to request advances based on the game ratio.
        if {($tm(ratio) eq "auto" || $tm(ratio) > 0.0)} {

            if {!$tm(advancePending)} {
                set newWC [expr {[WallClock] - $tm(baseWallclock)}]
                set newST [expr {[$self asMinutes] - $tm(baseSimtime)}]

                if {$tm(ratio) eq "auto" || 
                    $newWC*$tm(ratio) >= $newST} {
                    # FIRST, compute the next time

                    set newTime [expr {$tsim + 1}]
                    $self Log normal \
              "time advance request [$self toZulu $newTime] ($newTime)"
                    
                    # NEXT, remember that we've asked for an advance.
                    set tm(advancePending) 1

                    # NEXT, request the advance.  Call the -requestcmd
                    # if there is one; otherwise, trivially grant
                    # the request.
                    set cmd $options(-requestcmd)

                    if {$cmd ne ""} {
                        lappend cmd $newTime

                        set code [catch {uplevel \#0 $cmd} result]

                        if {$code == 3} {
                            # break!  Retry next time.
                            set tm(advancePending) 0
                            return
                        } elseif {$code} {
                            # Any other non-zero code is an error.
                            # Log the error and retry.
                            bgerror "-requestcmd: $result"
                            set tm(advancePending) 0
                            return
                        }
                    } else {
                        $self grant $newTime
                    }
                }
            }
        }
    }

    # SetRatio rat
    #
    # rat      A game ratio
    #
    # Sets tm(ratio) and updates any -ratiovar.

    method SetRatio {rat} {
        if {$rat ne "auto"} {
            set rat [expr {double($rat)}]
        }

        set tm(ratio) $rat
        set tm(baseWallclock) [WallClock]
        set tm(baseSimtime)   [$self asMinutes]
        
        if {$options(-ratiovar) ne ""} {
            set $options(-ratiovar) $tm(ratio)
        }
    }

    # SetActualRatio rat
    #
    # rat      A measured game ratio
    #
    # Sets tm(actualRatio) and updates any -actualratiovar.

    method SetActualRatio {rat} {
        set tm(actualRatio) $rat
        
        if {$options(-actualratiovar) ne ""} {
            set $options(-actualratiovar) $tm(actualRatio)
        }
    }

    # ComputeActualRatio grantTime
    #
    # grantTime    The timeAdvanceGrant wallclock time in decimal
    #              minutes, or 0.0
    #
    # Computes the actual game ratio as a smoothed estimate of the
    # last four measurements.

    method ComputeActualRatio {grantTime} {
        # FIRST, handling clearing the ratio
        if {$grantTime == 0.0} {
            set tm(grantWallclock) 0.0
            set tm(elapsedTimes)   [list]
            $self SetActualRatio "???"
            return
        }

        # NEXT, compute and save the new elapsed time; we
        # want to keep the most recent 20 values.
        if {$tm(grantWallclock) > 0.0 && $tm(ratio) > 0.0} {
            let diff {$grantTime - $tm(grantWallclock)}
        
            if {[llength $tm(elapsedTimes)] >= 20} {
                set tm(elapsedTimes) [lrange $tm(elapsedTimes) 1 end]
            }
            lappend tm(elapsedTimes) $diff

            # If we have only a few elapsed times, don't compute
            # the actual ratio.
            if {[llength $tm(elapsedTimes)] < 4} {
                $self SetActualRatio "???"
            } else {
                set sum 0.0
                foreach val $tm(elapsedTimes) {
                    let sum {$sum + $val}
                }
            

                set n [llength $tm(elapsedTimes)]
                let rat {double([$self toMinutes 1])/($sum/$n)}
                
                $self SetActualRatio [format "%.3f" $rat]
            }
        } else {
            $self SetActualRatio "???"
        }

        # Save the grant time
        set tm(grantWallclock) $grantTime
    }

    #-------------------------------------------------------------------
    # Manual Time Advancement

    # advance t
    #
    # t       A time in ticks no less than $tsim.
    #
    # Advances sim time to time t.  Returns the new sim time.
    #
    # Note that this command can actually update the simclock to
    # any desired time.  Use with care.
    
    method advance {t} {
        require {$tm(afterId) eq ""} \
            "Cannot advance simclock manually; simclock is active."
        require {[string is integer -strict $t]} \
            "expected integer ticks: \"$t\""
        require {$t >= 0} \
            "expected t >= 0, got \"$t\""

        return [$self SetSimTime $t]
    }

    # SetSimTime ticks
    #
    # ticks    A time in ticks
    #
    # Sets the sim time to ticks and updates -zuluvar
    
    method SetSimTime {ticks} {
        set tsim $ticks

        if {$options(-zuluvar) ne ""} {
            set $options(-zuluvar) [$self asZulu]
        }

        return $tsim
    }

    # step ticks
    #
    # ticks      A positive number of ticks
    #
    # Advances sim time by the specified number of ticks.
    # Returns the new sim time.  Valid only if motor is not
    # running

    method step {ticks} {
        require {$tm(afterId) eq ""} \
            "Cannot step simclock manually; simclock is active."
        require {[string is integer -strict $ticks]} \
            "expected integer ticks: \"$ticks\""
        require {$ticks > 0} \
            "expected ticks > 0, got \"$ticks\""

        return [$self SetSimTime [expr {$tsim + $ticks}]]
    }

    # reset
    #
    # Resets sim time to 0.

    method reset {} {
        # FIRST, set the time to 0 and update the -zuluvar
        $self SetSimTime 0

        # NEXT, stop the motor, if it's running
        $self stop

        return
    }

    # tick
    #
    # Advances time one tick, and calls the -advancecmd, if any.

    method tick {} {
        require {$tm(afterId) eq ""} \
            "Cannot tick simclock manually; simclock is active."

        $self grant [expr {$tsim + 1}]
    }

    #-------------------------------------------------------------------
    # Queries

    # now ?offset?
    #
    # offset     Ticks; defaults to 0.
    #
    # Returns the current sim time (plus the offset) in ticks.

    method now {{offset 0}} {
        return [expr {$tsim + $offset}]
    }

    # asZulu ?offset?
    #
    # offset     Ticks; defaults to 0.
    #
    # Return the current time (plus the offset) as a Zulu-time string.

    method asZulu {{offset 0}} {
        $self toZulu $tsim $offset
    }

    # asDays ?offset?
    #
    # offset     Ticks; defaults to 0.
    #
    # Return the current time (plus the offset) as decimal days.

    method asDays {{offset 0}} {
        $self toDays $tsim $offset
    }

    # asHours ?offset?
    #
    # offset     Ticks; defaults to 0.
    #
    # Return the current time (plus the offset) as decimal hours.

    method asHours {{offset 0}} {
        $self toHours $tsim $offset 
    }

    # asMinutes ?offset?
    #
    # offset     Ticks; defaults to 0.
    #
    # Return the current time (plus the offset) as decimal minutes.

    method asMinutes {{offset 0}} {
        $self toMinutes $tsim $offset 
    }

    #-------------------------------------------------------------------
    # Conversions

    # toZulu ticks ?offset?
    #
    # ticks        A sim time in ticks.
    # offset       Interval in ticks; defaults to 0.
    #
    # Converts the sim time plus offset to a Zulu-time string.

    method toZulu {ticks {offset 0}} {
        # FIRST, convert the number of ticks to base units,
        # and then convert to seconds:
        set seconds \
            [expr {($ticks + $offset) * $tickSize * $factor($units,seconds)}]

        # NEXT, convert the number of seconds to zulu.
        zulu fromsec [expr {$t0 + $seconds}]
    }

    # fromZulu zulutime
    #
    # zulutime     A zulu-time string
    #
    # Converts a Zulu-time string into a sim time in base units.

    method fromZulu {zulutime} {
        # FIRST, convert the zulu time to a unix time.
        set unixTime [zulu tosec $zulutime]

        # NEXT, convert the unix time to seconds since -t0
        set seconds [expr {$unixTime - $t0}]

        # NEXT, convert seconds to base units, and then divide
        # by the tick size to get ticks

        expr {int(round($seconds*$factor(seconds,$units)/$tickSize))}
    }

    # toDays ticks ?offset?
    #
    # ticks        A sim time in ticks.
    # offset       An interval in ticks; defaults to 0.
    #
    # Converts a sim time plus offset to a time in days.

    method toDays {ticks {offset 0}} {
        expr {($ticks + $offset) * $tickSize * $factor($units,days)}
    }

    # fromDays days
    #
    # days         A sim time in decimal days
    #
    # Converts decimal days to a sim time in ticks.
    
    method fromDays {days} {
        expr {int(round(double($days)*$factor(days,$units)/$tickSize))}
    }

    # toHours ticks ?offset?
    #
    # ticks        A sim time in ticks.
    # offset       An interval in ticks; defaults to 0.
    #
    # Converts a sim time plus offset to a time in hours.

    method toHours {ticks {offset 0}} {
        expr {($ticks + $offset) * $tickSize * $factor($units,hours)}
    }

    # fromHours hours
    #
    # hours         A sim time in decimal hours
    #
    # Converts decimal hours to a sim time in ticks.
    
    method fromHours {hours} {
        expr {int(round(double($hours)*$factor(hours,$units)/$tickSize))}
    }

    # toMinutes ticks ?offset?
    #
    # ticks        A sim time in ticks.
    # offset       An interval in ticks; defaults to 0.
    #
    # Converts a sim time plus offset to a time in minutes.

    method toMinutes {ticks {offset 0}} {
        expr {($ticks + $offset) * $tickSize * $factor($units,minutes)}
    }

    # fromMinutes minutes
    #
    # minutes         A sim time in decimal minutes
    #
    # Converts decimal minutes to a sim time in ticks.
    
    method fromMinutes {minutes} {
        expr {int(round(double($minutes)*$factor(minutes,$units)/$tickSize))}
    }

    # fromTimeSpec spec
    #
    # spec           A time-spec string
    #
    # Converts a time-spec string to a sim time in ticks.
    #
    # A time-spec string specifies a time in ticks as a base time 
    # optionally plus or minus an offset.  The offset is always in ticks;
    # the base time can be a time in ticks, a zulu time-string, or
    # a "named" time, e.g., "T0" or "NOW".  If the base time is omitted, 
    # "NOW" is assumed.  For example,
    #
    #    +5             simclock now 5
    #    -5             simclock now -5
    #    <zulu>+30      Zulu-time plus 30 ticks
    #    NOW-30         simclock now -30
    #    40             40
    #    40+5           45
    #    T0+45          45
    #    T0             0

    method fromTimeSpec {spec} {
        # FIRST, split the spec into base time, op, and offset.
        set result [regexp -expanded {
            # FIRST, Start from beginning of string
            ^

            # NEXT, capture the base time, which (at this point)
            # can be any string that doesn't contain +, -, or whitespace.
            # It can, however, be empty.
            ([^-+[:space:]]*)

            # NEXT, skip any amount of white space
            \s*

            # NEXT, capture the offset, if any
            (

            # NEXT, it begins with a + or -, which we need to capture
            ([-+])

            # NEXT, skip any amount of white space
            \s*
 
            # NEXT, the actual offset is an arbitrary integer at least
            # one character long
            (\d+)

            # NEXT, we need 0 or 1 offsets, including the operator and
            # the number.
            )?

            # NEXT, continue to the end of the string.
            $
        } $spec dummy basetime dummy2 op offset]

        if {!$result} {
            error "invalid time spec \"$spec\", should be <basetime><+/-><offset>"
        }

        # NEXT, convert the base time to ticks
        set basetime [string toupper $basetime]

        if {$basetime eq "T0"} {
            set t 0
        } elseif {$basetime eq "NOW" || $basetime eq ""} {
            set t [$self now]
        } elseif {[string is integer -strict $basetime]} {
            set t $basetime
        } elseif {![catch {$self fromZulu $basetime} result]} {
            set t $result
        } else {
            error "invalid time spec \"$spec\", base time should be \"NOW\", \"T0\", an integer tick, or a zulu-time string"
        }

        if {$offset ne ""} {
            incr t $op$offset
        }

        return $t
    }

    #-------------------------------------------------------------------
    # Validation Routines

    # timespec validate spec
    #
    # spec     Possibly, a time spec
    #
    # Validates it as a time spec, throwing INVALID if invalid, and
    # returning the time in ticks if valid.

    method {timespec validate} {spec} {
        if {[catch {$self fromTimeSpec $spec} result]} {
            return -code error -errorcode INVALID $result
        } else {
            return $result
        }
    }


    # past validate spec
    #
    # spec     Possibly, a time spec
    #
    # Validates it as a time spec for a time no later than "now", 
    # throwing INVALID if invalid, and returning the time in ticks if valid.

    method {past validate} {spec} {
        if {[catch {$self fromTimeSpec $spec} result]} {
            return -code error -errorcode INVALID $result
        } elseif {$result < 0 || $result > [$self now]} {
            return -code error -errorcode INVALID \
                "invalid time spec \"$spec\", expected time between T0 and NOW"
        } else {
            return $result
        }
    }

    # future validate spec
    #
    # spec     Possibly, a time spec
    #
    # Validates it as a time spec for a time no earlier than "now", 
    # throwing INVALID if invalid, and returning the time in ticks if valid.

    method {future validate} {spec} {
        if {[catch {$self fromTimeSpec $spec} result]} {
            return -code error -errorcode INVALID $result
        } elseif {$result < [$self now]} {
            return -code error -errorcode INVALID \
              "invalid time spec \"$spec\", expected time no earlier than NOW"
        } else {
            return $result
        }
    }

    #-------------------------------------------------------------------
    # Utility Methods and Procs

    # Log severity message
    #
    # severity         A logger(n) severity level
    # message          The message text.

    method Log {severity message} {
        if {$options(-logger) ne ""} {
            $options(-logger) $severity $options(-logcomponent) $message
        }
    }

    # WallClock
    #
    # Returns the wall clock time in decimal minutes. The time
    # in decimal seconds is acquired by calling gettimeofday from
    # marsutil(n).

    proc WallClock {} {
        # Convert to minutes
        expr {[gettimeofday]/60.0}
    }

}

#-----------------------------------------------------------------------
# Global simclock instance

::marsutil::simclockType ::marsutil::simclock


