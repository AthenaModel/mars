#-----------------------------------------------------------------------
# TITLE:
#   geometry.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Geometry utilities
#
#   Computational geometry routines.  The code in this module
#   derives from Sedgewick's _Algorithms in C_, 1990, Addison-Wesley,
#   as modified for use in CBS by Paul Firnett, and from an article
#   by Paul Bourke found on the web at 
#
#       http://astronomy.swin.edu.au/~pbourke/geometry/insidepoly
#
#   Note: some of these routines are also provided in Marsbin(n)
#   for speed.
#  
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Routines

namespace eval ::marsutil:: {
    namespace export \
        bbox         \
        boxaround    \
        ccw          \
        cedge        \
        cindex       \
        clength      \
        creverse     \
        intersect    \
        avgpoint     \
        point        \
        ptinpoly     \
        px           \
        py
}

#-----------------------------------------------------------------------
# Points
#
# A "point" is an x,y pair; it will be represented as a Tcl list with
# two elements.
#
# Examples:
#
#   set p1 [list 1.0 2.0]
#   set p2 {1.0 2.0}
#
# Helper commands:
#
#   set p1 [point $x $y]
#   set x [px $p1]
#   set y [py $p1]

# point x y
#
# x        An X coordinate
# y        A Y coordinate
#
# Creates a point given the coordinates

proc ::marsutil::point {x y} {
    list $x $y
}

# px point
#
# point      A point
#
# Returns a point's X coordinate

proc ::marsutil::px {point} {
    lindex $point 0
}

# py point
#
# point      A point
#
# Returns a point's Y coordinate

proc ::marsutil::py {point} {
    lindex $point 1
}

# avgpoint coords
#
# coords   A list of point pairs
#
# Returns the average of the provided points

proc ::marsutil::avgpoint {coords} {
        set len [llength $coords]
        set sumx 0.0
        set sumy 0.0
        foreach {px py} $coords {
            let sumx {$sumx+$px}
            let sumy {$sumy+$py}
        }

        let avgx {$sumx/($len/2)}
        let avgy {$sumy/($len/2)}

        list $avgx $avgy
}

if {[llength [info commands ::marsutil::ccw]] == 0} {
    # ccw a b c
    #
    # a     A point
    # b     A point
    # c     A point
    #
    # Checks whether a path from point a to point b to point c turns 
    # counterclockwise or not.
    #
    #                   c
    #                   |
    # Returns:   1    a-b    or   a-b-c
    #
    #
    #           -1    a-b    or   c-a-b
    #                   | 
    #                   c
    #
    #            0    a-c-b
    #                 
    # From Sedgewick, Algorithms in C, page 350, via the CBS Simscript
    # code.  Explicitly handles the case where a == b, which Sedgewick's
    # code doesn't.

    proc ::marsutil::ccw {a b c} {
        # FIRST, Compute the deltas from a-b and from a-c
        let dx1 {[px $b] - [px $a]}
        let dy1 {[py $b] - [py $a]}
        let dx2 {[px $c] - [px $a]}
        let dy2 {[py $c] - [py $a]}

        # NEXT, see if point c is on the left of a-b
        if {$dx1 * $dy2 > $dy1 * $dx2} {
            return 1
        }

        # NEXT, see if point c is on the right of a-b
        if {$dx1 * $dy2 < $dy1 * $dx2} {
            return -1
        }

        # NEXT, the points are collinear.
        # c-a-b
        if {($dx1 * $dx2 < 0) || ($dy1 * $dy2 < 0)} {
            return -1
        }

        # Explicitly handle the case where a == b
        if {$dx1 == 0 && $dy1 == 0} {
            # a == b

            if {$dx2 < 0} {
                # [px $c] < [px $a]
                return -1
            } elseif {$dx2 > 0} {
                # [px $c] > [px $a]
                return 1
            } else {
                return 0
            }
        }
        
        if {($dx1*$dx1 + $dy1*$dy1) < ($dx2*$dx2 + $dy2*$dy2)} {
            return 1
        }

        return 0
    } 
}

#-------------------------------------------------------------------
# intersect p1 p2 q1 q2
#
# Given two line segments p1-p2 and q1-q2, returns 1 if the line
# segments intersect and 0 otherwise.  The segments are still said
# to intersect if the point of intersection is the end point of one
# or both segments.  Either segment may be degenerate, i.e.,
# p1 == p2 and/or q1 == q2.
#
# From Sedgewick, Algorithms in C, 1990, Addison-Wesley, page 351.
# The comments include material from the CBS Simscript implementation.

if {[llength [info commands ::marsutil::intersect]] == 0} {
    proc ::marsutil::intersect {p1 p2 q1 q2} {
        expr {
              (([ccw $p1 $p2 $q1] * [ccw $p1 $p2 $q2]) <= 0) &&
              (([ccw $q1 $q2 $p1] * [ccw $q1 $q2 $p2]) <= 0)
          }
    }
}


#-----------------------------------------------------------------------
# Lists of coordinates
#
# A coordinate list contains a sequence of x,y coordinates, e.g.,
#
#   {x1 y1 x2 y2 ...}
#

# cedge coords i
#
# coords   A list of x,y coordinates
# i        An integer index
#
# Returns the ith edge as a list {x1 y1 x2 y2}.  Indices wrap around.

proc ::marsutil::cedge {coords i} {
    set ndx [expr {2*$i % [llength $coords]}]

    lrange [concat $coords [lrange $coords 0 1]] $ndx $ndx+3
}


# cindex coords i
#
# coords       A list of x,y coordinates
# i            An integer index
#
# Returns the ith coordinate pair

proc ::marsutil::cindex {coords i} {
    set xindex [expr {2*$i % [llength $coords]}]
    set yindex [expr {$xindex + 1}]

    return [lrange $coords $xindex $yindex]
}

# clength coords
#
# coords       A list of x,y coordinates
#
# Returns the number of coordinate pairs

proc ::marsutil::clength {coords} {
    return [expr {[llength $coords] / 2}]
}

# creverse coords
#
# coords       A list of x,y coordinates
#
# Returns the list in reverse order.

proc creverse {coords} {
    set n [llength $coords]

    set result {}

    for {set i [expr {$n-2}]} {$i >= 0} {incr i -2} {
        lappend result [lindex $coords $i]
        lappend result [lindex $coords [expr {$i + 1}]]
    }

    return $result
}

# bbox coords
#
# coords       A list of x,y coordinates
#
# Return the coordinates of the bounding box of the coords as
# a list {xmin ymin xmax ymax}.

if {[llength [info commands ::marsutil::bbox]] == 0} {
    proc ::marsutil::bbox {coords} {
        set xmin [lindex $coords 0]
        set ymin [lindex $coords 1]
        set xmax $xmin
        set ymax $ymin

        foreach {x y} [lrange $coords 2 end] {
            if {$x < $xmin} {
                set xmin $x
            } elseif {$x > $xmax} {
                set xmax $x
            }

            if {$y < $ymin} {
                set ymin $y
            } elseif {$y > $ymax} {
                set ymax $y
            }
        }
    
        return [list $xmin $ymin $xmax $ymax]
    }
}

# boxaround radius x y
#
# radius   A distance
# x,y      A point
#
# Returns a box {x1 y1 x2 y2} = {x-radius y-radius x+radius y+radius}

proc ::marsutil::boxaround {radius x y} {
    list \
        [expr {$x - $radius}] \
        [expr {$y - $radius}] \
        [expr {$x + $radius}] \
        [expr {$y + $radius}]
}

#-----------------------------------------------------------------------
# Polylines and Polygons
#
# A polyline is an ordered list of x,y coordinates, e.g., the
# following list defines a polyline of two segments.
#
#    {0 0  1 0  1 1}
#
# A polygon is a closed polyline, i.e., there is an implicit segment
# from the last point back to the first point.  Thus, the preceding
# example defines a triangle.  Note that polygon points must be specified 
# in counterclockwise order.
#

# ptinpoly poly p ?bbox?
#
# poly     A polygon -- a list of coordinates.
# p        A point   -- a list {x y}
# bbox     Optionally, the polygon's bounding box; otherwise, the 
#          bounding box will be computed.
#
# This function determines whether a given point p is inside or outside
# of a given polygon; if a point is on an edge or vertex it is defined to
# be on the inside.  The function determines this by:
#
# (1) Comparing p against the bounding box of the polygon; if it's outside
#     the bounding box, it's outside the polygon.
#
# (2) Checking p against each edge of the polygon, using [intersect].
#     If it's explicitly on the border, it's "inside".
#
# (3) Checking whether p is inside the polygon by counting the number
#     intersections made between q and a point outside the polygon.
#     This part of the algorithm was found in an on-line paper by
#     Paul Bourke called "Determining If A Point Lies On The Interior
#     Of A Polygon", at 
#
#     http://astronomy.swin.edu.au/~pbourke/geometry/insidepoly
#
# Returns 1 if p is inside (or on the border) and 0 if p is outside.

if {[llength [info commands ::marsutil::ptinpoly]] == 0} {

    proc ::marsutil::ptinpoly {poly p {bbox ""}} {
        # FIRST, get the coordinates of the point and the bounding box
        # of the polygon.
        set x [px $p]
        set y [py $p]

        # NEXT, get the bounding box, or use the provided one.
        if {[llength $bbox] != 4} {
            set bbox [bbox $poly]
        }

        # NEXT, if q is outside the bounding box, it's outside the
        # polygon.
        # TBD: Use lassign when we move to Tcl 8.5
        foreach {xmin ymin xmax ymax} $bbox {}

        if {$x < $xmin || $x > $xmax ||
            $y < $ymin || $y > $ymax} {
            return 0
        }

        # NEXT, get the length of the polygon.
        set n [clength $poly]

        # NEXT, count the intersections
        set counter 0
        set p1 [cindex $poly 0]

        for {set i 1} {$i <= $n} {incr i} {
            set p2 [cindex $poly $i]

            # FIRST, if the point is on this edge then it's "inside"
            if {[intersect $p1 $p2 $p $p]} {
                return 1
            }

            # NEXT, check for an intersection
            set x1 [lindex $p1 0]
            set y1 [lindex $p1 1]
            set x2 [lindex $p2 0]
            set y2 [lindex $p2 1]

            if {$y > min($y1,$y2)} {
                if {$y <= max($y1,$y2)} {
                    if {$x <= max($x1,$x2)} {
                        if {$y1 != $y2} {
                            let xInters {
                                ($y - $y1)*($x2 - $x1)/($y2 - $y1) + $x1
                            }

                            if {$x1 == $x2 || $x <= $xInters} {
                                incr counter
                            }
                        }
                    }
                }
            }
            
            set p1 $p2
        }

        if {$counter % 2 == 0} {
            return 0
        } else {
            return 1
        }
    }

}



