#-----------------------------------------------------------------------
# TITLE:
#    dynabox.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: dynabox
#
#    This package defines a modal dialog based on dynaview(n).  The
#    caller specifies the dynaform to display in the dialog, and is 
#    given the form data entered by the user.
#
#-----------------------------------------------------------------------

namespace eval ::marsgui:: {
    namespace export dynabox
}

#-----------------------------------------------------------------------
# dynabox

snit::type ::marsgui::dynabox {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # error text colors
    typevariable colors -array {
        ok      black
        error   "#BB0000"
    }

    # dialog -- Name of the dialog widget
    typevariable dialog .dynabox

    # opts -- Array of option settings.  See popup for values
    typevariable opts -array {}

    # tinfo -- Type Info Array
    #
    #   userdict   - The user's chosen output.  Setting this variable
    #                ends the modal grab.
    #   errorText  - The text to show in the error label.
    #   tinfo(errorDict)  - A field->message dictionary of text to show in the error
    #                label

    typevariable tinfo -array {
        userdict {}
        errorText ""
        errorDict {}
    }

    #-------------------------------------------------------------------
    # Public methods

    # popup option value....
    #
    # -resources dict   - Resources dictionary
    # -formtype name    - Dynaform name
    # -helpcmd cmd      - Help command
    # -initvalue dict   - Initial value for the form
    # -oktext text      - Text for the OK button.
    # -parent window    - The dialog box appears over the parent window
    # -title string     - Title of the dialog box
    # -validatecmd cmd  - Validation command
    #
    # Pops up the dialog box.  The OK and Cancel buttons will appear at 
    # the bottom, left to right, packed to the right.  The OK button will
    # have the specified text; it defaults to "OK".  If -helpcmd is given,
    # the Help button will appear at the bottom, packed to the left.  The
    # -form will appear in the middle of the window.
    #
    # The dialog will be application modal, and centered over the specified
    # -parent window.  It will have the specified -title string.  If 
    # -initvalue is non-empty, it should be a field/value dictionary
    # appropriate for the -form, into which it will be loaded.
    #
    # The command will wait until the user presses a button.  On 
    # "Cancel", it will return "".  On OK, it will call the -validatecmd
    # on the form dict.  If the -validatecmd throws INVALID, the
    # error message will appear in red below the form widget.  If the
    # -validatecmd throws REJECTED, the error is a dictionary of field names
    # and error messages; the error message for the current field will
    # appear in red below the form widget.  Otherwise, the -validatecmd's
    # return value will appear in black.

    typemethod popup {args} {
        # FIRST, get the option values
        $type ParseOptions $args

        # NEXT, create the dialog if it doesn't already exist.
        if {![winfo exists $dialog]} {
            # FIRST, create it
            toplevel $dialog         \
                -borderwidth        4 \
                -highlightthickness 0

            # NEXT, withdraw it; we don't want to see it yet
            wm withdraw $dialog

            # NEXT, the user can't resize it
            wm resizable $dialog 0 0

            # NEXT, it can't be closed
            wm protocol $dialog WM_DELETE_WINDOW \
                [mytypemethod DialogCancel]

            # NEXT, it must be on top
            wm attributes $dialog -topmost 1

            # NEXT, create and grid the standard widgets
            
            # Row 1: Dynaview Widget
            dynaview $dialog.form \
                -currentcmd [mytypemethod DialogCurrent] \
                -changecmd  [mytypemethod DialogValidate]

            # Row 2: Separator
            ttk::separator $dialog.sep \
                -orient horizontal

            # Row 3: Error label
            label $dialog.error \
                -textvariable [mytypevar tinfo(errorText)] \
                -wraplength   3i                    \
                -anchor       nw                    \
                -justify      left                  \
                -foreground   $colors(error)

            # Row 4: Button Box
            ttk::frame $dialog.button

            # Create the buttons
            ttk::button $dialog.button.cancel     \
                -text    "Cancel"                  \
                -command [mytypemethod DialogCancel]

            ttk::button $dialog.button.ok     \
                -text    $opts(-oktext)        \
                -command [mytypemethod DialogOK]

            ttk::button $dialog.button.help        \
                -text    "Help"                    \
                -command [mytypemethod DialogHelp]

            if {$opts(-helpcmd) ne ""} {
                pack $dialog.button.help -side left -padx 4
            }
            
            pack $dialog.button.ok     -side right -padx 4
            pack $dialog.button.cancel -side right -padx 4
           
            # Grid it all in
            grid $dialog.form \
                -row 0 -column 0 -padx 8 -pady 4 -sticky nsew

            grid $dialog.sep \
                -row 1 -column 0 -sticky ew

            grid $dialog.error \
                -row 2 -column 0 -padx 8 -pady 4 -sticky new

            grid $dialog.button \
                -row 3 -column 0 -padx 8 -pady 4 -sticky ew
        }

        # NEXT, configure the dialog according to the options
        
        # Set the title
        wm title $dialog $opts(-title)

        # Make it transient over the -parent
        osgui mktoolwindow $dialog $opts(-parent)

        # NEXT, clear the error message.
        set tinfo(errorText) ""

        # NEXT, set the -form, and add the -initvalue.
        $dialog.form configure \
            -resources $opts(-resources) \
            -formtype  $opts(-formtype)
        
        if {$opts(-initvalue) ne ""} {
            $dialog.form set $opts(-initvalue)
        }

        # NEXT, raise the dialog and set the focus
        wm deiconify $dialog
        wm attributes $dialog -topmost
        raise $dialog

        # NEXT, do the grab, and wait until they return.
        set tinfo(userdict) {}

        grab set $dialog
        vwait [mytypevar tinfo(userdict)]
        grab release $dialog
        wm withdraw $dialog

        return $tinfo(userdict)
    }

    # ParseOptions arglist
    #
    # arglist - List of popup args
    #
    # Parses the options into the opts array

    typemethod ParseOptions {arglist} {
        # FIRST, set the option defaults
        array set opts {
            -resources     {}
            -formtype      ""
            -helpcmd       ""
            -initvalue     {}
            -oktext        "OK"
            -parent        {}
            -title         {}
            -validatecmd   {}
        }

        # NEXT, get the option values
        while {[llength $arglist] > 0} {
            set opt [::marsutil::lshift arglist]

            switch -exact -- $opt {
                -resources     -
                -formtype      -
                -helpcmd       -
                -initvalue     -
                -oktext        -
                -parent        -
                -title         -
                -validatecmd   {
                    set opts($opt) [::marsutil::lshift arglist]
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, validate options
        require {$opts(-formtype) in [::marsutil::dynaform types]} \
            "Invalid form type: \"$opts(-formtype)\""

        if {$opts(-parent) ne ""} {
            snit::window validate $opts(-parent)
        } else {
            error "-parent: not specified"
        }
    }

    # DialogCancel
    #
    # Returns the empty string.

    typemethod DialogCancel {} {
        set tinfo(userdict) ""
    }

    # DialogOK
    #
    # Validates the string, and returns it.
    
    typemethod DialogOK {} {
        # FIRST, get the input data
        set dict [$dialog.form get]

        # NEXT, validate the data
        if {![$type ValidateData $dict]} {
            return
        }

        # NEXT, save the user's input; this will break us out of the
        # modal dialog.
        set tinfo(userdict) $dict
    }

    # DialogCurrent field
    #
    # field - A field name
    #
    # Called when a new field becomes the current field.  Displays any
    # related error message.

    typemethod DialogCurrent {field} {
        if {[dict size $tinfo(errorDict)] > 0} {
            if {[dict exists $tinfo(errorDict) $field]} {
                set tinfo(errorText) [dict get $tinfo(errorDict) $field]
            } else {
                set tinfo(errorText) \
          "Errors in input; click on fields with red labels for more detail."
            }
        }
    }

    # DialogValidate fields
    #
    # fields - Names of the fields whose value changed.
    #
    # Validates the input, setting the tinfo(errorText) as appropriate.
    
    typemethod DialogValidate {fields} {
        $type ValidateData [$dialog.form get]
        return
    }

    # ValidateData dict
    #
    # dict - Form's field dictionary
    #
    # Validates the input, setting the tinfo(errorText) as appropriate.
    
    typemethod ValidateData {dict} {
        set tinfo(errorDict) {}
        set tinfo(errorText) ""

        if {$opts(-validatecmd) ne ""} {
            if {[catch {
                {*}$opts(-validatecmd) $dict
            } result eopts]} {
                switch -exact -- [dict get $eopts -errorcode] {
                    INVALID {
                        set tinfo(errorText) $result
                        $dialog.error configure -foreground $colors(error)
                    }
                    REJECTED {
                        set tinfo(errorDict) $result
                        $dialog.form invalid [dict keys $result]
                        $type DialogCurrent [$dialog.form current]
                        $dialog.error configure -foreground $colors(error)
                    }
                    default {
                        # Rethrow the error
                        return {*}$eopts $result
                    }
                }

                return 0
            }
        } else {
            set result ""
        }

        set tinfo(errorText) $result
        $dialog.error configure -foreground $colors(ok)
        $dialog.form invalid {}

        return 1
    }

    # DialogHelp
    #
    # Calls the -helpcmd.
    
    typemethod DialogHelp {} {
        assert {$opts(-helpcmd) ne ""}
        uplevel #0 $opts(-helpcmd)
    }
}


