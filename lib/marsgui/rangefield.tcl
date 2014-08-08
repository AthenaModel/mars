#-----------------------------------------------------------------------
# TITLE:
#    rangefield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Range slider field
#
#    A rangefield is a data entry field containing a slider, a label
#    showing the current value, and optionally either a quality pulldown
#    or an editable text entry.  It can also have a reset button.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export rangefield
}

#-----------------------------------------------------------------------
# rangefield

snit::widget ::marsgui::rangefield {
    #-------------------------------------------------------------------
    # Type Variables

    # The type saves a dummy scale widget that is never displayed;
    # it's used to determine the label width.

    typevariable dummyScale ""


    #-------------------------------------------------------------------
    # Components

    component resetbtn        ;# ttk::button
    component scale           ;# tk::scale
    component vlabel          ;# Value label
    component qmenu           ;# Quality pulldown menu

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    delegate option -scalelength to scale as -length
    delegate option -menufont    to qmenu as -font

    # -background color
    #
    # Sets the widget's background, which is propagated to the vlabel.
    # The default is set programmatically.

    option -background \
        -configuremethod ConfigBackground

    method ConfigBackground {opt val} {
        set options($opt) $val

        $hull   configure -background $val
        $vlabel configure -background $val
    }

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val
        
        callwith $resetbtn configure -state $val
        $scale             configure -state $val
        callwith $qmenu    configure -state $val
    }


    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new text is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    # -changemode
    #
    # Specifies whether the -changecmd is called continuously, or 
    # only on ButtonRelease.  In the latter case, keystrokes are
    # disabled.
    #
    # If the default is changed to onrelease, the constructor will
    # need to be updated to disable keystrokes.

    option -changemode \
        -type            {snit::enum -values {continuous onrelease}} \
        -default         continuous                                  \
        -configuremethod ConfigChangeMode

    method ConfigChangeMode {opt val} {
        set options($opt) $val

        if {$val eq "continuous"} {
            bind $scale <Key> {}
        } else {
            bind $scale <Key> {break}
        }
    }

    # -font font
    #
    # Sets the vlabel and qmenu -font.
    
    option -font \
        -default         ""         \
        -configuremethod ConfigFont

    method ConfigFont {opt val} {
        set options($opt) $val

        $vlabel configure -font $val
        $qmenu configure -font $val
    }

    # -labelpos left|right
    #
    # Determines the position of the label widget, left or right of
    # the scale.
    
    option -labelpos \
        -type             {snit::enum -values {left right}} \
        -default          right                             \
        -configuremethod  ConfigLayoutOpt

    # -type command
    #
    # Command is a snit::double, snit::integer, range(n), or quality(n)
    # value (or anything with -min and -max options).  It determines
    # the range of values on the scale.

    option -type \
        -validatemethod  ValidateType    \
        -configuremethod ConfigLayoutOpt

    method ValidateType {opt val} {
        if {$options(-type) ne ""} {
            error "-type can only be set once"
        }
    }

    # -resetvalue value
    #
    # The value to which the scale is reset when the field's value
    # is cleared.  If not set, a heuristic is applied to 
    # determine a reasonable value.

    option -resetvalue \
        -default         ""              \
        -configuremethod ConfigLayoutOpt

    # -resolution value
    #
    # If not "", the value is propagated to the scale.  Otherwise,
    # a heuristic is applied to determine a reasonable resolution.
    
    option -resolution                   \
        -default         ""              \
        -configuremethod ConfigLayoutOpt


    # -showreset flag
    #
    # If true, the widget will have a "Reset" button that sets the
    # scale to the -resetvalue.

    option -showreset \
        -default         no              \
        -configuremethod ConfigLayoutOpt


    # -showsymbols flag
    #
    # If true, the field contains a menu of symbolic values from
    # the -type, which must be a quality(n) object.

    option -showsymbols \
        -default         no              \
        -configuremethod ConfigLayoutOpt

    # ConfigLayoutOpt opt val
    #
    # opt - An option that affects the layout
    # val - The option's value
    #
    # Sets the option, and computes the widget's layout.

    method ConfigLayoutOpt {opt val} {
        # FIRST, save the option value.
        set options($opt) $val

        # NEXT, layout the widget (unless we're in the constructor).
        if {!$inConstructor && $options(-type) ne ""} {
            $self LayoutWidget
        }
    }
    
    # -min value
    # -max value
    #
    # Set the min and max bounds.  Defaults to the min and max bounds
    # of the -type.  
    
    option -min \
        -readonly yes
    option -max \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance Variables

    variable inConstructor 1    ;# Flag: are we in the constructor?
    variable current       0    ;# Current value
    variable displayed     ""   ;# Displayed value (sometimes transient)
    variable scaleGuard    ""   ;# ScaleChanged guard value
    variable qmenuGuard    ""   ;# QmenuChanged guard value


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure the hull
        $hull configure                \
            -borderwidth        0      \
            -highlightthickness 0

        set options(-background) [$hull cget -background]

        # NEXT, create the scale
        install scale using scale $win.scale   \
            -orient    horizontal              \
            -showvalue no                      \
            -takefocus 1                       \
            -length    150

        # NEXT, create the label
        install vlabel using ttk::label $win.vlabel  \
            -textvariable [myvar displayed]

        # NEXT, create the qmenu; we'll grid it if need be.
        install qmenu as enumfield $win.qmenu    \
            -displaylong 1                       \
            -changecmd   [mymethod QmenuChanged]

        # NEXT, create the reset button; we'll grid it if need be.
        install resetbtn using button $win.reset \
            -state     $options(-state)          \
            -font      tinyfont                  \
            -text      "Reset"                   \
            -takefocus 0                         \
            -command   [mymethod Reset]

        # NEXT, clicking on the scale should give it the focus.
        bind $scale <1> {focus %W}

        # NEXT, a button release on the scale should cause the
        # value to be set.
        bind $scale <ButtonRelease> [mymethod ScaleButtonReleased]

        # NEXT, configure the arguments
        $self configure {*}$args

        # NEXT, layout the widget
        $self LayoutWidget
        
        # NEXT, we're no longer in the constructor; any layout-related
        # options should take effect immediately.
        set inConstructor 0


        # NEXT, clear the widget
        if {$options(-type) ne ""} {
            $self SetValue layout ""
        }
    }

    # LayoutWidget
    #
    # Lays out the widget, provided that the -type is defined.

    method LayoutWidget {} {
        # FIRST, there's no point if there's no -type.
        if {$options(-type) eq ""} {
            return
        }

        # NEXT, determine the -min and -max bounds.
        set min [$options(-type) cget -min]
        set max [$options(-type) cget -max]

        if {$options(-min) ne "" && $options(-min) > $min} {
            set min $options(-min)
        }

        if {$options(-max) ne "" && $options(-max) < $max} {
            set max $options(-max)
        }

        set options(-min) $min
        set options(-max) $max

        # NEXT, set the scale's bounds and value.
        if {$options(-resetvalue) eq ""} {
            $self ChooseResetValue
        }

        if {$options(-resolution) eq ""} {
            $self ChooseResolution
        }

        $scale configure \
            -from       $min                  \
            -to         $max                  \
            -resolution $options(-resolution)

        set vlabelWidth [$self GetLabelWidth]

        $scale configure \
            -command    [mymethod ScaleChanged]

        # NEXT, set the label's width
        $vlabel configure \
            -width $vlabelWidth

        # NEXT, create qmenu if needed.
        if {$options(-showsymbols)} {
            set width [lmaxlen [$options(-type) longnames]]

            $qmenu configure \
                -enumtype $options(-type) \
                -width    [expr {$width + 3}]
        }

        # NEXT, lay out the widgets.
        grid forget {*}[winfo children $win]

        set c -1

        if {$options(-labelpos) eq "left"} {
            grid $vlabel -row 0 -column [incr c] -sticky w -padx {0 4}

            grid $scale -row 0 -column [incr c] -sticky ew

            if {$options(-showsymbols)} {
                grid $qmenu -row 0 -column [incr c] -sticky ew -padx {4 0}
            }

            grid columnconfigure $win $c -weight 1

        } else {
            # -labelpos right

            grid $scale -row 0 -column [incr c] -sticky ew -padx {0 4}

            grid $vlabel -row 0 -column [incr c] -sticky w

            if {$options(-showsymbols)} {
                grid $qmenu -row 0 -column [incr c] -sticky ew -padx {4 0}
            }

            grid columnconfigure $win $c -weight 1
        }

        if {$options(-showreset)} {
            grid $resetbtn -row 0 -column [incr c] -sticky e -padx {4 0}
        }

    }

    #-------------------------------------------------------------------
    # Private Methods

    # ChooseResetValue
    #
    # Picks a reasonable resolution for the scale based on the limits.

    method ChooseResetValue {} {
        set min $options(-min)
        set max $options(-max)

        if {$min <= 0 && 0 <= $max} {
            set options(-resetvalue) 0
        } else {
            set options(-resetvalue) $min
        }
    }

    # ChooseResolution
    #
    # Picks a reasonable resolution for the scale based on the limits.

    method ChooseResolution {} {
        set min $options(-min)
        set max $options(-max)

        if {$max - $min >= 50} {
            set options(-resolution) 1
        } elseif {$max - $min < 0.5} {
            set options(-resolution) 0.01
        } else {
            set options(-resolution) 0.05
        }
    }

    # GetLabelWidth
    #
    # Computes and returns the appropriate width for the value label.

    method GetLabelWidth {} {
        # FIRST, create the dummyScale if it doesn't exist.
        if {![winfo exists $dummyScale]} {
            set dummyScale [scale $win.dummy]
        }

        # NEXT, configure the dummyScale
        $dummyScale configure \
            -resolution [$scale cget -resolution] \
            -from       [$scale cget -from] \
            -to         [$scale cget -to]

        # NEXT, take the measurements.
        $dummyScale set [$scale cget -from]
        set a [string length [$dummyScale get]]

        $dummyScale set [$scale cget -to]
        set b [string length [$dummyScale get]]

        return [expr {max($a,$b)}]
    }

    # SetScale value
    #
    # Sets the current value of the scale widget, disabled
    # ScaleChanged.

    method SetScale {value} {
        if {$value eq ""} {
            set value $options(-resetvalue)
        }

        set scaleGuard $value

        if {$options(-state) ne "disabled"} {
            $scale set $value
        } else {
            $scale configure -state normal
            $scale set $value
            $scale configure -state $options(-state)
        }
    }


    # ScaleChanged value
    #
    # The value of the scale widget changed.

    method ScaleChanged {value} {
        if {$value != $scaleGuard} {
            $self SetValue slide $value
        }
    }

    # ScaleButtonReleased
    #
    # The button was released on the scale widget

    method ScaleButtonReleased {} {
        $self SetValue release [$scale get]
    }


    # SetQmenu value
    #
    # Sets the current value of the qmenu widget, disabled
    # ScaleChanged.

    method SetQmenu {value} {
        if {$options(-showsymbols)} {
            set qmenuGuard [$options(-type) name $value]
            $qmenu set $qmenuGuard
            set inSetQmenu 0
        }
    }


    # QmenuChanged value
    #
    # The value of the qmenu widget changed.

    method QmenuChanged {value} {
        if {$value ne $qmenuGuard} {
            $self SetValue qmenu [$options(-type) value $value]
        }
    }

    # Reset
    #
    # The Reset button was pressed.

    method Reset {} {
        $self SetValue reset $options(-resetvalue)
    }

    # SetValue source value
    #
    # source - Indicates who set the value:
    #          layout|set|slide|release|qmenu|reset
    # value  - A new value
    #
    # Sets the widget's value to the new value.  Calls the
    # -changecmd if appropriate.

    method SetValue {source value} {
        # FIRST, if nothing's changed, do nothing
        if {$value eq $current} {
            # FIRST, if -changemode is onrelease, we may need to
            # update the displayed value.
            if {$options(-changemode) eq "onrelease"} {
                if {$value ne ""} {
                    set displayed [$scale get]
                } else {
                    set displayed ""
                }
            }

            return
        }

        # NEXT, update the scale and qmenu to reflect the new value.
        $self SetScale $value
        $self SetQmenu $value

        # NEXT, update the displayed value.  If it's non-empty, allow 
        # the scale to format it.
        if {$value ne ""} {
            set displayed [$scale get]
        } else {
            set displayed ""
        }

        # NEXT, If this is a slide change and we're not tracking
        # continuously, just return.
        if {$source eq "slide" && 
            $options(-changemode) eq "onrelease"
        } {
            return
        }

        # NEXT, this is now the current value.
        set current $displayed

        # NEXT, notify the client.
        if {$source ne "layout"} {
            callwith $options(-changecmd) $current
        }

        return
    }


    #-------------------------------------------------------------------
    # Public Methods

    # get
    #
    # Returns the current value.

    method get {} {
        return $current
    }

    # set value
    #
    # value    A new value
    #
    # Sets the widget's value to the new value.

    method set {value} {
        $self SetValue set $value
    }
}



