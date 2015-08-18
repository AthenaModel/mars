#-----------------------------------------------------------------------
# TITLE:
#    filefield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: File Selection field
#
#    A filefield is a data entry field containing:
#
#    * A readonly textfield displaying the name of a file, with the 
#      full path as a tooltip.
#    * A button, which pops up a file selection dialog.
#
#    The value of the field is the absolute path to the file.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export filefield
}

#-----------------------------------------------------------------------
# filefield

snit::widget ::marsgui::filefield {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Components

    component disp    ;# dispfield
    component ebtn    ;# Edit button

    #-------------------------------------------------------------------
    # Options

    delegate option * to disp

    # -title string
    #
    # Title for the file open dialog box.  Defaults to "Select File".

    option -title \
        -default "Select File"

    # -filetypes list
    #
    # List of file types you're looking for, in the form required for
    # tk_getOpenFile.

    option -filetypes

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val

        $ebtn configure -state $val
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

    variable fullname "" ;# The full path to the file
    

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the widgets.
        
        # Text Field
        install disp using dispfield $win.text

        # Edit Button
        install ebtn using ttk::button $win.ebtn \
            -style     Toolbutton                \
            -state     normal                    \
            -text      "Browse"                  \
            -takefocus 0                         \
            -command   [mymethod SelectFileCB]

        pack $disp   -side left -fill x -expand yes
        pack $ebtn   -side left

        # NEXT, get the user's options
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Private Methods

    # SelectFileCB 
    #
    # Called when the Edit button is pushed.  Pops up the Open File
    # dialog.

    method SelectFileCB {} {
        set filename [tk_getOpenFile                       \
                          -parent    $win                  \
                          -title     $options(-title)      \
                          -filetypes $options(-filetypes)]

        # NEXT, If none, they cancelled
        if {$filename eq ""} {
            return
        }

        $self set $filename
    }


    #-------------------------------------------------------------------
    # Public Methods

    # get
    #
    # Get the widget's value.

    method get {} {
        return $fullname
    }

    # set value
    #
    # value    A new value
    #
    # Sets the widget's value to the new value.

    method set {value} {
        # FIRST, Ignore unchanged values.
        set value [file normalize $value]

        if {$value eq $fullname} {
            return
        }

        # NEXT, set the text field's value
        set fullname $value
        $disp set [file tail $value]
        DynamicHelp::add $disp -text $fullname

        callwith $options(-changecmd) $value
    }
}



