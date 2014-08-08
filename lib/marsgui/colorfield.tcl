#-----------------------------------------------------------------------
# TITLE:
#    colorfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Color data entry field
#
#    A colorfield is a data entry field containing:
#
#    * A menu button that will pull down a menu of color swatches.
#    * A label, showing visually the currently selected color.
#    * A textfield showing the text of the color spec.  
#      Color names and specs can be entered explicitly in the text
#      field.  The text field's edit button will pop up a full-fledged
#      color picker.
#
#    The pulldown menu will be populated with a standard palette of 
#    colors; this palette can also be set using the -palette option, 
#    which will take a list of color specs.  The swatches will be 
#    arranged in rows and columns, with the number of rows specified 
#    by the -rows option.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export colorfield
}

#-----------------------------------------------------------------------
# colorfield

snit::widget ::marsgui::colorfield {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Type Variables

    # Swatch size
    typevariable swidth  20
    typevariable sheight 20

    # A cache of swatch image names by color name.  The images are
    # used in the palette menu.

    typevariable swatchCache -array {}

    #-------------------------------------------------------------------
    # Type Methods

    # GetSwatch color
    #
    # color     A color name
    #
    # Given a color, returns a swatch image.

    typemethod GetSwatch {color} {
        # FIRST, returned cached swatch, if any.
        if {[info exists swatchCache($color)]} {
            return $swatchCache($color)
        }

        # NEXT, On Windows, the image handler rejects named Windows colors like
        # SystemButtonFace.  Consequently, convert the color into canonical
        # form.
        lassign [winfo rgb . $color] r g b
        set goodc [format "#%04X%04X%04X" $r $g $b]

        # NEXT, create a new swatch, and cache it.
        set swatch [image create photo -width $swidth -height $sheight]
    
        $swatch put $goodc -to 1 1 $swidth $sheight
        $swatch put gray50 -to 0 0 $swidth 1
        $swatch put gray50 -to 0 1 1 $sheight
        $swatch put gray75 -to 0 [expr {$sheight - 1}] $sheight $sheight
        $swatch put gray75 -to [expr {$swidth - 1}] 1 $swidth $swidth

        set swatchCache($color) $swatch

        # NEXT, return it.
        return $swatch
    }


    #-------------------------------------------------------------------
    # Components

    component menu    ;# Menu displaying palette of colors
    component mbtn    ;# Menu button; pops up palette
    component swatch  ;# Label displaying selected color, or standard
                       # background if none.
    component text    ;# textfield
    component ebtn    ;# Edit button


    #-------------------------------------------------------------------
    # Options

    delegate option -width     to text

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val

        $mbtn configure -state $val
        $text configure -state $val
        $ebtn configure -state $val

    }

    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new text is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    # -palette colors
    #
    # List of colors to display in the menu.

    option -palette \
        -readonly yes \
        -default {
            #3333FF #5555FF #7777FF #8888FF #9999FF
            #00FFFF #00DDDD #00BBBB #009999 #007777 
            #FF0000 #DD0000 #BB0000 #990000 #770000 
            #FF9999 #FF8888 #FF7777 #FF5555 #FF3333 
            #885522 #AA7744 #CC9966 #CC6600 #FFAA44
            #00FF00 #00DD00 #00BB00 #009900 #007700 
            #FF00FF #DD00DD #BB00BB #990099 #770077 
            #FFFF00 #DDDD00 #BBBB00 #999900 #777700
        }
    
    # -rows num
    #
    # Number of rows of swatches in the pulldown menu.

    option -rows \
        -readonly yes \
        -default  5

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the widgets.
        
        # Menu Button
        install mbtn using ttk::menubutton $win.mbtn \
            -image  ::marsgui::icon::tridown         \
            -style  Toolbutton                       \
            -menu   $win.menu

        # Palette Menu
        install menu using menu $win.menu

        # Swatch label
        install swatch using label $win.swatch         \
            -image [$type GetSwatch $::marsgui::defaultBackground]

        # Text Field
        install text using textfield $win.text \
            -width     16                      \
            -state     normal                  \
            -changecmd [mymethod TextChanged]

        # Edit Button
        install ebtn using ttk::button $win.ebtn   \
            -style     Toolbutton \
            -state     normal                 \
            -text      "Pick"                 \
            -takefocus 0                      \
            -command   [mymethod ColorPicker]

        pack $mbtn   -side left
        pack $swatch -side left -padx {0 4}
        pack $text   -side left -fill x -expand yes
        pack $ebtn   -side left

        # NEXT, get the user's options
        $self configurelist $args

        # NEXT, populate the menu with the palette
        $self PopulateMenu
    }

    #-------------------------------------------------------------------
    # Private Methods

    # PopulateMenu
    #
    # Populates the menu component with the selected color palette.
    
    method PopulateMenu {} {
        set i -1
        
        foreach color $options(-palette) {
            set i [expr {($i + 1) % $options(-rows)}]

            if {$i == 0} {
                set break 1
            } else {
                set break 0
            }

            $menu add command \
                -columnbreak $break                   \
                -hidemargin  1                        \
                -image       [$type GetSwatch $color] \
                -command     [mymethod set $color]
        }
    }

    # TextChanged value
    #
    # value   A new value in the text field
    #
    # Updates the widget to display the new value, if it really is new.

    method TextChanged {value} {
        # FIRST, validate the value; then, set the swatch color
        # accordingly.
        if {![catch {::marsgui::hexcolor validate $value}]} {
            set image [$type GetSwatch $value]
        } else {
            set image [$type GetSwatch $::marsgui::defaultBackground]
        }

        $swatch configure -image $image

        # NEXT, call the -changecmd.
        callwith $options(-changecmd) $value
    }

    # ColorPicker
    #
    # Pops up a color picker dialog, displaying the specified color,
    # and allows the user to choose a new color.  Returns the new
    # color, or ""

    method ColorPicker {} {
        # FIRST, give focus to this field.
        focus $win

        # NEXT, get the initial color to display in the picker
        set color [$text get]

        if {[catch {::marsgui::hexcolor validate $color}]} {
            set color ""
        }

        if {$color ne ""} {
            set opts [list -color $color]
        } else {
            set opts ""
        }

        # NEXT, select a new color.
        set out [SelectColor::dialog $win.colorpicker \
                     -type   dialog                    \
                     -parent $win                     \
                     {*}$opts]

        # NEXT, if they picked a color, save it, converting it
        # to a 24-bit hex spec.
        if {$out ne ""} {
            $text set [::marsgui::hexcolor validate $out]
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method get to text

    # set value
    #
    # value    A new value
    #
    # Sets the widget's value to the new value.

    method set {value} {
        # FIRST, Ignore unchanged values.
        if {$value eq [$text get]} {
            return
        }

        # NEXT, set the text field's value
        $text set $value
    }
}



