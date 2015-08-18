#-----------------------------------------------------------------------
# FILE: dynaform_fields.tcl
#
#   dynaform(n) -- Dynamic Form Field Types 
#
# PACKAGE:
#   marsutil(n): Mars Utility Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Defines the standard dynaform field types.  A field type is an
#    object that mediates between the dynaform(n) and a field(i) widget
#    doing a particular job.  It is responsible for:
#
#    1. Specifying any type-specific attributes for the field type.
#    2. Validating the item definition dictionary, as required.  
#       Dynaforms are not user-defined code, so validation should be
#       used sparingly.
#    3. Creating an appropriately configured widget given the item
#       definition dictionary.  If the field is supposed to be context,
#       the "create" command must make it so.
#    4. Configuring the field widget (i.e., setting -values for an 
#       enumfield(n) widget) on demand, given the widget, the item
#       definition dictionary, and the upstream field values.
#
# NOTE:
#    Dynaform field types can be defined whether Tk is loaded or not;
#    in fact, they must be or dynaforms using those field types cannot
#    be defined.  However, the "create" and "reconfigure" methods do work
#    with field widgets and hence expect Tk and marsgui(n) to be in place.
#
#-----------------------------------------------------------------------

# check
::marsutil::dynaform fieldtype define check {
    typemethod attributes {} {
        return {text image}
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        checkfield $w \
            -state [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict text image]
    }
}

# color
::marsutil::dynaform fieldtype define color {
    typemethod create {w idict} {
        set context [dict get $idict context]

        colorfield $w \
            -state     [expr {$context ? "disabled" : "normal"}]
    }
}

# dbkey
::marsutil::dynaform fieldtype define dbkey {
    typemethod resources {} {
        return {db_}
    }

    typemethod attributes {} {
        # "table" and "keys" are used by the field's -loadcmd.
        return {table keys dispcols widths labels}
    }

    typemethod create {w idict rdict} {
        set context [dict get $idict context]
        set db_     [dict get $rdict db_]

        keyfield $w \
            -db    $db_                                      \
            -state [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict table keys dispcols widths labels]
    }
}

# dbmulti
::marsutil::dynaform fieldtype define dbmulti {
    typemethod attributes {} {
        # These are used by the field's -loadcmd.
        return {table key}
    }

    typemethod create {w idict} {
        # Don't need to worry about context flag; multi fields are
        # always context.
        multifield $w 
    }
}

# disp
::marsutil::dynaform fieldtype define disp {
    typemethod attributes {} {
        return {width textcmd}
    }

    typemethod create {w idict} {
        dispfield $w {*}[asoptions $idict width]
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -textcmd, call it and display
        # result.
        dict with idict {}

        if {$textcmd ne ""} {
            set text [formcall $vdict $textcmd] 
            $w set $text 
        }
    }
}

# enum
::marsutil::dynaform fieldtype define enum {
    typemethod attributes {} {
        return {list listcmd}
    }

    typemethod validate {idict} {
        dict with idict {}
        require {$list ne "" || $listcmd ne ""} "No enumeration data given"
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        enumfield $w \
            -autowidth on \
            -state     [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict {list -values}]
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -listcmd, call it and apply the
        # results (only if they've changed).
        dict with idict {}

        if {$listcmd ne ""} {
            set values [formcall $vdict $listcmd] 

            if {$values ne [$w cget -values]} {
                $w configure -values $values 
            }
        }
    }

    typemethod ready {w idict} {
        return [expr {[llength [$w cget -values]] > 0}]
    }
}

# enumlong
::marsutil::dynaform fieldtype define enumlong {
    typevariable defaults {
        dict     {}
        dictcmd  {}
        showkeys no
    }

    typemethod attributes {} {
        return [dict keys $defaults]
    }

    typemethod defvalue {attr} {
        return [dict get $defaults $attr]
    }

    typemethod validate {idict} {
        dict with idict {}
        require {$dict ne "" || $dictcmd ne ""} "No enumeration data given"
    }

    typemethod create {w idict} {
        set context [dict get $idict context]
        set dict [dict get $idict dict]

        if {[dict get $idict showkeys]} {
            dict for {key val} $dict {
                dict set dict $key "$key: $val"
            }
        }

        enumfield $w                                               \
            -autowidth   on                                        \
            -displaylong 1                                         \
            -state       [expr {$context ? "disabled" : "normal"}] \
            -values      $dict
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -dictcmd, call it and apply the
        # results (only if they've changed).
        dict with idict {}

        if {$dictcmd ne ""} {
            set dict [formcall $vdict $dictcmd] 

            if {[dict get $idict showkeys]} {
                dict for {key val} $dict {
                    dict set dict $key "$key: $val"
                }
            }

            if {$dict ne [$w cget -values]} {
                $w configure -values $dict 
            }
        }
    }

    typemethod ready {w idict} {
        return [expr {[dict size [$w cget -values]] > 0}]
    }
}

# enumlist
::marsutil::dynaform fieldtype define enumlist {
    typemethod attributes {} {
        return {list listcmd width height stripe}
    }

    typemethod validate {idict} {
        dict with idict {}
        require {$list ne "" || $listcmd ne ""} "No enumeration data given"
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        listfield $w \
            -showkeys no                                        \
            -state    [expr {$context ? "disabled" : "normal"}] \
            -itemdict [list2dict [dict get $idict list]]        \
            {*}[asoptions $idict width height stripe]
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -listcmd, call it and apply the
        # results (only if they've changed).
        dict with idict {}

        if {$listcmd ne ""} {
            set itemdict [list2dict [formcall $vdict $listcmd]]

            if {$itemdict ne [$w cget -itemdict]} {
                $w configure -itemdict $itemdict 
            }
        }
    }

    typemethod ready {w idict} {
        return [expr {[dict size [$w cget -itemdict]] > 0}]
    }
}

# enumlonglist
::marsutil::dynaform fieldtype define enumlonglist {
    typemethod attributes {} {
        return {dict dictcmd width height stripe showkeys}
    }

    typemethod validate {idict} {
        dict with idict {}
        require {$dict ne "" || $dictcmd ne ""} "No enumeration data given"
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        listfield $w                                            \
            -itemdict [dict get $idict dict]                    \
            -state    [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict width height stripe showkeys]
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -dictcmd, call it and apply the
        # results (only if they've changed).
        dict with idict {}

        if {$dictcmd ne ""} {
            set itemdict [formcall $vdict $dictcmd]

            if {$itemdict ne [$w cget -itemdict]} {
                $w configure -itemdict $itemdict 
            }
        }
    }

    typemethod ready {w idict} {
        return [expr {[dict size [$w cget -itemdict]] > 0}]
    }
}

# file
::marsutil::dynaform fieldtype define file {
    typemethod attributes {} {
        return {width filetypes title}
    }

    typemethod create {w idict} {
        filefield $w {*}[asoptions $idict width filetypes title]
    }
}

# key
::marsutil::dynaform fieldtype define key {
    typemethod attributes {} {
        return {db table keys dispcols widths labels}
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        keyfield $w \
            -state [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict db table keys dispcols widths labels]
    }
}

# multi
::marsutil::dynaform fieldtype define multi {
    typemethod attributes {} {
        return {db table key}
    }

    typemethod create {w idict} {
        # Don't need to worry about context flag; multi fields are
        # always context.
        multifield $w 
    }
}

# range
::marsutil::dynaform fieldtype define range {
    typemethod attributes {} {
        return {
            changemode min max scalelength datatype resetvalue 
            resolution showreset showsymbols
        }
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        rangefield $w \
            -state [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict \
                {datatype -type} changemode min max scalelength \
                resetvalue resolution showreset showsymbols]
    }
}

# text
::marsutil::dynaform fieldtype define text {
    typemethod attributes {} {
        return {width}
    }

    typemethod create {w idict} {
        if {![dict get $idict context]} {
            textfield $w {*}[asoptions $idict width]
        } else {
            dispfield $w {*}[asoptions $idict width]
        }
    }
}


