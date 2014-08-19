#-----------------------------------------------------------------------
# FILE: app_solve.tcl
#
# "solve" Application Subcommand
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
# Module: app_solve
#
# This module defines app_solve, the ensemble that implements
# the "solve" application subcommand, which loads a model and solves
# it once, outputting a variety of detailed information
# about the results and the process of computation.
#
# Syntax:
#   solve _filename ?options?_
#
# There are two sets of options.  The first set apply to the run as
# a whole:
#
#  -epsilon epsilon - Epsilon for solution; defaults to 0.0001
#  -maxiters num    - Max number of iterations; defaults to 100
#  -dumpstart       - Output dump of starting cell values and 
#                     formulas.
#  -initfrom        - A file that contiains a dictionary of fully 
#                     qualified cell names and values that the
#                     cell model should be initialized from.
#  -dumpfinal       - Output dump of final cell values and formulas.
#  -diffpages a b   - Dumps a comparison of the final values of two 
#                     pages a and b.
#
# The remaining options apply only to cyclic pages.  The value of
# each is the name of a cyclic page; each can be repeated to produce
# the output for multiple pages.
# 
#  -logiters page    - Log iteration deltas
#  -dumpiters page   - Dump values for each iteration, as for "dump".
#  -tracevalues page - Prints out a trace of cell values by iteration 
#                      for the first and last few iterations.
#  -tracedeltas page - Prints out a trace of cell value deltas by 
#                      iteration for the first and last few iterations.

snit::type app_solve {
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Type Variables

    # Type Variable: cm
    #
    # The cellmodel object.
    typevariable cm

    # Type Variable: opts
    #
    # Array of command-line options.
    typevariable opts -array {}

    # Type Variable: idelta
    #
    # Iteration delta.
    typevariable idelta 0.0

    # Type Variable: snap
    #
    # Array of model snapshots, by iteration number.
    typevariable snap -array {}

    # Type Variable: convergence
    # 
    # List of convergence messages for the cyclic pages.
    typevariable convergence


    #-------------------------------------------------------------------
    # Group: Subcommand Execution

    # Type method: execute
    #
    # Executes the "solve" subcommand.
    #
    # Syntax:
    #   app_solve execute _argv_
    #
    #   argv - Command line arguments

    typemethod execute {argv} {
        # FIRST, get the argument.
        if {[llength $argv] == 0} {
            puts "Usage: [app name] solve filename.cm ?options?"
            exit
        }

        # NEXT, Load the model.
        set cm [app load -sane [lshift argv]]

        # NEXT, get the options
        array set opts {
            -dumpstart   0
            -dumpfinal   0
            -diffpages   {}
            -logiters    {}
            -dumpiters   {}
            -tracevalues {}
            -tracedeltas {}
            -initfrom    {}
        }
        set opts(-epsilon)  [$cm cget -epsilon]
        set opts(-maxiters) [$cm cget -maxiters]

        while {[llength $argv] > 0 } {
            set opt [lshift argv]

            switch -exact -- $opt {
                -epsilon { 
                    set opts($opt) \
                        [app validate "$opt:" ::epsilon [lshift argv]]
                }

                -maxiters { 
                    set opts($opt) \
                        [app validate "$opt:" ::maxiters [lshift argv]]
                }

                -set {
                    set cell [lshift argv]
                    set value [lshift argv]

                    require {$cell in [$cm cells]} \
                        "-set: Unknown cell: \"$cell\""
                    
                    require {[string is double -strict $value]} \
                        "-set: Not a numeric value: \"$value\""

                    puts "let $cell = $value"
                    $cm set [list $cell $value]
                }

                -dumpstart -
                -dumpfinal { 
                    set opts($opt) 1 
                }

                -diffpages {
                    set pa [lshift argv]
                    set pb [lshift argv]

                    if {$pa ni [$cm pages]} {
                        puts "$opt: unknown page, \"$pa\""
                        exit 1
                    }

                    if {$pb ni [$cm pages]} {
                        puts "$opt: unknown page, \"$pb\""
                        exit 1
                    }

                    lappend opts(-diffpages) [list $pa $pb]
                }

                -logiters    -
                -dumpiters   -
                -tracevalues - 
                -tracedeltas {
                    set page [lshift argv]
                    
                    if {$page ni [$cm pages]} {
                        puts "$opt: unknown page, \"$page\""
                        exit 1
                    }

                    if {![$cm pageinfo cyclic $page]} {
                        puts "$opt: page isn't cyclic, \"$page\""
                        exit 1
                    }

                    lappend opts($opt) $page
                }
                
                -initfrom {
                    set filename [lshift argv]

                    if {![file exists $filename]} {
                        puts "-initfrom file, \"$filename\" does not exist."
                        exit 1
                    }

                    lappend opts($opt) $filename
                }

                default {
                    puts "Invalid option: \"$opt\""
                    exit 1
                }
            }
        }

        # NEXT, if no final outputs are specified, print the results.
        if {!$opts(-dumpstart)        &&
            !$opts(-dumpfinal)        &&
            $opts(-logiters)    eq "" &&
            $opts(-dumpiters)   eq "" &&
            $opts(-tracevalues) eq "" &&
            $opts(-tracedeltas) eq "" &&
            $opts(-diffpages)   eq ""
        } {
            set opts(-dumpfinal) 1
        }

        if {$opts(-initfrom) ne ""} {
            app section "Initializing cellmodel from $opts(-initfrom)"
            set f [open $opts(-initfrom) r]
            array set data [read $f]
            $cm set [array get data]
        }

        # NEXT, -dumpstart
        if {$opts(-dumpstart)} {
            app section "Initial Model"
            puts [$cm dump]
            puts ""
        }

        # NEXT, solving
        app section "Solving, -epsilon $opts(-epsilon) -maxiters $opts(-maxiters)"
        $cm configure \
            -epsilon  $opts(-epsilon)  \
            -maxiters $opts(-maxiters) \
            -tracecmd [mytypemethod Trace]

        set convergence [list]

        set result [$cm solve]

        # NEXT, -dumpfinal
        if {$opts(-dumpfinal)} {
            app section "Final Model"

            puts [$cm dump]
            puts ""
        }

        # NEXT, -diffpages
        foreach pair $opts(-diffpages) {
            lassign $pair pa pb
            app section "Comparison: Pages \"$pa\" and \"$pb\""
            puts [$type DiffPages $pa $pb]
        }

        # NEXT, output the result.  Print out the convergence messages
        # for those pages that converges; then, note any errors.
        
        if {[llength $convergence] > 0} {
            puts [join $convergence \n]
        }

        switch -exact -- [lindex $result 0] {
            diverge {
                puts "Page \"[lindex $result 1]\" diverged after $opts(-maxiters) iterations"
                $type OutputTrace [lindex $result 1] $opts(-maxiters)
            }

            errors {
                puts "Page \"[lindex $result 1]\" contains errors:"
                
                set wid [lmaxlen [$cm cells error]]

                foreach cell [$cm cells error] {
                    puts [format "%-*s => %s" $wid $cell \
                              [normalize [$cm cellinfo error $cell]]]
                }

                $type OutputTrace [lindex $result 1] $opts(-maxiters)
            }

            ok {
                puts "ok"
            }
        }
    }

    # Type method: DiffPages
    #
    # Returns output comparing the values of identically named 
    # cells on two pages.
    #
    # Syntax:
    #   DiffPages _pa pb_
    #
    #   pa - Name of the first page
    #   pb - Name of the second page

    typemethod DiffPages {pa pb} {
        # FIRST, accumulate the output.
        set out ""
        
        # NEXT, get page a's cell values
        array set avalues [$cm get $pa -bare]
        set wid [lmaxlen [array names avalues]]

        # NEXT, iterate over page b's values, outputting 
        # those cells that also exist in A.

        append out [format "%-*s  %12s  %12s\n" \
                        $wid "Cell" "${pa}::" "${pb}::"]
        
        foreach {cell value} [$cm get $pb -bare] {
            # FIRST, if there's no matching cell in pa, skip it.
            if {![info exists avalues($cell)]} {
                continue
            }

            # NEXT, if either is symbolic we're done.
            if {[$cm cellinfo vtype ${pa}::$cell] eq "symbol" ||
                [$cm cellinfo vtype ${pb}::$cell] eq "symbol"
            } {
                continue
            }

            # NEXT, get the numeric values.
            set aval [format %12g $avalues($cell)]
            set bval [format %12g $value]

            if {$aval eq $bval} {
                set bval ""
            }

            # NEXT, save it.
            append out [format "%-*s  %12s  %12s\n" \
                            $wid $cell $aval $bval]
        }

        return $out
    }
    

    # Type method: Trace iterate
    #
    # This method is called on each iteration of each cyclic page.
    #
    # Syntax:
    #   Trace iterate _page i maxdelta maxcell_
    #
    #   page      - The page being iterated
    #   i         - The iteration number, 0 through N
    #   maxdelta  - The iteration's maxdelta
    #   maxcell   - The cell for which the maxdelta was computed

    typemethod "Trace iterate" {page i maxdelta maxcell} {
        # FIRST, if iteration is 0, throw away any results for
        # the previous page.
        if {$i == 0} {
            array unset snap
            set snap(0) [$cm get $page]
            set idelta $maxdelta
            return
        }

        # NEXT, save the current values
        set snap($i) [$cm get $page]

        # NEXT, get the old and new ideltas.
        set old $idelta
        set idelta $maxdelta

        # NEXT, if iterations are logged for this page, do so.
        if {$page in [concat $opts(-logiters) $opts(-dumpiters)]} {
            if {$old != 0.0} {
                let delta {($idelta-$old)/$old}
                set delta [format %g $delta]
            } else {
                set delta "N/A"
            }
            puts "$page, Iteration $i: maxdelta=[format %g $idelta] on $maxcell ($delta)"
        }

        # NEXT, if iterations are being dumped for this page, do so.
        if {$page in $opts(-dumpiters)} {
            puts [$cm dump $page]
        }
    }
    
    # Type method: Trace converge
    #
    # This method is called for each cyclic page that converges.
    #
    # Syntax:
    #   Trace converge _page num_
    #
    #   page - The page name
    #   num  - The number of iterations
    
    typemethod "Trace converge" {page num} {
        # FIRST, skip acyclic pages
        if {![$cm pageinfo cyclic $page]} {
            return
        }

        # NEXT, save the convergence message.
        lappend convergence "Page \"$page\" converged after $num iterations."

        # NEXT, do any tracing of this page.
        $type OutputTrace $page $num
    }

    # Type method: Trace diverge
    #
    # This method is called for cyclic pages that diverge.
    #
    # Syntax:
    #   Trace diverge _page_
    #
    #   page - The page name
    
    typemethod {Trace diverge} {page} {

        puts "Page \"$page\" diverged after $opts(-maxiters) iterations"

        # NEXT, do any tracing of this page.
        $type OutputTrace $page $opts(-maxiters)
    }


    # Type method: OutputTrace
    #
    # Outputs the -tracevalues and -tracedeltas information for a page.
    #
    # Syntax:
    #   OutputTrace _page num_
    #
    #   page - The page name
    #   num  - The iteration number

    typemethod OutputTrace {page num} {
        # FIRST, return unless we're tracing something.
        if {$page ni [concat $opts(-tracevalues) $opts(-tracedeltas)]} {
            return
        }

        # NEXT, Determine the set of iterations for which we want to 
        # output results.
        set iters [list 0]

        for {set i 1} {$i <= $num && $i <= 3} {incr i} {
            lappend iters $i
        }

        if {$num > 3} {
            for {set i [expr {$num - 2}]} {$i <= $num} {incr i} {
                if {$i ni $iters} {
                    lappend iters $i
                }
            }
        }

        # NEXT, get the width of the longest cell name.
        set wid [lmaxlen [dict key $snap(0)]]

        # NEXT, if -tracevalues, print out a trace of the page's values.
        if {$page in $opts(-tracevalues)} {
            app section "Page \"$page\": Cell Results by Iteration"

            puts -nonewline [format "%-*s  " $wid "Results:"]
                
            foreach i $iters {
                puts -nonewline [format " %12s" "Iteration $i"]
            }

            puts ""

            foreach cell [dict keys $snap(0)] {
                puts -nonewline [format "%-*s =" $wid $cell]

                set new [dict get $snap(0) $cell]

                if {[$cm cellinfo vtype $cell] eq "symbol"} {
                    puts -nonewline [format " %12s" $new]

                    foreach i [lrange $iters 1 end] {
                        set new [format " %12s" [dict get $snap($i) $cell]]
                        puts -nonewline $new
                    }
                } else {
                    set new [format " %12g" [dict get $snap(0) $cell]]
                    puts -nonewline [format " %12g" $new]

                    foreach i [lrange $iters 1 end] {
                        set old $new
                        set new [format " %12g" [dict get $snap($i) $cell]]

                        if {$new ne $old} {
                            puts -nonewline $new
                        } else {
                            puts -nonewline [format " %12s" ""]
                        }
                    }
                }
                puts ""
            }
            
            puts ""
        }


        # NEXT, if -tracedeltas, print out a trace of the page's deltas.
        if {$page in $opts(-tracedeltas)} {
            app section "Page \"$page\": Cell Deltas by Iteration"

            puts -nonewline [format "%-*s  " $wid "Deltas:"]
                
            foreach i $iters {
                puts -nonewline [format " %12s" "Iteration $i"]
            }

            puts ""

            foreach cell [dict keys $snap(0)] {
                # FIRST, skip symbol cells.
                if {[$cm cellinfo vtype $cell] eq "symbol"} {
                    continue
                }

                puts -nonewline [format "%-*s =" $wid $cell]
                
                set new [dict get $snap(0) $cell]
                puts -nonewline [format " %12g" $new]

                foreach i [lrange $iters 1 end] {
                    set old $new
                    set new [dict get $snap($i) $cell]
                    
                    puts -nonewline [format " %12g" [expr {$new - $old}]]
                }
                puts ""
            }
            
            puts ""
        }
    }
}


