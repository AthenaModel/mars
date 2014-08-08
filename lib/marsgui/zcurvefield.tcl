#-----------------------------------------------------------------------
# TITLE:
#    zcurvefield.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    marsgui(n) package: Z-curve editing field
#
#    The z-curve editing field conforms to the field(i) interface. As
#    such, it can be used in order dialogs that need z-curve editing.
#
#    This widget consists of a canvas that depicts the z-curve to be
#    edited graphically and four entry widgets that correspond to the
#    lo, a, b and hi elements of the z-curve on display in the canvas.
#
#    The user can edit a z-curve in two ways:
#        * By changing the lo, a, b and hi values in the entry widgets
#        * By dragging the handles on the graphical representation of
#          the z-curve in the canvas
#
#    As the user edits the z-curve the widgets change command (supplied
#    in the -changecmd option) is called. This allows for key stroke by
#    key stroke validation. Typically, the zcurve editor is set up so 
#    that changing the z-curve by dragging the handles always results 
#    in a valid z-curve.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export zcurvefield
}

#-----------------------------------------------------------------------
# zcurvefield

snit::widget ::marsgui::zcurvefield {
    #-------------------------------------------------------------------
    # Type Constructor


    #-------------------------------------------------------------------
    # Lookup Tables

    # Canvas Layout Parameters
    #
    # border      Canvas border width
    #
    # margin      margin around canvas data.
    #
    # base        Base dimension: the graph extends from -base to +base
    #             on the X-axis and from 0 to +base on the Y-axis (in
    #             canvas units).

    typevariable parms -array {
        border  2
        margin  8
        base    100
    }

    # cursors:  mouse cursors, by handle type

    typevariable cursors -array {
        lo   double_arrow
        alo  fleur
        bhi  fleur
        hi   double_arrow
    }

    # The type saves a dummy scale widget that is never displayed;
    # it's used to determine the label width.

    typevariable dummyScale ""


    #-------------------------------------------------------------------
    # Components

    component title        ;# ttk::label
    component zval         ;# ttk::label
    component canvas       ;# tk::canvas

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull
    
    #-------------------------------------------------------------------
    # Options

    # -title    Descriptive text for the editor

    option -title \
        -default         ""              \
        -configuremethod ConfigTitle

    method ConfigTitle {opt val} {
        set options($opt) $val

        $title configure -text $val

        if {$val eq ""} {
            grid forget $title
        } else {
            grid $title -row 0 -column 0 -sticky ew
        }
    }

    # -ymax     Maximum application y value
    
    option -ymax \
        -default  100.0 \
        -readonly yes

    # -state    normal|readonly
    #
    # If normal, the Z-curve can be edited; otherwise not

    option -state \
        -default         normal      \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val

        # FIRST, configure the entry widgets
        foreach parm [array names z] {
            $win.box.$parm configure -state $val
        }

        # NEXT, Make other changes.
        #
        # * Handles are visible or not
        if {$val eq "normal"} {
            $canvas raise handle
        } else {
            $canvas lower handle
        }
    }

    # -type
    #
    # Specify a Z-curve type.  Defaults to a generic zcurve.

    option -type -default ::marsutil::zcurve
  
    # -background color
    #
    # Sets the widget's background, which is propagated to the vlabel.
    # The default is set programmatically.

    option -background \
        -configuremethod ConfigBackground

    method ConfigBackground {opt val} {
        set options($opt) $val
    }

    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new text is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    #-------------------------------------------------------------------
    # Instance Variables

    variable current       0    ;# Current value
    #
    # z  -- The four z-curve parameters

    variable z -array {
        lo   5.0
        a  -50.0
        b   50.0
        hi  95.0
    }

    # zedit -- The entry widget textvariables.  Same keys as
    # z().

    variable zedit -array { }

    # entry -- The entry fields for the four z-curve parameters

    variable entry -array { }

    # trans -- Array of transient data used while dragging.

    variable trans -array { 
        dragging  0
    }

    # info -- array of other scalars
    #
    # cxmin,cymin,    Bounds of the data area in canvas coordinates.
    # cxmax,cymax     set by LayoutCanvas
    #
    # xoffset         X-offset for A2C and C2A.  Set by LayoutCanvas
    # yoffset         Y-offset for A2C and C2A.  Set by LayoutCanvas

    variable info -array {
        cxmin   {}
        cymin   {}
        cxmax   {}
        cymax   {}

        xoffset {}
        yoffset {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, add a border
        $hull configure \
            -borderwidth 2    \
            -relief      flat 

        # NEXT, create the components

        # Title
        install title using ttk::label $win.title \
            -text   ""                            \
            -anchor center

        # Canvas. Note that the dimensions will be
        # modified during the layout process.
        install canvas using canvas $win.canvas \
            -background         white           \
            -width              200             \
            -height             80              \
            -borderwidth        $parms(border)  \
            -highlightthickness 0               \
            -relief             sunken

        # Entry box
        set box [ttk::frame $win.box   \
                     -borderwidth 0    \
                     -padding     2]

        # lo,a,b,hi
        $self MakeEntry 0 lo
        $self MakeEntry 1 a
        $self MakeEntry 2 b
        $self MakeEntry 3 hi

        # The title will be gridded later
        grid $canvas  -row 1 -column 0 -sticky nsew -padx 2 -pady 2
        grid $win.box -row 1 -column 1 -sticky n

        # NEXT, get the options
        $self configurelist $args

        # NEXT, layout the canvas
        $self LayoutCanvas

        # Add handle bindings
        $canvas bind handle <Enter> [mymethod HandleEnter]
        $canvas bind handle <Leave> [mymethod HandleLeave]

        $canvas bind handle <ButtonPress-1> \
            [mymethod HandleMark %x %y]

        $canvas bind handle <B1-Motion> \
            [mymethod HandleDrag %x %y]

        $canvas bind handle <ButtonRelease-1> \
            [mymethod HandleDrag %x %y done]
    }

    # MakeEntry row parm
    #
    # row    A row, 0 to N
    # parm   The Z-curve parm name

    method MakeEntry {row parm} {
        ttk::label $win.box.label$parm \
            -text $parm

        set entry($parm) $win.box.$parm

        ttk::entry $entry($parm)               \
            -justify      right                \
            -width        6                    \
            -textvariable [myvar zedit($parm)]

        # Bind to key releases
        bind $entry($parm) <KeyRelease> [mymethod SetCurve]

        grid $win.box.label$parm -row $row -column 0 -padx 2 -pady 2
        grid $entry($parm)       -row $row -column 1
    }

    # SetCurve
    #
    # Sets the curve to match the entries

    method SetCurve {} {
        set curve [list $zedit(lo) $zedit(a) $zedit(b) $zedit(hi)]
        $self set $curve
    }

    #-------------------------------------------------------------------
    # Layout

    # LayoutCanvas
    #
    # Lays out the canvas data given the options and layout parameters.

    method LayoutCanvas {} {
        # FIRST, Determine the width of the canvas.  Note that the 
        # canvas widget will add the border width automatically.
        let width {2*($parms(base) + $parms(margin))}

        # NEXT, the height depends on the height of the X-axis labels.
        # So create a label and get its bounding box
        set item [$canvas create text 0 0 -text "0" -anchor n]
        lassign [$canvas bbox $item] x1 y1 x2 textheight
        $canvas delete $item

        # NEXT, Determine the height of the canvas.  Note that the 
        # canvas widget will add the border width automatically.
        let height {
            2*$parms(margin) + $parms(base) + $textheight
        }

        # NEXT, set the canvas dimensions
        $canvas configure -width $width -height $height

        # NEXT, create a white rectangle to hide the handles when we're
        # readonly.
        $canvas create rectangle 0 0 $width $height \
            -fill white                             \
            -outline white

        # NEXT, set the X and Y offsets for the coordinate conversions
        let info(xoffset) {$parms(margin) + $parms(base) + $parms(border)}
        let info(yoffset) {$parms(margin) + $parms(base) + $parms(border)}

        # NEXT, compute the bounding box of the data area, remembering that
        # the sign of the y-coordinates is reversed!

        lassign [$self A2C -$parms(base) 0.0] \
            info(cxmin) info(cymax)

        lassign [$self A2C  $parms(base) $options(-ymax)] \
            info(cxmax) info(cymin)

        # NEXT, plot the axes

        $canvas create line [$self A2C -$parms(base) 0.0 $parms(base) 0.0] \
            -width 1                                                       \
            -fill  gray

        $canvas create line [$self A2C 0.0 0.0 0.0 $options(-ymax)] \
            -width 1                                                \
            -fill  gray

        # NEXT, add the labels
        $canvas create text [$self A2C 4.0 $options(-ymax)] \
            -text   $options(-ymax)                         \
            -anchor nw

        $canvas create text [$self A2C 0.0 0.0] \
            -text   0                           \
            -anchor n
        
        $canvas create text [$self A2C -$parms(base) 0.0] \
            -text   -$parms(base)                         \
            -anchor nw

        $canvas create text [$self A2C  $parms(base) 0.0] \
            -text   $parms(base)                          \
            -anchor ne

        # NEXT, add the Z-curve
        $canvas create line 0 0 0 0 \
            -width 2                \
            -fill  red              \
            -tags  curve

        # NEXT, add the handles
        $self HandleCreate lo   w
        $self HandleCreate alo  center
        $self HandleCreate bhi  center
        $self HandleCreate hi   e

        # NEXT, lower the handles if the state is readonly.
        if {$options(-state) eq "readonly"} {
            $canvas lower handle
        }
    }

    # UpdateCurve
    #
    # Makes the drawn curve match the current Z-curve parameters.  Also
    # makes the "edited" parameters match the current parameters

    method UpdateCurve {} {
        # FIRST, update the entry fields
        foreach parm [array names z] {
            set zedit($parm) $z($parm)
        }

        foreach parm [array names entry] {
            $entry($parm) configure -foreground black
        }

        # NEXT, update the curve itself
        $canvas coords curve \
            [$self A2C -$parms(base) $z(lo)  $z(a) $z(lo)  $z(b) $z(hi) \
                 $parms(base) $z(hi)]

        # NEXT, update the handles
        $canvas coords lo  [$self A2C -$parms(base) $z(lo)]
        $canvas coords alo [$self A2C $z(a) $z(lo)]
        $canvas coords bhi [$self A2C $z(b) $z(hi)]
        $canvas coords hi  [$self A2C $parms(base) $z(hi)]

        set current [list $z(lo) $z(a) $z(b) $z(hi)]

        # NEXT, the curve has changed, call the change command if there
        # is one
        if {$options(-changecmd) ne ""} {
            {*}$options(-changecmd) $current
        }
    }

    #-------------------------------------------------------------------
    # Handles

    # HandleCreate name anchor
    #
    # name      Name of the new handle.
    # anchor    -anchor
    #
    # Creates a new handle at 0,0

    method HandleCreate {name anchor} {
        $canvas create image 0 0           \
            -image ::marsgui::icon::handle \
            -anchor $anchor                \
            -tags  [list $name handle]
    }

    # HandleEnter
    #
    # Sets the cursor when entering a handle
    
    method HandleEnter {} {
        set handle [lindex [$canvas gettags current] 0]

        $canvas configure -cursor $cursors($handle)
    }

    # HandleLeave
    #
    # Sets the cursor when leaving a handle
    
    method HandleLeave {} {
        if {!$trans(dragging)} {
            $canvas configure -cursor ""
        }
    }

    # HandleMark wx wy
    #
    # wx,wy     Window coordinates of mouse pointer
    #
    # The user has clicked on a handle.  Set up for the drag.

    method HandleMark {wx wy} {
        # FIRST, convert the window coordinates to canvas coordinates.
        set cx [$canvas canvasx $wx]
        set cy [$canvas canvasy $wy]

        # NEXT, get the ID of the handle
        set trans(id) [lindex [$canvas gettags current] 0]

        # NEXT, get the current location of the handle
        lassign [$canvas coords $trans(id)] hx hy

        # NEXT, start dragging the handle
        set trans(dragging) 1
        set trans(cx)       $cx
        set trans(cy)       $cy
        let trans(dx)       {$hx - $cx}
        let trans(dy)       {$hy - $cy}
    }

    # HandleDrag wx wy ?flag?
    #
    # wx,wy     Window coordinates of mouse pointer
    # flag      If "done", the drag is complete.
    #
    # The user is dragging the handle.  Update the model as appropriate.

    method HandleDrag {wx wy {flag ""}} {
        # FIRST, if we aren't dragging, do nothing.
        if {![info exists trans(dragging)]} {
            return
        }

        # NEXT, convert the window coordinates to canvas coordinates.
        set cx [$canvas canvasx $wx]
        set cy [$canvas canvasy $wy]

        # NEXT, convert the coordinates.
        let hx {$cx + $trans(dx)}
        let hy {$cy + $trans(dy)}

        switch $trans(id) {
            lo -
            hi {
                lassign [$self HandleValidateLoHi $hx $hy] hx hy
            }
            alo {
                lassign [$self HandleValidateALo $hx $hy] hx hy
            }
            bhi {
                lassign [$self HandleValidateBHi $hx $hy] hx hy
            }
            default {
                error "Invalid handle id \"$trans(id)\""
            }
        }

        # NEXT, if a coordinate is invalid, leave it where it is.
        if {$hx eq ""} {
            set cx $trans(cx)
        }

        if {$hy eq ""} {
            set cy $trans(cy)
        }

        # NEXT, move the handle to its new location.
        set dx [expr {$cx - $trans(cx)}]
        set dy [expr {$cy - $trans(cy)}]
        
        $canvas move $trans(id) $dx $dy
        
        # NEXT, update the model
        $self HandleUpdate

        # NEXT, remember the transient info, unless we're done.
        if {$flag ne "done"} {
            set trans(cx) $cx
            set trans(cy) $cy
        } else {
            $canvas configure -cursor ""
            set trans(dragging) 0
        }
    }

    # HandleValidateLoHi hx hy
    #
    # hx,hy    Valid handle coordinates?
    #
    # Validates and transforms the handle coordinates

    method HandleValidateLoHi {hx hy} {
        # FIRST, we don't want to change the x coordinate
        set hx {}

        # NEXT, is the y coordinate within range
        if {$hy < $info(cymin) || $hy > $info(cymax)} {
            set hy {}
        }

        return [list $hx $hy]
    }

    # HandleValidateALo hx hy
    #
    # hx,hy    Valid handle coordinates?
    #
    # Validates and transforms the handle coordinates

    method HandleValidateALo {hx hy} {
        # FIRST, get the coordinates of the bhi handle
        lassign [$canvas coords bhi] bx hiy

        # NEXT, is the x coordinate within range?
        if {$hx < $info(cxmin) || $hx > $bx} {
            set hx {}
        }

        # NEXT, is the y coordinate within range
        if {$hy < $info(cymin) || $hy > $info(cymax)} {
            set hy {}
        }

        return [list $hx $hy]
    }

    # HandleValidateBHi hx hy
    #
    # hx,hy    Valid handle coordinates?
    #
    # Validates and transforms the handle coordinates

    method HandleValidateBHi {hx hy} {
        # FIRST, get the coordinates of the alo handle
        lassign [$canvas coords alo] ax loy

        # NEXT, is the x coordinate within range?
        if {$hx < $ax || $hx > $info(cxmax)} {
            set hx {}
        }

        # NEXT, is the y coordinate within range
        if {$hy < $info(cymin) || $hy > $info(cymax)} {
            set hy {}
        }

        return [list $hx $hy]
    }

    # HandleUpdate
    #
    # Updates the model given the current handle coordinates.

    method HandleUpdate {} {
        lassign [$canvas coords $trans(id)] hx hy
        lassign [$self C2A $hx $hy] ax ay

        switch $trans(id) {
            lo { 
                set z(lo) $ay 
            }

            alo { 
                set z(a)  $ax
                set z(lo) $ay
            }

            bhi {
                set z(b)  $ax
                set z(hi) $ay
            }

            hi {
                set z(hi) $ay
            }

            default {
                error "Invalid handle id \"$trans(id)\""
            }
        }

        $self UpdateCurve
    }

    #-------------------------------------------------------------------
    # Coordinate Conversion

    # A2C coords...
    #
    # coords...        A flat list of x,y pairs in application 
    #                  coordinates
    #
    # Converts application coordinates into canvas coordinates.

    method A2C {args} {
        set result [list]

        # The yfactor scales the ay value, and reverses the sign,
        # since cy increases downward.
        let yfactor {$parms(base)/$options(-ymax)}

        foreach {ax ay} $args {
            let cx { 
                $info(xoffset) + $ax
            }

            # Clamp cy to the -ymax option
            let cy { 
                $info(yoffset) - min($ay,$options(-ymax))*$yfactor
            }

            lappend result $cx $cy
        }

        return $result
    }

    # C2A coords...
    #
    # coords...        A flat list of x,y pairs in canvas 
    #                  coordinates
    #
    # Converts canvas coordinates into application coordinates.

    method C2A {args} {
        set result [list]

        # The yfactor scales the cy value, and reverses the sign,
        # since ay increases upward.
        let yfactor {$parms(base)/$options(-ymax)}

        foreach {cx cy} $args {
            let ax { 
                $cx - $info(xoffset)
            }

            let ay { 
                ($info(yoffset) - $cy)/$yfactor
            }

            lappend result $ax $ay
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Public Methods

    # get
    #
    # Returns the current value.

    method get {} {
        return $current
    }

    #
    # set zcurve
    #
    # zcurve     A Z-curve spec, {lo a b hi}
    #
    # Sets the z-curve and updates the widget

    method set {zcurve} {
        lassign $zcurve z(lo) z(a) z(b) z(hi)
        
        # FIRST validate the curve, if its bad just set the current value 
        # to it, otherwise update the canvas
        if {[catch {$options(-type) validate $zcurve}]} {
            set current $zcurve
        } else {
            $self UpdateCurve
        }

        # NEXT, call the change command
        if {$options(-changecmd) ne ""} {
            {*}$options(-changecmd) $zcurve
        }
    }
}



