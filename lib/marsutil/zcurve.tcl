#-----------------------------------------------------------------------
# TITLE:
#	zcurve.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Mars: marsutil(n) module: zcurve function
#
#	A zcurve is a piecewise-linear function with three segments; 
#       it's called a Z-curve because of its shape.  Here's a 
#       stereotypical example, Z(x)
#
#               |            a                    |
#           low |------------+                    |     
#               |             \                   |
#               |              \                  |
#               |               \                 |
#               |                \                |
#               |                 \               |
#               |                  \              |
#               |                   \             |
#               |                    +------------| high
#               |                    b            |
#               +----------------+----------------+
#             -100               0              +100
#
#       The X-axis is shown as running from -100 to +100,
#       but this is not essential.  The only real constraint is that
#       a <= b.  "low" is the output value associated with low
#       input values; "high" is the output value associated with 
#       high input values.  If "low" < "high" you get a curve
#       that slopes up from left to right.
#
#       If a == b (within an epsilon), then Z(a) equals Z(b) equals
#       the average of low and high.
#
#       The function is computed as follows:
#
#       * If x < a, then Z(x) = low
#       * Else, if x > b then Z(x) = high
#       * Else, if (b - a) < epsilon then Z(x) = (low + high)/2.
#       * Else, Z(x) is on the line from (a,low) to (b,high)
#
#       The slope of the line between a and b is (rise/run) or
#
#           slope = (high - low) / (b - a)
#
#       so when a < x < b
#
#           Z(x) = low + slope * (x - a)
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export Public Commands

namespace eval ::marsutil:: {
    namespace export zcurve
}

#-----------------------------------------------------------------------
# zcurve type-definition ensemble

snit::type ::marsutil::zcurve {
    #-------------------------------------------------------------------
    # Type Variables

    typevariable epsilon 0.1
    
    #-------------------------------------------------------------------
    # Ensemble Subcommands

    # validate curve
    #
    # curve       Z-curve parameters {lo a b hi}
    #
    # Validates the parameters, throwing an error on failure and
    # returning them unchanged on success.

    typemethod validate {curve} {
        # FIRST, does it have four elements?
        if {[llength $curve] != 4} {
            return -code error -errorcode INVALID \
                "invalid zcurve, should be {lo a b hi}: \"$curve\""
        }

        lassign $curve lo a b hi

        if {![string is double -strict $lo]} {
            return -code error -errorcode INVALID \
                "invalid zcurve, lo is not a number: \"$lo\""
        }
        
        if {![string is double -strict $a]} {
            return -code error -errorcode INVALID \
                "invalid zcurve, a is not a number: \"$a\""
        }
        
        if {![string is double -strict $b]} {
            return -code error -errorcode INVALID \
                "invalid zcurve, b is not a number: \"$b\""
        }
        
        if {$a > $b} {
            return -code error -errorcode INVALID \
                "invalid zcurve, (a=$a) > (b=$b)"
        }
        
        if {![string is double -strict $hi]} {
            return -code error -errorcode INVALID \
                "invalid zcurve, hi is not a number: \"$hi\""
        }
        
        return $curve
    }

    # eval curve x
    #
    # curve      A list of parameters {lo a b hi} which define the
    #            Z curve.
    # x          The x value
    #
    # Computes and returns the value of Z(x) for the Z-curve defined by the
    # curve.

    typemethod eval {curve x} {
        lassign $curve lo a b hi

        if {$x < $a} {
            return [expr double($lo)]
        } elseif {$x > $b} {
            return [expr double($hi)]
        } elseif {$b - $a < $epsilon} {
            return [expr {(double($lo) + double($hi))/2}]
        } else {
            set slope \
                [expr {(double($hi) - double($lo))/(double($b) - double($a))}]
            
            return [expr {double($lo) + $slope*(double($x) - double($a))}]
        }
    }

    #-------------------------------------------------------------------
    # Instance Options

    # -xmin
    # -xmax
    # -ymin
    # -ymax
    #
    # Set the min and max limits for the Z-curve.

    option -xmin -default -100.0 -type snit::double -readonly yes
    option -xmax -default  100.0 -type snit::double -readonly yes
    option -ymin -default    0.0 -type snit::double -readonly yes
    option -ymax -default  100.0 -type snit::double -readonly yes

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        # NEXT, verify them.
        if {$options(-xmin) > $options(-xmax)} {
            error "-xmin > -xmax ($options(-xmin) > $options(-xmax))"
        }

        if {$options(-ymin) > $options(-ymax)} {
            error "-ymin > -ymax ($options(-ymin) > $options(-ymax))"
        }
    }

    #-------------------------------------------------------------------
    # Instance Methods

    delegate method eval using {%t eval}

    # validate curve
    #
    # curve       Z-curve parameters {lo a b hi}
    #
    # Validates the parameters, throwing an error on failure and
    # returning them unchanged on success.
    #
    # First uses [zcurve validate], then checks the limits.

    method validate {curve} {
        # FIRST, validate as a general z-curve
        $type validate $curve

        # NEXT, check the limits
        lassign $curve lo a b hi

        if {$a < $options(-xmin) || $a > $options(-xmax)} {
            return -code error -errorcode INVALID \
  "invalid a \"$a\", expected value in range $options(-xmin), $options(-xmax)"
        }
        
        if {$b < $options(-xmin) || $b > $options(-xmax)} {
            return -code error -errorcode INVALID \
  "invalid b \"$b\", expected value in range $options(-xmin), $options(-xmax)"
        }

        if {$lo < $options(-ymin) || $lo > $options(-ymax)} {
            return -code error -errorcode INVALID \
 "invalid lo \"$lo\", expected value in range $options(-ymin), $options(-ymax)"
        }
        
        if {$hi < $options(-ymin) || $hi > $options(-ymax)} {
            return -code error -errorcode INVALID \
 "invalid hi \"$hi\", expected value in range $options(-ymin), $options(-ymax)"
        }

        return $curve
    }






}





