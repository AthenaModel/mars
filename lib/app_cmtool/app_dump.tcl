#-----------------------------------------------------------------------
# FILE: app_dump.tcl
#
# "dump" Application Subcommand
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
# Module: app_dump
#
# This module defines app_dump, the ensemble that implements
# the "dump" application subcommand, which loads a model and dumps
# each cell, value, and formula in human readable form.  If desired,
# it outputs only a single page.
#
# Syntax:
#   dump _filename_ ?-page _page_?

snit::type app_dump {
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Subcommand Execution

    # Type method: execute
    #
    # Executes the "dump" subcommand.
    #
    # Syntax:
    #   app_dump execute _argv_
    #
    #   argv - Command line arguments

    typemethod execute {argv} {
        # FIRST, get the argument.
        if {[llength $argv] == 0} {
            puts "Usage: [app name] dump filename.cm ?-page page?"
            exit
        }

        set filename [lshift argv]

        # NEXT, get the options
        array set opts {
            -page all
        }

        while {[llength $argv] > 0} {
            set opt [lshift argv]

            switch -exact -- $opt {
                -page {
                    set opts(-page) [lshift argv]
                }

                default {
                    puts "Unknown option: \"$opt\""
                    exit 1
                }
            }
        }

        # NEXT, Load the model.
        set cm [app load -force $filename]

        # NEXT, does the requested page exist?
        if {$opts(-page) ni [concat all [$cm pages]]} {
            puts "No such page in model: \"$opts(-page)\""
            exit 1
        }

        puts [$cm dump $opts(-page)]

        if {![$cm sane]} {
            puts "Error, model is not sane.  Run \"[app name] check\" for details."
        }
    }
}


