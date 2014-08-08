#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.5 "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    test_cmsheet.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Test script for cmsheet
#
#-----------------------------------------------------------------------

package require Tk
package require marsutil
package require marsgui

namespace import marsutil::* marsgui::*

#-----------------------------------------------------------------------
# Main-line Code

snit::double celltype -min 0.0 -max 100.0

proc main {argv} {
    # FIRST, define a cell model with rows and columns whose sum is
    # computed.
    cellmodel cm

    cm load {
        index i {a b c}
        index j {a b c}

        forall i {
            forall j {
                let X.$i.$j = 0.0
            }
        }

        forall i {
            let ROW.$i = {<:sum j {[X.$i.$j]}:>}
        }

        forall j {
            let COL.$j = {<:sum i {[X.$i.$j]}:>}
        }
    }

    # NEXT, define a cmsheet
    set n     [llength [cm index i]]
    let nrows {$n + 2}
    let ncols {$n + 2}

    cmsheet .sheet                 \
        -cellmodel   ::cm          \
        -rows        $nrows        \
        -cols        $ncols        \
        -roworigin   -1            \
        -colorigin   -1            \
        -titlerows   1             \
        -titlecols   1             \
        -validatecmd ::Validate    \
        -refreshcmd  ::Refresh     \
        -formatcmd   {format %.3f}

    pack .sheet -fill both -expand yes

    .sheet textrow -1,0 [concat [cm index j] {"Sum"}]
    .sheet textcol 0,-1 [concat [cm index i] {"Sum"}]

    .sheet map 0,0 i j X.%i.%j %cell

    .sheet maprow $n,0 j COL.%j %cell \
        -background brown             \
        -foreground white

    .sheet mapcol 0,$n i ROW.%i %cell \
        -background blue              \
        -foreground yellow            \
        -formatcmd {format %.2f}

    .sheet empty $n,$n $n,$n
}

proc Validate {rc value} {
    set cellname [.sheet cell $rc]
    
    puts "Validating $cellname@$rc: \"$value\""
    celltype validate $value
}

proc Refresh {} {
    puts "Refreshing display"
}


#-----------------------------------------------------------------------
# Invoke application

main $argv




