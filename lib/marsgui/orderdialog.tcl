#-----------------------------------------------------------------------
# FILE: orderdialog.tcl
#
#   Mars Order Dialog Manager
#
# PACKAGE:
#   marsgui(n): Mars GUI Infrastructure Package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-------------------------------------------------------------------

namespace eval ::marsgui:: {
    namespace export orderdialog
}

#-----------------------------------------------------------------------
# Widget: orderdialog
#
# The orderdialog(n) widget creates order dialogs for orders defined
# using order(n).  In addition, this module is responsible for 
# creating and managing orderdialog(n) widgets on demand.
#
# This module sends the <OrderEntry> event to indicate what kind of
# parameter is currently being entered.  Because orderdialog(n) is a
# GUI submodule of order(n), it will use the same notifier(n) subject
# as order(n).
#
#-----------------------------------------------------------------------

snit::widget ::marsgui::orderdialog {
    typeconstructor {
        namespace import ::marsutil::*
    }

    #===================================================================
    # Dialog Management
    #
    # This section contains code that manages the collection of dialogs.
    # The actual dialog code appears below.

    #-------------------------------------------------------------------
    # Type Components

    typecomponent rdb    ;# The order(n) -rdb.


    #-------------------------------------------------------------------
    # Type Variables

    # Scalars, etc.
    #
    # initialized      - 1 if initialized, 0 otherwise.
    # appname          - Application name, for use in dialog titles
    # helpcmd          - Help command, for order help
    # parent           - Parent window for dialogs, or command for 
    #                    determining what the parent window is.
    # refreshon        - List of notifier(n) subjects and events that
    #                    trigger a dialog refresh.
    # ftrans           - field option translator commands, by field type.
    # wincounter       - Counter for creating widget names.
    # win-$order       - The dialog's widget name.  We reuse the same name
    #                  - over and over.
    # position-$order  - The dialog's saved geometry (i.e., screen position)

    typevariable info -array {
        initialized   0
        appname       "<set -appname>"
        helpcmd       ""
        parent        ""
        refreshon     {}
        ftrans        {}
        wincounter    0
    }

    #-------------------------------------------------------------------
    # Initialization

    # init ?options?
    #
    # Initializes the order GUI.

    typemethod init {args} {
        # FIRST, we can only initialize once.
        if {$info(initialized)} {
            return
        }

        # NEXT, order(n) must have been initialized.
        require {[order initialized]} "order(n) has not been initialized"

        # NEXT, get the option values
        if {[llength $args] > 0} {
            $type configure {*}$args
        }

        require {$info(parent) ne ""} "-parent is unset"

        # NEXT, create the necessary fonts.
        # TBD: This probably shouldn't go here, but it needs to go 
        # somewhere.
        font create OrderTitleFont {*}[font actual TkDefaultFont] \
            -weight bold                                          \
            -size   -16

        # NEXT, create the initial order dialog names
        foreach order [order names] {
            $type InitOrderData $order
        }

        # NEXT, get the rdb
        set rdb [order cget -rdb]

        # NEXT, note that we're initialized
        set info(initialized) 1
    }

    # InitOrderData order
    #
    # order     Name of an order
    #
    # Initializes the window name, etc.

    typemethod InitOrderData {order} {
        set info(win-$order)      .order[format %04d [incr info(wincounter)]]
        set info(position-$order) {}
    }

    # cget ?option?
    #
    # option  - An option name
    #
    # If option is given, returns the option value.  Otherwise,
    # returns a dictionary of the module configuration options and
    # their values.

    typemethod cget {{option ""}} {
        # FIRST, query an option.
        if {$option ne ""} {
            switch -exact -- $option {
                -appname   { return $info(appname)               }
                -helpcmd   { return $info(helpcmd)               }
                -parent    { return $info(parent)                }
                -refreshon { return $info(refreshon)             }
                default    { error "Unknown option: \"$option\"" }
            }
        } else {
            return [dict create \
                        -appname   $info(appname)    \
                        -helpcmd   $info(helpcmd)    \
                        -parent    $info(parent)     \
                        -refreshon $info(refreshon)]
        }
    }

    # configure ?option value...?
    #
    # option  - An option name
    # value   - An option value
    #
    # Sets the values of one or more module options.

    typemethod configure {args} {
        while {[llength $args] > 0} {
            set option [lshift args]

            if {[llength $args] == 0} {
                error "Option $option: no value given"
            }

            switch -exact -- $option {
                -appname   { set info(appname)   [lshift args]   }
                -helpcmd   { set info(helpcmd)   [lshift args]   }
                -parent    { set info(parent)    [lshift args]   }
                -refreshon { set info(refreshon) [lshift args]   }
                default    { error "Unknown option: \"$option\"" }
            }
        }

        return
    }

    #-------------------------------------------------------------------
    # Order Entry

    # enter name ?parmdict?
    # enter name ?parm value...?
    #
    # name       - The name of the order
    # parmdict   - A (partial) dictionary of initial parameter values
    # parm,value - A (partial) dictionary of initial parm values specified
    #              as individual arguments.
    #
    # Begins entry of the specified order:
    #
    # * If the order is not active, the dialog is created with the
    #   initial parmdict, and popped up.
    #
    # * If the order is active, it is given the initial parmdict, and
    #   then receives focus and raised to the top.

    typemethod enter {name args} {
        require {$info(initialized)}    "$type is uninitialized."
        require {[order exists $name]} "Undefined order: \"$name\""
        require {[llength [order parms $name]] != 0} \
            "Can't enter order dialog, no parameters: \"$name\""

        # FIRST, get the initial parmdict.
        if {[llength $args] > 1} {
            set parmdict $args
        } else {
            set parmdict [lindex $args 0]
        }

        # NEXT, if this is a new order, initialize its data.
        if {![info exists info(win-$name)]} {
            $type InitOrderData $name
        }

        # NEXT, if it doesn't exist, create it.
        #
        # NOTE: If at some point we need special dialogs for some
        # orders, we can add a query to order metadata here.

        if {![$type isactive $name]} {
            # FIRST, Create the dialog for the specified order
            orderdialog $info(win-$name) \
                -order $name
        }

        # NEXT, give the parms and the focus
        $info(win-$name) EnterDialog $parmdict
    }

    # puck tagdict
    #
    # tagdict - A dictionary of tags and values
    #
    # Specifies a dictionary of tags and values that indicate an
    # object or objects selected by the application.  The first
    # tagged value whose tag matches a tag on the current field
    # of the topmost order dialog (if any) will be inserted into
    # that field.

    typemethod puck {tagdict} {
        # FIRST, is there an active dialog?
        set dlg [$type TopDialog]

        if {$dlg eq ""} {
            return
        }

        $dlg ObjectSelect $tagdict
    }

    #-------------------------------------------------------------------
    # Queries

    # isactive order
    #
    # order    Name of an order
    #
    # Returns true if the order's dialog is active, and false otherwise.

    typemethod isactive {order} {
        return [winfo exists $info(win-$order)]
    }

    #-------------------------------------------------------------------
    # Helper Typemethods

    # Notify event args...
    #
    # event     - A notifier(n) event
    # args...   - The event arguments
    #
    # Sends the notifier event from the same subject as the
    # the order(n) module.

    typemethod Notify {event args} {
        notifier send [order cget -subject] $event {*}$args
    }

    # Parent
    #
    # Returns the parent window for the order dialogs.
    
    typemethod Parent {} {
        if {[string match ".*" $info(parent)]} {
            return $info(parent)
        } else {
            return [callwith $info(parent)]
        }
    }


    #===================================================================
    # Dialog Widget
    #
    # Each order has a widget of this type.

    hulltype toplevel

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    # -order order
    #
    # The name of the order for this dialog.

    option -order     \
        -readonly yes

    #-------------------------------------------------------------------
    # Components

    component form       ;# The form(n) widget
    component raiser     ;# A timeout(n) object.

    #-------------------------------------------------------------------
    # Instance Variables

    # my array -- scalars and field data
    #
    # parms             Names of all parms.
    # context           Names of all context parms
    # valid             1 if current values are valid, and 0 otherwise.

    variable my -array {
        parms      {}
        context    {}
        valid      0
    }

    # ferrors -- Array of field errors by parm name
    
    variable ferrors -array { }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        # NEXT, withdraw the hull; we will deiconify at the end of the
        # constructor.
        wm withdraw $win
        
        # NEXT, set up the window manager details

        # Title
        wm title $win "$info(appname): Send Order"
        
        # User can't resize it
        wm resizable $win 0 0

        # Control closing the window
        wm protocol $win WM_DELETE_WINDOW [mymethod Close]

        # NEXT, create the title bar
        ttk::frame $win.tbar \
            -borderwidth 0   \
            -relief      flat

        # NEXT, create the title widget
        ttk::label $win.tbar.title                        \
            -font          OrderTitleFont                 \
            -text          [order title $options(-order)] \
            -padding       4

        # NEXT, create the help button
        ttk::button $win.tbar.help               \
            -style   Toolbutton                  \
            -image   ::marsgui::icon::question22 \
            -state   normal                      \
            -command [mymethod Help]

        DynamicHelp::add $win.tbar.help -text "Get help!"

        pack $win.tbar.title -side left

        if {$info(helpcmd) ne ""} {
            pack $win.tbar.help  -side right
        }

        # NEXT, create the dynaview.
        install form using dynaview $win.form    \
            -formtype    $options(-order)        \
            -borderwidth 1                       \
            -relief      raised                  \
            -padding     2                       \
            -currentcmd  [mymethod CurrentField] \
            -changecmd   [mymethod FormChange] 

        # NEXT, set up the metadata.
        set my(parms)      [order parms $options(-order)]
        set my(context)    [dynaform context $options(-order)]
        set my(valid)      0

        # NEXT, create the message display
        rotext $win.message                                \
            -takefocus          0                          \
            -font               TkDefaultFont              \
            -width              40                         \
            -height             3                          \
            -wrap               word                       \
            -relief             flat                       \
            -background         [$win cget -background]    \
            -highlightthickness 0

        # NEXT, create the frame to hold the buttons
        ttk::frame $win.buttons \
            -borderwidth 0      \
            -relief      flat

        ttk::button $win.buttons.clear        \
            -text    "Clear"                  \
            -width   6                        \
            -command [mymethod Clear]

        ttk::button $win.buttons.send         \
            -text    "Send"                   \
            -width   6                        \
            -command [mymethod Send]

        ttk::button $win.buttons.sendclose    \
            -text    "Send & Close"           \
            -width   12                       \
            -command [mymethod SendClose]

        pack $win.buttons.clear     -side left  -padx {2 15}
        pack $win.buttons.sendclose -side right -padx 2
        pack $win.buttons.send      -side right -padx 2

        # NEXT, pack components
        pack $win.tbar    -side top -fill x
        pack $win.form    -side top -fill x -padx 4 -pady 4
        pack $win.message -side top -fill x -padx 4
        pack $win.buttons -side top -fill x -pady 4

        # NEXT, make the window visible, and transient over the
        # current top window.
        osgui mktoolwindow  $win [$type Parent]
        wm deiconify  $win
        raise $win
        
        # NEXT, if there's saved position, give the dialog the
        # position.
        if {$info(position-$options(-order)) ne ""} {
            wm geometry \
                $info(win-$options(-order)) \
                $info(position-$options(-order))
        }

        # NEXT, refresh the dialog on events from order(n).
        notifier bind \
            [order cget -subject] <State>    $win [mymethod RefreshDialog]
        notifier bind \
            [order cget -subject] <Accepted> $win [mymethod RefreshDialog]

        # NEXT, prepare to refresh the dialog on particular events from
        # the application.
        foreach {subject event} $info(refreshon) {
            notifier bind $subject $event $win [mymethod RefreshDialog]
        }

        # NEXT, raise the widget if it's obscured by its parent.
        install raiser using timeout ${selfns}::raiser \
            -interval   500 \
            -repetition yes \
            -command    [mymethod KeepVisible]
        $raiser schedule

        # NEXT, wait for visibility.
        update idletasks
    }

    destructor {
        notifier forget $win
    }

    #-------------------------------------------------------------------
    # Event Handlers: Visibility

    # KeepVisible 
    #
    # If the dialog is fully obscured, this raises it above its parent.

    method KeepVisible {} {
        if {[wm stackorder $win isbelow [$type Parent]]} {
            raise $win
        }
    }

    #-------------------------------------------------------------------
    # Event Handlers: Entering the Dialog

    # EnterDialog parmdict
    #
    # parmdict     A dictionary of initial parameter values.
    #
    # Gives the window the focus, and populates it with the initial data.
    # This is used by "orderdialog enter".

    method EnterDialog {parmdict} {
        # FIRST, make the window visible
        raise $win

        # NEXT, verify that all context parameters are included.
        set missing [list]
        foreach cparm $my(context) {
            if {![dict exists $parmdict $cparm]} {
                lappend missing $cparm
            }
        }

        if {[llength $missing] > 0} {
            set msg "Cannot enter $options(-order) dialog, context parm(s) missing: [join $missing {, }]"
            $self Close
            return -code error $msg
        }

        # NEXT, fill in the data
        $self Clear

        if {[dict size $parmdict] > 0} {
            $form set $parmdict

            # NEXT, focus on the first editable field
            $self SetFocus
        }
    }

    # SetFocus
    #
    # Sets the focus to the first editable field.

    method SetFocus {} {
        # TBD: Set the focus to the first editable, non-disabled
        # field.

        # TBD: Is this needed?
    }

    #-------------------------------------------------------------------
    # Event Handlers: Form Change

    # FormChange fields
    #
    # fields   A list of one or more field names
    #
    # The data in the form has changed.  Validate the order, and set
    # the button state.

    method FormChange {fields} {
        # FIRST, validate the order.
        $self CheckValidity

        # NEXT, set the button state
        $self SetButtonState
    }

    #-------------------------------------------------------------------
    # Event Handlers: Object Selection

    # ObjectSelect tagdict
    #
    # tagdict   A dictionary of tags and values
    #
    # A dictionary of tags and values that indicates the object or 
    # objects that were selected.  The first one that matches the current
    # field, if any, will be inserted into it.

    method ObjectSelect {tagdict} {
        # FIRST, Get the current field.  If there is none,
        # we're done.
        set current [$self GetCurrentField]

        if {$current eq ""} {
            return
        }

        # NEXT, get the tags for the current field.  If there are none,
        # we're done.

        set tags [order tags $options(-order) $current]

        if {[llength $tags] == 0} {
            return
        }

        # NEXT, get the new value, if any.  If none, we're done.
        set newValue ""

        foreach {tag value} $tagdict {
            if {$tag in $tags} {
                set newValue $value
                break
            }
        }

        if {$newValue eq ""} {
            return
        }

        # NEXT, save the value
        $form set $current $newValue
    }

    # TopDialog
    #
    # Returns the name of the topmost order dialog

    typemethod TopDialog {} {
        foreach w [lreverse [wm stackorder .]] {
            if {[winfo class $w] eq "Orderdialog"} {
                return $w
            }
        }

        return ""
    }

    #-------------------------------------------------------------------
    # Event Handlers: Dialog Refresh

    # RefreshDialog ?args...?
    #
    # args      Ignored optional arguments.
    #
    # At times, it's necessary to refresh the entire dialog:
    # at initialization, on clear, etc.
    #
    # Any arguments are ignored; this allows a refresh to be
    # triggered by any notifier(n) event.

    method RefreshDialog {args} {
        $form refresh
        $self CheckValidity
        $self SetButtonState
    }

    #-------------------------------------------------------------------
    # Order Validation

    # CheckValidity
    #
    # Checks the current parameters; on error, reveals the error.

    method CheckValidity {} {
        # FIRST, clear the error messages.
        array unset ferrors
        $form invalid {}

        # NEXT, check the order, and handle any errors
        if {[catch {
            order check $options(-order) [$form get]
        } result opts]} {
            # FIRST, if it's unexpected let the app handle it.
            if {[dict get $opts -errorcode] ne "REJECT"} {
                return {*}$opts $result
            }

            # NEXT, save the error text
            array set ferrors $result

            # NEXT, mark the bad parms.
            dict unset result *

            $form invalid [dict keys $result]

            # NEXT, show the current error message
            set current [$self GetCurrentField]

            if {$current ne "" && [info exists ferrors($current)]} {
                $self ShowParmError $current $ferrors($current)
            } elseif {[dict exists $result *]} {
                $self Message "Error in order: [dict get $result *]"
            } else {
                $self Message \
                 "Error in order; click in marked fields for error messages."
            }

            set my(valid) 0
        } else {
            set my(valid) 1
            $self Message ""
        }
    }


    #-------------------------------------------------------------------
    # Event Handlers: Buttons

    # Clear
    #
    # Clears all parameter values

    method Clear {} {
        # FIRST, clear the dialog
        $form clear

        # NEXT, refresh all of the fields.
        $self RefreshDialog

        # NEXT, set the focus to first editable field
        $self SetFocus

        # NEXT, notify the app that the dialog has been cleared; this
        # will allow it to clear up any entry artifacts.
        $type Notify <OrderEntry> {}
    }

    # Close
    #
    # Closes the dialog

    method Close {} {
        # FIRST, save the dialog's position
        set geo [wm geometry $win]
        set ndx [string first "+" $geo]
        set info(position-$options(-order)) [string range $geo $ndx end]

        # NEXT, notify the app that no order entry is being done.
        $type Notify <OrderEntry> {}

        # NEXT, destroy the dialog
        destroy $win
    }

    # Help
    #
    # Brings up the on-line help for the application
    
    method Help {} {
        callwith $info(helpcmd) $options(-order)
    }

    # Send
    #
    # Sends the order; on error, reveals the error.

    method Send {} {
        # FIRST, clear the error text from the previous order.
        array unset ferrors
        $form invalid {}

        # NEXT, send the order, and handle any errors
        if {[catch {
            order send gui $options(-order) [$form get]
        } result opts]} {
            # FIRST, if it's unexpected let the app handle it.
            if {[dict get $opts -errorcode] ne "REJECT"} {
                return {*}$opts $result
            }

            # NEXT, save the error text
            array set ferrors $result

            # NEXT, mark the bad parms.
            dict unset result *

            $form invalid [dict keys $result]

            # NEXT, if it's not shown, show the message box
            if {[dict exists $result *]} {
                $self Message "Error in order: [dict get $result *]"
            } else {
                $self Message \
                 "Error in order; click in marked fields for error messages."
            }

            return 0
        }

        # NEXT, either output the result, or just say that the order
        # was accepted.
        if {$result ne ""} {
            $self Message $result
        } else {
            $self Message "The order was accepted."
        }

        # NEXT, notify the app that no order entry is being done; this
        # will allow it to clear up any entry artifacts.
        $type Notify <OrderEntry> {}

        # NEXT, the order was accepted; we're done here.
        return 1
    }

    # SendClose
    #
    # Sends the order and closes the dialog on success.

    method SendClose {} {
        if {[$self Send]} {
            $self Close
        }
    }

    #-------------------------------------------------------------------
    # Event Handlers: Other

    # CurrentField parm
    #
    # parm    The parameter name
    #
    # Updates the display when the user is on a particular field.

    method CurrentField {parm} {
        # FIRST, if there's an error message, display it.
        if {[info exists ferrors($parm)]} {
            $self ShowParmError $parm $ferrors($parm)
        } else {
            $self Message ""
        }

        # NEXT, tell the app what kind of parameter this is.
        set tags [order tags $options(-order) $parm]

        if {[llength $tags] == 0} {
            set tags null
        }

        $type Notify <OrderEntry> $tags
    }

    # SetButtonState
    #
    # Enables/disables the send button based on 
    # whether there are unsaved changes, and whether the data is valid,
    # and so forth.

    method SetButtonState {} {
        # FIRST, the order can be sent if the field values are
        # valid, and if either we aren't checking order states or
        # the order is valid in this state.
        if {$my(valid) &&
            (![order interface cget gui -checkstate] ||
             [order cansend $options(-order)])
        } {
            $win.buttons.send      configure -state normal
            $win.buttons.sendclose configure -state normal
        } else {
            $win.buttons.send      configure -state disabled
            $win.buttons.sendclose configure -state disabled
        }
    }

    #-------------------------------------------------------------------
    # Utility Methods


    # GetCurrentField
    #
    # Gets the name of the currently active field, or the first
    # editable field otherwise.

    method GetCurrentField {} {
        return [$form current]
    }

    # Message text
    #
    # Opens the message widget, and displays the text.

    method Message {text} {
        # FIRST, normalize the whitespace
        set text [string trim $text]
        set text [regsub {\s+} $text " "]

        # NEXT, display the text.
        $win.message del 1.0 end
        $win.message ins 1.0 $text
        $win.message see 1.0
    }

    # ShowParmError parm message
    #
    # parm    - The parameter name
    # message - The error message string
    #
    # Shows the error message on the message line.
    #
    # TBD: The method used to get the dynaform field's label 
    # is kind of fragile.  Perhaps some other way of linking
    # the field with the message could be used?  I.e., an
    # asterisk on the current field, if the current field is in
    # error?

    method ShowParmError {parm message} {
        set label [$form getlabel $parm]

        if {$label ne ""} {
            $self Message "$label: $message"
        } else {
            $self Message $message
        }
    }

    #-------------------------------------------------------------------
    # Public methods

    delegate method get to form
    delegate method set to form

    #-------------------------------------------------------------------
    # Refresh Callbacks

    # keyload key fields idict value
    #
    # key     - Name of a key field.  For tables with complex keys, use a
    #           view that concatenates the key columns into one column.
    # fields  - Fields whose values should be loaded given the key field.
    #           If "*", all fields are loaded.  Defaults to "*".
    # idict   - The field item's definition dictionary.
    # value   - The current value of the key field.
    #
    # For use as a dynaform field -loadcmd with key fields.
    #
    # Loads the table row from the database specified in the idict given 
    # the other parameters, and returns it as a dictionary.  If "fields"
    # is not *, only the listed field names will be returned.

    typemethod keyload {key fields idict value} {
        # FIRST, get the metadata.
        set ftype  [dict get $idict ftype]
        set db     [dict get $idict db]
        set table  [dict get $idict table]

        # NEXT, get the list of fields
        if {$fields eq "*"} {
            set fields [dynaform fields $ftype]
        }

        # NEXT, retrieve the record.
        $rdb eval "
            SELECT [join $fields ,] FROM $table
            WHERE $key=\$value
        " row {
            unset row(*)

            return [array get row]
        }

        return ""
    }

    # multiload multi fields idict keyvals
    #
    # multi   - Name of the multi field itself
    # fields  - Fields whose values should be loaded given the multi field.
    #           If "*", all fields are loaded.  Defaults to "*".
    # idict   - The field item's definition dictionary.
    # keyvals - The current value of the multi field.
    #
    # For use as a dynaform field -loadcmd with multi fields.
    #
    # Reads the named fields from the multi's table given the multi's
    # current list of values.  Builds a dictionary of values common
    # to all records, and clears the others.

    typemethod multiload {multi fields idict keyvals} {
        # FIRST, get the field metadata.
        set ftype   [dict get $idict ftype]
        set db      [dict get $idict db]
        set table   [dict get $idict table] 
        set keycol  [dict get $idict key]

        # NEXT, if the list of key values is empty, clear the values;
        # we're done.
        if {[llength $keyvals] == 0} {
            # TBD: Should clear the set of values, probably.
            return
        }
        
        # NEXT, get the list of fields
        if {$fields eq "*"} {
            set fields [dynaform fields $ftype]
            ldelete fields $multi
        }

        # NEXT, retrieve the first entity's data.
        set key [lshift keyvals]

        set query "
            SELECT [join $fields ,] FROM $table WHERE $keycol=\$key
        "

        $rdb eval $query prev {}
        unset prev(*)

        # NEXT, retrieve the remaining entities, looking for
        # mismatches
        foreach key $keyvals {
            $rdb eval $query current {}

            foreach field $fields {
                if {$prev($field) ne $current($field)} {
                    set prev($field) ""
                }
            }
        }

        # NEXT, return the loaded values.
        return [array get prev]
    }
}


