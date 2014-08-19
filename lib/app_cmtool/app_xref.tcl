#-----------------------------------------------------------------------
# FILE: app_xref.tcl
#
# "xref" Application Subcommand
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
# Module: app_xref
#
# This module defines app_xref, the ensemble that implements
# the "xref" application subcommand, which loads a model and outputs 
# a cross-reference of the cells that reference each cell.
#
# Syntax:
#   xref _filename_

snit::type app_xref {
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Subcommand Execution

    # Type method: execute
    #
    # Executes the "xref" subcommand.
    #
    # Syntax:
    #   app_xref execute _argv_
    #
    #   argv - Command line arguments

    typemethod execute {argv} {
        # FIRST, get the argument.
        if {[llength $argv] != 1} {
            puts "Usage: [app name] xref filename.cm"
            exit
        }

        # NEXT, Load the model.
        set cm [app load -force [lshift argv]]

        # NEXT, output the results in human-readable form.
        set wid [lmaxlen [$cm cells]]
        puts [format "%-*s    Is used by these cells" $wid Cell]
        foreach cell [$cm cells] {
            puts [format "%-*s => %s" $wid $cell \
                      [$cm cellinfo usedby $cell]]
        }
    }
}


