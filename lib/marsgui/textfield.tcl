#-----------------------------------------------------------------------
# TITLE:
#    textfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Text data entry field
#
#    A textfield is a data entry field containing editable text.
#    If desired, it can have an -editcmd, which pops up a value editor.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export textfield
}

#-------------------------------------------------------------------
# textfield

snit::widget ::marsgui::textfield {
    #-------------------------------------------------------------------
    # Components

    component entry    ;# ttk::entry; displays text
    component editbtn  ;# Edit button

    #-------------------------------------------------------------------
    # Options

    delegate option -background  to hull
    delegate option -borderwidth to hull
    delegate option *               to entry

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val
        
        if {$val eq "normal"} {
            if {$editbtn ne ""} {
                $entry configure -state readonly
                $editbtn configure -state normal
            } else {
                $entry configure -state normal
            }
        } elseif {$val eq "disabled"} {
            $entry configure -state disabled

            if {$editbtn ne ""} {
                $editbtn configure -state disabled
            }
        } else {
            error "Invalid -state: \"$val\""
        }
    }


    # -editcmd command
    #
    # If given, the widget will have an "Edit" button that executes this
    # command when pressed.  The command should take two arguments,
    # the field window and the current value, and should return a new 
    # value or "" on cancel.

    option -editcmd   \
        -default ""   \
        -readonly yes


    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new text is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    #-------------------------------------------------------------------
    # Instance Variables

    variable oldValue ""   ;# Used to detect changes.

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure the hull
        $hull configure                \
            -borderwidth        0      \
            -highlightthickness 0

        # NEXT, create the entry to display the text.
        install entry using ::ttk::entry $win.entry \
            -state              normal              \
            -exportselection    yes                 \
            -justify            left                \
            -width              20

        # NEXT, add the entry's name to the hull's bindtags, and add
        # a binding to give focus to the entry.
        bindtags $win [linsert [bindtags $win] 0 $win.entry]

        bind $win.entry <FocusIn> [list focus $win.entry]

        # NEXT, detect the changes as the user types.
        bind $win.entry <KeyRelease> [mymethod DetectChange]

        # NEXT, create the button, if needed.
        set options(-editcmd) [from args -editcmd]

        if {$options(-editcmd) eq ""} {
            grid $win.entry -sticky nsew

            set editbtn ""
        } else {
            ttk::frame $win.bframe  \
                -borderwidth 1      \
                -relief      sunken

            install editbtn using button $win.bframe.edit \
                -state     normal                         \
                -font      tinyfont                       \
                -text      "Edit"                         \
                -takefocus 0                              \
                -command   [mymethod Edit]

            pack propagate $win.bframe no
            $win.bframe configure                \
                -width  30                       \
                -height [winfo reqheight $entry]

            pack $win.bframe.edit -fill both

            grid $win.entry $win.bframe -sticky nsew

            # NEXT, a <Return> in the entry widget should pop up
            # the editor.
            bind $win.entry <Return> [mymethod Edit]
        }

        # NEXT, allow the entry widget to expand
        grid columnconfigure $win 0 -weight 1

        # NEXT, configure the arguments
        $self configure -state normal {*}$args
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Edit
    #
    # Called when the Edit button is pressed

    method Edit {} {
        # FIRST, give focus to this field
        focus $win

        # NEXT, call the editor command given the current data value
        set value [{*}$options(-editcmd) $win [$entry get]]

        # NEXT, if the value is not "", set it.
        if {$value ne ""} {
            $self set $value
        }
    }

    # DetectChange
    #
    # Calls the change command if the field's value has changed.

    method DetectChange {} {
        set value [$self get]

        if {$value eq $oldValue} {
            return
        }

        set oldValue $value

        if {$options(-changecmd) ne ""} {
            {*}$options(-changecmd) $value
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method get to entry
    delegate method *   to entry


    # set value
    #
    # value    A new value
    #
    # Sets the widget's value to the new value.

    method set {value} {
        # FIRST, set the value
        $entry configure -state normal
        $entry delete 0 end
        $entry insert end $value
        $self configure -state $options(-state)

        # NEXT, detect changes
        $self DetectChange
    }
}



