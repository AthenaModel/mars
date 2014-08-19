#-----------------------------------------------------------------------
# FILE: app_run.tcl
#
# "run" Application Subcommand
#
# PACKAGE:
#   app_cmtool(n) -- mars_cmtool(1) implementation package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: app_run
#
# This module defines app_run, the ensemble that implements
# the "run" application subcommand, which solves the model contained 
# in _filename_ multiple times, once for each "-case".  Each case 
# consists of a name, used in the output, and zero or more cell/value 
# pairs.  The output is displayed in parallel columns.
#
# Syntax:
#   run _filename ?options?_
#
# Options:
#   -epsilon value              - Epsilon for solution
#   -maxiters value             - Max number of iterations
#   -case name ?cell value....? - Specifies a case.

snit::type app_run {
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Subcommand Execution

    # Type method: execute
    #
    # Executes the "run" subcommand.
    #
    # Syntax:
    #   app_run execute _argv_
    #
    #   argv - Command line arguments

    typemethod execute {argv} {
        # FIRST, get the argument.
        if {[llength $argv] == 0} {
            puts "Usage: [app name] run filename.cm ?options?"
            exit
        }

        # NEXT, load it.
        set cm [app load -sane [lshift argv]]

        # NEXT, get the cellname width
        set wid [lmaxlen [$cm cells]]

        # NEXT, get the options
        set cases [list]
        set epsilon  [$cm cget -epsilon]
        set maxiters [$cm cget -maxiters]

        while {[llength $argv] > 0 } {
            set opt [lshift argv]

            switch -exact -- $opt {
                -epsilon { 
                    set epsilon \
                        [app validate "$opt:" ::epsilon [lshift argv]]
                }

                -maxiters { 
                    set maxiters \
                        [app validate "$opt:" ::maxiters [lshift argv]]
                }

                -case {
                    set case [lshift argv]

                    require {$case ne ""} "$opt: Invalid case name: \"\""
                    require {$case ni $cases} \
                        "$opt: Duplicate case name: \"$case\""

                    lappend cases $case
                    set casedict($case) [dict create]

                    puts "Case: $case"

                    while {[llength $argv] > 0 &&
                           ![string match "-*" [lindex $argv 0]]} {

                        set cell [lshift argv]
                        set value [lshift argv]

                        require {$cell in [$cm cells]} \
                            "-case $case: Unknown cell: \"$cell\""
                    
                        require {[string is double -strict $value]} \
                            "-case $case: Not a numeric value: \"$value\""
                        
                        dict set casedict($case) $cell $value

                        puts [format "    %-*s %s" $wid $cell $value]
                    }
                }
            }
        }

        # NEXT, configure the cell model.

        $cm configure \
            -epsilon  $epsilon  \
            -maxiters $maxiters

        # NEXT, solve each of the cases.
        foreach case $cases {
            # FIRST, reset the model to its initial values, and apply
            # the case's parameters.
            $cm reset
            $cm set $casedict($case)

            # NEXT, solve it and save the result.
            set result($case) [$cm solve]
            if {$result($case) eq "ok"} {
                set values($case) [$cm get]
            }
        }

        # NEXT, output the results.
        puts ""
        app section "Results for each case"

        puts -nonewline [format "%-*s" $wid "Cell"]

        foreach case $cases {
            puts -nonewline [format " %12s" $case]
        }

        puts ""

        puts -nonewline [string repeat - $wid]

        foreach case $cases {
            puts -nonewline " [string repeat - 12]"
        }

        puts ""

        foreach cell [$cm cells] {
            # FIRST, output the cell name.
            puts -nonewline [format "%-*s" $wid $cell]

            set old ""

            # NEXT, do each case.
            foreach case $cases {
                # If there's an error result, print that in the space.
                # Otherwise, print the cell value.
                if {$result($case) ne "ok"} {
                    set new [format " %12s" $result($case)]
                } elseif {[$cm cellinfo vtype $cell] eq "symbol"} {
                    set new [format " %12s" [dict get $values($case) $cell]]
                } else {
                    set new [format " %12g" [dict get $values($case) $cell]]
                }

                if {$new eq $old} {
                    puts -nonewline [format " %12s" " "]
                } else {
                    puts -nonewline $new
                    set old $new
                }
            }

            puts ""
        }
    }
}


