#-----------------------------------------------------------------------
# FILE: app_mash.tcl
#
# "mash" Application Subcommand
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
# Module: app_mash
#
# This module defines app_mash, the ensemble that implements
# the "mash" application subcommand.  This subcommand will run many,
# many variations on a single model, logging specified results and
# looking for serious problems.  It has two purposes: testing a model's
# robustness, and producing output for sensitivity analysis.
#
# The set of cases to run is specified in a "mash" file.  When
# run, "mash" outputs the number of failed cases to standard output.
# It can produce a variety of output files, as determined by its 
# options.  See mars_cmtool(1) for the format of the "mash" file.
#
# Syntax:
#   mash _model mashfile ?options?_
#
#   model    - The name of the cellmodel(5) file.
#   mashfile - The name of the "mash" file.   
#
# Options:
#   -epsilon value    - Epsilon for solution
#   -maxiters value   - Max number of iterations
#   -logfile name     - Log file name.  Simple text output of each
#                       each case with its inputs, outputs, and 
#                       success/failure status.
#   -csvfile name     - Log CSV file: the content of the log file
#                       in CSV format, suitable for loading into Excel.
#   -errfile name     - Error file.  Contains specifics about each 
#                       case that failed.  

snit::type app_mash {
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Type Variables

    # Type Variable: cm
    #
    # The cellmodel object.

    typevariable cm

    # Type Variable: info
    #
    # Array variable; general information about the mash to be run.
    # The keys are as follows, where $cell is an input or output
    # cell name and $cid is a case ID.  Case IDs run from 0 to count-1.
    #
    #  cells        - Input and output cells
    #  inputs       - List of range input cell names
    #  range-$cell  - Range defined for the specified input cell
    #  lets         - List of let input cell names
    #  let-$cell    - formula for let cell
    #  outputs      - List of output cell names
    #  conditions   - List of conditions that must be true for a case
    #                 to succeed.
    #  count        - Number of cases.
    #  failures     - Number of cases that failed.
    #  flog         - File handle for the log file, or ""
    #  fcsv         - File handle for the CSV file, or ""
    #  ferr         - File handle for the err file, or ""

    typevariable info -array {
        cells      {} 
        inputs     {}
        lets       {}
        outputs    {}
        conditions {}
        count      0
        failures   0
        flog       ""
        fcsv       ""
        ferr       ""
        
    }

    #-------------------------------------------------------------------
    # Group: Subcommand Execution

    # Type method: execute
    #
    # Executes the "mash" subcommand.
    #
    # Syntax:
    #   app_mash execute _argv_
    #
    #   argv - Command line arguments

    typemethod execute {argv} {
        # FIRST, get the argument.
        if {[llength $argv] < 2} {
            puts "Usage: [app name] model mashfile ?options?"
            exit
        }

        # NEXT, load it.
        set cm [app load -sane [lshift argv]]

        # NEXT, load the mashfile.
        set mashfile [lshift argv]

        if {[catch {
            $type LoadMashFile $mashfile
        } result]} {
            puts "Error loading mash file \"$mashfile\":\n$result"
            exit 1
        }

        if {[llength $info(inputs)] == 0} {
            $type masherr "No input ranges specified."
        }

        # NEXT, get the base output file name
        set basename [file rootname [file tail $mashfile]]

        # NEXT, handle the options.
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

                -logfile {
                    set next [lindex $argv 0]

                    if {$next eq "" || [string match "-*" $next]} {
                        set logfile $basename.log
                    } else {
                        set logfile [lshift argv]
                    }

                    set info(flog) [open $logfile w]
                    fconfigure $info(flog) -buffering line

                    puts "Log File: $logfile"

                    puts $info(flog) "cid ok $info(cells)"
                }

                -csvfile {
                    set next [lindex $argv 0]

                    if {$next eq "" || [string match "-*" $next]} {
                        set csvfile $basename.csv
                    } else {
                        set csvfile [lshift argv]
                    }

                    set info(fcsv) [open $csvfile w]
                    fconfigure $info(fcsv) -buffering line

                    puts "CSV File: $csvfile"

                    puts $info(fcsv) \
                        "\"cid\",\"[join $info(cells) \",\"]\""
                }

                -errfile {
                    set next [lindex $argv 0]

                    if {$next eq "" || [string match "-*" $next]} {
                        set errfile $basename.err
                    } else {
                        set errfile [lshift argv]
                    }

                    set info(ferr) [open $errfile w]
                    fconfigure $info(ferr) -buffering line

                    puts "Error File: $errfile"
                }

                default {
                    puts "Unknown option: $opt"
                    exit 1
                }
            }
        }

        # NEXT, configure the cell model.
        $cm configure \
            -epsilon  $epsilon  \
            -maxiters $maxiters


        # NEXT, run the mash.
        $type RunMash

        # NEXT, close the files.
        if {$info(flog) ne ""} {
            close $info(flog)
        }

        if {$info(fcsv) ne ""} {
            close $info(fcsv)
        }

        if {$info(ferr) ne ""} {
            puts $info(ferr) "$info(failures) failures."
            close $info(ferr)
        }

        # NEXT, output the number of failures
        puts "$info(failures) failures."
    }

    # Type Method: RunMash
    #
    # Solves the model for all combinations of inputs, and saves the
    # results.

    typemethod RunMash {} {
        $type StepInput 0
    }

    # Type Method: StepInput
    #
    # Iterates over the input range for a single cell, recursively
    # iterating over the next cell.

    typemethod StepInput {i} {
        set cell [lindex $info(inputs) $i]
        set next [expr {$i + 1}]

        if {$cell eq ""} {
            $type RunCase
            return
        }

        lassign $info(range-$cell) flower fupper fstep

        set lower [$cm eval $flower]
        set upper [$cm eval $fupper]
        set step  [$cm eval $fstep]

        if {$lower > $upper} {
            $type masherr "Stepping $cell, lower = $lower > upper = $upper"
        }

        if {$step <= 0} {
            $type masherr "Stepping $cell, step $step <= 0"
        }

        set i 0
        for {
            set value $lower
        } {
            $value <= $upper 
        } {
            incr i
            set value [expr {$lower + $i*$step}]
        } {
            # FIRST, set this value
            $cm set [list $cell $value]

            # NEXT, compute the "let" cells
            if {[llength $info(lets)] > 0} {
                
                foreach cell $info(lets) {
                    set letv($cell) [$cm eval $info(let-$cell)]
                }

                $cm set [array get letv]
            }

            # NEXT, step the next cell.
            $type StepInput $next
        }
    }

    # Type Method: RunCase
    #
    # Runs the current combination of inputs, and saves the results.
    
    typemethod RunCase {} {
        # FIRST, get the case ID
        set cid [incr info(count)]

        set result [$cm solve]

        # NEXT, if it converges then check the conditions.
        set problems [list]

        if {$result eq "ok"} {
            foreach condition $info(conditions) {
                if {![$cm eval $condition]} {
                    lappend problems $condition
                    set result "no"
                }
            }
        }

        if {$result eq "ok"} {
            set flag "ok"
        } else {
            set flag "no"
            incr info(failures)
        }

        set out [list]

        foreach cell $info(cells) {
            lappend out [$cm value $cell]
        }
        
        if {$info(flog) ne ""} {
            puts $info(flog) "$cid $flag $out"
        }

        if {$info(fcsv) ne "" && $result eq "ok"} {
            puts $info(fcsv) "$cid,[join $out ,]"
        }

        if {$info(ferr) ne "" && $result ne "ok"} {
            foreach cell $info(inputs) {
                lappend errInputs $cell [$cm value $cell]
            }

            puts $info(ferr) "$cid $errInputs"

            if {[llength $problems] == 0} {
                puts $info(ferr) "    DIVERGED"
            } else {
                foreach problem $problems {
                    puts $info(ferr) "    $problem"
                }
            }

            puts $info(ferr) ""
        }
    }

    #-------------------------------------------------------------------
    # Group: Mash File Loader

    # Type Method: LoadMashFile
    #
    # Loads the mash file, and saves the contents.
    #
    # Syntax:
    #   LoadMashFile _filename_

    typemethod LoadMashFile {filename} {
        # FIRST, create an interpreter to use to parse the file.
        set loader [interp create -safe]

        $loader alias range   $type Load_range
        $loader alias require $type Load_require
        $loader alias let     $type Load_let
        $loader alias log     $type Load_log

        # NEXT, load the model, destroying the loader when done
        try {
            $loader eval [readfile $filename]
        } finally {
            rename $loader ""
        }
    }

    # Type Method: Load_range
    #
    # Defines a range of values for a specific cell.
    #
    # Syntax:
    #   range _cell lower upper step_
    #
    #   cell  - A cell name
    #   lower - The lower bound of the range.
    #   upper - The upper bound of the range.
    #   step  - The step size
    
    typemethod Load_range {cell lower upper step} {
        # FIRST, is this a valid cell?
        if {$cell ni [$cm cells]} {
            $type masherr "no such cell \"$cell\""
        }

        if {$cell in $info(cells)} {
            $type masherr "duplicate cell \"$cell\""
        }

        if {[$cm cellinfo ctype $cell] ne "constant"} {
            $type masherr "can't use \"range\" on formula cell: \"$cell\""
        }


        # NEXT, validate the range values:
        set prefix "Error in range \"$cell\", " 
        $type ValidateFormula "$prefix invalid lower bound formula" $lower
        $type ValidateFormula "$prefix invalid upper bound formula" $upper
        $type ValidateFormula "$prefix invalid upper bound formula" $step

        # NEXT, save the range
        lappend info(cells)  $cell
        lappend info(inputs) $cell
        
        set info(range-$cell) [list $lower $upper $step]
    }

    # Type Method: Load_let
    #
    # Initializes a constant cell to the value of some formula.
    # The formula should generally be in terms of other constant cells,
    # including those whose values are set by the "range" command.
    #
    # Syntax:
    #   let _cell = formula_
    #
    #   cell    - A cell name
    #   =       - Sugar
    #   formula - A cellmodel(5) formula
    
    typemethod Load_let {cell "=" formula} {
        # FIRST, is this a valid cell?
        if {$cell ni [$cm cells]} {
            $type masherr "no such cell \"$cell\""
        }

        if {$cell in $info(cells)} {
            $type masherr "duplicate cell \"$cell\""
        }

        if {[$cm cellinfo ctype $cell] ne "constant"} {
            $type masherr "can't use \"let\" on formula cell: \"$cell\""
        }

        # NEXT, validate the formula:
        $type ValidateFormula "let $cell" $formula

        # NEXT, save the range
        lappend info(cells)  $cell
        lappend info(lets) $cell
        
        set info(let-$cell) $formula
    }

    # Type Method: ValidateFormula
    #
    # Verifies that a formula can be evaluated without error.
    # Calls <masherr> if an error is detected.
    #
    # Syntax:
    #   ValidateFormula _prefix formula_

    typemethod ValidateFormula {name formula} {
        if {[catch {
            $cm eval $formula
        } result]} {
            $type masherr "$prefix, cannot evaluate formula \"$formula\""
        }
    }
    

    # Type Method: Load_log
    #
    # Defines a cell to be logged with the inputs.
    #
    # Syntax:
    #   log _cell_

    typemethod Load_log {cell} {
        # FIRST, is this a valid cell?
        if {$cell ni [$cm cells]} {
            $type masherr "no such cell \"$cell\""
        }
        
        if {$cell in $info(cells)} {
            $type masherr "duplicate cell \"$cell\""
        }

        # NEXT, save the cell
        lappend info(cells)   $cell
        lappend info(outputs) $cell
    }

    # Type Method: Load_require
    #
    # Specifies a formula that must be true for a case to have succeeded.
    #
    # Syntax:
    #   require _condition_

    typemethod Load_require {condition} {
        # FIRST, can we evaluate this?
        if {[catch {
            $cm eval $condition
        } result]} {
            $type masherr "cannot evaluate condition \"$condition\""
        }

        # NEXT, save the cell
        lappend info(conditions) [normalize $condition]
    }

    # Type Method: masherr
    #
    # Outputs an error message and terminates.

    typemethod masherr {message} {
        puts "Error in mash file:\n$message"
        exit 1
    }


}


