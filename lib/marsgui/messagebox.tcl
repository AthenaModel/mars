#-----------------------------------------------------------------------
# TITLE:
#    messagebox.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: messagebox
#
#    This is a replacement for tk_messageBox with a slightly different
#    set of options.  In particular, the message box can include a
#    "Do not show this message again" check box; ignoring the message the
#    next time is automatic.
#
#    In addition, it provides a dialog for requesting a string value
#    from the user.
#
# TBD:
#    The caller should be able to specify arbitrary Tk images is
#    the value of -icon.
#
#-----------------------------------------------------------------------

namespace eval ::marsgui:: {
    namespace export messagebox
}

#-----------------------------------------------------------------------
# messagebox

snit::type ::marsgui::messagebox {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Create the icons
        namespace eval ${type}::icon { }

        mkicon ${type}::icon::question {
            ...........XXXXXXXXXX...........
            ........XXX,,,,,,,,,,XXX........
            ......XX,,,,,,,,,,,,,,,,XX......
            .....X,,,,,,,,,,,,,,,,,,,,X.....
            ....X,,,,,,,,,,,,,,,,,,,,,,X....
            ...X,,,,,,,,,@@@@@@,,,,,,,,,X...
            ..X,,,,,,,,,@,,,@@@@,,,,,,,,,X..
            .X,,,,,,,,,@@,,,,@@@@,,,,,,,,,X.
            .X,,,,,,,,,@@@,,,@@@@,,,,,,,,,X.
            X,,,,,,,,,,@@@,,,@@@@,,,,,,,,,,X
            X,,,,,,,,,,,@,,,@@@@,,,,,,,,,,,X
            X,,,,,,,,,,,,,,@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@@,,,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@,,,,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@,,,,,,,,,,,,,,,X
            X,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,X
            .X,,,,,,,,,,,,@@,,,,,,,,,,,,,,X.
            .X,,,,,,,,,,,@@@@,,,,,,,,,,,,,X.
            ..X,,,,,,,,,,@@@@,,,,,,,,,,,,X..
            ...X,,,,,,,,,,@@,,,,,,,,,,,,X...
            ....X,,,,,,,,,,,,,,,,,,,,,,X....
            .....XX,,,,,,,,,,,,,,,,,,,X.....
            .......XXX,,,,,,,,,,,,,XXX......
            ..........XX,,,,,,,XXXX.........
            ............XX,,,,X.............
            ..............X,,,X.............
            ..............X,,,X.............
            ...............X,,X.............
            ................X,X.............
            .................XX.............
            ................................
            ................................
        } {
            X black
            @ blue
            , white
            . trans
        }

        mkicon ${type}::icon::info {
            ...........XXXXXXXXXX...........
            ........XXX,,,,,,,,,,XXX........
            ......XX,,,,,,,,,,,,,,,,XX......
            .....X,,,,,,,,@@@@,,,,,,,,X.....
            ....X,,,,,,,,@@@@@@,,,,,,,,X....
            ...X,,,,,,,,,@@@@@@,,,,,,,,,X...
            ..X,,,,,,,,,,,@@@@,,,,,,,,,,,X..
            .X,,,,,,,,,,,,,,,,,,,,,,,,,,,,X.
            .X,,,,,,,,,,,,,,,,,,,,,,,,,,,,X.
            X,,,,,,,,,,,@@@@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,@@@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@@@@,,,,,,,,,,,,X
            X,,,,,,,,,,,,,@@@@@,,,,,,,,,,,,X
            .X,,,,,,,,,,,,@@@@@,,,,,,,,,,,X.
            .X,,,,,,,,,,,@@@@@@@,,,,,,,,,,X.
            ..X,,,,,,,,,@@@@@@@@@,,,,,,,,X..
            ...X,,,,,,,,,,,,,,,,,,,,,,,,X...
            ....X,,,,,,,,,,,,,,,,,,,,,,X....
            .....XX,,,,,,,,,,,,,,,,,,,X.....
            .......XXX,,,,,,,,,,,,,XXX......
            ..........XX,,,,,,,XXXX.........
            ............XX,,,,X.............
            ..............X,,,X.............
            ..............X,,,X.............
            ...............X,,X.............
            ................X,X.............
            .................XX.............
            ................................
            ................................
        } {
            X black
            @ blue
            , white
            . trans
        }

        mkicon ${type}::icon::warning {
            ..............XXXX..............
            .............X,,,,X.............
            ............X,,,,,,X............
            ............X,,,,,,X............
            ...........X,,,,,,,,X...........
            ...........X,,,,,,,,X...........
            ..........X,,,,,,,,,,X..........
            ..........X,,,,,,,,,,X..........
            .........X,,,,,,,,,,,,X.........
            .........X,,,,@@@@,,,,X.........
            ........X,,,,@@@@@@,,,,X........
            ........X,,,,@@@@@@,,,,X........
            .......X,,,,,@@@@@@,,,,,X.......
            .......X,,,,,@@@@@@,,,,,X.......
            ......X,,,,,,@@@@@@,,,,,,X......
            ......X,,,,,,,@@@@,,,,,,,X......
            .....X,,,,,,,,@@@@,,,,,,,,X.....
            .....X,,,,,,,,@@@@,,,,,,,,X.....
            ....X,,,,,,,,,,@@,,,,,,,,,,X....
            ....X,,,,,,,,,,@@,,,,,,,,,,X....
            ...X,,,,,,,,,,,@@,,,,,,,,,,,X...
            ...X,,,,,,,,,,,,,,,,,,,,,,,,X...
            ..X,,,,,,,,,,,,@@,,,,,,,,,,,,X..
            ..X,,,,,,,,,,,@@@@,,,,,,,,,,,X..
            .X,,,,,,,,,,,,@@@@,,,,,,,,,,,,X.
            .X,,,,,,,,,,,,,@@,,,,,,,,,,,,,X.
            X,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,X
            X,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,X
            X,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,X
            .X,,,,,,,,,,,,,,,,,,,,,,,,,,,,X.
            ..XXXXXXXXXXXXXXXXXXXXXXXXXXXX..
            ................................
        } {
            X black
            @ black
            , yellow
            . trans
        }

        mkicon ${type}::icon::error {
            ............XXXXXXX.............
            .........XXX,,,,,,,XXX..........
            .......XX,,,,,,,,,,,,,XX........
            ......XX,,,,,,,,,,,,,,,XX.......
            .....X,,,,,,,,,,,,,,,,,,,X......
            ....X,,,,,,,,,,,,,,,,,,,,,X.....
            ...X,,,,,,,,,,,,,,,,,,,,,,,X....
            ..XX,,,,,@,,,,,,,,,,,@,,,,,XX...
            ..X,,,,,@@@,,,,,,,,,@@@,,,,,X...
            .X,,,,,@@@@@,,,,,,,@@@@@,,,,,X..
            .X,,,,,,@@@@@,,,,,@@@@@,,,,,,X..
            .X,,,,,,,@@@@@,,,@@@@@,,,,,,,X..
            X,,,,,,,,,@@@@@,@@@@@,,,,,,,,,X.
            X,,,,,,,,,,@@@@@@@@@,,,,,,,,,,X.
            X,,,,,,,,,,,@@@@@@@,,,,,,,,,,,X.
            X,,,,,,,,,,,,@@@@@,,,,,,,,,,,,X.
            X,,,,,,,,,,,@@@@@@@,,,,,,,,,,,X.
            X,,,,,,,,,,@@@@@@@@@,,,,,,,,,,X.
            X,,,,,,,,,@@@@@,@@@@@,,,,,,,,,X.
            .X,,,,,,,@@@@@,,,@@@@@,,,,,,,X..
            .X,,,,,,@@@@@,,,,,@@@@@,,,,,,X..
            .X,,,,,@@@@@,,,,,,,@@@@@,,,,,X..
            ..X,,,,,@@@,,,,,,,,,@@@,,,,,X...
            ..XX,,,,,@,,,,,,,,,,,@,,,,,XX...
            ...X,,,,,,,,,,,,,,,,,,,,,,,X....
            ....X,,,,,,,,,,,,,,,,,,,,,X.....
            .....X,,,,,,,,,,,,,,,,,,,X......
            ......XX,,,,,,,,,,,,,,,XX.......
            .......XX,,,,,,,,,,,,,XX........
            .........XXX,,,,,,,XXX..........
            ............XXXXXXX.............
            ................................
        } {
            X black
            @ white
            , red
            . trans
        }
    }

    #-------------------------------------------------------------------
    # Lookup Tables

    # iconnames: list of valid icons

    typevariable iconnames {error info question warning}

    #-------------------------------------------------------------------
    # Type Variables

    # dialog -- Name of the dialog widget

    typevariable dialog .messagebox

    # getsdlg -- Name of the gets dialog widget

    typevariable getsdlg .messageboxgets

    # pickdlg -- Name of the pick dialog widget

    typevariable pickdlg .messageboxpick

    # listdlg -- Name of the listselect dialog widget
    typevariable listdlg .messageboxlist

    # opts -- Array of option settings.  See popup for values

    typevariable opts -array {}

    # ignore -- Array of ignore flags by ignore tag.

    typevariable ignore -array {}

    # choice -- The user's choice
    typevariable choice {}

    # errorText -- Error message, for "gets".
    typevariable errorText {}


    #-------------------------------------------------------------------
    # Public methods

    # popup option value....
    #
    # -buttons dict          Dictionary {symbol labeltext ...} of buttons
    # -default symbol        Symbolic name of the default button
    # -onclose symbol        Button "pressed" if dialog is closed using the
    #                        window manager's close button.
    # -icon image            error, info, question, warning, peabody
    # -ignoretag tag         Tag for ignoring this dialog
    # -ignoredefault symbol  Button "pressed" if dialog is ignored.
    # -message string        Message to display.  Will be wrapped.
    # -parent window         The message box appears over the parent window
    # -title string          Title of the message box
    # -wraplength len        Wrap length for the message; defaults to 4i.
    #                        if "", no wrapping is done.
    #
    # Pops up the message box.  The -buttons will appear at the bottom,
    # left to right, packed to the right.  The specified button will be
    # the -default; or the first button is -default is not given.  The
    # -icon will be displayed; defaults to "info".  The -message will be 
    # wrapped into the message space.  The dialog will be application modal,
    # and centered over the specified -parent window.  It will have the
    # specified -title string.
    #
    # The command will wait until the user presses a button, and will
    # return the symbol for the button.
    #
    # If -ignoretag is specified, there will be a "Do not show this again"
    # checkbox just above the buttons.  If checked, this state will be
    # saved; if the dialog is requested again, it will simply return
    # the symbolic name of the -ignoredefault button.

    typemethod popup {args} {
        # FIRST, get the option values
        $type ParsePopupOptions $args

        # NEXT, ignore it if they've so indicated
        if {[info exists ignore($opts(-ignoretag))] &&
            $ignore($opts(-ignoretag))
        } {
            return $opts(-ignoredefault)
        }

        # NEXT, create the dialog.
        toplevel $dialog           \
            -borderwidth 4         \
            -highlightthickness 0

        # NEXT, withdraw it; we don't want to see it yet
        wm withdraw $dialog

        # NEXT, the user can't resize it
        wm resizable $dialog 0 0

        # NEXT, it can't be closed
        wm protocol $dialog WM_DELETE_WINDOW \
            [mytypemethod PopupClose]


        # NEXT, it must be on top
        wm attributes $dialog -topmost 1

        # NEXT, create and grid the standard widgets
        
        # Row 1: Icon and message
        ttk::frame $dialog.top

        ttk::label $dialog.top.icon \
            -image  ${type}::icon::info \
            -anchor nw

        if {$opts(-wraplength) eq ""} {
            set wrap [list]
        } else {
            set wrap "-wraplength $opts(-wraplength)"
        }

        ttk::label $dialog.top.message \
            -textvariable [mytypevar opts(-message)] \
            -anchor       nw                         \
            -justify      left                       \
            {*}$wrap


        grid $dialog.top.icon \
            -row 0 -column 0 -padx 8 -pady 4 -sticky nw 
        grid $dialog.top.message \
            -row 0 -column 1 -padx 8 -pady 4 -sticky new

        # Row 2: Ignore checkbox
        ttk::checkbutton $dialog.ignore                   \
            -text   "Do not show this message again"
        
        # Row 3: button box
        ttk::frame $dialog.button

        pack $dialog.top    -side top    -fill x
        pack $dialog.button -side bottom -fill x

        # NEXT, configure the dialog according to the options
        
        # Set the title
        wm title $dialog $opts(-title)

        # Set the icon
        if {$opts(-icon) eq "peabody"} {
            set icon ::marsgui::icon::peabody32
        } else {
            set icon ${type}::icon::$opts(-icon)
        }

        $dialog.top.icon configure -image $icon

        # Set the ignore tag
        if {$opts(-ignoretag) ne ""} {
            set ignore($opts(-ignoretag)) 0

            $dialog.ignore configure \
                -variable [mytypevar ignore($opts(-ignoretag))]

            pack $dialog.ignore \
                -after $dialog.top \
                -side  top         \
                -fill  x           \
                -padx  8           \
                -pady  4
        } else {
            $dialog.ignore configure \
                -variable ""

            pack forget $dialog.ignore
        }

        # Delete any old buttons
        foreach btn [winfo children $dialog.button] {
            destroy $btn
        }

        # Create the buttons
        foreach symbol [lreverse [dict keys $opts(-buttons)]] {
            set text [dict get $opts(-buttons) $symbol]

            set button($symbol) \
                [ttk::button $dialog.button.$symbol                 \
                     -text    $text                                 \
                     -width   [expr {max(8,[string length $text])}] \
                     -command [mytypemethod Choose $symbol]]

            pack $dialog.button.$symbol -side right -padx 4
        }

        # Make it transient over the -parent
        osgui mktoolwindow $dialog $opts(-parent)

        # NEXT, raise the button and set the focus
        wm deiconify $dialog
        wm attributes $dialog -topmost
        raise $dialog
        focus $button($opts(-default))

        # NEXT, do the grab, and wait until they return.
        set choice {}

        grab set $dialog
        vwait [mytypevar choice]
        grab release $dialog
        destroy $dialog

        return $choice
    }

    # ParsePopupOptions arglist
    #
    # arglist     List of popup args
    #
    # Parses the options into the opts array

    typemethod ParsePopupOptions {arglist} {
        # FIRST, set the option defaults
        array set opts {
            -buttons       {ok OK}
            -ignoredefault {}
            -default       {}
            -onclose       {}
            -icon          info
            -ignoretag     {}
            -message       {}
            -parent        {}
            -title         {}
            -wraplength    3i
        }

        # NEXT, get the option values
        while {[llength $arglist] > 0} {
            set opt [::marsutil::lshift arglist]

            switch -exact -- $opt {
                -buttons       -
                -default       -
                -onclose       -
                -icon          -
                -ignoretag     -
                -ignoredefault -
                -message       -
                -parent        -
                -title         -
                -wraplength    {
                    set opts($opt) [::marsutil::lshift arglist]
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, validate -buttons
        if {[llength $opts(-buttons)] == 0 ||
            [llength $opts(-buttons)] % 2 != 0
        } {
            error "-buttons: not a dictionary"
        }

        # NEXT, validate -default
        if {$opts(-default) eq ""} {
            set opts(-default) [lindex $opts(-buttons) 0]
        } else {
            if {$opts(-default) ni [dict keys $opts(-buttons)]} {
                error "-default: unknown button: \"$opts(-default)\""
            }
        }

        # NEXT, validate -ignoredefault
        if {$opts(-ignoredefault) eq ""} {
            set opts(-ignoredefault) $opts(-default)
        } else {
            if {$opts(-ignoredefault) ni [dict keys $opts(-buttons)]} {
                error \
                    "-ignoredefault: unknown button: \"$opts(-ignoredefault)\""
            }
        }

        # NEXT, validate -icon
        if {$opts(-icon) ni $iconnames && $opts(-icon) ne "peabody"} {
            error "-icon: should be one of [join $iconnames {, }]"
        }

        # NEXT, validate -parent
        if {$opts(-parent) ne ""} {
            snit::window validate $opts(-parent)
        } else {
            error "-parent: not specified"
        }
    }

    # Choose symbol
    #
    # symbol    A symbolic name from -buttons
    #
    # Sets the button as their choice

    typemethod Choose {symbol} {
        set choice $symbol
    }

    # OnClose
    #
    # Chooses the -onclose symbol (if any) when the dialog is closed.

    typemethod PopupClose {} {
        if {$opts(-onclose) ne ""} {
            $type Choose $opts(-onclose)
        } else {
            $type Choose [lindex $opts(-buttons) 0]
        }
    }

    # reset ?tag?
    #
    # tag     An ignore tag
    #
    # Resets the specified ignore flag, or all ignore flags.

    typemethod reset {{tag ""}} {
        if {$tag ne ""} {
            set ignore($tag) 0
        } else {
            array unset ignore
        }
    }

    #-------------------------------------------------------------------
    # gets

    # gets option value....
    #
    # -oktext text           Text for the OK button.
    # -icon image            error, info, question, warning, peabody
    # -message string        Message to display.  Will be wrapped.
    # -parent window         The message box appears over the parent window
    # -title string          Title of the message box
    # -initvalue string      Initial value for the entry field
    # -validatecmd cmd       Validation command
    #
    # Pops up the "get string" message box.  The buttons will appear at 
    # the bottom, left to right, packed to the right.  The OK button will
    # have the specified text; it defaults to "OK".  The
    # -icon will be displayed; defaults to "question".  The -message will be 
    # wrapped into the message space; the entry widget will be below
    # the -message. The dialog will be application modal,
    # and centered over the specified -parent window.  It will have the
    # specified -title string.  If -initvalue is non-empty, its value
    # will be placed in the entry widget, and selected.
    #
    # The command will wait until the user presses a button.  On 
    # "cancel", it will return "".  On OK, it will call the -validatecmd
    # on the trimmed string.  If the -validatecmd throws INVALID, the
    # error message will appear in red below the entry widget.  Otherwise,
    # the command will return the entered string.

    typemethod gets {args} {
        # FIRST, get the option values
        $type ParseGetsOptions $args

        # NEXT, create the dialog if it doesn't already exist.
        if {![winfo exists $getsdlg]} {
            # FIRST, create it
            toplevel $getsdlg         \
                -borderwidth        4 \
                -highlightthickness 0

            # NEXT, withdraw it; we don't want to see it yet
            wm withdraw $getsdlg

            # NEXT, the user can't resize it
            wm resizable $getsdlg 0 0

            # NEXT, it can't be closed
            wm protocol $getsdlg WM_DELETE_WINDOW \
                [mytypemethod GetsCancel]

            # NEXT, it must be on top
            wm attributes $getsdlg -topmost 1

            # NEXT, create and grid the standard widgets
            
            # Row 1: Icon and message
            ttk::frame $getsdlg.top

            ttk::label $getsdlg.top.icon \
                -image  ${type}::icon::question \
                -anchor nw

            ttk::label $getsdlg.top.message \
                -textvariable [mytypevar opts(-message)] \
                -wraplength   3i                         \
                -anchor       nw                         \
                -justify      left

            # Row 2: Entry Widget
            ttk::entry $getsdlg.top.entry

            bind $getsdlg.top.entry <Return> [mytypemethod GetsOK]

            # Row 3: Error label
            label $getsdlg.top.error \
                -textvariable [mytypevar errorText] \
                -wraplength   3i                    \
                -anchor       nw                    \
                -justify      left                  \
                -foreground   "#BB0000"
            
            grid $getsdlg.top.icon \
                -row 0 -column 0 -padx 8 -pady 4 -sticky nw 

            grid $getsdlg.top.message \
                -row 0 -column 1 -padx 8 -pady 4 -sticky new
            
            grid $getsdlg.top.entry \
                -row 1 -column 1 -padx 8 -pady 4 -stick ew

            grid $getsdlg.top.error \
                -row 2 -column 1 -padx 8 -pady 4 -sticky new

            # Button box
            ttk::frame $getsdlg.button

            # Create the buttons
            ttk::button $getsdlg.button.cancel     \
                -text    "Cancel"                  \
                -command [mytypemethod GetsCancel]

            ttk::button $getsdlg.button.ok     \
                -text    $opts(-oktext)        \
                -command [mytypemethod GetsOK]
            
            pack $getsdlg.button.ok     -side right -padx 4
            pack $getsdlg.button.cancel -side right -padx 4


            # Pack the top-level components.
            pack $getsdlg.top    -side top    -fill x
            pack $getsdlg.button -side bottom -fill x
        }

        # NEXT, configure the dialog according to the options
        
        # Set the title
        wm title $getsdlg $opts(-title)

        # Set the icon
        if {$opts(-icon) eq "peabody"} {
            set icon ::marsgui::icon::peabody32
        } else {
            set icon ${type}::icon::$opts(-icon)
        }

        $getsdlg.top.icon configure -image $icon

        # Make it transient over the -parent
        osgui mktoolwindow $getsdlg $opts(-parent)

        # NEXT, clear the error message and the entered text, and
        # apply the initvalue.
        set errorText ""
        $getsdlg.top.entry delete 0 end
        $getsdlg.top.entry insert 0 $opts(-initvalue)
        $getsdlg.top.entry selection range 0 end

        # NEXT, raise the dialog and set the focus
        wm deiconify $getsdlg
        wm attributes $getsdlg -topmost
        raise $getsdlg
        focus $getsdlg.top.entry

        # NEXT, do the grab, and wait until they return.
        set choice {}

        grab set $getsdlg
        vwait [mytypevar choice]
        grab release $getsdlg
        wm withdraw $getsdlg

        return $choice
    }

    # ParseGetsOptions arglist
    #
    # arglist     List of popup args
    #
    # Parses the options into the opts array

    typemethod ParseGetsOptions {arglist} {
        # FIRST, set the option defaults
        array set opts {
            -oktext        "OK"
            -icon          question
            -message       {}
            -parent        {}
            -title         {}
            -initvalue     {}
            -validatecmd   {}
        }

        # NEXT, get the option values
        while {[llength $arglist] > 0} {
            set opt [::marsutil::lshift arglist]

            switch -exact -- $opt {
                -oktext        -
                -icon          -
                -message       -
                -parent        -
                -title         -
                -initvalue     -
                -validatecmd   {
                    set opts($opt) [::marsutil::lshift arglist]
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, validate -icon
        if {$opts(-icon) ni $iconnames && $opts(-icon) ne "peabody"} {
            error "-icon: should be one of [join $iconnames {, }]"
        }

        if {$opts(-parent) ne ""} {
            snit::window validate $opts(-parent)
        } else {
            error "-parent: not specified"
        }
    }

    # GetsCancel
    #
    # Returns the empty string.

    typemethod GetsCancel {} {
        set choice ""
    }

    # GetsOK
    #
    # Validates the string, and returns it.
    
    typemethod GetsOK {} {
        set string [string trim [$getsdlg.top.entry get]]

        if {$opts(-validatecmd) ne ""} {
            if {[catch {{*}$opts(-validatecmd) $string} result eopts]} {
                set ecode [dict get $eopts -errorcode]

                if {$ecode ne "INVALID"} {
                    return {*}$eopts $result
                }

                set errorText $result
                return
            }

            # Allow the validation command to canonicalize the
            # string.
            set string $result
        }

        # Save the string for next time.
        set choice $string
    }

    #-------------------------------------------------------------------
    # pick

    # pick option value....
    #
    # -oktext text           Text for the OK button.
    # -icon image            error, info, question, warning, peabody
    # -message string        Message to display.  Will be wrapped.
    # -parent window         The message box appears over the parent window
    # -title string          Title of the message box
    # -initvalue string      Initial value for the menubox field
    # -values list           List of values to display
    #
    # Pops up the "pick item" message box.  The buttons will appear at 
    # the bottom, left to right, packed to the right.  The OK button will
    # have the specified text; it defaults to "OK".  The
    # -icon will be displayed; defaults to "question".  The -message will be 
    # wrapped into the message space; the entry widget will be below
    # the -message. The dialog will be application modal,
    # and centered over the specified -parent window.  It will have the
    # specified -title string.  If -initvalue is non-empty, its value
    # will be placed in the menubox widget; the menubox will pick 
    # from the -values.
    #
    # The command will wait until the user presses a button.  On 
    # "cancel", it will return "".  On OK, it will return the 
    # item selected in the menubox.

    typemethod pick {args} {
        # FIRST, get the option values
        $type ParsePickOptions $args

        # NEXT, create the dialog if it doesn't already exist.
        if {![winfo exists $pickdlg]} {
            # FIRST, create it
            toplevel $pickdlg         \
                -borderwidth        4 \
                -highlightthickness 0

            # NEXT, withdraw it; we don't want to see it yet
            wm withdraw $pickdlg

            # NEXT, the user can't resize it
            wm resizable $pickdlg 0 0

            # NEXT, it can't be closed
            wm protocol $pickdlg WM_DELETE_WINDOW \
                [mytypemethod PickCancel]

            # NEXT, it must be on top
            wm attributes $pickdlg -topmost 1

            # NEXT, create and grid the standard widgets
            
            # Row 1: Icon and message
            ttk::frame $pickdlg.top

            ttk::label $pickdlg.top.icon \
                -image  ${type}::icon::question \
                -anchor nw

            ttk::label $pickdlg.top.message \
                -textvariable [mytypevar opts(-message)] \
                -wraplength   3i                         \
                -anchor       nw                         \
                -justify      left

            # Row 2: Entry Widget
            menubox $pickdlg.top.menubox

            grid $pickdlg.top.icon \
                -row 0 -column 0 -padx 8 -pady 4 -sticky nw 

            grid $pickdlg.top.message \
                -row 0 -column 1 -padx 8 -pady 4 -sticky new
            
            grid $pickdlg.top.menubox \
                -row 1 -column 1 -padx 8 -pady 4 -stick ew

            # Button box
            ttk::frame $pickdlg.button

            # Create the buttons
            ttk::button $pickdlg.button.cancel     \
                -text    "Cancel"                  \
                -command [mytypemethod PickCancel]

            ttk::button $pickdlg.button.ok     \
                -text    $opts(-oktext)        \
                -command [mytypemethod PickOK]
            
            pack $pickdlg.button.ok     -side right -padx 4
            pack $pickdlg.button.cancel -side right -padx 4

            # Pack the top-level components.
            pack $pickdlg.top    -side top    -fill x
            pack $pickdlg.button -side bottom -fill x
        }

        # NEXT, configure the dialog according to the options
        
        # Set the title
        wm title $pickdlg $opts(-title)

        # Set the icon
        if {$opts(-icon) eq "peabody"} {
            set icon ::marsgui::icon::peabody32
        } else {
            set icon ${type}::icon::$opts(-icon)
        }

        $pickdlg.top.icon configure -image $icon

        # Make it transient over the -parent
        osgui mktoolwindow $pickdlg $opts(-parent)

        # NEXT, set the menubox values and initvalue.

        $pickdlg.top.menubox configure -values $opts(-values)
        $pickdlg.top.menubox set $opts(-initvalue)

        # NEXT, raise the dialog and set the focus
        wm deiconify $pickdlg
        wm attributes $pickdlg -topmost
        raise $pickdlg
        focus $pickdlg.top.menubox

        # NEXT, do the grab, and wait until they return.
        set choice {}

        grab set $pickdlg
        vwait [mytypevar choice]
        grab release $pickdlg
        wm withdraw $pickdlg

        return $choice
    }

    # ParsePickOptions arglist
    #
    # arglist     List of popup args
    #
    # Parses the options into the opts array

    typemethod ParsePickOptions {arglist} {
        # FIRST, set the option defaults
        array set opts {
            -oktext        "OK"
            -icon          question
            -message       {}
            -parent        {}
            -title         {}
            -initvalue     {}
            -values        {}
        }

        # NEXT, get the option values
        while {[llength $arglist] > 0} {
            set opt [::marsutil::lshift arglist]

            switch -exact -- $opt {
                -oktext        -
                -icon          -
                -message       -
                -parent        -
                -title         -
                -initvalue     -
                -values        {
                    set opts($opt) [::marsutil::lshift arglist]
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, validate -icon
        if {$opts(-icon) ni $iconnames && $opts(-icon) ne "peabody"} {
            error "-icon: should be one of [join $iconnames {, }]"
        }

        # NEXT, validate -parent
        if {$opts(-parent) ne ""} {
            snit::window validate $opts(-parent)
        }
    }

    # PickCancel
    #
    # Returns the empty string.

    typemethod PickCancel {} {
        set choice ""
    }

    # PickOK
    #
    # Returns the selected string.
    
    typemethod PickOK {} {
        set choice [$pickdlg.top.menubox get]
    }

    #-------------------------------------------------------------------
    # listselect

    # listselect option value....
    #
    # -oktext text           Text for the OK button.
    # -icon image            error, info, question, warning, peabody
    # -message string        Message to display.  Will be wrapped.
    # -parent window         The message box appears over the parent window
    # -title string          Title of the message box
    # -initvalue string      Initial value for the listfield
    # -itemdict              Dict of keys and values from which the
    #                        user can select.
    # -showkeys flag         If 0, shows -itemdict values only; if 1,
    #                        shows "key: value"
    # -stripe flag           Should even rows be striped?
    # -listrows rows         Height of the include/omit lists, in rows.
    # -listwidth chars       Width of the include/omit lists, in characters.
    #
    # Pops up the "list select" message box.  The buttons will appear at 
    # the bottom, left to right, packed to the right.  The OK button will
    # have the specified text; it defaults to "OK".  The
    # -icon will be displayed; defaults to "question".  The -message will be 
    # wrapped into the message space; the listfield widget will be below
    # the -message. The dialog will be application modal,
    # and centered over the specified -parent window.  It will have the
    # specified -title string.  If -initvalue is non-empty, its value
    # will be placed in the listfield; the listfield will select
    # from the -values.
    #
    # The command will wait until the user presses a button.  On 
    # "cancel", it will return "".  On OK, it will return the 
    # item selected in the menubox.

    typemethod listselect {args} {
        # FIRST, get the option values
        $type ParseListOptions $args

        # NEXT, create the dialog if it doesn't already exist.
        if {![winfo exists $listdlg]} {
            # FIRST, create it
            toplevel $listdlg         \
                -borderwidth        4 \
                -highlightthickness 0

            # NEXT, withdraw it; we don't want to see it yet
            wm withdraw $listdlg

            # NEXT, the user can't resize it
            wm resizable $listdlg 0 0

            # NEXT, it can't be closed
            wm protocol $listdlg WM_DELETE_WINDOW \
                [mytypemethod ListCancel]

            # NEXT, it must be on top
            wm attributes $listdlg -topmost 1

            # NEXT, create and grid the standard widgets
            
            # Row 1: Icon and message
            ttk::frame $listdlg.top

            ttk::label $listdlg.top.icon \
                -image  ${type}::icon::question \
                -anchor nw

            ttk::label $listdlg.top.message \
                -textvariable [mytypevar opts(-message)] \
                -wraplength   5i                         \
                -anchor       nw                         \
                -justify      left

            # Row 2: Entry Widget
            listfield $listdlg.top.listfield                

            grid $listdlg.top.icon \
                -row 0 -column 0 -padx 8 -pady 4 -sticky nw 

            grid $listdlg.top.message \
                -row 0 -column 1 -padx 8 -pady 4 -sticky new
            
            grid $listdlg.top.listfield \
                -row 1 -column 1 -padx 8 -pady 4 -stick ew

            # Button box
            ttk::frame $listdlg.button

            # Create the buttons
            ttk::button $listdlg.button.cancel     \
                -text    "Cancel"                  \
                -command [mytypemethod ListCancel]

            ttk::button $listdlg.button.ok     \
                -text    $opts(-oktext)        \
                -command [mytypemethod ListOK]
            
            pack $listdlg.button.ok     -side right -padx 4
            pack $listdlg.button.cancel -side right -padx 4

            # Pack the top-level components.
            pack $listdlg.top    -side top    -fill x
            pack $listdlg.button -side bottom -fill x
        }

        # NEXT, configure the dialog according to the options
        
        # Set the title
        wm title $listdlg $opts(-title)

        # Set the icon
        if {$opts(-icon) eq "peabody"} {
            set icon ::marsgui::icon::peabody32
        } else {
            set icon ${type}::icon::$opts(-icon)
        }

        $listdlg.top.icon configure -image $icon

        # Make it transient over the -parent
        osgui mktoolwindow $listdlg $opts(-parent)

        # NEXT, configure the listfield and set its value
        $listdlg.top.listfield configure \
            -height   $opts(-listrows)   \
            -width    $opts(-listwidth)  \
            -itemdict $opts(-itemdict)   \
            -showkeys $opts(-showkeys)   \
            -stripe   $opts(-stripe)

        $listdlg.top.listfield set $opts(-initvalue)

        # NEXT, raise the dialog and set the focus
        wm deiconify $listdlg
        wm attributes $listdlg -topmost
        raise $listdlg
        focus $listdlg.top.listfield

        # NEXT, do the grab, and wait until they return.
        set choice {}

        grab set $listdlg
        vwait [mytypevar choice]
        grab release $listdlg
        wm withdraw $listdlg

        return $choice
    }

    # ParseListOptions arglist
    #
    # arglist     List of popup args
    #
    # Parses the options into the opts array

    typemethod ParseListOptions {arglist} {
        # FIRST, set the option defaults
        array set opts {
            -oktext        "OK"
            -icon          question
            -message       {}
            -parent        {}
            -title         {}
            -initvalue     {}
            -itemdict      {}
            -showkeys      0
            -stripe        0
            -listrows      12
            -listwidth     30
        }

        # NEXT, get the option values
        while {[llength $arglist] > 0} {
            set opt [::marsutil::lshift arglist]

            if {![info exists opts($opt)]} {
                error "Unknown option: \"$opt\""
            }

            set opts($opt) [::marsutil::lshift arglist]
        }

        # NEXT, validate -icon
        if {$opts(-icon) ni $iconnames && $opts(-icon) ne "peabody"} {
            error "-icon: should be one of [join $iconnames {, }]"
        }

        # NEXT, validate -parent
        if {$opts(-parent) ne ""} {
            snit::window validate $opts(-parent)
        }
    }

    # ListCancel
    #
    # Returns the empty string.

    typemethod ListCancel {} {
        set choice [list cancel]
    }

    # ListOK
    #
    # Returns the selected string.
    
    typemethod ListOK {} {
        set choice [list ok [$listdlg.top.listfield get]]
    }
}


