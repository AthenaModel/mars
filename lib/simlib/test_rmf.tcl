#-----------------------------------------------------------------------
# TITLE:
#   test_rmf.tcl
#
# PACKAGE:
#   simlib(n) -- Simulation Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Test program for rmf(n): Plots RMFs on a canvas.
#
#-----------------------------------------------------------------------

package require simlib
package require marsgui

namespace import ::marsutil::* 
namespace import ::marsutil::* ::simlib::* ::marsgui::*

snit::widget rmfplot {
    component canvas

    option -rmf -type ::simlib::rmf -default quad \
        -configuremethod CnfRmf

    method CnfRmf {opt val} {
        set options(-rmf) [::simlib::rmf name $val]
        $self DrawPlot
    }
        
    # Width of the plot in pixels; the height is computed from the
    # width.
    option -size -type {snit::integer -min 10 -max 1000} -default 100

    # Instance variables
    variable ymin
    variable ymax

    constructor {args} {
        set $options(-size) [from args -size 100]

        frame $win.bgframe -borderwidth 2 -background black
        install canvas using canvas $win.bgframe.canvas \
            -background white       \
            -height $options(-size) \
            -width $options(-size)  \
            -borderwidth 0          \
            -highlightthickness 0

        pack $canvas -fill both -expand no
        
        label $win.title -background white
        label $win.xaxis -background white -text "R"
        label $win.yaxis -background white -text "r"

        grid $win.title   -row 0 -column 0 -sticky sew   -padx 2
        grid $win.xaxis   -row 1 -column 1 -sticky ns    -padx 2
        grid $win.yaxis   -row 2 -column 0 -sticky ew    -pady 2
        grid $win.bgframe -row 1 -column 0 -sticky nsew

        $self configurelist $args
        $hull configure -background white

        $self DrawPlot
    }

    method DrawPlot {} {
        $canvas delete all

        # FIRST, set the title
        $win.title configure -text [rmf longname $options(-rmf)]

        # NEXT, The X range is always -1 to 1, and the Y range is large
        # enough to contain the plot, rounded to the nearest integer.
        # Compute the ymin and ymax values.

        $self GetYLimits

        # NEXT, set the height of the canvas
        set wid $options(-size)
        set half [expr {$wid/2.0}]
        set ht [expr {$half * ($ymax - $ymin)}]

        $canvas configure -height $ht

        # NEXT, we want to draw the Y axis.
        $canvas create line $half 0 $half $ht -fill black -width 1
        
        # NEXT, we want to draw horizontal lines at every unit, from top
        # to bottom, except at the extremes.

        for {set y [expr {$ymin + 1}]} {$y < $ymax} {incr y} {
            set cy [expr {($ymax - $y)*$half}]
            $canvas create line 0 $cy $wid $cy -fill black -width 1
        }

        # NEXT, draw the function
        set line {}
        for {set x -1.0} {$x <= 1.0} {set x [expr {$x + 0.01}]} {
            set y [rmf $options(-rmf) $x]


            set i [expr {$wid*($x + 1.0)/2.0}]
            set j [expr {$ht - $ht*($y - $ymin)/($ymax - $ymin)}]

            lappend line $i $j
        }

        $canvas create line $line -fill red -width 4

    }

    # GetYLimits
    #
    # Compute the ymin and ymax values

    method GetYLimits {} {
        set limit 1

        # The limits are at the extremes, so compute the two
        # extremes.

        foreach value {-1.0 1.0} {
            set y [rmf $options(-rmf) $value]
            
            if {abs($y) > $limit} {
                set limit [expr {int(ceil(abs($y)))}]
            }
        }

        set ymax $limit
        set ymin [expr {-$limit}]
    }

}

# capture window file
# 
# window       A Tk window name
# file         A file name, e.g., foo.gif
#
# Captures the window's contents as a GIF image, and saves the image to
# the named file.  Note that the window must be visible, and all
# drawing must already be done.
proc capture {window file} {
   set image [image create photo -format window -data $window]
   $image write -format gif $file
   image delete $image
}

proc putplot {name r c} {
    rmfplot .plot$name -rmf $name

    grid .plot$name -row $r -column $c -padx 5 -sticky nsew
}

#-------------------------------------------------------------------
# Main line code

# FIRST, set the nominal relationship to 1.0
rmf parm set rmf.nominalRelationship 1.0


# NEXT, get the min and max extremes.
putplot constant 0 0
putplot linear   0 1
putplot quad     0 2

putplot frquad   1 0
putplot frmore   1 1
putplot enquad   1 2
putplot enmore   1 3

# NEXT, set the window background to white
. configure -background white

if {[llength $argv] > 0} {
    # Wait until it's visible.
    tkwait visibility .
    update idletasks

    capture . [lindex $argv 0]
}











