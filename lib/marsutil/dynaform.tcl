#-----------------------------------------------------------------------
# FILE: dynaform.tcl
#
#   dynaform(n) -- Dynamic Form Specification 
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
# UNCHECKED CONSTRAINTS:
#    These constraints are assumed to be true, but are not checked.
#
#    * Field names should be unique for each line of descent
#    * Field names must be identifiers not ending in "_".
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export dynaform
}


#-----------------------------------------------------------------------
# dynaform Type
#
# This is part of a prototype of a "dynamic form": a user data entry
# form whose contents varies depending on the user's selections.  This
# type handles the non-gui part of the problem: defining the fields 
# the user can edit, and the relationships between them, with all necessary
# metadata.  This allows the dynaform to be defined as part of an order(n)
# order. The dynaview widget works closely with dynaform to display the form
# to the user.
#
#-----------------------------------------------------------------------

snit::type ::marsutil::dynaform {
    pragma -hasinstances no

    #===================================================================
    # Type Definitions
    #
    # The type methods and variables are used to define and manipulate
    # form types.

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*

        ::marsutil::enum elayout {
            ncolumn "N-Column"
            2column "Two-Column"
            ribbon  "Ribbon"
        }
    }

    #-------------------------------------------------------------------
    # Type Variables

    # reservedNames: List of reserved item type names
    typevariable reservedNames {
        c
        cc
        label
        rc
        rcc
        selector
        when
    }

    # meta array
    #
    # This array contains data about the defined form types and the
    # items within them.
    #
    # Key is formType name.  Values are:
    #
    # types            - List of form type names 
    # fieldtypes       - List of field type names 
    # aliases          - List of aliased field type names
    # idcounter        - Item ID counter.
    # all-$ftype       - List of numeric item IDs of all items for this 
    #                    form type.
    # top-$ftype       - List of numeric item IDs of the top-level items 
    #                    for this form type.
    # fields-$ftype    - List of distinct field names for this form type.
    #                    Items on different branches can share a field name.
    # layout-$ftype    - The layout algorithm for this form type.
    #                    Defaults to ncolumn
    # height-$ftype    - The default form height in pixels; defaults to 
    #                    200.
    # width-$ftype     - The default form width in pixels; defaults to 400
    # shrink-$ftype    - If true, (the default) shrink the form to the 
    #                    smallest size that will contain the content.  If
    #                    shrink is set, the height and width are ignored.
    # ft-$fieldtype    - Field type definition singleton
    # aliasto-$alias   - Field type to which the alias refers
    # aliasopts-$alias - Options associated with the alias
    # item-$id         - The definition dictionary for item $id
    #
    # Each dynaform type consists of a tree of items.  Each item has a 
    # unique integer ID, and a definition dictionary.
    #
    # The data stored in the item definition dictionary varies by item 
    # type, as shown here.
    #
    # First, all items share these attributes:
    #
    #   ftype      - The form type to which this item belongs.
    #   itype      - The item type
    #   widget     - Flag; 1 if this item will have a widget, and 0 o.w.
    #                Essentially, this is 1 for fields and 0 for 
    #                everything else.
    #    
    # All fields, whether external or internal, have the following
    # attributes:
    #
    #   field      - The field name.
    #   tip        - The field's tool tip, a label string.  The tool tip is
    #                used in different ways by different layout algorithms.
    #   loadcmd    - Command to provide values for downstream fields when
    #                this field's value changes, or "".
    #   defvalue   - Default value.
    #   context    - Boolean; if 0 (the default) the widget is editable,
    #                but if 1 it is not.  It is up to the field's "create"
    #                command to enforce this.
    #   invisible  - Boolean; if 0 (the default) the widget is included in
    #                the layout, but if 1 it is not.
    #
    # "selector" items are fields; they also have these specific attributes:
    #
    #   dict       - The dictionary of case symbols and labels.
    #   listcmd    - A command that returns the subset of case symbols
    #                to actually display.  Can include prior fields.
    #   cases      - Dictionary: case symbol => item ID list.  For each
    #                case, contains the list of IDs directly included in
    #                that case.
    #
    # "when" items are computed selectors; they are not fields, but like
    # "selector" items they have a "cases" attribute, mapping 1 and 0 to
    # child items:
    #
    #   expr       - A boolean expression, which can include upstream
    #                field variables.
    #   cases      - Dictionary: case symbol => item ID list.  For each
    #                case, contains the list of IDs directly included in
    #                that case.
    #
    # "label" items contain non-widget boilerplate text to include in the
    # layout.  They have these keys:
    #
    #   text       - The text to include in the layout
    #   for        - If defined, a field name (not an item ID).  This
    #                allows the text to label the field with the given
    #                name.
    #
    # ncolumn layout's row and column break commands (rc, rcc, c, cc) 
    # have these keys:
    #
    #   text       - Label text to include in the layout
    #   for        - If defined, a field name (not an item ID).  This
    #                allows the text to label the field with the given
    #                name.
    #   width      - Width of the column in HTML units (e.g., 75px)
    #   span       - Number of table columns a column should span.
    
    typevariable meta -array {
        types      {}
        fieldtypes {}
        aliases    {}
        idcounter  0
    }

    # itypeAttrs array: List of type-specific item attributes
    
    typevariable itypeAttrs -array {
        br          { }
        c           { text for span width }
        cc          { text for span width }
        field       { field tip loadcmd defvalue context invisible ft }
        label       { text for }
        para        { }
        rc          { text for span width }
        rcc         { text for span width }
        selector    { field tip loadcmd defvalue context invisible listcmd}
        when        { expr }
    }
    
    # compile array: Transient array of compilation data
    #
    # finterp   - The form interpreter
    # sinterp   - The selector interpreter 
    # ftype     - The form type being defifieldtypened.
    # selector  - Item ID of selector currently being processed, or ""
    # case      - Case symbol for selector currently being processed, or ""

    typevariable compile -array {
        finterp  {}
        sinterp  {}
        ftype    {}
        selector {}
        case     {}
    }

    #-------------------------------------------------------------------
    # Type Methods

    # reset
    #
    # Clears all form type data and field type aliases.  (Normal field
    # types are not affected.)  This command is intended for use in
    # the dynaform(n) test suite.

    typemethod reset {} {
        # FIRST, save the field type data.
        set save(fieldtypes) $meta(fieldtypes)

        array set save [array get meta ft-*]

        # NEXT, clear the meta array.
        array unset meta

        array set meta {
            types      {}
            aliases    {}
            idcounter  0
        }

        # NEXT, restore the field types
        array set meta [array get save] 
    }
    
    # define ftype fscript
    #
    # ftype    - Form type name
    # fscript  - Form definition scrip
    #
    # Defines a new form type (or redefines an old one).

    typemethod define {ftype fscript} {
        # FIRST, if we already have a form of this type, delete it.
        DeleteFormItems $ftype

        # NEXT, define the form script interpreter
        set finterp [interp create -safe]

        $finterp alias br         ${type}::FormBR
        $finterp alias c          ${type}::FormC
        $finterp alias cc         ${type}::FormCC
        $finterp alias label      ${type}::FormLabel
        $finterp alias layout     ${type}::FormLayout
        $finterp alias para       ${type}::FormPara
        $finterp alias rc         ${type}::FormRC
        $finterp alias rcc        ${type}::FormRCC
        $finterp alias selector   ${type}::FormSelector
        $finterp alias when       ${type}::FormWhen

        foreach name $meta(fieldtypes) {
            $finterp alias $name ${type}::FormField $name
        }

        # Aliases can shadow built-in field types, so define
        # their commands second.
        foreach name $meta(aliases) {
            $finterp alias $name ${type}::FormAlias $name
        }

        # NEXT, define the selector script interpreter
        set sinterp [interp create -safe]

        $sinterp alias case ${type}::FormCase

        # NEXT, initialize the compile array
        array unset compile
        set compile(finterp)  $finterp
        set compile(sinterp)  $sinterp
        set compile(ftype)    $ftype
        set compile(selector) ""
        set compile(case)     ""

        # NEXT, initialize the form data
        lappend meta(types) $ftype

        set meta(all-$ftype)       [list]
        set meta(top-$ftype)       [list]
        set meta(fields-$ftype)    [list]
        set meta(layout-$ftype)    ncolumn
        set meta(height-$ftype)    200
        set meta(width-$ftype)     400
        set meta(shrink-$ftype)    true

        # NEXT, evaluate the form definition script, building up data.  
        if {[catch {
            $finterp eval $fscript
        } result]} {
            return -code error \
            "Error in definition script for dynaform type \"$ftype\"\n$result"
        }

        # NEXT, clear the compilation data
        rename $finterp ""
        rename $sinterp ""
        array unset compile
    }

    # DeleteFormItems ftype
    #
    # ftype  - The form type
    #
    # Deletes all meta data associated with the form type.

    proc DeleteFormItems {ftype} {
        if {![info exists meta(all-$ftype)]} {
            return
        }

        foreach id $meta(all-$ftype) {
            unset meta(item-$id)
        }

        unset meta(all-$ftype)
        unset meta(top-$ftype)
        unset meta(fields-$ftype)
        unset meta(layout-$ftype)
    }

    # fieldtype define name body 
    #
    # name   - The field type name, e.g., "text"
    # body   - A snit::type body defining the field type commands.
    #
    # Defines a new field type as $type::NAME.

    typemethod {fieldtype define} {name body} {
        # FIRST, require that the name isn't reserved.
        require {$name ni $reservedNames} \
            "field type name is reserved: \"$name\""

        # NEXT, define the type.
        set header "
            # Make it a singleton
            pragma -hasinstances no

            typemethod attributes  {}              { }
            typemethod defvalue    {args}          { return {} }
            typemethod ready       {w idict}       { return 1 }
            typemethod reconfigure {w idict vdict} { }
            typemethod validate    {idict}         { }

            typeconstructor {
                namespace import ${type}::asoptions
                namespace import ${type}::formcall
                namespace import ${type}::list2dict
            }
        "

        set fullname ${type}::[string toupper $name]
        snit::type $fullname "$header\n$body"

        # NEXT, save the type metadata
        ladd meta(fieldtypes) $name
        set meta(ft-$name) $fullname
    }

    # fieldtype alias name fieldtype options...
    #
    # name      - A new field type name
    # fieldtype - An existing field type name
    # options   - A list of options and values appropriate for the field type
    # 
    # Defines an alias to an existing field type/options combination; 
    # it can be used just like a field type.  dynaview(n) will see it
    # as an instance of the existing field type.

    typemethod {fieldtype alias} {name fieldtype args} {
        # FIRST, validate the name and fieldtype 
        require {$name ni $reservedNames} \
            "field type name is reserved: \"$name\""
        require {$fieldtype in $meta(fieldtypes)} \
            "cannot alias to unknown field type: \"$fieldtype\""

        ladd meta(aliases)        $name
        set meta(aliasto-$name)   $fieldtype
        set meta(aliasopts-$name) $args
    }

    #-------------------------------------------------------------------
    # Form Script Routines

    # FormAlias alias field ?options...?
    #
    # alias   - The field type name
    # field   - The field name
    #
    # Options:  Any options defined by the aliased field type:
    #
    # Defines an item of an aliased field type with the given field name 
    # and options.

    proc FormAlias {alias field args} {
        set fieldtype $meta(aliasto-$alias)
        set opts [concat $meta(aliasopts-$alias) $args]

        FormField $fieldtype $field {*}$opts
    }

    # FormBR 
    #
    # Inserts a line break into the form.  This item is handled
    # differently by the different layout algorithms.

    proc FormBR {} {
        set id [DefineItem br]
    }

    # FormC ?label? ?options...?
    #
    # Options:
    #   -for field   - The field name of an associated field item.
    #   -span n      - Number of columns to span
    #   -width wid   - Sets the width of the column in HTML units.
    #
    # In ncolumn layout, begins a new column on the current row.
    # If label is given, it appears first in the column, and will
    # be tagged as being "for" the -for field.  The new column will
    # span n columns in the layout.

    proc FormC {{label ""} args} {
        set opts [GetOpts "c item" $args {-for -span -width}]
        
        set id [DefineItem c]

        # TBD: Validate options
        
        dict set meta(item-$id) text $label
        SaveOptions $id $opts
    }

    # FormCC label ?options...?
    #
    # Options:
    #   -for field   - The field name of an associated field item.
    #   -span n      - Number of columns to span
    #   -width wid   - Sets the width of the second column in HTML units.
    #
    # In ncolumn layout, begins two new columns on the current row.
    # The label is placed in the first column, and will
    # be tagged as being "for" the -for field.  The second column will
    # span n columns in the layout.

    proc FormCC {label args} {
        set opts [GetOpts "cc item" $args {-for -span -width}]
        
        set id [DefineItem cc]

        # TBD: Validate options
        
        dict set meta(item-$id) text $label
        SaveOptions $id $opts
    }

    # FormField fieldtype field ?options...?
    #
    # fieldtype   - The field type name
    # field       - The field name
    #
    # Options:  Any options defined by the field type, plus:
    #     -tip       - Tool tip string
    #     -loadcmd   - Load command
    #     -defvalue  - Default value
    #     -context   - Flag, field is a non-editable context field.
    #     -invisible - Flag, field should be invisible.
    #
    # Defines an item of a defined field type with the given field name 
    # and options.

    proc FormField {fieldtype field args} {
        # FIRST, get the field type object
        set ft $meta(ft-$fieldtype)

        # NEXT, prepare to load the options.  We have two sets: the 
        # standard options and the type-specific options.
        set optlist [list -tip -loadcmd -defvalue -context -invisible]

        foreach attr [$ft attributes] {
            lappend optlist "-$attr"

            if {[$ft defvalue $attr] ne ""} {
                set args [linsert $args 0 "-$attr" [$ft defvalue $attr]]
            }
        }
        
        # NEXT, define the field.
        set opts [GetOpts "$fieldtype field" $args $optlist]

        set id [DefineField field $field $opts]

        dict set meta(item-$id) ft $ft

        # NEXT, validate the idict.
        $ft validate $meta(item-$id)
    }

    # FormLabel text ?options...?
    #
    # text  -  A text string
    #
    # The options are as follows:
    #
    #   -for field   - The field name of an associated field item.
    #
    # Defines a label item, possibly related to some field.
    # The text might be displayed by the layout algorithm.

    proc FormLabel {text args} {
        # FIRST, save the item data
        set id [DefineItem label]

        # NEXT, parse the options
        set opts [GetOpts "label" $args {-for}]

        dict set meta(item-$id) for  [dict get $opts -for]
        dict set meta(item-$id) text $text
    }


    # FormLayout layout ?options...?
    #
    # layout  - The layout algorithm
    # options - Layout options
    #
    #    -width 
    #    -height
    #    -shrink
    #
    # Sets the default layout algorithm for this form type.  Options
    # are passed down to the htmlframe in the dynaview widget.

    proc FormLayout {layout args} {
        elayout validate $layout

        set meta(layout-$compile(ftype)) $layout

        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -height { set meta(height-$compile(ftype)) [lshift args] }
                -width  { set meta(width-$compile(ftype)) [lshift args] }
                -shrink { set meta(shrink-$compile(ftype)) [lshift args] }
                default { error "Unexpected option: \"$opt\""}
            }
        }
    }

    # FormPara 
    #
    # Inserts a paragraph break into the form.  This item is handled
    # differently by the different layout algorithms.

    proc FormPara {} {
        set id [DefineItem para]
    }

    # FormRC ?label? ?options...?
    #
    # Options:
    #   -for field   - The field name of an associated field item.
    #   -span n      - Number of columns to span
    #   -width wid   - Sets the width of the column in HTML units.
    #
    # In ncolumn layout, begins a new row and column.
    # If label is given, it appears first in the column, and will
    # be tagged as being "for" the -for field.  The new column will
    # span n columns in the layout.

    proc FormRC {{label ""} args} {
        set opts [GetOpts "rc item" $args {-for -span -width}]
        
        set id [DefineItem rc]

        # TBD: Validate options
        
        dict set meta(item-$id) text $label
        SaveOptions $id $opts
    }

    # FormRCC label ?options...?
    #
    # Options:
    #   -for field   - The field name of an associated field item.
    #   -span n      - Number of columns spanned by the second column.
    #   -width wid   - Sets the width of the second column in HTML units.
    #
    # In ncolumn layout, begins a new row with two new columns.
    # The label is placed in the first column, and will
    # be tagged as being "for" the -for field.  The second column will
    # span n columns in the layout.

    proc FormRCC {label args} {
        set opts [GetOpts "rcc item" $args {-for -span -width}]
        
        set id [DefineItem rcc]

        # TBD: Validate options
        
        dict set meta(item-$id) text $label
        SaveOptions $id $opts
    }

    # FormSelector field ?options...? selscript
    #
    # field     - The label name
    # selscript - The selector definition script
    #
    # Options:
    #     -tip       - Tool tip string
    #     -loadcmd   - Load command
    #     -defvalue  - Default value
    #     -context   - Flag, field is an uneditable context field.
    #     -invisible - Flag, field is invisible.
    #     -listcmd   - A command that filters the list of cases to display.
    #
    # Defines a selector item with the given field name and tool tip.
    # By default, the selector contains all of the cases; however, a 
    # -listcmd can be used to specify the precise list to show.  This would
    # be used, for example, when the valid cases depend on context.

    proc FormSelector {field args} {
        # FIRST, grab the definition script
        set script [lindex $args end]
        set args [lrange $args 0 end-1]

        # NEXT, parse the options
        set opts [GetOpts "selector" $args \
            {-tip -loadcmd -defvalue -context -invisible -listcmd}]

        # NEXT, save the item data
        set id [DefineField selector $field $opts]

        # NEXT, prepare to load the cases
        dict set meta(item-$id) dict    [dict create]
        dict set meta(item-$id) cases   [dict create]

        # NEXT, Prepare to execute the selector script
        set old(selector) $compile(selector)
        set old(case)     $compile(case)

        set compile(selector) $id
        set compile(case)     ""

        # NEXT, execute the selector script
        if {[catch {
            $compile(sinterp) eval $script
        } result eopts]} {
            return {*}$eopts "selector $field, $result" 
        }

        # NEXT, pop the selector stack
        set compile(selector) $old(selector)
        set compile(case)     $old(case)
    }

    # FormCase case label script 
    #
    # case   - The selector case symbol
    # label  - The human-readable label for this case
    # script - The field definition script for this case
    #
    # Defines one selector case.

    proc FormCase {case label script} {
        set sid $compile(selector)

        require {![dict exists $meta(item-$sid) dict $case]} \
            "Duplicate case \"$case\""

        dict set meta(item-$sid) dict $case $label
        dict set meta(item-$sid) cases $case [list]

        set compile(case) $case

        if {[catch {
            $compile(finterp) eval $script
        } result eopts]} {
            return {*}$eopts "case $case, $result"
        }
    }

    # FormWhen expr tscript ?"else" fscript" 
    #
    # expr    - A boolean expression
    # tscript - The "true" definition script.
    # fscript - The "false" definition script.
    #
    # Defines a boolean selector item. The expr can contain upstream
    # fields, like a -listcmd or -dictcmd.  If it is true (1) the 
    # tscript case is used; otherwise, the fscript case is used.

    proc FormWhen {expr tscript {"else" ""} {fscript ""}} {
        # FIRST, save the item data
        set id [DefineItem when]
        dict set meta(item-$id) expr $expr

        # NEXT, prepare to load the cases
        dict set meta(item-$id) dict    [dict create]
        dict set meta(item-$id) cases   [dict create]

        # NEXT, Prepare to execute the case scripts
        set old(selector) $compile(selector)
        set old(case)     $compile(case)

        set compile(selector) $id
        
        # NEXT, execute the true script
        FormCase 1 true  $tscript
        FormCase 0 false $fscript 

        # NEXT, pop the selector stack
        set compile(selector) $old(selector)
        set compile(case)     $old(case)
    }

    #-------------------------------------------------------------------
    # Definition Utilities

    # GetOpts entity optNames arglist
    #
    # entity    - The entity type, e.g., "entry field"
    # arglist   - Argument list containing the options
    # optNames  - List of options to load
    #
    # Parses the named options from the arglist, returning a dict
    # of the parsed values. Options that do not appear in the arglist 
    # get an empty value. Throws an error on unexpected option names.
    #
    # It is up to the caller to validate the values.

    proc GetOpts {entity arglist optNames} {
        # FIRST, initialize the options
        set opts [dict create]
        foreach opt $optNames {
            dict set opts $opt ""
        }

        # NEXT, parse out the options.
        while {[llength $arglist] > 0} {
            set opt [lshift arglist]

            if {$opt in $optNames} {
                dict set opts $opt [lshift arglist]
            } else {
                error "Unknown $entity option \"$opt\""
            }
        }

        return $opts
    }
    
    # 
    # DefineItem itype
    #
    # itype - The item type
    #
    # Returns the ID of a new item of the given type.  Adds the ftype and
    # itype entries to the item dict, and appends the ID to the form type's
    # list of items.

    proc DefineItem {itype} {
        # FIRST, create the item.  Assume it has no associated widget.
        set id [incr meta(idcounter)]

        set meta(item-$id) [dict create \
            ftype  $compile(ftype)      \
            itype  $itype               \
            widget 0]

        # NEXT, add it to the form and to its parent.
        lappend meta(all-$compile(ftype)) $id
        AddToParent $id

        # NEXT, return the ID
        return $id
    }

    # AddToParent id
    #
    # id   - An item ID
    #
    # Adds the item ID to either the top-level or the current selector.

    proc AddToParent {id} {
        # FIRST, save it in its parent
        if {$compile(selector) eq ""} {
            # It's a top-level item
            lappend meta(top-$compile(ftype)) $id
        } else {
            # It's defined in a selector
            set sid $compile(selector)
            set casedict [dict get $meta(item-$sid) cases]

            dict lappend casedict $compile(case) $id

            dict set meta(item-$sid) cases $casedict
        }
    }

    # DefineField itype field opts
    #
    # itype   - The item type 
    # field   - The field aname
    # opts    - Dictionary of validated field options
    #
    # Defines a new field item, saving the data.
    # Returns the item ID.

    proc DefineField {itype field opts} {
        # FIRST, define it as an item.
        set id [DefineItem $itype]

        dict set meta(item-$id) field     $field
        dict set meta(item-$id) widget    1 

        SaveOptions $id $opts

        if {[dict get $meta(item-$id) context] eq ""} {
            dict set meta(item-$id) context 0
        }

        if {[dict get $meta(item-$id) invisible] eq ""} {
            dict set meta(item-$id) invisible 0
        }

        ladd meta(fields-$compile(ftype)) $field

        # If -context yes, can only be at top level.
        if {[dict get $meta(item-$id) context] &&
            $compile(selector) ne ""
        } {
            error "Fields with -context must be at top level"
        }

        return $id
    }

    # SaveOptions id opts
    #
    # id     - Item ID
    # opts   - Options dictionary
    #
    # Saves the options as item attributes

    proc SaveOptions {id opts} {
        dict for {opt val} $opts {
            set attr [string range $opt 1 end]
            dict set meta(item-$id) $attr $val
        }
    }

    #-------------------------------------------------------------------
    # Commands for use by field types

    # asoptions idict attr...
    #
    # idict   - Item definition dictionary
    # attr... - Attributes to turn into options
    #
    # Retrieves the attribute values, and if not-empty turns them into
    # options, which it returns as a list.  An attribute can be specified
    # as a bare name, or as a name/option pair.  In the first case,
    # the option is the name with a hyphen; in the latter, the given
    # option is used.

    proc asoptions {idict args} {
        set result [list]

        foreach pair $args {
            if {[llength $pair] == 2} {
                lassign $pair attr opt
            } else {
                set attr [lindex $pair 0]
                set opt -$attr
            }

            if {[dict get $idict $attr] ne ""} {
                lappend result $opt [dict get $idict $attr]
            }
        }

        return $result
    }

    # formcall vdict_ cmd_
    #
    # vdict_   - A field value dictionary
    # cmd_     - A -listcmd or -dictcmd, etc., that might contain
    #            field name interpolations.
    #
    # Evaluates the command in a scope with the field name variables
    # defined, using [eval] so that proper argument substitution is done.

    proc formcall {vdict_ cmd_} {
        # FIRST, bring the field variables into scope.
        dict with vdict_ {
            # NEXT, evaluate the command in that scope, and return
            # the rulset.
            return [eval $cmd_]
        }
    }

    # formexpr vdict_ expr_
    #
    # vdict_   - A field value dictionary
    # expr_    - A boolean expression that might contain
    #            field name interpolations.
    #
    # Evaluates the expression in a scope with the field name variables
    # defined.

    proc formexpr {vdict_ expr_} {
        # FIRST, bring the field variables into scope.
        dict with vdict_ {
            # NEXT, evaluate the expression in that scope, and return
            # the result.
            return [expr $expr_]
        }
    }

    # list2dict list
    #
    # list   - A list of unique items
    #
    # Converts the list to a dictionary where the keys and values are
    # the same.

    proc list2dict {list} {
        set result [dict create]

        foreach value $list {
            dict set result $value $value
        }

        return $result
    }
    
    #-------------------------------------------------------------------
    # Type Introspection

    # types
    #
    # Returns a list of the defined form types.

    typemethod types {} {
        return $meta(types)
    }

    # allitems ftype
    #
    # Returns the IDs of all items associated with the ftype.

    typemethod allitems {ftype} {
        if {![info exists meta(all-$ftype)]} {
            return ""
        }

        return $meta(all-$ftype)
    }

    # topitems ftype
    #
    # Returns the IDs of all top-level items associated with the ftype.

    typemethod topitems {ftype} {
        if {![info exists meta(top-$ftype)]} {
            return ""
        }

        return $meta(top-$ftype)
    }

    # fields ftype
    #
    # ftype - A form type
    #
    # Returns the names of the fields 
    # associated with this form type.

    typemethod fields {ftype} {
        if {![info exists meta(fields-$ftype)]} {
            return ""
        }

        return $meta(fields-$ftype)
    }

    # context ftype
    #
    # ftype  - A form type
    #
    # Returns a list of the names of the context fields for this form
    # type.

    typemethod context {ftype} {
        set names [list]

        if {![info exists meta(all-$ftype)]} {
            return ""
        }

        foreach id $meta(all-$ftype) {
            if {[dict exists $meta(item-$id) field] &&
                [dict get $meta(item-$id) context]
            } {
                lappend names [dict get $meta(item-$id) field]
            }
        }

        return $names
    }

    # layout ftype
    #
    # ftype - A form type
    #
    # Returns the name of the form's default layout algorithm.

    typemethod layout {ftype} {
        if {![info exists meta(layout-$ftype)]} {
            return ""
        }

        return $meta(layout-$ftype)
    }

    # height ftype
    #
    # ftype - A form type
    #
    # Returns the name of the form's default height.

    typemethod height {ftype} {
        if {![info exists meta(height-$ftype)]} {
            return ""
        }

        return $meta(height-$ftype)
    }

    # width ftype
    #
    # ftype - A form type
    #
    # Returns the name of the form's default width.

    typemethod width {ftype} {
        if {![info exists meta(width-$ftype)]} {
            return ""
        }

        return $meta(width-$ftype)
    }

    # shrink ftype
    #
    # ftype - A form type
    #
    # Returns the name of the form's default shrink-to-fit flag 

    typemethod shrink {ftype} {
        if {![info exists meta(shrink-$ftype)]} {
            return ""
        }

        return $meta(shrink-$ftype)
    }



    # item id ?attr?
    #
    # id     - An item ID
    # attr   - An attribute name
    #
    # Returns the value of the id's attribute, or the entire item 
    # dictionary if attr is omitted.  Returns the empty string if there's
    # no matching data.

    typemethod item {id {attr ""}} {
        if {![info exists meta(item-$id)]} {
            return ""
        }

        if {$attr eq ""} {
            return $meta(item-$id)
        }

        if {[dict exists $meta(item-$id) $attr]} {
            return [dict get $meta(item-$id) $attr] 
        }

        return ""
    }

    # cases ftype field vdict
    #
    # ftype - A form type
    # field - A selector field name
    # vdict - A partial dictionary of field values.
    #
    # Returns the selector cases for the named selector field in the
    # context of the value dictionary, or if the selector cannot be
    # reached, returns an empty list.

    typemethod cases {ftype field vdict} {
        require {[info exists meta(top-$ftype)]} \
            "Undefined form type: \"$ftype\""

        $type Traverse $ftype vdict {
            # id, idict, and itype are available
            if {$itype eq "selector" &&
                [dict get $idict field] eq $field
            } {
                return [dict keys [dict get $idict cases]]
            }
        }

        return [list]
    }


    # fill ftype vdict
    #
    # ftype      - A form type
    # vdict      - A partial dictionary of field values. 
    #
    # Returns a value dictionary with default values inserted for 
    # missing fields.  A field is presumed to be missing if it has no 
    # key or if its value is "".  The structure of the form is taken 
    # into account.
    
    typemethod fill {ftype vdict} {
        require {[info exists meta(top-$ftype)]} \
            "Undefined form type: \"$ftype\""

        $type Traverse $ftype vdict {
            # id, idict, and itype are available
            if {[dict exists $idict field]} {
                set field [dict get $idict field]

                if {![dict exists $vdict $field] ||
                    [dict get $vdict $field] eq ""
                } {
                    dict set vdict $field [dict get $idict defvalue]
                }
            }
        }
        
        return $vdict
    }

    # prune ftype vdict
    #
    # ftype      - A form type
    # vdict      - A partial dictionary of field values. 
    #
    # Returns a value dictionary with default values inserted for 
    # missing fields.  A field is presumed to be missing if it has no 
    # key or if its value is "".  The structure of the form is taken 
    # into account.
    
    typemethod prune {ftype vdict} {
        require {[info exists meta(top-$ftype)]} \
            "Undefined form type: \"$ftype\""

        # FIRST, prepare to accumulate the results.
        set result $vdict

        $type Traverse $ftype vdict {
            # id, idict, and itype are available

            if {[dict exists $idict field]} {
                set field [dict get $idict field]

                # FIRST, if there's no value, put in a "" so that
                # when expressions won't crash.

                if {![dict exists $vdict $field]} {
                    dict set vdict $field ""
                }
                    
                # NEXT, if the value in vdict is the default, remove it
                # from the result.
                if {[dict get $vdict $field] eq [dict get $idict defvalue]} {
                    set result [dict remove $result $field]
                }
            }
        }
        
        return $result
    }

    # Traverse ftype vdictVar script
    #
    # ftype    - A form type
    # vdictVar - Name of a dictionary of field names and values
    # script   - A script to execute for each selected item ID
    #
    # Traverses the selected items, starting with the toplevel items
    # and working down, handling selector cases in the context of the
    # vdict.  The script is called for each item.
    #
    # The script is executed in the caller's context, so that the caller's
    # variables are visible.  In addition, the following variables are
    # made available to the script:
    #
    #   id     - The current item's ID
    #   idict  - The current item's definition dictionary
    #   itype  - The current item's item type
    #
    # The vdict variable belongs to the caller, and thus is visible in
    # the script; and changes to it by the script will be taken into account
    # while traversing the tree.

    typemethod Traverse {ftype vdictVar script} {
        # FIRST, make the relevant variables visible in the caller
        upvar 1 $vdictVar vdict
        upvar 1 id id
        upvar 1 idict idict
        upvar 1 itype itype

        # NEXT, get the list of candidate items.
        set candidates $meta(top-$ftype)

        while {[llength $candidates] > 0} {
            # FIRST, get the data for this item
            set id    [lshift candidates]
            set idict $meta(item-$id)
            set itype [dict get $idict itype]

            # NEXT, call the user's script, handling "continue".
            set code [catch {uplevel 1 $script} result erropts]

            # If they returned normally, we're OK.  If they "continue"'d,
            # they've already skipped the code they wanted to skip,
            # so again we're OK.  If they did anything else, including
            # "break", we need to rethrow.

            if {$code == 2} {
                dict incr erropts -level
                return {*}$erropts $result
            } elseif {$code != 0 && $code != 4} {
                return {*}$erropts $result
            }
            
            # NEXT, Insert child items into the list.
            set case ""

            if {$itype eq "selector"} {
                set field [dict get $idict field]
                if {[dict exists $vdict $field]} {
                    set case [dict get $vdict $field]
                }
            } elseif {$itype eq "when"} {
                set expr [dict get $idict expr]
                # Don't assume that the vdict is fully populated.
                catch {
                    set case [formexpr $vdict $expr] 
                }
            }

            if {$case ne "" && [dict exists $idict cases $case]} {
                set children [dict get $idict cases $case]
                set candidates [concat $children $candidates]
            }
        }
    }

    # dump ftype
    #
    # ftype - A form type
    #
    # Returns a pretty-printed item tree for the form type.

    typemethod dump {ftype} {
        # FIRST, do we have one?
        if {$ftype ni $meta(types)} {
            return ""
        }

        # NEXT, output the list of fields
        set output ""
        append output \
            "Form Type: $ftype\n" \
            "Layout:    $meta(layout-$ftype)\n" \
            "Fields:    [join $meta(fields-$ftype) {, }]\n"

        append output "Items:\n"

        foreach id $meta(top-$ftype) {
            append output [DumpItem 1 $id]
        } 

        return $output
    }

    # DumpItem level id
    #
    # level    - The dump level: 1 for top-level items, increasing with
    #            selector/case levels.
    # id       - The id to display
    #
    # Returns a dump of the given item, indented as required.

    proc DumpItem {level id} {
        set prefix [string repeat "    " $level]
        set itype  [dict get $meta(item-$id) itype]
        set next   [expr {$level+1}]

        append output "${prefix}($id) $itype\n"

        switch -exact -- $itype {
            c         -
            cc        -
            field     -
            label     -
            rc        -
            rcc       {
                append output [DumpAttrs $next $id]
            }

            selector -
            when     {
                append output [DumpAttrs $next $id] 

                set casedict [dict get $meta(item-$id) cases]
                foreach case [dict keys $casedict] {
                    append output [DumpCase $next $id $case]
                }
            }
        }

        return $output
    }

    # DumpAttrs level id
    #
    # level   - Indentation level
    # id      - item id
    #
    # Dumps the list of attributes and values at the given indentation
    # level.

    proc DumpAttrs {level id} {
        # FIRST, get the item type
        set itype [dict get $meta(item-$id) itype]

        # NEXT, output the data.
        set attrs $itypeAttrs($itype)

        if {$itype eq "field"} {
             lappend attrs {*}[[dict get $meta(item-$id) ft] attributes]
        }

        set wid [lmaxlen $attrs]

        set output ""
        set p [string repeat "    " $level]
        foreach attr $attrs {
            set value [dict get $meta(item-$id) $attr]
            append output \
                [format "$p%-*s = <%s>\n" $wid $attr $value]
        }

        return $output
    }
    

    # DumpCase level id case
    #
    # level    Indentation level
    # id       selector id
    # case     selector case
    #
    # Dumps the case at the specified indentation level.

    proc DumpCase {level id case} {
        set output ""
        set p [string repeat "    " $level]

        set label [dict get $meta(item-$id) dict $case]
        append output "${p}case $case \"$label\"\n"

        foreach cid [dict get $meta(item-$id) cases $case] {
            append output [DumpItem [expr {$level+1}] $cid]
        } 

        return $output
    }
}

