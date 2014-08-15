#-----------------------------------------------------------------------
# TITLE:
#   mapref.tcl
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
#   marsutil(n) module: a generic projection(i) type.
#
#   Routines for conversion between canvas coordinates and map references.
#   A map is an image file used as a map background.
#
#   There are three kinds of coordinate in use:
#
#   * Canvas coordinates: cx,cy coordinates extending to the right and
#     and down from the origin.  The full area of the canvas can be
#     much larger than the visible area.  Canvas coordinates are floating
#     point pixels.  The canvas coordinates for a map location are
#     unique for any given zoom factor, but vary from one zoom factor
#     to another.  Conversions to and from canvas coordinates take
#     the zoom factor into account.
#
#   * Map units: mx,my coordinates extending to the right and down from
#     the upper-left corner of the map image.  Map units are
#     independent of zoom factor.  Map units are determined as
#     follows:
#
#         map units = canvas units / (map factor * (zoom factor/100.0))
#
#     The zoom factor is a number, nominally 100, which indicates the
#     zoom level, i.e., 100%, 200%, 50%, etc.
#
#     The map factor is computed as follows:
#
#         map factor = max(map width, map height)/999.0
#
#     In other words, the long dimension of the map image, in pixels, 
#     is divided into 999 units.  The map factor can be computed
#     once, for the 100% (default) zoom, and combined with the zoom
#     factor as shown above, or recomputed for each zoom.  This code
#     does the former.  Map units are integer units.
#
#   * Map references (map refs): A map ref is a six-digit
#     alphanumeric string that is equivalent to an x,y pair in map
#     units.
#
#     * Each coordinate is a number between 000 and 999.  The first
#       digit is turned into a character, A,B,C,D,E,F,G,H,J,K.  Thus,
#       0,0 is A00A00 and 123,456 is B23E56.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsutil:: {
    namespace export mapref zoomfactor
}

#-----------------------------------------------------------------------
# mapref type

snit::integer ::marsutil::zoomfactor -min 1 -max 300

snit::type ::marsutil::mapref {
    #-------------------------------------------------------------------
    # Options

    # Width and height of map, in pixels
    option -width  \
        -type {snit::integer -min 1}  \
        -default 1000

    option -height \
        -type {snit::integer -min 1}  \
        -default 1000

    #-------------------------------------------------------------------
    # Instance Variables

    # map factor: map_unit = factor*canvas_unit
    variable mapFactor 1.0

    # mwid, mht
    #
    # Dimensions in map coordinates
    
    variable mwid 1000
    variable mht  1000
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {

        $self configurelist $args

        set mapFactor [expr {
            max($options(-width),$options(-height))/999.0
        }]

        set mwid [expr {round($options(-width)  / $mapFactor)}]
        set mht  [expr {round($options(-height) / $mapFactor)}]
    }

    #-------------------------------------------------------------------
    # Methods

    # box
    #
    # Returns the bounding box of the map in map units

    method box {} {
        list 0 0 $mwid $mht
    }

    # dim
    #
    # Returns the dimensions of the map in map units

    method dim {} {
        list $mwid $mht
    }

    # c2m zoom cx cy
    #
    # zoom     Zoom factor
    # cx,cy    Position in canvas units
    #
    # Returns the position in map units

    method c2m {zoom cx cy} {
        set fac [expr {$mapFactor * ($zoom/100.0)}]

        list [expr {round($cx / $fac)}] [expr {round($cy / $fac)}]
    }

    # m2c zoom mx my....
    #
    # zoom     Zoom factor
    # mx,my    One or points in map units
    #
    # Returns the points in canvas units

    method m2c {zoom args} {
        set out [list]

        foreach {mx my} $args {
            set fac [expr {$mapFactor * ($zoom/100.0)}]

            lappend out [expr {$mx * $fac}] [expr {$my * $fac}]
        }

        return $out
    }

    # c2ref zoom cx cy
    #
    # zoom     Zoom factor
    # cx,cy    Position in canvas units
    #
    # Returns the position as a map reference

    method c2ref {zoom cx cy} {
        set fac [expr {$mapFactor * ($zoom/100.0)}]

        return [GetRef $fac $cx][GetRef $fac $cy]
    }


    # c2loc zoom cx cy
    #
    # zoom     Zoom factor
    # cx,cy    Position in canvas units
    #
    # Returns the position as a map location for purposes of display, 
    # which in the projection is trivially the map reference string.

    method c2loc {zoom cx cy} {
        return [$self c2ref $zoom $cx $cy]
    }

    # ref2c zoom ref...
    #
    # zoom     Zoom factor
    # ref      A map reference
    #
    # Returns a list {cx cy} in canvas units

    method ref2c {zoom args} {
        set fac [expr {$mapFactor * ($zoom/100.0)}]

        foreach ref $args {
            lappend result \
                [expr {[GetCan $fac [string range $ref 0 2]]}] \
                [expr {[GetCan $fac [string range $ref 3 5]]}]
        }

        return $result
    }

    # m2ref mx my....
    #
    # mx,my    Position in map units
    #
    # Returns the position(s) as mapref strings

    method m2ref {args} {
        set result [list]

        foreach {mx my} $args {
            lappend result [GetRef 1.0 $mx][GetRef 1.0 $my]
        }
        
        return $result
    }

    # ref2m ref...
    #
    # ref   A map reference string
    #
    # Returns a list {mx my...} in map units

    method ref2m {args} {
        set result ""

        foreach ref $args {
            lappend result \
                [expr {round([GetCan 1.0 [string range $ref 0 2]])}] \
                [expr {round([GetCan 1.0 [string range $ref 3 5]])}]
        }

        return $result
    }

    # ref validate ref....
    #
    # ref   A map reference
    #
    # Validates the map reference for form and content.

    method {ref validate} {args} {
        set prefix ""

        foreach ref $args {
            if {[llength $args] > 1} {
                set prefix "point \"$ref\" is "
            }

            if {![regexp {^([A-HJK]\d\d){2}$} $ref]} {
                return -code error -errorcode INVALID \
                    "${prefix}not a map reference string"
            }
        }

        return $args
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # GetRef factor cu
    #
    # factor    The map factor
    # cu        A coordinate value in canvas units
    #
    # Returns the mapref coordinate, e.g., "A35".
    # Pass factor=1.0 to convert map units into a ref

    proc GetRef {factor cu} {
        set mu [expr {round($cu/$factor)}]

        set tail [expr {$mu % 100}]
        set head [expr {$mu / 100}]
        set char [lindex {A B C D E F G H J K L} $head]

        return "$char[format %02d $tail]"
    }

    # GetCan factor ref
    #
    # factor    The map factor
    # ref       A map ref coordinate value, e.g., "A35".
    #
    # Returns the coordinate in canvas units.
    # Pass factor=1.0 to convert into map units.

    proc GetCan {factor ref} {
        set char [string toupper [string index $ref 0]]
        scan [string range $ref 1 end] %d tail
        set head [lsearch -exact {A B C D E F G H J K L} $char]
        
        set cu [expr {$factor*(100.0*$head + $tail)}]
        
        return $cu
    }
}



