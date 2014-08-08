#-----------------------------------------------------------------------
# TITLE:
#    checkfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Checkbox data entry field
#
#    A checkfield is a ttk::checkbutton wrapped up to support the
#    field(i) API.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export checkfield
}

#-------------------------------------------------------------------
# checkfield

snit::widget ::marsgui::checkfield {
    #-------------------------------------------------------------------
    # Components

    component cbox    ;# ttk::checkbutton

    #-------------------------------------------------------------------
    # Options

    delegate option * to cbox except {
        -command
        -onvalue
        -offvalue
        -variable
    }

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val
        
        if {$val eq "disabled"} {
            $cbox state disabled
        } elseif {$val eq "normal"} {
            $cbox state !disabled
        } else {
            error "Invalid -state: \"$val\""
        }
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

    variable currentValue 0   ;# The field's value.
    variable oldValue     0   ;# The field's old value

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure the hull
        $hull configure                \
            -borderwidth        0      \
            -highlightthickness 0

        # NEXT, create the checkbutton.
        install cbox using ::ttk::checkbutton $win.entry \
            -variable [myvar currentValue]            \
            -command  [mymethod DetectChange]

        # NEXT, pack it in
        pack $cbox -fill both -expand yes

        # NEXT, configure the arguments
        $self configure {*}$args
    }

    #-------------------------------------------------------------------
    # Private Methods


    # DetectChange
    #
    # Calls the change command if the field's value has changed.

    method DetectChange {} {
        if {$currentValue == $oldValue} {
            return
        }

        set oldValue $currentValue

        if {$options(-changecmd) ne ""} {
            {*}$options(-changecmd) $currentValue
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to cbox

    # get
    #
    # Retrieves the value

    method get {} {
        return $currentValue
    }

    # set value ?-silent?
    #
    # value    A new value
    #
    # Sets the widget's value to the new value.  If the value changed,
    # and -silent is not given, the -changecmd will be called.

    method set {value {opt ""}} {
        # FIRST, set the value
        if {$value ne ""} {
            if {$value} {
                set currentValue 1
            } else {
                set currentValue 0
            }
        } else {
            set currentValue ""   
        }

        if {$opt ne ""} {
            set oldValue $currentValue
        }

        # NEXT, detect changes
        $self DetectChange
    }
}



