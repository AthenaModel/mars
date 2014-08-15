#-----------------------------------------------------------------------
# TITLE:
#	geoset.tcl
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
#   Geometry collection data type
#
#   The geoset type manages a collection of polygons, polylines,
#   point objects.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export geoset
}

#-----------------------------------------------------------------------
# Polymap Type

snit::type ::marsutil::geoset {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::marsutil::*

        # Enumeration of item types supported in the map
        enum itemtype {
            line    line
            point   point
            polygon polygon
        }
    }


    #-------------------------------------------------------------------
    # Instance Variables

    # TBD: Move these into info()?
    variable itemtype     ;# Array of itemtypes by item ID
    variable itemcoords   ;# Array of item coordinates by item ID
    variable bbox         ;# Array of bounding boxes by item ID

    # info -- array of scalars
    #
    #  ids              List of all item IDs
    #  ids-$tag         List of ids by tag
    #  tags-$id         List of tags for each id.

    variable info -array {
        ids      {}
    }

    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    # Default Constructor

    # Default Destructor

    #-------------------------------------------------------------------
    # Public Methods

    # create point id point ?tagList?
    #
    # id        The item ID; must be unique
    # point     The point
    # tagList   List of tags associated with this item
    #
    # Creates a point item named id given the coordinates, and associates
    # the tags with it.
    
    method {create point} {id point {tagList ""}} {
        ValidatePoint $point

        $self CreateItem point $id $point $tagList
    }

    # create line id coords ?tagList?
    #
    # id        The item ID; must be unique
    # coords    The list of coords.
    # tagList   List of tags associated with this item
    #
    # Creates a polyline named id given the list of coords, and associates
    # the tags with it.

    method {create line} {id coords {tagList ""}} {
        ValidateCoordinates $coords 2

        $self CreateItem line $id $coords $tagList
    }

    # create polygon id coords ?tagList?
    #
    # id        The item ID; must be unique
    # coords    The list of coords.
    # tagList   List of tags associated with this item
    #
    # Creates a polygon named id given the list of coords, and associates
    # the tags with it.

    method {create polygon} {id coords {tagList ""}} {
        ValidateCoordinates $coords 3

        $self CreateItem polygon $id $coords $tagList
    }


    # CreateItem theType id coords tagList
    #
    # theType     an itemtype value
    # id          The item ID; must be unique
    # coords      The list of coords.
    # tagList     List of tags associated with this item
    #
    # Creates the item; assumes all data is valid.

    method CreateItem {theType id coords tagList} {
        identifier validate $id

        if {[info exists itemcoords($id)]} {
            error "item already exists with id: \"$id\""
        }
        
        # Remember the item's data
        lappend info(ids)      $id

        set itemcoords($id) $coords
        set bbox($id) [bbox $coords]
        set itemtype($id) $theType

        # Tag it with its type
        set info(tags-$id) $theType
        lappend info(ids-$theType) $id
        
        # Tag it with all other tags.
        foreach tag $tagList {
            $self tag $id $tag
        }
    }

    # delete id
    #
    # id      An item ID
    #
    # Deletes the item with this ID.

    method delete {id} {
        ldelete info(ids) $id
        unset itemcoords($id)
        unset bbox($id)
        foreach tag $info(tags-$id) {
            ldelete info(ids-$tag) $id
        }
        unset info(tags-$id)
        unset itemtype($id)
    }

    # exists id
    #
    # id      An item ID
    #
    # Returns 1 if there's an item with this ID and 0 otherwise

    method exists {id} {
        info exists itemcoords($id)
    }

    # itemtype id
    #
    # id      An item ID
    #
    # Returns the itemtype of the specified item.

    method itemtype {id} {
        if {![info exists itemtype($id)]} {
            error "unknown ID: \"$id\""
        }

        return $itemtype($id)
    }

    # coords id
    #
    # id      An item ID
    #
    # Gets the points associated with the item as a list of coords

    method coords {id} {
        if {![info exists itemcoords($id)]} {
            error "unknown ID: \"$id\""
        }
        return $itemcoords($id)
    }

    # bbox ?tagOrId?
    #
    # tagOrId     An item id or a known tag.
    #
    # Returns the bounding box for the item, the tagged items,
    # or all items.
    
    method bbox {{tagOrId ""}} {
        # FIRST, if they requested a specific item, return its
        # bounding box.
        if {[info exists bbox($tagOrId)]} {
            return $bbox($tagOrId)
        }

        # NEXT, validate tagOrId
        if {$tagOrId ne ""} {
            if {![info exists info(ids-$tagOrId)]} {
                error "unknown tag or ID: \"$tagOrId\""
            }
        }

        # NEXT, Otherwise, loop over all points in all tagged items.
        set coords {}

        foreach item [$self list $tagOrId] {
            foreach {xmin ymin xmax ymax} $bbox($item) {}

            lappend coords $xmin $ymin $xmax $ymax
        }

        if {[llength $coords] == 0} {
            error "no items found"
        }

        return [bbox $coords]
    }

    # tag id tag
    #
    # id        The item ID
    # tag       The tag
    #
    # Tags the item with the tag.

    method tag {id tag} {
        if {![info exists info(tags-$id)]} {
            error "unknown ID: \"$id\""
        }

        if {[lsearch $info(tags-$id) $tag] != -1} {
            return
        }
        lappend info(tags-$id) $tag
        lappend info(ids-$tag) $id
    }

    # tags id
    #
    # id        The item ID
    #
    # Returns the tags associated with the item.

    method tags {id} {
        if {![info exists info(tags-$id)]} {
            error "unknown ID: \"$id\""
        }

        return $info(tags-$id)
    }

    # list ?tag?
    #
    # tag     A tag
    #
    # Returns all items, or all items with the given tag.  If the
    # tag is unknown, returns the empty list.

    method list {{tag ""}} {
        if {$tag eq ""} {
            return $info(ids)
        } elseif {[info exists info(ids-$tag)]} {
            return $info(ids-$tag)
        } else {
            return {}
        }
    }

    # find point ?tag?
    #
    # Returns the ID of the uppermost (i.e., last) polygon 
    # which contains the specified point, or "".  If tag is given,
    # only polygons with that tag are included.

    method find {point {tag ""}} {
        ValidatePoint $point

        set ids [$self list $tag]

        let last {[llength $ids] - 1}

        for {set i $last} {$i >= 0} {incr i -1} {
            set id [lindex $ids $i]

            if {$itemtype($id) eq "polygon"} {
                if {[ptinpoly $itemcoords($id) $point $bbox($id)]} {
                    return $id
                }
            }
        }

        return ""
    }

    # clear
    #
    # Deletes all content

    method clear {} {
        array unset itemtype
        array unset itemcoords
        array unset bbox
        array unset info

        set info(ids) {}
    }

    #-------------------------------------------------------------------
    # Utility procedures

    proc ValidateCoordinates {coords minPoints} {
        if {[llength $coords] % 2 != 0} {
            error "expected even number of coordinates, got: \"$coords\""
        }

        if {[clength $coords] < $minPoints} {
            error "expected at least $minPoints points, got: \"$coords\""
        }

        foreach coord $coords {
            if {![string is double -strict $coord]} {
                error "invalid coordinate value: \"$coord\""
            }
        }
    }

    proc ValidatePoint {point} {
        if {[llength $point] != 2} {
            error "invalid point: \"$point\""
        }

        ValidateCoordinates $point 1
    }
}






