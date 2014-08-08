#-----------------------------------------------------------------------
# TITLE:
#    dispfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Display entry field
#
#    A dispfield is a data entry field using to display non-editable text.
#    If desired, it can have an -editcmd, which pops up a value editor.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export dispfield
}

#-------------------------------------------------------------------
# dispfield

snit::widget ::marsgui::dispfield {
    #-------------------------------------------------------------------
    # Components

    component entry    ;# ttk::entry; displays text
    component editbtn  ;# Edit button

    #-------------------------------------------------------------------
    # Options

    delegate option * to entry

    # -state state
    #
    # This option is ignored; the field is not editable whether it's
    # disabled or not.

    option -state \
        -default "normal"

    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new text is appended to the command as a 
    # single argument.
    #
    # NOTE: This option exists because it's part of the field(i) 
    # interface.  However, as dispfield(n) is output only, it is never
    # called.

    option -changecmd \
        -default ""


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure the hull
        $hull configure                \
            -borderwidth        0      \
            -highlightthickness 0

        # NEXT, create the entry to display the text.
        install entry using ::ttk::entry $win.entry \
            -state              readonly            \
            -exportselection    yes                 \
            -justify            left                \
            -width              20

        # NEXT, add the entry's name to the hull's bindtags, and add
        # a binding to give focus to the entry.
        bindtags $win [linsert [bindtags $win] 0 $win.entry]

        # NEXT, grid the entry
        grid $win.entry -sticky nsew
        
        # NEXT, allow the entry widget to expand
        grid columnconfigure $win 0 -weight 1

        # NEXT, configure the arguments
        $self configure {*}$args
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
        $entry configure -state normal
        $entry delete 0 end
        $entry insert end $value
        $entry configure -state readonly
    }
}



