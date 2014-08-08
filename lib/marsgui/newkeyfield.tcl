#-----------------------------------------------------------------------
# FILE: newkeyfield.tcl
#
#   newkeyfield(n) -- Prototype database key field(i)
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
    namespace export newkeyfield
}

#-----------------------------------------------------------------------
# Widget: newkeyfield
#
# This is a prototype widget to enter the (possibly multi-column) key 
# for a new, not-yet-existing entity in a database table, where the 
# range of valid values exists as a (possibly multi-column) key in
# another table.  It is a field(i) widget.
#-----------------------------------------------------------------------

snit::widget ::marsgui::newkeyfield {
    #-------------------------------------------------------------------
    # Group: Options
    #
    # Unknown options are delegated to the hull.

    delegate option * to hull

    # Option: -changecmd 
    #
    # Specifies a command to be called whenever the field's value
    # changes, for any reason whatsoever (including explicit calls to
    # <set>. The new value is appended to the command as an argument.

    option -changecmd \
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

        foreach name [array names fields] {
            if {$val eq "normal"} {
                $fields($name) configure -state readonly
            } else {
                $fields($name) configure -state $val
            }
        }
    }

    # Option: -db
    #
    # Names an SQLite3 database object.

    option -db \
        -readonly yes

    # Option: -universe
    #
    # Names a table or view in <-db>.  All valid combinations of 
    # the keys exist in this table.

    option -universe \
        -readonly yes

    # Option: -table
    #
    # Names a table or view in <-db>; the new key will be for this table.

    option -table \
        -readonly yes

    # Option: -keys
    #
    # A list of the names of one or more key columns for <-table> in <-db>.

    option -keys \
        -readonly yes

    # Option: -widths
    #
    # If given, a list of widths for the menuboxes.

    option -widths \
        -readonly yes

    # Option: -labels
    #
    # If given, a list of label strings for the menuboxes.

    option -labels \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance Variables

    # Variable: currentValue
    #
    # The current value of the widget; used to detect changes.
    
    variable currentValue {}

    # Variable: fields
    #
    # Array of menubox(n) widgets by key column name.

    variable fields -array {}

    #-------------------------------------------------------------------
    # Group: Constructor/Destructor

    # Constructor: constructor
    #
    # Creates the widget given the options.

    constructor {args} {
        # FIRST, apply the options
        $self configurelist $args

        # NEXT, create an menubox for each key.
        set k -1
        set c -1

        foreach name $options(-keys) {
            # FIRST, create and grid the field.
            set fields($name) $win.field[incr k]

            set width [lindex $options(-widths) $k]

            set label [lindex $options(-labels) $k]

            if {$k == 0} {
                set pad 0
            } else {
                set pad 4
            }

            if {$label ne ""} {
                ttk::label $win.label$k \
                    -text $label

                grid $win.label$k -row 0 -column [incr c] \
                    -sticky ew -padx [list $pad 0]
                grid columnconfigure $win $c -weight 0

                set pad 0
            }

            menubox $fields($name)                          \
                -exportselection yes                        \
                -takefocus       1                          \
                -postcommand     [mymethod KeyValues $name] \
                -command         [mymethod KeyChange $name] \
                -width           10

            if {$width ne ""} {
                $fields($name) configure \
                    -width $width
            }

            grid $fields($name) -row 0 -column [incr c] \
                -sticky ew -padx [list $pad 0]
            grid columnconfigure $win $c -weight 1
        }

        # NEXT, initialize the cached value
        set currentValue [$self GetValue]
    }

    #-------------------------------------------------------------------
    # Group: Helper Methods

    # Method: KeyValues
    #
    # Gets the list of enumerated values for the specified key column.
    # This is tricky because the proper set of values depends on the
    # values of the keys to the left.
    #
    # Syntax:
    #   KeyValues _name_
    #
    #   name       - The name of this key column
    
    method KeyValues {name} {
        # FIRST, build up the list of leftward keys that
        # need to be matched.
        set conditions [list]

        foreach kname $options(-keys) {
            if {$kname eq $name} {
                break
            }

            set key($kname) [$fields($kname) get]

            lappend conditions "$kname=\$key($kname)"
        }

        if {[llength $conditions] > 0} {
            set where "WHERE [join $conditions { AND }]"
        } else {
            set where ""
        }

        # NEXT, get the names of this key and those to the right.
        set ndx [lsearch -exact $options(-keys) $name]
        set rest [lrange $options(-keys) $ndx end]

        # NEXT, get the universe values.
        set names [join $rest " || ' ' || "]
        
        set index [dict create]

        $options(-db) eval "
            SELECT $names AS id 
            FROM $options(-universe)
            $where
        " {
            dict set index {*}$id 1
        }

        # NEXT, prune the ones that already exist
        $options(-db) eval "
            SELECT $names AS id 
            FROM $options(-table)
            $where
        " {
            dict unset index {*}$id
        }

        set values [lsort [dict keys $index]]

        # NEXT, give them to the menubox
        $fields($name) configure -values $values

        # NEXT, if the current value is wrong, clear it.
        if {[$fields($name) get] ni $values} {
            $fields($name) set ""
        }
    }

    # Method: KeyChange
    #
    # This method is called when a value changes for the named
    # key column: 
    #
    # - Implicitly, when the user selects a new value
    # - Explicitly, by <set>.
    #
    # It has two jobs:
    #
    # - It must verify that subsequent columns contain valid values or "".
    #
    # - If it is the last column, it must check whether the overall
    #   value really changed, and if so call the -changecmd.
    #
    # Note that it is called only for the left-most column to change.
    #
    # Syntax:
    #   KeyChange _name_
    #
    #   name - The name of a key column

    method KeyChange {name} {
        # FIRST, make sure that this and all subsequent columns have
        # valid values.
        set ndx  [lsearch -exact $options(-keys) $name]
        set rest [lrange $options(-keys) $ndx end]

        foreach kname $rest {
            # This will retrieve the set of valid values for the
            # key column $kname, given the key values in the leftward
            # columns, and clear the field if the current value isn't
            # in the list.
            $self KeyValues $kname
        }

        # NEXT, save the new current value, and call the -changecmd
        # if there's a real change.

        set oldValue $currentValue
        set currentValue [$self GetValue]

        if {$currentValue ne $oldValue} {
            callwith $options(-changecmd) $currentValue
        }

        return
    }
    
    # Method: GetValue
    #
    # Returns a list of the values from the field widgets (or one value
    # if there's a single widget).

    method GetValue {} {
        if {[llength $options(-keys)] > 1} {
            set result [list]

            foreach name $options(-keys) {
                lappend result [$fields($name) get]
            }

            return $result
        } else {
            set name [lindex $options(-keys) 0]
            return [$fields($name) get]
        }
    }

    #-------------------------------------------------------------------
    # Group: Public Methods

    # Method: set
    #
    # Sets the widget's value, and calls the -changecmd on change.
    #
    # Key values can be empty, resulting in empty pulldowns, or wrong,
    # also resulting in empty pulldowns.
    #
    # Syntax:
    #   set _value_
    #
    #   value - If length(-keys) = 1, a value for the key column, or "".
    #           If length(-keys) > 1, a list of 1 to length values for the 
    #           key columns.
   
    method set {value} {
        # FIRST, save the new values into the menuboxes.
        if {[llength $options(-keys)] == 1} {
            set name [lindex $options(-keys) 0]
            $fields($name) set $value
        } else {
            foreach name $options(-keys) key $value {
                $fields($name) set $key
            }
        }

        # NEXT, call KeyChange for the first key; this will clear
        # invalid entries and call -changecmd.
        $self KeyChange [lindex $options(-keys) 0]
    }

    # Method: get
    #
    # Retrieves the widget's current value: A single value if
    # length(-keys) = 1, and a list of values if length(-keys) > 1.
    
    method get {} {
        return $currentValue
    }
}







