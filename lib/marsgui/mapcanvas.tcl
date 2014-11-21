#-----------------------------------------------------------------------
# TITLE:
#    mapcanvas.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Map Canvas widget
#
#    This is a canvas widget designed to display a map with
#    features upon it, including neighborhood polygons and asset icons.
#
# DISPLAYED OBJECTS:
#    mapcanvas(n) displays the following kinds of objects:
#
#    The Map
#        The map is an image file; the canvas' scroll region is precisely
#        the extent of the map.
#
#    Neighborhoods
#        Neighborhoods are represented as polygons.  By default, 
#        nbhood polygons have no fill, allowing the map to show through;
#        however, fill colors can be used as desired to convey nbhood
#        status and other relationships.
#
#    Icons
#        Icons are things positioned on the map, usually within 
#        neighborhoods: military units, infrastructure, etc.
#
# COORDINATE SYSTEMS:
#    mapcanvas(n) works with and translates between the following 
#    coordinate systems.
#
#    Window Coordinates
#        (x,y) with origin at the top-left of the canvas widget's
#        viewport.  Mouse-clicks come in with these coordinates via
#        the %x,%y event-handler substitutions.
#
#        In code, the symbols wx and wy are used for window coordinates.
#
#    Canvas Coordinates
#        (x,y) with origin at the top-left of the map, and extending
#        to the right and down.  Canvas coordinates are pixel coordinates.
#
#        In code, the symbols cx and cy are used for canvas coordinates.
#
#    Map Coodinates
#        (x,y), referring to unique positions on the map.  Conversion
#        between map coordinates and canvas coordinates is handled by
#        a coordinate-conversion object given to the mapcanvas when it
#        is created.
#
#        In code, the symbols mx and my are used for map coordinates.
#
#    Map Reference Strings
#        A map reference string, or "mapref" is a short string that
#        equivalent to some (x,y) in map coordinates (e.g., MGRS
#        strings are equivalent to lat/lon.  Conversion between
#        maprefs and canvas coordinates is also handled by the 
#        coordinate-conversion object.
#
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export mapcanvas mapimage
}

#-------------------------------------------------------------------
# Data Types

snit::type ::marsgui::mapimage {
    typemethod validate {img} {
        if {$img eq ""} {
            return
        }

        # NEXT, make sure it's an image
        if {[catch {
            image width $img
        } result]} {
            error "not an image"
        }
    }
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ::marsgui::mapcanvas {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # FIRST, Define the standard Mapcanvas bindings

        # Track when the pointer enters and leaves the window.
        bind Mapcanvas <Enter>  {%W MapEnter}
        bind Mapcanvas <Leave>  {%W MapLeave}

        # Support -locvariable
        bind Mapcanvas <Motion> {%W MaplocSet %x %y}

        # NEXT, Define the bindtags for the interaction modes

        # Mode: browse
        # No bindtags yet

        # Mode: point
        bind Mapcanvas.point <ButtonPress-1>       {%W Point-1 %x %y}

        # Mode: poly

        bind Mapcanvas.poly <ButtonPress-1>        {%W PolyPoint %x %y}
        bind Mapcanvas.poly <Motion>               {%W PolyMove  %x %y}
        bind Mapcanvas.poly <Double-ButtonPress-1> {%W PolyComplete}
        bind Mapcanvas.poly <Escape>               {%W PolyFinish}

        # Mode: pan

        bind Mapcanvas.pan <ButtonPress-1> {%W scan mark %x %y}
        bind Mapcanvas.pan <B1-Motion>     {%W scan dragto %x %y 1}
    }

    #-------------------------------------------------------------------
    # Lookup Tables

    # Zoom Factors: Dictionary of -zoom/-subsample values, by zoom
    # percentage

    typevariable zoomfactors {
        25  {1 4}
        50  {1 2}
        75  {3 4}
        100 {1 1}
        125 {5 4}
        150 {3 2}
        200 {2 1}
        250 {5 2}
        300 {3 1}
    }

    # Mode data, by mode name
    #
    #    cursor    Name of the Tk cursor for this mode
    #    cleanup   Name of a method to call when a different mode is
    #              selected.
    #    bindings  A list, {tag event binding ...}, of bindings on 
    #              canvas tags which should be used when this mode is
    #              in effect.

    typevariable modes -array {
        null {
            cursor   left_ptr
            cleanup  {}
            bindings {}
        }

        browse {
            cursor   left_ptr
            cleanup  {}
            bindings {
                icon   <ButtonPress-3>    {%W Icon-3 %x %y %X %Y}
                icon   <Button-1>         {%W IconMark %x %y}
                icon   <B1-Motion>        {%W IconDrag %x %y}
                icon   <B1-ButtonRelease> {%W IconRelease %x %y}
                nbhood <ButtonPress-1>    {%W Nbhood-1 %x %y %X %Y}
                nbhood <ButtonPress-3>    {%W Nbhood-3 %x %y %X %Y}
            }
        }

        point {
            cursor   crosshair
            cleanup  {}
            bindings {}
        }

        poly {
            cursor   crosshair
            cleanup  PolyCleanUp
            bindings {}
        }

        pan {
            cursor   fleur
            cleanup  {}
            bindings {}
        }
    }

    #-------------------------------------------------------------------
    # Type variables

    # Array of icon type data
    #
    # names        List of icon type names
    # icon-$name   Type command

    typevariable icontypes -array {
        names ""
    }

    #-------------------------------------------------------------------
    # Typemethods: Icon Management

    # icon register iconType
    #
    # iconType     A mapicon(i) type command
    #
    # Registers the iconType with the mapcanvas

    typemethod {icon register} {iconType} {
        set name [$iconType typename]

        if {$name ni $icontypes(names)} {
            lappend icontypes(names) $name
        }

        set icontypes(type-$name) $iconType
    }

    # icon types
    #
    # Returns a list of the icon type names

    typemethod {icon types} {} {
        return $icontypes(names)
    }

    #-------------------------------------------------------------------
    # Components

    component proj       ;# The projection(i) component

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    # -map
    #
    # Tk photo image of the map
    
    option -map                                 \
        -type            ::marsgui::mapimage \
        -configuremethod ConfigMap

    method ConfigMap {opt val} {
        # FIRST, save the map value
        if {$val eq $options(-map)} {
            return
        }

        set options(-map) $val

        # NEXT, clear the zoom cache
        foreach factor [array names zooms] {
            if {$factor ne "100"} {
                image delete $zooms($factor)
            }
        }
        
        array unset zooms

        # NEXT, set the zoom to 100%
        set zooms(100) $options(-map)

        if {$info(zoom) != 100} {
            $self ScaleMap $info(zoom)
        }


        # TBD: Might want to schedule a refresh....
    }

    # -projection
    #
    # A projection(i) object.  If not specified, a mapref(n) will be
    # used.

    option -projection

    # -locvariable
    #
    # A variable name.  It is set to the map location string of the
    # location under the mouse pointer.

    option -locvariable -default ""

    # -modevariable
    #
    # A variable name.  It is set to the current interaction mode, or
    # "" if none.

    option -modevariable -default ""

    # -snapradius
    #
    # Radius, in pixels, for snapping to points.

    option -snapradius \
        -type    {snit::integer -min 0} \
        -default 5

    # -snapmode
    #
    # Whether snapping is on or not.
    
    option -snapmode \
        -type    snit::boolean \
        -default yes

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   gotPointer      1 if mouse pointer over widget, 0 otherwise.
    #   iconCounter     Used to name icons
    #   mode            Current interaction mode
    #   modeTags        List of canvas tags associated with the current
    #                   mode's bindings.
    #   region          normal | extended
    #   regionNormal    Normal scroll region: shrinkwrapped to map image
    #   regionExtended  Extended scroll region: square
    #   zoom            Current zoom factor.

    variable info -array {
        gotPointer     0
        iconCounter    0
        mode           ""
        modeTags       {}
        region         normal
        regionNormal   {0 0 1000 1000}
        regionExtended {0 0 1000 1000}
        zoom           100
    }

    # zooms array
    #
    # Array of images by zoom factor.  The zoom factor is one of
    # the keys in the zoomfactors() array, e.g., 100 is full size.

    variable zooms -array {
        100 {}
    }

    # icons array
    #
    # ids               List of icon ids
    # ids-$icontype     List of icon ids by type
    # icon-$id          Dictionary of icon data for icon $id
    #      id           Icon id
    #      icontype     Icon type
    #      cmd          Icon command
    #      mxy          Icon location as map coordinate pair

    variable icons -array {
        ids {}
    }

    # nbhoods array
    #
    # ids              List of nbhood ides
    # refpoint-$id     Reference point as map coordinate pair
    # polygon-$id      Polygon as list of map coordinates
    # fill-$id         Polygon fill color
    # pointcolor-$id   Refpoint color
    # linewidth-$id    Width of polygon line in pixels
    # polycolor-$id    Polygon color

    variable nbhoods -array {
        ids {}
    }

    # trans: Data array used during multi-event user interactions

    variable trans -array {}

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the canvas
        installhull using canvas  \
            -highlightthickness 0 \
            -borderwidth        0

        # NEXT, replace Canvas in the bindtags with Mapcanvas
        set tags [bindtags $win]
        set ndx [lsearch -exact $tags Canvas]
        bindtags $win [lreplace $tags $ndx $ndx Mapcanvas]

        # NEXT, create the namespace for icon commands
        namespace eval ${selfns}::icons {}

        # NEXT, save the options
        $self configurelist $args

        # NEXT, display the initial map image; this also sets
        # the initial interaction mode.
        $self refresh
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # clear
    #
    # Clears all content from the mapcanvas and reinitializes it to
    # display -map using -projection. If -projection
    # is not defined, a mapref(n) instance will be used.

    method clear {} {
        # FIRST, delete all content

        # Nbhoods
        array unset nbhoods
        set nbhoods(ids) [list]

        # Icons
        $self icon delete all

        # NEXT, refresh the screen
        $self refresh
    }

    # zoom ?factor?
    #
    # factor    The zoom factor
    #
    # Sets/queries the zoom factor.  Changing the zoom factor creates
    # a new zoom image (if needed) and refreshes the screen.
    #
    # Always returns the current zoom factor.

    method zoom {{factor ""}} {
        # FIRST, if no new factor is specified, or if it is the
        # same as the current, do nothing.
        
        if {$factor eq ""          ||
            $factor eq $info(zoom)
        } {
            return $info(zoom)
        }

        # NEXT, validate the zoom factor
        if {$factor ni [dict keys $zoomfactors]} {
            return -code error -errorcode INVALID \
                "Invalid zoom factor, should be one of: [join [dict keys $zoomfactors] {, }]"
        }

        # NEXT, scale the image, if needed.
        if {$options(-map) ne "" &&
            ![info exists zooms($factor)]
        } {
            $self ScaleMap $factor
        }
        
        # NEXT, set the zoom factor
        set info(zoom) $factor

        # NEXT, save the center point
        lassign [$self Center2m] mx my

        # NEXT, refresh the display
        $self refresh

        # NEXT, center on the saved point
        $self see $mx $my
        
        # FINALLY, return the zoom factor
        return $info(zoom)
    }

    # zoomfactors
    #
    # Returns the list of valid zoomfactors
    
    method zoomfactors {} {
        return [dict keys $zoomfactors]
    }

    # refresh
    #
    # Refreshes the display:
    #
    # * Deletes all drawn items from the canvas.
    # * Adds the map at the current zoom level.
    # * Redraws all icons and neighborhoods in their proper locations.
    # * Sets the mode to "browse".

    method refresh {} {
        # FIRST, delete all drawn items.
        $hull delete all

        # NEXT, if there's no map, handle it.
        if {$options(-map) eq ""} {
            $self mode browse

            $self GetProjection

            # NEXT, get and set the scroll region
            $self GetScrollRegions
            $self region normal
        } else {
            # NEXT, get the projection.
            $self GetProjection

            # NEXT, create the map item using the current zoom.
            $hull create image 0 0          \
                -anchor nw                  \
                -image  $zooms($info(zoom)) \
                -tags   map
            
            # NEXT, get and set the scroll region
            $self GetScrollRegions
            $self region $info(region)
        }
        
        # NEXT, add the layer marker, to separate nbhoods from
        # icons.  Nbhoods will be drawn below it, icons above it.
        $hull create line -1 -1 -2 -2 -tags marker

        # NEXT, draw all neighborhoods in their correct places
        foreach id $nbhoods(ids) {
            $self NbhoodDraw $id
        }

        # NEXT, draw all icons in their correct places
        foreach id $icons(ids) {
            dict with icons(icon-$id) {
                $cmd draw {*}[$proj m2c $info(zoom) {*}$mxy]
            }
        }

        # NEXT, set the interaction mode back to "browse".
        $self mode browse

        return
    }

    # GetProjection
    #
    # Determines the projection to use, given the inputs, and
    # returns it.

    method GetProjection {} {
        # FIRST, if we've been given a projection, use it; it's
        # up the caller to get it right.  Otherwise, create and
        # configure one.

        if {$options(-projection) ne ""} {
            set proj $options(-projection)
        } else {
            set proj ${selfns}::proj

            # FIRST, create one if we don't have one.
            if {[llength [info command $proj]] == 0} {
                mapref $proj
            }

            # NEXT, if we have a map use the map dimensions; otherwise
            # use 1000x1000

            if {$options(-map) ne ""} {
                $proj configure                           \
                    -width  [image width  $options(-map)] \
                    -height [image height $options(-map)]
            } else {
                $proj configure  \
                    -width  1000 \
                    -height 1000
            }
        }
    }

    # GetScrollRegions
    #
    # Determines the bounding boxes for the normal and extended
    # scroll regions

    method GetScrollRegions {} {
        set bbox [$hull bbox map]

        if {[llength $bbox] != 0} {
            # x1,y1 = 0,0
            lassign $bbox x1 y1 x2 y2
        } else {
            let fact {$info(zoom)/100.0}
            set x2 [expr {int($fact*[$proj cget -width ])}]
            set y2 [expr {int($fact*[$proj cget -height])}]
        }

        set info(regionNormal) [list 0 0 $x2 $y2]

        set bound [expr {max($x2,$y2)}]
        set info(regionExtended) [list 0 0 $bound $bound]
    }

    # region ?region?
    #
    # region    normal | extended
    #
    # Sets/queries the displayed region.  If normal, only the map is shown;
    # if extended, the full range of map coordinates are shown.

    method region {{region ""}} {
        if {$region eq ""} {
            return $info(region)
        }

        require {$region in {normal extended}} "Invalid region: \"$region\""

        set info(region) $region

        if {$region eq "normal"} {
            $hull configure -scrollregion $info(regionNormal)
        } else {
            $hull configure -scrollregion $info(regionExtended)
        }

        return $info(region)
    }

    # see mappoint
    #
    # mappoint    A point in map coordinates, in any of the usual forms
    #
    # Makes sure that the specified point is visible.

    method see {args} {
        # FIRST, check args
        if {[llength $args] < 1 || [llength $args] > 2} {
            $self WrongNumArgs "see mappoint"
        }

        # NEXT, get the map coordinates.
        lassign [$self GetMapPoint args] mx my

        # NEXT, center the display (insofar as possible) on mx,my.
        # Begin by converting the point to canvas coordinates.
        lassign [$proj m2c $info(zoom) $mx $my] cx cy

        # NEXT, I need to determine the fx,fy that yields this
        # cx,cy at the center.  What are the window coordinates of
        # the center?
        set wx [expr {[winfo width $win]/2.0}]
        set wy [expr {[winfo height $win]/2.0}]

        # NEXT, get the canvas coordinates of the desired upper left
        # corner.
        set cx1 [expr {$cx - $wx}]
        set cy1 [expr {$cy - $wy}]

        # NEXT, get the scroll region
        lassign [$hull cget -scrollregion] xdummy ydummy cwidth cheight

        # NEXT, compute the fractions
        set fx [expr {min(max($cx1/$cwidth,0.0),1.0)}]
        set fy [expr {min(max($cy1/$cheight,0.0),1.0)}]

        # NEXT, scroll!
        $hull xview moveto $fx
        $hull yview moveto $fy
    }

    #-------------------------------------------------------------------
    # Interaction Modes
    #
    # Mapcanvas defines a number of interaction modes.  Modes are defined
    # by a combination of bindtags and canvas tag bindings.  First,
    # each mode is associated with a Tk bindtag called Mapcanvas.<mode>.
    # Second, each mode has a list {tag event binding ...} in the
    # modes array.
    #
    # The currently defined modes are as follows:
    #
    #    null       No behavior
    #    browse     Default behavior
    #    point      Puck map points
    #    poly       Draw polygons.
    #    pan        Pan mode: pan the map.

    # mode ?mode?
    #
    # mode    A Mapcanvas interaction mode
    #
    # If mode is given, sets the interaction mode.  Returns the current
    # interaction mode.
   
    method mode {{mode ""}} {
        # FIRST, if no new mode is given, return the current mode.
        if {$mode eq "" || $mode eq $info(mode)} {
            return $info(mode)
        }

        # NEXT, call the old mode's cleanup method, if any.
        if {[info exists modes($info(mode))]} {
            set method [dict get $modes($info(mode)) cleanup]
            
            if {$method ne ""} {
                $self $method
            }
        }

        # NEXT, save the mode
        set info(mode) $mode

        # NEXT, clear the old mode's canvas tag bindings.
        foreach tag $info(modeTags) {
            foreach event [$hull bind $tag] {
                $hull bind $tag $event {}
            }
        }

        set info(modeTags) [list]

        # NEXT, Set up the new mode's cursor.
        $self SetModeCursor $mode

        # NEXT, add the new mode's canvas tag bindings
        if {[info exists modes($mode)]} {
            foreach {tag event binding} [dict get $modes($mode) bindings] {
                if {$tag ni $info(modeTags)} {
                    lappend info(modeTags) $tag
                }

                $hull bind $tag $event $binding
            }
        }

        # NEXT, Find the old mode's bindtag
        set tags [bindtags $win]

        set ndx [lsearch -glob $tags "Mapcanvas.*"]

        if {$ndx > -1} {
            set tags [lreplace $tags $ndx $ndx Mapcanvas.$mode]
        } else {
            set ndx [lsearch -exact $tags "Mapcanvas"]

            set tags [linsert $tags $ndx+1 Mapcanvas.$mode]
        }
        
        # Install the new mode's bindtag
        bindtags $win $tags

        # NEXT, set the mode variable (if any)
        if {$options(-modevariable) ne ""} {
            uplevel 1 [list set $options(-modevariable) $info(mode)]
        }

        # NEXT, return the mode
        return $info(mode)
    }

    #-------------------------------------------------------------------
    # Binding Handlers

    # MapEnter
    #
    # Remembers that the pointer is over the window.

    method MapEnter {} {
        set info(gotPointer) 1
    }

    # MapClear
    #
    # Rembers that the pointer is not over the window.

    method MapLeave {} {
        set info(gotPointer) 0
    }


    # MaplocSet wx wy
    #
    # wx,wy    Position in window units
    #
    # Sets the -locvariable, if any

    method MaplocSet {wx wy} {
        if {$info(gotPointer) 
            && $options(-locvariable) ne "" 
        } {
            set ref [$self w2loc $wx $wy]

            uplevel \#0 [list set $options(-locvariable) $ref]
        }
    }


    # IconMark wx wy
    #
    # wx    x window coordinate
    # wy    y window coordinate
    # 
    # Begins the process of dragging an icon on Control-Click.

    method IconMark {wx wy} {
        # FIRST, convert the window coordinates to canvas coordinates.
        lassign [$win w2c $wx $wy] cx cy

        # NEXT, get the ID of the selected icon
        set trans(dragging) 1
        set trans(id)       [lindex [$win gettags current] 0]
        set trans(startx)   $cx
        set trans(starty)   $cy
        set trans(cx)       $cx
        set trans(cy)       $cy
        set trans(moved)    0

        # NEXT, raise the icon, so it when moved it will be over
        # the others.
        $win raise $trans(id)

        # NEXT, notify the app
        event generate $win <<Icon-1>> \
            -x    $wx                  \
            -y    $wy                  \
            -data $trans(id)
    }

    # IconDrag wx wy
    #
    # wx    x window coordinate
    # wy    y window coordinate
    # 
    # Continues the process of dragging an icon

    method IconDrag {wx wy} {
        if {![info exists trans(dragging)]} {
            return
        }

        # FIRST, convert the window coordinates to canvas coordinates.
        lassign [$win w2c $wx $wy] cx cy

        # NEXT, compute the delta from the last drag position,
        # and move the icon by that much.
        set dx [expr {$cx - $trans(cx)}]
        set dy [expr {$cy - $trans(cy)}]

        $win move $trans(id) $dx $dy

        # NEXT, remember where it is on the canvas, and that it has
        # been moved.
        set trans(cx) $cx
        set trans(cy) $cy
        set trans(moved) 1
    }

    # IconRelease
    #
    # Finishes the process of dragging an icon.

    method IconRelease {wx wy} {
        if {![info exists trans(dragging)]} {
            return
        }

        # FIRST, if it's been moved, update its mxy, and notify the
        # user.

        if {$trans(moved)} {
            # FIRST, is the current location within the visible bounds
            # of the window?  If so move it!

            if {$info(gotPointer)} {

                # FIRST, Get the delta relative to the point we started
                # dragging.
                set dx [expr {$trans(cx) - $trans(startx)}]
                set dy [expr {$trans(cy) - $trans(starty)}]

                # NEXT, get the icon's original mxy
                lassign [dict get $icons(icon-$trans(id)) mxy] mx1 my1

                # NEXT, get the icon's original cxy
                lassign [$proj m2c $info(zoom) $mx1 $my1] cx1 cy1

                # NEXT, get the icon's new cxy
                set cx2 [expr {$cx1 + $dx}]
                set cy2 [expr {$cy1 + $dy}]

                # NEXT, get the icon's new mxy, and save it.
                dict set icons(icon-$trans(id)) \
                    mxy [$proj c2m $info(zoom) $cx2 $cy2]

                # NEXT, notify the user
                event generate $win <<IconMoved>> \
                    -x    $wx                     \
                    -y    $wy                     \
                    -data $trans(id)
            } else {

                # Whoops!  Put the icon back where it was.
                set dx [expr {$trans(startx) - $trans(cx)}]
                set dy [expr {$trans(starty) - $trans(cy)}]

                $win move $trans(id) $dx $dy
            }
        }

        # NEXT, clear the trans array
        array unset trans
    }

    # Icon-1 wx wy
    #
    # wx    x window coordinate
    # wy    y window coordinate
    #
    # Generates the <<Icon-1>> virtual event for the selected icon.

    method Icon-1 {wx wy} {
        set id [lindex [$win gettags current] 0]

        $win raise $id

        event generate $win <<Icon-1>> \
            -x    $wx                  \
            -y    $wy                  \
            -data $id
    }

    # Icon-3 wx wy rx ry
    #
    # wx,wy   x,y window coordinates
    # rx,ry   x,y root window coordinate
    #
    # Generates the <<Icon-3>> virtual event for the selected icon.

    method Icon-3 {wx wy rx ry} {
        set id [lindex [$win gettags current] 0]

        event generate $win <<Icon-3>> \
            -x     $wx                   \
            -y     $wy                   \
            -rootx $rx                   \
            -rooty $ry                   \
            -data  $id
    }

    # Nbhood-1 wx wy rx ry
    #
    # wx,wy   x,y window coordinates
    # rx,ry   x,y root window coordinate
    #
    # Generates the <<Nbhood-1>> virtual event for the selected nbhood.

    method Nbhood-1 {wx wy rx ry} {
        set id [lindex [$win gettags current] 0]

        event generate $win <<Nbhood-1>> \
            -x     $wx                   \
            -y     $wy                   \
            -rootx $rx                   \
            -rooty $ry                   \
            -data  $id
    }

    # Nbhood-3 wx wy rx ry
    #
    # wx,wy   x,y window coordinates
    # rx,ry   x,y root window coordinate
    #
    # Generates the <<Nbhood-3>> virtual event for the selected nbhood.

    method Nbhood-3 {wx wy rx ry} {
        set id [lindex [$win gettags current] 0]

        event generate $win <<Nbhood-3>> \
            -x     $wx                   \
            -y     $wy                   \
            -rootx $rx                   \
            -rooty $ry                   \
            -data  $id
    }

    # Point-1
    #
    # wx,wy    Window coordinates of a mouse-click
    #
    # Pucks a location, resulting in <<Point-1>>.

    method Point-1 {wx wy} {
        # FIRST, get the current position as a map ref.
        set ref [$self w2ref $wx $wy]

        # NEXT, notify the application
        event generate $win <<Point-1>> \
            -x    $wx  \
            -y    $wy  \
            -data $ref
    }

    # PolyPoint
    #
    # wx,wy    Window coordinates of a mouse-click
    #
    # Begins/extends a polygon in poly mode.

    method PolyPoint {wx wy} {
        # FIRST, get the current position in canvas coordinates.
        # TBD: Should probably snap to map units!
        lassign [$self PolySnap {*}[$self w2c $wx $wy]] cx cy

        # NEXT, are we already drawing a polygon?  If so, save the
        # current line.
        if {[info exists trans(poly)]} {
            # FIRST, if the new point is the same as the first point, and
            # we've got enough for a full polygon, we'll complete the
            # polygon with this point.  Is this the case?

            set done [expr {
                $cx == $trans(startx) && 
                $cy == $trans(starty) &&
                [llength $trans(coords)] >= 6
            }]

            # NEXT, if this point is already on the polygon, ignore it
            # (unless it's the first point)

            if {!$done} {
                foreach {x y} [lrange $trans(coords) 0 end] {
                    if {$x == $cx && $y == $cy} {
                        return
                    }
                }
            }

            # NEXT, If this edge intersects an earlier edge, return.
            set n [clength $trans(coords)]

            set q1 [lrange $trans(coords) end-1 end]
            set q2 [list $cx $cy]

            for {set i $done} {$i < $n - 2} {incr i} {
                set edge [cedge $trans(coords) $i]
                set p1 [lrange $edge 0 1]
                set p2 [lrange $edge 2 3]

                if {[intersect $p1 $p2 $q1 $q2]} {
                    return
                }
            }

            # NEXT, if done, complete the polygon
            if {$done} {
                $self PolyComplete
                return
            }

            # NEXT, save the point
            lappend trans(coords) $cx $cy
            
            $hull create line $trans(cx) $trans(cy) $cx $cy \
                -fill red -tags partial
        } else {
            set trans(poly) 1
            set trans(coords) [list $cx $cy]
            set trans(startx) $cx
            set trans(starty) $cy
        }

        # NEXT, Create the rubber line
        set trans(cx) $cx
        set trans(cy) $cy

        $hull delete rubberline

        $hull create line $cx $cy $cx $cy \
            -fill red -tags rubberline

        # NEXT, focus on the window, so that Escape will cancel.
        focus $win
    }

    # PolyComplete
    #
    # Called when a polygon has been completed.  Notifies the
    # application.

    method PolyComplete {} {
        # FIRST, are we already drawing a polygon?  If not, or if the
        # polygon hasn't enough points, ignore this event.
        if {![info exists trans(poly)] ||
            [llength $trans(coords)] < 6
        } {
            return
        }

        # NEXT, convert the coords to a list of map reference strings
        foreach {cx cy} $trans(coords) {
            lappend refs [$proj c2ref $info(zoom) $cx $cy]
        }

        # NEXT, notify the application
        event generate $win <<PolyComplete>> \
            -data $refs
        
        # NEXT, we're done.
        $self PolyFinish
    }

    # PolyMove wx wy
    #
    # Does rubber-banding as we're drawing a polygon.

    method PolyMove {wx wy} {
        # FIRST, if we're not drawing a polygon, we're done.
        if {![info exists trans(poly)]} {
            return
        }

        # NEXT, snap the current point.
        lassign [$self PolySnap {*}[$win w2c $wx $wy]] cx cy

        # NEXT, Updated the rubber line
        set coords [$hull coords rubberline]
        set coords [lreplace $coords 2 end $cx $cy]
        $hull coords rubberline {*}$coords
    }

    # PolyFinish
    #
    # Called when we're finished with the current polygon, whether
    # because it's complete or it's been cancelled.

    method PolyFinish {} {
        # FIRST, clean up the transient data.
        $self PolyCleanUp

        # NEXT, go back to point mode.
        $self mode point
    }

    # PolyCleanUp
    #
    # Cleans up the transient data and canvas artifacts associated with
    # drawing polygons.

    method PolyCleanUp {} {
        array unset trans
        $hull delete rubberline
        $hull delete partial
    }

    # PolySnap cx cy
    #
    # cx,cy   A point in canvas coordinates
    #
    # Given a point cx,cy, tries to snap to a point within a radius.
    # If the first point in the polygon is within range, and snapping
    # to it would yield a valid polygon, snaps to that.  Otherwise,
    # uses SnapToPoint.

    method PolySnap {cx cy} {
        # FIRST, snap to the first point in the polygon, if that 
        # makes sense.  We can do this even if -snapmode is off.
        if {[info exists trans(poly)] &&
            [$self CanSnap $cx $cy $trans(startx) $trans(starty)] &&
            [llength $trans(coords)] >= 6
        } {
            return [list $trans(startx) $trans(starty)]
        }

        # NEXT, Use a normal snap, otherwise.
        if {$options(-snapmode)} {
            return [$self SnapToPoint $cx $cy]
        } else {
            return [list $cx $cy]
        }
    }
   
    #-------------------------------------------------------------------
    # Coordinate Conversion methods

    # Methods delegated to projection
    delegate method m2ref  to proj
    delegate method ref2m  to proj

    # c2m cx cy
    #
    # cx,cy    Position in canvas units
    #
    # Returns the position in map units

    method c2m {cx cy} {
        $proj c2m $info(zoom) $cx $cy
    }

    # m2c mx my
    #
    # mx,my    Position in map units
    #
    # Returns the position in canvas units

    method m2c {mx my} {
        $proj m2c $info(zoom) $mx $my
    }

    # c2ref cx cy
    #
    # cx,cy    Position in canvas units
    #
    # Returns the position as a map reference

    method c2ref {cx cy} {
        $proj c2ref $info(zoom) $cx $cy
    }

    # ref2c ref...
    #
    # ref      A map reference
    #
    # Returns a list {cx cy} in canvas units

    method ref2c {args} {
        $proj ref2c $info(zoom) {*}$args
    }

    # w2c wx wy
    #
    # wx,wy    Position in window units
    #
    # Returns the position in canvas units

    method w2c {wx wy} {
        list [$hull canvasx $wx] [$hull canvasy $wy]
    }

    # w2m wx wy
    #
    # wx,wy    Position in window units
    #
    # Returns the position in map units

    method w2m {wx wy} {
        $proj c2m $info(zoom) [$hull canvasx $wx] [$hull canvasy $wy]
    }

    # w2ref wx wy
    #
    # wx,wy    Position in window units
    #
    # Returns the position as a map reference

    method w2ref {wx wy} {
        $proj c2ref $info(zoom) [$hull canvasx $wx] [$hull canvasy $wy]
    }

    # w2loc wx wy
    #
    # wx,wy    Position in window units
    #
    # Returns the position as a map location for display

    method w2loc {wx wy} {
        $proj c2loc $info(zoom) [$hull canvasx $wx] [$hull canvasy $wy]
    }

    #-------------------------------------------------------------------
    # Icon Management

    # icon create icontype mappoint options...
    #
    # icontype    Name of a registered icon type
    # mappoint    Location in map coordinates/map ref
    # options...  Depends on icon type
    #
    # Creates an icon at the specified location, with the specified
    # options.  The option types are icontype-specific.
    #
    # The mappoint can be specified as a mapref or as "mx my"; the
    # latter can be passed as one or two arguments.
    #
    # Returns the new icon's ID, which will be the first tag on the icon.

    method {icon create} {icontype args} {
        # FIRST, check args
        if {[llength $args] < 1} {
            $self WrongNumArgs "icon create icontype mappoint options..."
        }

        if {![info exists icontypes(type-$icontype)]} {
            error "Unknown icon type: \"$icontype\""
        }

        # NEXT, get the map coordinates.
        lassign [$self GetMapPoint args] mx my

        # NEXT, Convert the map coords to canvas coords, and create
        # the icon, given the options.
        
        lassign [$proj m2c $info(zoom) $mx $my] cx cy

        set id "$icontype[incr info(iconCounter)]"
        set cmd  ${selfns}::icons::$id

        # Allow option errors to propagate to the user
        $icontypes(type-$icontype) $cmd $self $cx $cy {*}$args

        # NEXT, save the icon's name and current data.
        lappend icons(ids)           $id
        lappend icons(ids-$icontype) $id

        set icons(icon-$id) [dict create                  \
                                 id       $id             \
                                 icontype $icontype       \
                                 cmd      $cmd            \
                                 mxy      [list $mx $my]]

        # NEXT, return the icon ID
        return $id
    }

    # icon exists id
    #
    # id       The icon ID
    #
    # Returns 1 if the icon exists, and 0 otherwise.

    method {icon exists} {id} {
        info exists icons(icon-$id)
    }


    # icon list ?iconType?
    #
    # iconType       An icon type
    #
    # Returns a list of icon IDs

    method {icon list} {{iconType ""}} {
        if {$iconType eq ""} {
            return $icons(ids)
        }

        if {[info exists icons(ids-$iconType)]} {
            return $icons(ids-$iconType)
        } else {
            return ""
        }
    }


    # icon delete id
    #
    # id       The icon ID, or an icon type, or all
    #
    # Deletes the named icon or set of icons

    method {icon delete} {id} {
        if {$id eq "all"} {
            foreach id $icons(ids) {
                $self IconDelete $id
            }
        } elseif {$id in $icontypes(names)} {
            set icontype $id

            # If none have been created, we're done
            if {![info exists icons(ids-$icontype)]} {
                return
            }

            foreach id $icons(ids-$icontype) {
                $self IconDelete $id
            }
        } else {
            require {[$self icon exists $id]} "no such icon: $id"
            $self IconDelete $id
        }

        return
    }


    # IconDelete id
    #
    # id       The icon ID
    #
    # Deletes the named icon.

    method IconDelete {id} {
        # FIRST, save the command name.
        set cmd      [dict get $icons(icon-$id) cmd]
        set icontype [dict get $icons(icon-$id) icontype]
            
        # NEXT, clean up the metadata
        ldelete icons(ids)           $id
        ldelete icons(ids-$icontype) $id
        unset icons(icon-$id)
            
        # NEXT, destroy the icon's command; this will also
        # delete it from the canvas.
        $cmd destroy

        return
    }

    # icon configure id option value...
    #
    # id       The icon ID
    # options  Depends on the icon type
    #
    # Sets the options for the specified icon.

    method {icon configure} {id args} {
        if {[llength $args] < 2 || [llength $args] % 2 != 0} {
            $self WrongNumArgs \
                "icon configure id option value ?option value...?"
        }

        require {[$self icon exists $id]} "no such icon: $id"

        set cmd [dict get $icons(icon-$id) cmd]

        $cmd configure {*}$args
    }

    # icon cget id option...
    #
    # id       The icon ID
    # option   Option name; depends on the icon type
    #
    # Queries the options for the specified icon.

    method {icon cget} {id option} {
        require {[$self icon exists $id]} "no such icon: $id"

        set cmd [dict get $icons(icon-$id) cmd]

        return [$cmd cget $option]
    }

    # icon ref id
    #
    # id   An icon id
    #
    # Returns the location of the icon as a map reference

    method {icon ref} {id} {
        require {[$self icon exists $id]} "no such icon: $id"

        $self m2ref {*}[dict get $icons(icon-$id) mxy]
    }

    # icon moveto id mappoint
    #
    # id          An icon id
    # mappoint    A location in map units or mapref, as for icon create

    method {icon moveto} {id args} {
        require {[$self icon exists $id]} "no such icon: $id"

        # FIRST, validate the arguments
        if {[llength $args] < 1} {
            $self WrongNumArgs "icon moveto id mappoint"
        }

        lassign [$self GetMapPoint args] mx2 my2

        if {[llength $args] > 0} {
            $self WrongNumArgs "icon moveto id mappoint"
        }

        # NEXT, move the icon to the new location.  We need to compute
        # the delta.
        lassign [dict get $icons(icon-$id) mxy] mx1 my1

        lassign [$proj m2c $info(zoom) $mx1 $my1] cx1 cy1
        lassign [$proj m2c $info(zoom) $mx2 $my2] cx2 cy2

        set dx [expr {$cx2 - $cx1}]
        set dy [expr {$cy2 - $cy1}]

        $win move $id $dx $dy

        dict set icons(icon-$id) mxy [list $mx2 $my2]

        return
    }


    #-------------------------------------------------------------------
    # Nbhood Management

    # nbhood create refpoint polygon options...
    #
    # refpoint    Reference point location as map coords/map ref
    # polygon     Polygon as list of map coordinates/map ref
    # options...  
    #
    #    -background     Neighborhood background color
    #
    # Creates a neighborhood with the specified reference point and
    # polygon.
    #
    # The refpoint can be specified as a mapref or as "mx my"; the
    # latter can be passed as one or two arguments.
    #
    # The polygon can be specified as a one argument, a list of 
    # map refs or map coordinates, or as individual map refs or map 
    # coordinates.
    #
    # It's assumed that the refpoint is within the polygon.
    #
    # Returns the new nbhood's ID, which will be the first tag on the 
    # nbhood's items.

    method {nbhood create} {args} {
        # FIRST, check args
        if {[llength $args] < 2} {
            $self WrongNumArgs "nbhood create refpoint polygon options..."
        }

        # NEXT, extract the valid options
        set fill      [optval args -fill       ""   ]
        set pointfg   [optval args -pointcolor black]
        set linewidth [optval args -linewidth  1    ]
        set polycolor [optval args -polycolor  black]

        # NEXT, get the ref point
        lassign [$self GetMapPoint args] rx ry
        lassign [$proj m2c $info(zoom) $rx $ry] crx cry

        # NEXT, everything else is the polygon
        set mpoly [$self GetMapPointList args]

        # NEXT, Create the nbhood
        set id "nbhood[incr info(iconCounter)]"

        lappend nbhoods(ids)            $id
        set     nbhoods(refpoint-$id)   [list $rx $ry]
        set     nbhoods(polygon-$id)    $mpoly
        set     nbhoods(fill-$id)       $fill
        set     nbhoods(pointcolor-$id) $pointfg
        set     nbhoods(linewidth-$id)  $linewidth
        set     nbhoods(polycolor-$id)  $polycolor

        # NEXT, draw it
        $self NbhoodDraw $id

        # NEXT, return the neighborhood ID
        return $id
    }

    # nbhood delete id
    #
    # id      The neighborhood ID
    #
    # Deletes the neighborhood with the specified ID.

    method {nbhood delete} {id} {
        # FIRST, check the id
        require {[info exists nbhoods(polygon-$id)]} \
            "Unknown neighborhood ID: \"$id\""

        # NEXT, delete it.
        $hull delete $id

        ldelete nbhoods(ids) $id
        unset nbhoods(refpoint-$id)
        unset nbhoods(polygon-$id)
        unset nbhoods(fill-$id)
        unset nbhoods(pointcolor-$id)
        unset nbhoods(polycolor-$id)
        unset nbhoods(linewidth-$id)

        return
    }

    # nbhood ids
    #
    # Returns a list of the neighborhood IDs.

    method {nbhood ids} {} {
        return $nbhoods(ids)
    }

    # nbhood configure id option value...
    #
    # id    The neighborhood ID
    #
    # Configures the neighborhood's options.

    method {nbhood configure} {id args} {
        while {[llength $args] > 0} {
            set opt [lshift args]
            set val [lshift args]
            
            switch -exact -- $opt {
                -fill {
                    $hull itemconfigure $id.poly -fill $val
                    set nbhoods(fill-$id) $val
                }
                -pointcolor {
                    $hull itemconfigure $id.inner \
                        -fill    $val

                    set nbhoods(pointcolor-$id) $val
                }
                -polycolor {
                    $hull itemconfigure $id.poly -outline $val
                    set nbhoods(polycolor-$id) $val
                }
                -linewidth {
                    $hull itemconfigure $id.poly -width $val
                    set nbhoods(linewidth-$id) $val
                }
                default {
                    error "Unrecognized option \"$opt\""
                }
            }
        }
    }

    # nbhood cget id option
    #
    # id      The neighborhood ID
    # option  A neighborhood option
    #
    # Returns the option's value

    method {nbhood cget} {id option} {
        switch -exact -- $option {
            -fill       { return $nbhoods(fill-$id)            }
            -pointcolor { return $nbhoods(pointcolor-$id)      }
            -polycolor  { return $nbhoods(polycolor-$id)       }
            -linewidth  { return $nbhoods(linewidth-$id)       }
            default     { error "Unrecognized option \"$opt\"" }
        }
    }

    # nbhood polygon id ?polygon?
    #
    # polygon     Polygon as list of map coordinates/map ref
    #
    # Sets/queries the neighborhood polygon's coordinates.
    #
    # The coordinates can be specified as a one argument, a list of 
    # map refs or map coordinates, or as individual map refs or map 
    # coordinates.
    #
    # Returns the nbhood's polygon in map coordinates.

    method {nbhood polygon} {id args} {
        # FIRST, check the id
        require {[info exists nbhoods(polygon-$id)]} \
            "Unknown neighborhood ID: \"$id\""

        # NEXT, set the coordinates, if given
        if {[llength $args] > 0} {
            # FIRST, save the new map coordinates
            set mpoly [$self GetMapPointList args]

            set nbhoods(polygon-$id) $mpoly

            # NEXT, update the display
            $hull coords $id.poly [$proj m2c $info(zoom) {*}$mpoly]
        }

        # NEXT, return the coords
        return $nbhoods(polygon-$id)
    }

    # nbhood point id ?mappoint?
    #
    # mappoint     Reference point as map coordinates/ref string
    #
    # Sets/queries the neighborhood's refpoint.
    #
    # The coordinates can be specified as a map reference, or
    # as a pair of map coordinates, as one argument or two.
    #
    # Returns the nbhood's reference point in map coordinates.

    method {nbhood point} {id args} {
        # FIRST, check the id
        require {[info exists nbhoods(polygon-$id)]} \
            "Unknown neighborhood ID: \"$id\""

        # NEXT, set the coordinates, if given
        if {[llength $args] > 0} {
            # FIRST, Get the new map coordinates
            set mxy [$self GetMapPoint args]

            # NEXT, compute the delta in canvas coords
            lassign [$proj m2c $info(zoom) {*}$nbhoods(refpoint-$id)] cx1 cy1
            lassign [$proj m2c $info(zoom) {*}$mxy]                   cx2 cy2

            set cxdelta [expr {$cx2 - $cx1}]
            set cydelta [expr {$cy2 - $cy1}]

            # NEXT, save the new refpoint
            set nbhoods(refpoint-$id) $mxy

            # NEXT, update the display
            $hull move "$id&&refpoint" $cxdelta $cydelta
        }

        # NEXT, return the coords
        return $nbhoods(refpoint-$id)
    }

    # NbhoodDraw id
    #
    # id       A nbhood ID
    #
    # Draws the neighborhood on the canvas

    method NbhoodDraw {id} {
        # FIRST, Get the refpoint in canvas coords
        lassign [$proj m2c $info(zoom) {*}$nbhoods(refpoint-$id)] crx cry

        # NEXT, Get the polygon in canvas coords
        set cpoly [$proj m2c $info(zoom) {*}$nbhoods(polygon-$id)]

        # NEXT, Draw it
        $hull create polygon $cpoly                        \
            -outline $nbhoods(polycolor-$id)               \
            -width   $nbhoods(linewidth-$id)               \
            -fill    $nbhoods(fill-$id)                    \
            -tags    [list $id $id.poly nbhood snaps]

        $hull create oval [boxaround 3 $crx $cry]          \
            -outline black                                 \
            -fill    $nbhoods(pointcolor-$id)              \
            -tags    [list $id $id.inner refpoint nbhood]

        $hull create oval [boxaround 5 $crx $cry]          \
            -outline black                                 \
            -fill    ""                                    \
            -tags    [list $id $id.outer refpoint nbhood]

        # NEXT, lower it below the marker
        $hull lower $id marker
    }

    #-------------------------------------------------------------------
    # Utility Methods

    # GetMapPoint argvar
    #
    # argvar    Argument list variable
    #
    # Reads one map point from the specified list.  A map point can
    # be specified as a mapref, or as a coordinate pair in map units
    # passed as one or two arguments.

    method GetMapPoint {argvar} {
        upvar $argvar args

        set first [lshift args]

        if {[llength $first] == 1} {
            # If it's a double, get the next arg; otherwise, it's a ref.
            if {[string is double -strict $first]} {
                set mx $first
                set my [lshift args]
            } else {
                lassign [$self ref2m $first] mx my
            }
        } elseif {[llength $first] == 2} {
            # It's an mx my pair
            lassign $first mx my
        } else {
            error "invalid mappoint: \"$first\""
        }

        return [list $mx $my]
    }

    # GetMapPointList argvar
    #
    # argvar    Argument list variable
    #
    # Reads a sequence of one or map points from the specified list,
    # in any of the usual forms.

    method GetMapPointList {argvar} {
        upvar $argvar args

        # FIRST, one point or many?
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        # NEXT, build up the coordinate list.
        set coords [list]

        while {[llength $args] > 0} {
            lassign [$self GetMapPoint args] mx my

            lappend coords $mx $my
        }

        return $coords
    }

    # SetModeCursor mode
    #
    # Sets the appropriate cursor for the current mode
    
    method SetModeCursor {mode} {
        if {[info exists modes($mode)]} {
            $hull configure -cursor [dict get $modes($mode) cursor]
        } else {
            $hull configure -cursor left_ptr
        }
    }

    # ScaleMap factor
    #
    # factor    Creates a scaled copy of the the -map at the specified
    #           zoom factor.
    #
    # Creates and caches a new map image.  Assumes that:
    # 
    # * factor is a valid zoomfactor
    # * There is a -map
    # * No cached image exists for this factor

    method ScaleMap {factor} {
        # FIRST, update the GUI, and set the watch cursor
        set oldCursor [$hull cget -cursor]
        $hull configure -cursor watch
        update idletasks

        # NEXT, get the base image, and the upsample/downsample figures
        set img $options(-map)
        lassign [dict get $zoomfactors $factor] up down

        # NEXT, upsample, if necessary
        set temp [image create photo]
        $temp copy $img -zoom $up

        # NEXT, downsample, if necessary
        set final [image create photo]
        $final copy $temp -subsample $down

        # NEXT, delete the temp image and save the new image.
        image delete $temp
        set zooms($factor) $final

        # NEXT, restore the cursor
        $hull configure -cursor $oldCursor
    }

    # CanSnap x1 y1 x2 y2
    #
    # x1,y1     A point
    # x2,y2     Another point
    #
    # Returns 1 if distance between the two points is within the snap
    # radius.

    method CanSnap {x1 y1 x2 y2} {
        expr {[Distance $x1 $y1 $x2 $y2] <= $options(-snapradius)}
    }

    # SnapToPoint cx cy
    #
    # cx,cy   A point in canvas coordinates
    #
    # Given a point cx,cy, tries to snap to a point within a radius.
    # Candidate points are points in the "coords" list of items 
    # tagged with "snaps".

    method SnapToPoint {cx cy} {
        set mindist [expr {2*$options(-snapradius)}]
        set minitem ""
        set nearest [list]

        set bbox [boxaround $options(-snapradius) $cx $cy]

        foreach item [$hull find overlapping {*}$bbox] {
            set tags [$hull gettags $item]

            if {"snaps" ni $tags} {
                continue
            }
            
            foreach {sx sy} [$hull coords $item] {
                set dist [Distance $cx $cy $sx $sy]

                if {$dist < $mindist} {
                    set nearest [list $sx $sy]
                    set mindist $dist
                    set minitem [lindex $tags 0]
                }
            }
        }

        if {[llength $nearest] == 2} {
            return $nearest
        } else {
            return [list $cx $cy]
        }
    }

    # Center2m
    #
    # Returns the map coordinate of the point at the center of the
    # displayed map as an {mx my} pair

    method Center2m {} {
        # FIRST, get the xview/yview fractions
        lassign [$hull xview] fx1 fx2
        lassign [$hull yview] fy1 fy2

        # NEXT, get the scroll region in map coordinates.
        # Note that cx1 and cy1 are both zero.
        lassign [$hull cget -scrollregion] cx1 cy1 cx2 cy2

        # NEXT, compute the center point in canvas coordinates
        set cx [expr {0.5*($fx1 + $fx2)*$cx2}]
        set cy [expr {0.5*($fy1 + $fy2)*$cy2}]

        # NEXT, convert to mxy, and return.
        return [$proj c2m $info(zoom) $cx $cy]
    }

    # WrongNumArgs methodsig
    #
    # methodsig    The method name and arg spec
    #
    # Outputs a WrongNumArgs method
    
    method WrongNumArgs {methodsig} {
        return -code error "wrong \# args: should be \"$self $methodsig\""
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # Distance x1 y1 x2 y2
    #
    # x1,y1    A point
    # x2,y2    Another point
    #
    # Computes the distance between the two points.

    proc Distance {x1 y1 x2 y2} {
        expr {sqrt(($x1-$x2)**2 + ($y1-$y2)**2)}
    }

    # UndefinedMap
    #
    # Throws an error if called.

    proc UndefinedMap {args} {
        error "-map is undefined or \"clear\" has not been called"
    }
    
    # InBox x1 y1 x2 y2 x y
    #
    # x1,y1,x2,y2    Bounds of bounding box
    # x,y            A point
    #
    # Returns 1 if x,y is in the box
    
    proc InBox {x1 y1 x2 y2 x y} {
        expr {$x1 <= $x && $x2 >= $x && $y1 <= $y && $y2 >= $y}
    }
}


