#-----------------------------------------------------------------------
# TITLE:
#   latlong.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#	Latitude/Longitude Operations
#
#   These are Tcl equivalents for a subset of the commands provided by
#   Marsbin's latlong ensemble.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export latlong
}


#-----------------------------------------------------------------------
# Latlong Ensemble

# Include this code only if ::marsutil::latlong isn't defined in C++.
if {[llength [info commands ::marsutil::latlong]] == 0} {

snit::type ::marsutil::latlong {
    # Make it an ensemble
    pragma -hastypeinfo 0 -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Constants

    typevariable pi
    typevariable radians
    typevariable earthDiameter
    typevariable earthRadius

    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::marsutil::*

        # Pi
        set pi [expr {acos(-1.0)}]

        # Degrees to radians multiplier
        set radians [expr {$pi/180.0}]

        # Earth's diameter in kilometers, per CBS
        set earthDiameter 12742.0

        # Earth's radius in kilometers
        set earthRadius [expr {$earthDiameter/2.0}]
    }

    #-------------------------------------------------------------------
    # Variables

    # Pole for radius computations 
    typevariable pole {0.0 0.0}

    #-------------------------------------------------------------------
    # Ensemble subcommands

    # dist loc1 loc2
    #
    # loc1       A lat/long pair in decimal degrees.
    # loc2       A lat/long pair in decimal degrees.
    #
    # Distance in kilometers between the two points.

    typemethod dist {loc1 loc2} {

        $type dist4 [lindex $loc1 0] \
                    [lindex $loc1 1] \
                    [lindex $loc2 0] \
                    [lindex $loc2 1] 
    }

    # dist4 lat1 lon1 lat2 lon2
    #
    # lat1      Latitude  1 in decimal degrees
    # lon1      Longitude 1 in decimal degrees
    # lat2      Latitude  2 in decimal degrees
    # lon2      Longitude 2 in decimal degrees
    # 
    # Distance in kilometers between the two points.

    typemethod dist4 {lat1 lon1 lat2 lon2} {
        # Earth's diameter in kilometers, per CBS
        set diameter 12742.0

        set lat1 [expr {$lat1*$radians}]
        set lon1 [expr {$lon1*$radians}]

        set lat2 [expr {$lat2*$radians}]
        set lon2 [expr {$lon2*$radians}]

        # NEXT, compute the distance.
        set sinHalfDlat [expr {sin(($lat2 - $lat1)/2.0)}]
        set sinHalfDlon [expr {sin(($lon2 - $lon1)/2.0)}]

        expr {$diameter *
              asin(sqrt($sinHalfDlat * $sinHalfDlat +
                        cos($lat1)*cos($lat2)*$sinHalfDlon*$sinHalfDlon))}
    }

    # pole ?loc?
    #
    # loc       A lat/long pair in decimal degrees.
    #
    # Sets/gets pole for radius compuations.
    
    typemethod pole {{loc ""}} {
        if {[llength $loc] == 2} {
            set pole $loc
        }

        return $pole
    }

    # radius lat lon
    #
    # lat       A latitude in decimal degrees.
    # lon       A longitude in decimal degrees.
    #
    # Distance from pole, in kilometers.

    typemethod radius {lat lon} {
        $type dist $pole [list $lat $lon]
    }

    # area coords
    #
    # coords     The lat/long coordinates in decimal degrees of a
    #            polygon, expressed in counter-clockwise order.
    #
    # Computes the area of the polygon in square kilometers, taking
    # curvature of the earth into account.
    #
    # Assumptions:
    #
    # * Polygon is expressed in counter-clockwise order.
    # * Polygon must be simply connected, with no loops or holes.
    # * Polygon edges are assumed to be segments of great circles.
    # * The polygon may not contain either the north or south pole.
    # * Earth is assumed to be a perfect sphere with diameter 12472.0
    #   kilometers.
    # * The sine of the latitude of each edge is approximated throughout
    #   its length by the average of the sines of the latitudes of its
    #   end points.
    #
    # Properties:
    #
    # * The polygon must be CCW; but if it is not, the result has the
    #   same magnitude, but is negative.  This means that this operation 
    #   can be used to determine whether the polygon is CCW or not; and 
    #   correct it if not.

    typemethod area {coords} {
        # FIRST, verify the length
        set len [llength $coords]
        require {$len % 2 == 0} \
            "expected even number of coordinates, got $len: \"$coords\""

        let size {$len/2}
        require {$size >= 3} \
            "expected at least 3 point(s), got $size: \"$coords\""

        # NEXT, convert the vertices to radians from decimal degrees
        set rcoords {}

        foreach {lat lon} $coords {
            latlong validate [list $lat $lon]
            let rlat {$lat*$radians}
            let rlon {$lon*$radians}

            lappend rcoords $rlat $rlon
        }

        # NEXT, compute the sum
        set sum 0.0

        let n [clength $rcoords]

        for {set i 0} {$i < $n} {incr i} {
            let j {($i - 2) % $n}
            let k {($i - 1) % $n}

            set ilon [py [cindex $rcoords $i]]
            set jlon [py [cindex $rcoords $j]]
            set klat [px [cindex $rcoords $k]]

            let sum {$sum + ($ilon - $jlon)*sin($klat)}
        }

        let area {-($earthRadius*$earthRadius/2.0)*$sum}

        return $area
    }

    # validate loc
    #
    # loc          A lat/long pair in decimal degrees
    #
    # Validates a lat/long pair: lat must be a double number between
    # -90.0 and 90.0 degrees, and lon must be a double number between
    # -180.0 and 360.0 degrees.

    typemethod validate {loc} {
        require {[llength $loc] == 2} \
            "expected lat/long pair, got: \"$loc\""

        set lat [lindex $loc 0]
        set lon [lindex $loc 1]

        require {[string is double -strict $lat]} \
            "expected floating-point number but got \"$lat\""

        require {[string is double -strict $lon]} \
            "expected floating-point number but got \"$lon\""

        require {$lat >= -90.0 && $lat <= 90.0} \
            "invalid latitude, should be -90.0 to 90.0 degrees: \"$lat\""

        require {$lon >= -180.0 && $lon <= 360.0} \
            "invalid longitude, should be -180.0 to 360.0 degrees: \"$lon\""

        return $loc
    }

    #-------------------------------------------------------------------
    # Unimplemented methods
    #
    # The following methods are implemented only in the C++ version of
    # the command.

    delegate typemethod spheroid to UnimplementedSubcommand
    delegate typemethod tomgrs   to UnimplementedSubcommand
    delegate typemethod frommgrs to UnimplementedSubcommand
    delegate typemethod togcc    to UnimplementedSubcommand
    delegate typemethod fromgcc  to UnimplementedSubcommand

    typemethod UnimplementedSubcommand {args} {
        error "subcommand requires libMarsUtil.so"
    }

}

# End of Conditional Inclusion
}










