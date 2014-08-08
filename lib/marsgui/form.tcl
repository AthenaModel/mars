#-----------------------------------------------------------------------
# FILE: form.tcl
#
#   form(n) -- Order Dialog Form
#
# PACKAGE:
#   marsgui(n) -- Mars Forms Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

namespace eval ::marsgui:: {
    namespace export form
}

#-----------------------------------------------------------------------
# Widget: form
#
# This is a prototype widget to layout parameter entry fields for
# use in order dialogs.
#-----------------------------------------------------------------------

snit::widget ::marsgui::form {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Group: Type Variables

    # Type Variable: colors
    #
    # Array of colors used by the form widget

    typevariable colors -array {
        valid    black
        context  black
        invalid  #CC0000
        disabled gray55
    }
    

    # Type Variable: ftypes
    #
    # An array of field type definitions.  The key is the type name,
    # e.g., "text" or "enum".  The value is a list of two items:
    # the actual widget type, and a (possibly empty) list of default
    # option values.

    typevariable ftypes -array {}

    #-------------------------------------------------------------------
    # Group: Type Methods

    # Type Method: register
    #
    # Registers new field types with the form(n) widget.
    #
    # Syntax:
    #
    #   register _ftype widget ?options...?_
    #
    #   ftype   - The field type name, e.g., "enum".
    #   widget  - The actual widget type command, e.g., 
    #             ::marsgui::enumfield
    #
    #   options - Default options and values to be used when creating
    #             fields of this type.
    #
    # This scheme allows a single widget type to implement more than
    # one kind of field.
    
    typemethod register {ftype widget args} {
        set ftypes($ftype) [list $widget $args]
    }

    #-------------------------------------------------------------------
    # Group: Options
    #
    # Unknown options are delegated to the hull.

    delegate option * to hull

    # Option: -changecmd 
    #
    # Specifies a command to be called whenever any field's value
    # changes, for any reason whatsoever (including explicit calls to
    # <set>. A list of the names of the changed fields is appended to the 
    # command as anargument.

    option -changecmd \
        -default ""

    # Option: -currentcmd
    #
    # Specifies a command to be called when one of the field widgets
    # receives the focus.  The field name is appended to the command
    # as an argument.

    option -currentcmd \
        -default ""

    # Option: -state
    #
    # *normal* or *disabled*  The <set> command still works when the
    # state is disabled.

    option -state \
        -default         normal                                 \
        -type            {snit::enum -values {normal disabled}} \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val

        $self DisplayFieldStates
    }


    #-------------------------------------------------------------------
    # Instance Variables

    # Variable: info
    #
    # Dict containing the field meta-data.  The indices are as follows:
    #
    #    fields          List of the field names in order of definition.
    #    context         List of context fields
    #    invalid         List of fields with invalid values.
    #    disabled        List of disabled fields.
    #    current         Name of the field with the focus.
    #    inSet           1 while in "set" method, 0 otherwise.
    #    text-$field     Label string
    #    ftype-$field    Field type
    #    options-$field  Additional options used when creating the 
    #                    field.
    #    w-$field        Widget for this field
    #    label-$field    Label widget for this field

    variable info -array {
        fields   {}
        context  {}
        invalid  {}
        disabled {}
        current  ""
        inSet    0
    }

    # Variable: trans
    #
    # Array of transient data used by the layout algorithm.
    #
    # interp  - Safe interpreter for layout language
    # wdict   - Info about current parent window
    #
    # wdict keys:
    #    pw  - Current parent window
    #    pr  - Current row in parent
    #    pc  - Current column in parentv

    variable trans -array {}

    #-------------------------------------------------------------------
    # Group: Constructor/Destructor

    # Constructor: constructor
    #
    # Creates the widget given the options.

    constructor {args} {
        # FIRST, apply the options
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Group: Event Handlers

    # Method: CurrentFieldCmd
    #
    # Called when a field receives the focus.  Remembers the name of
    # the field.

    method CurrentFieldCmd {field} {
        set info(current) $field

        callwith $options(-currentcmd) $field
    }

    # Method: FieldChangeCmd
    #
    # -changecmd callback for all defined fields.  Calls -changecmd
    # with the changed field name, only if we're not doing a "set".
    #
    # Syntax:
    #   FieldChangeCmd _field value_
    #
    #   field  - The field name
    #   value  - The field's new value

    method FieldChangeCmd {field value} {
        if {!$info(inSet)} {
            callwith $options(-changecmd) [list $field]
        }
    }


    #-------------------------------------------------------------------
    # Group: Field Commands
    #
    # These commands affect individual fields.

    # Method: field create
    #
    # Creates a new field with the specified name, type, and options.
    #
    # Syntax:
    #
    #   field create _field label ftype ?options...?_
    #
    #   field     - A symbolic name for the field; usually the name of
    #               the matching order parameter.
    #   label     - The label text for the field.
    #   ftype     - The field type, as registered with form(n).
    #   options   - Any additional options to be used when creating
    #               the field widget.

    method "field create" {field label ftype args} {
        ladd info(fields) $field

        set info(text-$field)    $label
        set info(ftype-$field)   $ftype
        set info(options-$field) $args
        set info(w-$field)       $win.field_$field
        set info(label-$field)   $win.label_$field
    }

    # Method: field names
    #
    # Returns a list of the names of the fields, in order of 
    # definition.

    method "field names" {} {
        return $info(fields)
    }

    # Method: field cget
    #
    # Retrieves an option value from a field widget.
    #
    # Syntax:
    #
    #   field cget _field option_
    #
    #   field     - A symbolic name for the field; usually the name of
    #               the matching order parameter.
    #   option    - One of the field widget's options.

    method "field cget" {field option} {
        $info(w-$field) cget $option
    }

    # Method: field configure
    #
    # Sets one or more option values for a field widget.  This is usually
    # used to set constraints, e.g., an enum field's values.  The
    # -state and -changecmd options should not be changed.
    #
    # Syntax:
    #
    #   field configure _field options..._
    #
    #   field     - A symbolic name for the field; usually the name of
    #               the matching order parameter.
    #   options   - Options and values for the field widget.

    method "field configure" {field args} {
        $info(w-$field) configure {*}$args
    }

    # Method: field ftype
    #
    # Returns the field's field type, e.g., "text" or "enum".
    #
    # Syntax:
    #
    #   field ftype _field_

    method "field ftype" {field} {
        return $info(ftype-$field)
    }

    # Method: field current
    #
    # Returns the name of the field that most recently received the
    # input focus.

    method "field current" {} {
        if {$info(current) ne ""} {
            return $info(current)
        } else {
            return [lindex $info(fields) 0]
        }
    }

    # Method: field win
    #
    # Returns the field's widget.  This should be used sparingly.
    #
    # Syntax:
    #
    #   field win _field_

    method "field win" {field} {
        return $info(w-$field)
    }

    # Method: field get
    #
    # Returns the field's value.
    #
    # Syntax:
    #
    #   field get _field_

    method "field get" {field} {
        $info(w-$field) get
    }

    #-------------------------------------------------------------------
    # Group: Layout

    # Method: clear
    #
    # Deletes all fields.

    method clear {} {
        # FIRST, forget the field info
        array unset info
        set info(fields)   {}
        set info(context)  {}
        set info(invalid)  {}
        set info(disabled) {}
        set info(inSet)    0

        # NEXT, delete the field widgets
        foreach w [winfo children $win] {
            destroy $w
        }
    }


    # Method: layout
    #
    # Layouts out the fields according to the layout spec.  If the
    # layout spec is empty, the fields are layed out in two columns,
    # labels on the left and fields on the right, in the order of 
    # definition.

    method layout {{spec ""}} {
        # FIRST, delete and recreate all child widgets.
        foreach w [winfo children $win] {
            destroy $w
        }

        foreach f $info(fields) {
            lassign $ftypes($info(ftype-$f)) widget defopts

            ttk::label $info(label-$f) -text "$info(text-$f):"

            $widget $info(w-$f)                         \
                {*}$defopts                             \
                {*}$info(options-$f)                    \
                -changecmd [mymethod FieldChangeCmd $f]

            bind $info(w-$f) <FocusIn> [mymethod CurrentFieldCmd $f]
        }

        # NEXT, lay out the widgets
        if {$spec eq ""} {
            $self LayoutStack
        } else {
            $self LayoutFromSpec $spec
        }

        # NEXT, display the field states.
        $self DisplayFieldStates
    }


    # Method: LayoutStack
    #
    # Lays out the labels and fields in two parallel columns.

    method LayoutStack {} {
        set r 0

        foreach f $info(fields) {
            grid $info(label-$f) -row $r -column 0 -sticky w
            grid $info(w-$f)     -row $r -column 1 -sticky ew \
                -padx 2 -pady 4

            incr r
        }

        grid columnconfigure $win 1 -weight 1
    }

    # Method: LayoutFromSpec
    #
    # Lays out the labels and fields according to the layout spec.
    #
    # Syntax:
    #   LayoutFromSpec _spec_
    #
    #   spec - The layout spec; see the form(n) man page.

    method LayoutFromSpec {spec} {
        # FIRST, create the interpreter
        set trans(interp) [interp create -safe]
        $trans(interp) alias at $self LayoutAt

        # NEXT, initialize the wdict.
        set trans(wdict) [dict create pw $win pr 0 pc 0]

        # NEXT, eval the spec.
        try {
            $trans(interp) eval $spec
        } finally {
            rename $trans(interp) ""
            array unset trans
        }
    }

    # Method: LayoutAt
    #
    # Lays out an element in the form. See the man page for the
    # element types.
    #
    # Syntax:
    #    LayoutAt _rc etype value ?args...?_
    #
    #    rc     - A row and column as "r,c".  "r" and "c" can be: an
    #             integer; "=", meaning use the same value as before,
    #             "+", meaning increment the value used before.
    #    etype  - The element type.
    #    value  - The element value; usually, a field name.
    #    args   - Any additional arguments; usually field options.

    method LayoutAt {rc etype value args} {
        # FIRST, get the window dict
        set wdict $trans(wdict)

        # NEXT, get the row and column
        dict with wdict {
            lassign [split $rc ,] r c

            if {$r eq "="} {
                set r $pr
            } elseif {$r eq "+"} {
                set r [incr pr]
            } else {
                set pr $r
            }
            
            if {$c eq "="} {
                set c $pc
            } elseif {$c eq "+"} {
                set c [incr pc]
            } else {
                set pc $c
            }
        }

        # NEXT, if it's labelfield it's a special case.
        if {$etype eq "labelfield"} {
            $self LayoutAt $r,$c       label $value
            $self LayoutAt $r,[incr c] field $value {*}$args
            return
        }

        dict with wdict {
            # NEXT, handle it based on the element type
            switch -exact -- $etype {
                text {
                    set wid $pw.text${r}_$c
                    ttk::label $wid -text $value
                    set sticky w
                }

                label {
                    set wid $info(label-$value)
                    set sticky w
                }

                field {
                    grid columnconfigure $pw $c -weight 1
                    set wid $info(w-$value)
                    set sticky ew
                }

                labelframe {
                    grid columnconfigure $pw $c -weight 1
                    set wid $pw.frame${r}_$c
                    ttk::labelframe $wid \
                        -text $value

                    # Put the frame lower than the field widgets.
                    lower $wid

                    set sticky nsew

                    set spec [lshift args]

                    
                    set trans(wdict) [dict create pw $wid pr 0 pc 0]

                    $trans(interp) eval $spec
                }

                default {
                    error "Unknown element type: \"$etype\""
                }
            }

            # NEXT, position it.
            grid $wid \
                -in [dict get $wdict pw]           \
                -row $r -column $c -sticky $sticky \
                -padx 2 -pady 2 {*}$args
        }

        set trans(wdict) $wdict
    }
    


    #-------------------------------------------------------------------
    # Group: Other Public Methods

    # Method: context
    #
    # Marks particular fields as context fields.  If called with no arguments,
    # returns the list of context fields.  Call with an empty list
    # to mark all fields non-context.  Context fields are disabled
    # with a normal label.
    #
    # Syntax:
    #    context ?_fields_?

    method context {args} {
        # FIRST, if there are no arguments return the list of
        # context fields.
        if {[llength $args] == 0} {
            return $info(context)
        }

        # NEXT, get the list of context fields, and mark them.
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        # NEXT, update the existing list.
        $self UpdateSet info(context) $args

        # NEXT, Display the field states
        $self DisplayFieldStates

        return $info(context)
    }

    # Method: invalid
    #
    # Marks particular fields as invalid.  If called with no arguments,
    # returns the list of invalid fields.  Call with an empty list
    # to mark all fields valid.  Invalid fields are displayed in red.
    #
    # Syntax:
    #    invalid ?_fields_?

    method invalid {args} {
        # FIRST, if there are no arguments return the list of
        # invalid fields.
        if {[llength $args] == 0} {
            return $info(invalid)
        }

        # NEXT, get the list of invalid fields, and mark them.
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        # NEXT, update the existing list.
        $self UpdateSet info(invalid) $args

        # NEXT, Display the field states
        $self DisplayFieldStates

        return $info(invalid)
    }

    # Method: disabled
    #
    # Marks particular fields as disabled (i.e., readonly).  If called
    # with no arguments, returns the list of disabled fields.  Call
    # with an empty list to mark all fields enabled.  Labels of 
    # disabled fields are grayed out.
    #
    # Normally, the new list of disabled fields completely replaces
    # the old list.  If the list of fields begins with "+"
    # or "-", then the existing set of disabled fields remain
    # disabled; and the listed fields only are disabled "+" or 
    # re-enabled "-".

    method disabled {args} {
        # FIRST, if there are no arguments return the list of
        # disabled fields.
        if {[llength $args] == 0} {
            return $info(disabled)
        }

        # NEXT, get the new list.
        if {[llength $args] == 1} {
            set args [lindex $args 0] 
        }

        # NEXT, update the existing list.
        $self UpdateSet info(disabled) $args

        # NEXT, display the field states
        $self DisplayFieldStates

        return $info(disabled)
    }

    # Method: set
    #
    # Sets the widget's value, and calls the -changecmd for the fields
    # that actually changed.
    #
    # Syntax:
    #   set _dict_
    #
    #   set _field value..._
    #
    #   dict - A dictionary of field names and values.
   
    method set {args} {
        # FIRST, mark that we're in the set method.
        set info(inSet) 1

        # NEXT, try to set all of the field values, keeping track
        # of the fields that changed.
        set changed [list]

        # NEXT, if there's only one arg it's the dict.
        if {[llength $args] == 1} {
            set dict [lindex $args 0]
        } else {
            set dict $args
        }

        try {
            # Process the data in the order in which the fields are
            # defined.
            foreach field $info(fields) {
                if {[dict exists $dict $field]} {
                    set value [dict get $dict $field]

                    if {$value ne [$info(w-$field) get]} {
                        $info(w-$field) set $value
                        lappend changed $field
                    }
                }
            }
        } finally {
            # Be sure to clear the inSet flag, or we'll be in trouble.
            set info(inSet) 0
        }

        if {[llength $changed] > 0} {
            callwith $options(-changecmd) $changed
        }
    }

    # Method: get
    #
    # Retrieves the widget's current value: a dictionary of 
    # field names and values.
    
    method get {} {
        set dict [dict create]

        foreach field $info(fields) {
            dict set dict $field [$info(w-$field) get]
        }

        return $dict
    }

    #-------------------------------------------------------------------
    # Group: Utility Methods

    # UpdateSet
    #
    # Updates a set of values.  The set can be replaced with a new
    # set; values can be added to it; and values can be subtracted
    # from it.
    #
    # Syntax:
    #   UpdateSet _setVar values_
    #
    #   setVar - Name of a list variable
    #   values - Values to assign, add, or subtract from the setVar.
    #            Add or subtract if first value is "+" or "-".
    
    method UpdateSet {setVar values} {
        upvar $setVar theSet

        # NEXT, update the existing list.
        switch -exact -- [lindex $values 0] {
            "+" {
                lshift values
                foreach value $values {
                    ladd theSet $value
                }
            }

            "-" {
                lshift values
                foreach value $values {
                    ldelete theSet $value
                }
            }

            default {
                set theSet $values
            }
        }
    }

    method DisplayFieldStates {} {
        foreach f $info(fields) {
            set state normal
            set color valid

            if {$f in $info(invalid)} {
                set color invalid
            }

            if {$options(-state) eq "disabled" ||
                $f in $info(disabled)
            } {
                set state disabled
                set color disabled
            } elseif {$f in $info(context)} {
                set state disabled
                set color context
            }

            $info(label-$f) configure -foreground $colors($color)
            $info(w-$f)     configure -state      $state
        }
    }
}


#-----------------------------------------------------------------------
# Register standard field types

::marsgui::form register color   ::marsgui::colorfield
::marsgui::form register disp    ::marsgui::dispfield
::marsgui::form register enum    ::marsgui::enumfield
::marsgui::form register key     ::marsgui::keyfield
::marsgui::form register list    ::marsgui::listfield
::marsgui::form register multi   ::marsgui::multifield
::marsgui::form register newkey  ::marsgui::newkeyfield
::marsgui::form register range   ::marsgui::rangefield
::marsgui::form register text    ::marsgui::textfield





