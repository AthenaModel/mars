#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    test_dynabox.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Test script for dynabox(n).
#
# TBD:
#    Tests "dynabox gets" and "dynabox pick"
#
#-----------------------------------------------------------------------

package require Tk

package require marsutil
package require marsgui

namespace import kiteutils::* marsutil::* marsgui::*


#-----------------------------------------------------------------------
# Main-line Code

dynaform define TESTFORM {
    rc {
        Please enter the first and last name of the individual.
    } -span 2
    rcc "First:" -for first
    text first -width 50
    rcc "Last:" -for last
    text last -width 50
}

proc ShowDialog {flag} {
    .output delete 1.0 end

    if {$flag} {
        set validatecmd ""
    } else {
        set validatecmd ::Validate
    }

    set dict [dynabox popup \
        -formtype TESTFORM \
        -validatecmd $validatecmd \
        -helpcmd ::ShowHelp \
        -initvalue {first Joe last Pro} \
        -oktext "Got Him!" \
        -parent . \
        -title "Dynabox: TESTFORM"]

    dict for {key value} $dict {
        .output insert end [format "%-8s <%s>\n" $key $value]
    }
}

proc Validate {dict} {
    dict with dict {
        set first [string trim $first]
        set last  [string trim $last]

        if {$first eq "" || $last eq ""} {
            throw INVALID "Missing names"
        }

        if {$last eq "Bozo"} {
            throw REJECTED {last "No Bozos Allowed"}
        }
    } 

    if {$first eq "Joe" && $last eq "Pro"} {
        return "Tex Fiddler!"
    }

    return
}

proc main {argv} {
    # FIRST, pop up a debugger
    debugger new

    if {[llength $argv] > 0} {
        set flag 1
    } else {
        set flag 0
    }

    ttk::button .show \
        -text     "Show Dialog" \
        -command  [list ShowDialog $flag]

    text .output \
        -height 10 \
        -width  40

    pack .show   -side top -fill x
    pack .output -side top -fill x
}



#-----------------------------------------------------------------------
# Invoke application

main $argv




