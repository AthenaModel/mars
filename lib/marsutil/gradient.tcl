#-----------------------------------------------------------------------
# TITLE:
#    gradient.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) Module: Color Gradient Computer
#
#    This module defines the "gradient" type, which is used to compute
#    color gradients, linear interpolations between two colors.  
#    A gradient is defined by its endpoints and by a min and max
#    input level.  Then, given an input level a gradient object computes
#    an output color in which R, G, and B are each interpolated
#    separately.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export gradient
}

#-----------------------------------------------------------------------
# gradient

snit::type ::marsutil::gradient {
    #-------------------------------------------------------------------
    # Options

    # -mincolor
    #
    # A hexadecimal color string, e.g., "#FFFFFF"
    
    option -mincolor -default "#FFFFFF" -configuremethod ConfigMinColor

    method ConfigMinColor {opt val} {
        set options($opt) $val

        scan $val "#%2x%2x%2x" min(r) min(g) min(b)
    }

    # -midcolor
    #
    # A hexadecimal color string, e.g., "#FFFFFF"
    
    option -midcolor -default "#FFFFFF" -configuremethod ConfigMidColor

    method ConfigMidColor {opt val} {
        set options($opt) $val

        scan $val "#%2x%2x%2x" mid(r) mid(g) mid(b)
    }


    # -maxcolor
    #
    # A hexadecimal color string, e.g., "#000000"

    option -maxcolor -default "#000000" -configuremethod ConfigMaxColor

    method ConfigMaxColor {opt val} {
        set options($opt) $val

        scan $val "#%2x%2x%2x" max(r) max(g) max(b)
    }

    # -minlevel
    #
    # The minimum input level

    option -minlevel -default 0.0

    # -midlevel
    #
    # The minimum input level

    option -midlevel -default 0.0

    # -maxlevel
    #
    # The maximum input level
    
    option -maxlevel -default 0.0

    #-------------------------------------------------------------------
    # Instance variables

    # Array of hex components of -mincolor
    variable min -array {
        r    0xFF
        g    0xFF
        b    0xFF
    }


    # Array of hex components of -midcolor
    variable mid -array {
        r    0xFF
        g    0xFF
        b    0xFF
    }


    # Array of hex components of -maxcolor
    variable max -array {
        r    0x00
        g    0x00
        b    0x00
    }

    #-------------------------------------------------------------------
    # Public Methods

    # color level
    #
    # level    An input level
    #
    # Given an input level between -minlevel and -maxlevel, produces
    # an output color between -mincolor and -maxcolor.  Actually, 
    # inputs from -minlevel to -midlevel scale between -mincolor and
    # -midcolor; inputs from -midlevel to -maxlevel scale between
    # -midcolor and -maxcolor.  Inputs outside of -minlevel,-maxlevel
    # are clamped.
   

    method color {level} {
        # FIRST, it all depends on where we are relative to the
        # -midlevel. 
        if {$level == $options(-midlevel)} {
            set out(r) $mid(r)
            set out(g) $mid(g)
            set out(b) $mid(b)
        } elseif {$level < $options(-midlevel)} {
            # FIRST, clamp.
            set level [expr {max($options(-minlevel), $level)}]

            # NEXT, compute the level fraction
            set frac \
                [expr {double($level - $options(-minlevel))/ \
                           double($options(-midlevel) - $options(-minlevel))}]

            # NEXT, interpolate the three color channels separately.
            foreach c [list r g b] {
                if {$min($c) == $mid($c)} {
                    set out($c) $min($c)
                } else {
                    set out($c) \
                        [expr {int($min($c) + $frac*($mid($c) - $min($c)))}]
                }
            }
        } else {
            # FIRST, clamp.
            set level [expr {min($options(-maxlevel), $level)}]

            # NEXT, compute the level fraction
            set frac \
                [expr {double($level - $options(-midlevel))/ \
                           double($options(-maxlevel) - $options(-midlevel))}]

            # NEXT, interpolate the three color channels separately.
            foreach c [list r g b] {
                if {$max($c) == $mid($c)} {
                    set out($c) $max($c)
                } else {
                    set out($c) \
                        [expr {int($mid($c) + $frac*($max($c) - $mid($c)))}]
                }
            }
        }

        set hexrgb [expr {($out(r) << 16) + ($out(g) << 8) + $out(b)}]

        return [format "#%06X" $hexrgb]
    }
}






