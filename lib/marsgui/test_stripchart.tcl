#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.5 "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    test_stripchart.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Test script for stripchart
#
#-----------------------------------------------------------------------

package require Tk
package require marsutil
package require marsgui

namespace import marsutil::* marsgui::*

#-----------------------------------------------------------------------
# Main-line Code

proc main {argv} {
    array set series {
        1 {
             0  50
             1  40
             2   0 
             3 -10 
             4  10 
             5 -20
             6 -25 
             7 -40 
             8  15
             9  25
            10  30
        }

        2 {
             0 -20
             1 -10
             2  -5 
             3   5 
             4  10 
             5  20
             6  25 
             7  35 
             8  40
             9  50
            10  55
        }

        3 {
             3  55 
             5  30
             7  -5 
             9 -15
        }
    }

    stripchart .chart                  \
        -width       400               \
        -height      300               \
        -closeenough 2                 \
        -title       "My Sample Chart" \
        -titlepos    n                 \
        -xtext       "Time"            \
        -ytext       "Satisfaction"    \
        -yformatcmd  {format %.1f}     \
        -xformatcmd  {format %.1f}

    .chart plot series1 \
        -label "Series 1" \
        -data  $series(1) \
        -rmin  -60        \
        -rmax  60

    .chart plot series2 \
        -label "Series 2" \
        -data  $series(2) \
        -rmin  -60        \
        -rmax  60

    .chart plot series3 \
        -label "Series 3" \
        -data  $series(3) \
        -rmin  -60        \
        -rmax  60

    pack .chart -fill both -expand yes


    bind .chart <<Context>> {puts "Context <%d> %x,%y %X,%Y"}
    bind . <Control-F12> {debugger new}
}



#-----------------------------------------------------------------------
# Invoke application

main $argv




