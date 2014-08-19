#-----------------------------------------------------------------------
# FILE: app_check.tcl
#
# "check" Application Subcommand
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
# Module: app_check
#
# This module defines app_check, the ensemble that implements
# the "check" application subcommand, which loads a model and outputs 
# the results of the model sanity check.
#
# Syntax:
#   check _filename_

snit::type app_check {
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Subcommand Execution

    # Type method: execute
    #
    # Executes the "check" subcommand.
    #
    # Syntax:
    #   app_check execute _argv_
    #
    #   argv - Command line arguments

    typemethod execute {argv} {
        # FIRST, get the argument.
        if {[llength $argv] != 1} {
            puts "Usage: [app name] check filename.cm"
            exit
        }

        # NEXT, Load the model.
        set cm [app load -force [lshift argv]]

        # NEXT, output the results in human-readable form.
        set sections [list]

        # Basic info about each page.
        if {[$cm sane]} {
            set out ""
            foreach page [$cm pages] {
                if {[$cm pageinfo cyclic $page]} {
                    append out "Page \"$page\" is cyclic.\n"
                } else {
                    append out "Page \"$page\" is acyclic.\n"
                }
            }

            lappend sections $out
        }

        # Defined but not referenced.
        if {[llength [$cm cells unused]] > 0} {
            set out "The following cells are defined but not referenced:\n"

            foreach cell [$cm cells unused] {
                append out "    $cell\n"
            }

            lappend sections $out
        }

        # Referenced but not defined.
        if {[llength [$cm cells unknown]] > 0} {
            set out "The following cells are referenced but not defined:\n"

            foreach cell [$cm cells unknown] {
                set refcount [llength [$cm cellinfo usedby $cell]]

                append out [format "    %3d refs: %s\n" \
                                $refcount $cell]
            }

            lappend sections $out
        }

        # Invalid cells
        if {[llength [$cm cells invalid]] > 0} {
            set out "The following cells have serious errors:\n"

            foreach cell [$cm cells invalid] {
                append out [format "  %s = \"%s\"\n" $cell [$cm formula $cell]]

                if {[$cm cellinfo error $cell] ne ""} {
                    append out \
                        "      => [normalize [$cm cellinfo error $cell]]\n"
                }

                foreach rcell [$cm cellinfo unknown $cell] {
                    append out \
                        "      => References undefined cell: $rcell\n"
                }

                foreach rcell [$cm cellinfo badpage $cell] {
                    append out \
                        "      => References cell on later page: $rcell\n"
                }
            }

            lappend sections $out
        }

        # Sanity
        if {[$cm sane]} {
            lappend sections "The model is sane.\n"
        } else {
            lappend sections "The model is not sane.\n"
        }

        set result [join $sections \n]

        puts $result
    }
}


