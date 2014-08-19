#-----------------------------------------------------------------------
# TITLE: 
#   app.tcl
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
# DESCRIPTION:
#   Main Application Module
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: app
#
# This module defines app, the application ensemble.  app contains
# the application start-up code, as well a variety of subcommands
# available to the application as a whole.  To invoke the 
# application,
#
# > package require app_cmtool
# > app init $argv
#
# Note that app_cmtool is usually invoked by mars(1).

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Look-up Tables

    # Type Variable: appname
    #
    # This is the name of the application, for use in usage strings.

    typevariable appname "mars cmtool"

    # Type Variable: help
    #
    # This is an array of mars_cmtool(1) subcommands, with a 
    # brief help string for each.

    typevariable help -array {
        check     "Model sanity check"
        dump      "Dump initial cell values and formulas"
        help      "This help."
        mash      "Run many cases of the model, looking for failures."
        run       "Run several cases of the model."
        solve     "Solve the model."
        xref      "Cross-reference of cell dependencies."
    }

    #-------------------------------------------------------------------
    # Group: Application Initialization

    # Type method: init
    #
    # Initializes the application, and executes the selected subcommand.
    #
    # Syntax:
    #   app init _argv_
    #
    #   argv - Command line arguments

    typemethod init {argv} {
        # FIRST, if there are no arguments, do help.
        if {[llength $argv] == 0} {
            $type help {}
            exit
        }

        # NEXT, execute the subcommand.
        set sub [lshift argv]

        if {![info exists help($sub)]} {
            puts "No such subcommand: \"$sub\""
            puts "Try \"mars cmtool help\"."
            exit
        }

        if {$sub eq "help"} {
            $type help $argv
        } else {
            app_$sub execute $argv
        }
    }

    #-------------------------------------------------------------------
    # Group: help subcommand
    #
    # Displays the <help> text for the full list of subcommands.
    #
    # Syntax:
    #   help
    
    # Type method: help
    #
    # Implements the "help" subcommand.
    #
    # Syntax:
    #   help _argv_
    #
    #   argv - The remainder of the command line.

    typemethod help {argv} {
        # FIRST, get the argument list.
        if {[llength $argv] != 0} {
            puts "Usage: $appname help"
            exit
        }

        # NEXT, format and display the help information.
        set wid [lmaxlen [array names help]]

        puts "cmtool subcommands:\n"

        foreach sub [lsort [array names help]] {
            puts [format "   %-*s  %s" $wid $sub $help($sub)]
        }
    }

    #-------------------------------------------------------------------
    # Group: Public Type Methods
    #
    # These are for use by the various subcommands.

    # Type Method: name
    #
    # Returns the application's command name, for use in error messages.

    typemethod name {} {
        return $appname
    }


    # Type method: load
    #
    # Loads the model from the named file into a cellmodel(n) object,
    # which is returned.
    #
    # Syntax:
    #   load -sane|-force _filename_
    #
    #   filename - The name of the model file

    typemethod load {opt filename} {
        if {[catch {
            set cm [cellmodel %AUTO]
            $cm load [readfile $filename]
        } result]} {
            puts "Error reading model: $result"
            # puts "$::errorInfo"
            exit 1
        }

        switch -exact -- $opt {
            -sane {
                if {![$cm sane]} {
                    puts \
     "Error, model is not sane.  Run \"[app name] check\" for details."
                    exit 1
                }
            }

            -force {
                # Do nothing
            }

            default {
                error "Unknown option: \"$opt\""
            }
        }

        return $cm
    }

    # Type Method: validate
    #
    # Validates a _value_ using a validation type _vtype_.  On success, 
    # returns the value; on failure, outputs the validation error, 
    # beginning with the _prefix_, and exits.
    #
    # Syntax:
    #   validate _prefix vtype value_
    #
    #   prefix - An error message prefix
    #   vtype  - A validation type
    #   value  - A value to validate

    typemethod validate {prefix vtype value} {
        if {[catch {{*}$vtype validate $value} result]} {
            puts "$prefix $result"
            exit 1
        }

        return $value
    }

    # Type Method: section
    #
    # Formats and outputs a section header, for the program's output.
    #
    # Syntax:
    #   section "string"
    #
    #   string - A text string used as the section title.

    typemethod section {string} {
        set len [string length $string]

        set stars [string repeat "*" [expr {max(3, 55-$len)}]]

        puts "*** $string $stars\n"
    }
}

#-----------------------------------------------------------------------
# Section: Data Types

# Type: epsilon
#
# Validation type for -epsilon values.

snit::double epsilon  -min 0.0

# Type: maxiters
#
# Validation type for -maxiters values.

snit::double maxiters -min 1

# Type: dpositive
#
# Validation type for positive doubles.

snit::double dpositive -min 1e-5
