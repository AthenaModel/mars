#-----------------------------------------------------------------------
# FILE: dynaview.tcl
#
#   dynaview(n) -- Dynamic Form Widget
#
# PACKAGE:
#   marsgui(n) -- Mars GUI Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
# BUGS:
#    * Tab traversal mostly appears to be working, though there are some 
#      hidden tab stops.  Need to look into this further.
#      * Might be a listfield issue.
#    * -shrinkwrap doesn't work quite right with enumlists; it wants to
#      wrap it when it shouldn't. (This might be a problem with listfield.)
#      It's OK if the form is stretched wider due to other content, though.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export dynaview
}

#-----------------------------------------------------------------------
# dynaview Widget
#
# This is a prototype widget to display dynaform(n) dynamic entry
# forms.
#-----------------------------------------------------------------------

snit::widget ::marsgui::dynaview {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Type Variables 

    typevariable styles {
        /* TBD: This should possibly be a standard htmlframe(n) style. */
        BODY { margin: 2px; }

        /* Classes for coloring field labels */
        .invalid { 
            color: red;   
        }
        .normal  { 
            color: black; 
        }

        /* This seems to handle the INPUT tag's vertical alignment problem
         * somewhat better than "center".  With "center", text following
         * an <input> in a table cell is offset vertically for some reason. 
         * Keep an eye on this, though; it might differ for different fonts.
         */
        INPUT { vertical-align:-6px } 
    }

    #-------------------------------------------------------------------
    # Components

    component hf   ;# htmlframe

    #-------------------------------------------------------------------
    # Options
    #
    # Unknown options are delegated to the hull.

    delegate option * to hull

    # -formtype ftype
    #
    # Required; read-only after creation.  Specifies the form type this 
    # widget should use.

    option -formtype \
        -validatemethod  ValidateFormtype \
        -configuremethod ConfigFormtype

    method ValidateFormtype {opt val} {
        require {$val in [dynaform types]} "Unknown -formtype \"$val\""
    }

    method ConfigFormtype {opt val} {
        # FIRST, get the new form type
        set options($opt) $val
        set ftype $options(-formtype)

        # NEXT, get rid of any existing child widgets, first clearing the
        # current HTML layout.  (Note: that might not be necessary, but
        # it seems desirable.)
        $hf reset
        foreach w $info(fwidgets) {
            destroy $w
        }

        # NEXT, clean up all metadata.
        array unset info
        array set info {
            fwidgets      {}
            itemsInLayout {}
            inSet         0
            current       ""
            invalid       {}
        }

        # NEXT, configure the frame.
        set opts [list -shrink [dynaform shrink $ftype]]

        if {![dynaform shrink $ftype]} {
            lappend opts -width [dynaform width $ftype]
            lappend opts -height [dynaform height $ftype]
        }

        $hf configure {*}$opts

        # NEXT, create the field widgets
        foreach id [dynaform allitems $ftype] {
            if {[dynaform item $id widget]} {
                $self CreateWidget $id
            }
        }

        # NEXT, clear the data and do the initial layout
        $self clear 

        # NEXT, apply the -state
        $self ShowState
    }

    # -changecmd cmd
    #
    # Specifies a command to be called whenever any field's value
    # changes, for any reason whatsoever (including explicit calls to
    # set). A list of the names of the changed fields is appended to the 
    # command as an argument.

    option -changecmd \
        -default ""

    # -currentcmd
    #
    # Specifies a command to be called when one of the field widgets
    # receives the focus.  The field name is appended to the command
    # as an argument.

    option -currentcmd \
        -default ""

    # -state
    #
    # *normal* or *disabled*  The set command still works when the
    # state is disabled. 

    option -state \
        -default         normal                                 \
        -type            {snit::enum -values {normal disabled}} \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val

        $self ShowState
    }


    #-------------------------------------------------------------------
    # Instance Variables

    # Form type (for convenience)
    variable ftype ""

    # info: info array
    #
    # fwidgets        - Window names of the field widgets
    # itemsInLayout   - A list of the IDs of the items that were last
    #                   layed out by the Layout command.  This is saved
    #                   for the Layout command's use in checking whether
    #                   the layout has changed.  Use Traverse to acquire
    #                   such a list for other purposes.
    # inSet           - Flag: in [set] method.  If so, setting a field should
    #                   not cause the -changecmd to be called; instead, we'll
    #                   call it when [set] is complete.
    # current         - Item ID of the field widget with the focus.
    # invalid         - List of names of fields that have been marked invalid.
    # w-$id           - Window name for item ID
    # f-$id           - For convenience, field name for item ID

    variable info -array {
        fwidgets        {}
        itemsInLayout   {}
        inSet           0
        current         ""
        invalid         {}
    }

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor args
    #
    # Creates the widget given the options.

    constructor {args} {
        # FIRST, create the htmlframe.
        install hf using htmlframe $win.hf \
            -styles $styles

        pack $hf -fill both -expand yes

        # NEXT, apply the options.
        $self configurelist $args
    }


    #-------------------------------------------------------------------
    # Field Widget Creation

    # CreateWidget id
    #
    # id - An item ID
    #
    # Creates field widgets

    method CreateWidget {id} {
        set idict [dynaform item $id]
        
        # FIRST, determine the widget name, and cache some data.
        set w $hf.item$id
        set f [dict get $idict field]
        set info(w-$id) $w
        set info(f-$id) $f
        lappend info(fwidgets) $w
    
        # NEXT, create the widget
        set opts [list]

        switch -exact -- [dict get $idict itype] {
            field {
                set ft [dict get $idict ft]
                $ft create $w $idict 
                $w configure \
                    -changecmd [mymethod FieldChange $id $f] \
            }

            selector {
                enumfield $w \
                    -autowidth   yes                              \
                    -displaylong 1                                \
                    -values      [dict get $idict dict]           \
                    -changecmd   [mymethod SelectorChange $id $f]
            }
        }

        # NEXT, detect which widget has the focus.
        bind $w <FocusIn> [mymethod CurrentFieldCmd $id]
    }

    #-------------------------------------------------------------------
    # Handlers

    # SelectorChange id field newCase
    #
    # id       - Item ID of a selector item
    # field    - The field name of the selector item
    # newCase  - The newly selected case symbol
    #
    # If the case has actually changed, lays out the form again.

    method SelectorChange {id field newCase} {
        # FIRST, if we're in [set], do nothing.  We'll re-layout, etc.,
        # at the proper time.
        if {$info(inSet)} {
            return
        }

        # NEXT, reconfigure the widgets
        set ids [$self ReconfigureAfter $id]

        # NEXT, redo the layout; we've got a new selector case (or "")
        $self Layout $ids

        # NEXT, call the -changecmd
        callwith $options(-changecmd) [list $field]
    }

    # FieldChange id newValue
    #
    # id        - Item ID of a visible field item
    # field     - The field name of the selector item
    # newValue  - The new field value.
    #
    # Calls the -changecmd on a single field change.

    method FieldChange {id field newValue} {
        # FIRST, if we're in [set], do nothing.
        if {$info(inSet)} {
            return
        }

        # NEXT, reconfigure the widgets, and re-layout if need be.
        $self Layout [$self ReconfigureAfter $id]

        # NEXT, call the -changecmd
        callwith $options(-changecmd) [list $field]
    }

    # CurrentFieldCmd
    #
    # Called when a field widget receives the focus.  Remembers the 
    # item ID of the field, and calls the -currentcmd.

    method CurrentFieldCmd {id} {
        set info(current) $id

        callwith $options(-currentcmd) [dynaform item $id field]
    }

    #-------------------------------------------------------------------
    # Layout Algorithms
    # 
    # A layout algorithm is a routine that takes the items on the
    # selected line of descent and returns HTML that lays them out in
    # the htmlframe.  By convention, text displayed in the form that is
    # related to a particular field should use the <label for=> element
    # to associate itself.  The value of the for= attribute should be
    # the *field name*, not the item ID; only one item with a given
    # field name will be visible at a time, and this allows the text
    # to be colored according to the field's state using the htmlframe's
    # API.

    # Layout ids
    #
    # ids - The IDs of the items to layout.
    #
    # Lays out the widget given the selected layout algorithm.  This
    # involves creating an HTML string.
    #
    # The command needs to be told which items to lay out.  Such lists
    # are produced by the DoSet and ReconfigureAfter commands, and by
    # Traverse.
    #
    # TBD: If desired, we can cache the layout strings.

    method Layout {ids} {
        # FIRST, has the layout changed?
        if {$ids eq $info(itemsInLayout)} {
            return
        }

        # FIRST, call the layout algorithm.
        switch -exact -- [dynaform layout $ftype] {
            ncolumn { set html [$self LayoutNColumn $ids] }
            2column { set html [$self LayoutTwoColumn $ids] }
            ribbon  { set html [$self LayoutRibbon $ids]    }
            default { error "Unknown layout algorithm" }
        }

        # NEXT, apply the computed layout
        $hf layout $html

        # NEXT, if there are invalid fields, mark them.
        if {[llength $info(invalid)] > 0} {
            $self invalid $info(invalid)
        }

        # NEXT, remember that we've done this layout
        set info(itemsInLayout) $ids

        lassign [$hf bbox] x y wid ht

        if {$wid > [$hf cget -width]} {
            $hf configure -width $wid
        }

        if {$ht > [$hf cget -height]} {
            $hf configure -height $ht
        }
    }

    # LayoutNColumn ids
    #
    # ids    - The IDs of the items to layout.
    #
    # This routine does a table layout, with row and column breaks
    # expressly indicated by the dynaform.

    method LayoutNColumn {ids} {
        # FIRST, begin the layout, including the first row.
        set html_ "<table>\n<tr>\n"
        set atBeginning 1

        # NEXT, begin the first column.  If the first item is an rc or
        # rcc, use its span.
        set fid [lindex $ids 0]
        if {[dynaform item $fid itype] in {rc rcc}} {
            set span  [dynaform item $fid span]
            set width [dynaform item $fid width]
        } else {
            set span  ""
            set width ""
        }

        append html_ [TD $span $width]

        # NEXT, layout each of the items.
        foreach id $ids {
            set idict_ [dynaform item $id]
            dict with idict_ {}

            # FIRST, layout field widgets, ignoring invisible widgets.
            if {$widget} {
                if {!$invisible} {
                    set name_ "item$id"
                    append html_ "<input name=\"item$id\">"

                    if {$tip ne ""} {
                        DynamicHelp::add $info(w-$id) -text $tip
                    } 
                }

                set atBeginning 0
                continue
            }

            # NEXT, handle labels and formatting items
            switch -exact -- $itype {
                br {
                    append html_ "<br>"
                }

                c {
                    append html_ "</td>\n[TD $span $width]"

                    if {$text ne ""} {
                        append html_ [LayoutLabel $id]
                    }
                }

                cc {
                    append html_ "</td>\n<td>"

                    append html_ [LayoutLabel $id]

                    append html_ "</td>\n[TD $span $width]"
                }

                label {
                    append html_ [LayoutLabel $id]
                }

                para {
                    append html_ "<p>"
                }

                rc {
                    if {!$atBeginning} {
                        append html_ "</td></tr>\n<tr>[TD $span $width]"
                    }

                    if {$text ne ""} {
                        append html_ [LayoutLabel $id]
                    }
                }

                rcc {
                    if {!$atBeginning} {
                        append html_ "</td></tr>\n<tr><td>"
                    }

                    append html_ [LayoutLabel $id]
                
                    append html_ "</td>\n[TD $span $width]"
                }
            }

            set atBeginning 0
        }

        append html_ "</td>\n</tr>"
        append html_ "</table>\n"

        return $html_
    }

    # TD span width
    #
    # Returns a <td> tag, with a colspan and a width if desired.

    proc TD {span width} {
        set attrs ""

        if {$span ne ""} {
            append attrs " colspan=\"$span\""
        }

        if {$width ne ""} {
            append attrs " width=\"$width\""
        }

        return "<td$attrs>"
    }

    # LayoutLabel id ?bold?
    #
    # Returns the HTML for a label item

    proc LayoutLabel {id {mode ""}} {
        set idict_ [dynaform item $id]
        dict with idict_ {}

        set html_ " "

        if {$mode eq "bold"} {
            append html_ "<b>"
        }
        if {$for eq ""} {
            append html_ "$text"
        } else {
            append html_ "<label for=\"$for\">[nbsp $text]</label>"
        }

        if {$mode eq "bold"} {
            append html_ "</b>"
        }

        append html_ " "

        return $html_
    }

    # LayoutTwoColumn ids
    #
    # ids    - The IDs of the items to layout.
    #
    # This routine does a classic two-column order dialog layout,
    # using the field tooltips as the labels.

    method LayoutTwoColumn {ids} {
        # FIRST, begin the layout.
        set html_ "<table>\n"

        foreach id $ids {
            set idict_ [dynaform item $id]
            dict with idict_ {}

            # We only care about the visible field widgets and their
            # tool tips.
            if {!$widget || $invisible} {
                continue
            }

            set name_ "item$id"

            if {$tip eq ""} {
                set tip $field
            }

            append html_ \
                "<tr><td>\n" \
                "<label for=\"$field\">[nbsp $tip:]</label>" \
                "</td>\n" \
                "<td><input name=\"$name_\"></td></tr>\n"
        }

        append html_ "</table>\n"

        return $html_
    }

    # LayoutRibbon ids
    #
    # ids    - The IDs of the items to layout.
    #
    # This routine does a horizontal ribbon layout.  Field tool tip strings
    # are actually used as tool tips; boilerplate text is provided by the
    # "text" item.  Text items with the -for option set are entered as
    # "<label for=...>" for a field, and will change color when the field
    # is invalid.

    method LayoutRibbon {ids} {
        # FIRST, begin the layout.
        set html_ "<body>\n"

        foreach id $ids {
            set idict_ [dynaform item $id]
            dict with idict_ {}

            # FIRST, add text items.
            if {$itype eq "label"} {
                if {$for ne ""} {
                    append html_ "<label for=\"$for\">$text</label>"
                } else {
                    append html_ "$text\n"
                }
            } elseif {$widget && !$invisible} {
                # Add fields
                append html_ " <input name=\"item$id\">\n"

                if {$tip ne ""} {
                    DynamicHelp::add $info(w-$id) -text $tip
                } 
            }
        }

        append html_ "<p>"
        append html_ "</body>\n"

        return $html_
    }

    # nbsp text
    #
    # text - Some HTML prose.
    # 
    # Converts all space characters in the prose into non-breaking
    # spaces (&nbsp;).
    proc nbsp {text} {
       return [string map {" " &nbsp;} $text]
    }

    #-------------------------------------------------------------------
    # Set and Field Configuration Logic
    #
    # When a field's value changes, the configuration of downstream
    # fields (e.g., an enumerated list) can also change.  This needs
    # to be handled carefully however the field's value changes, whether
    # due to a programmatic [set] or a user GUI interaction.  This
    # section contains the routines implementing the relevant logic.
    #
    # [DoSet] is called when the application calls the [$df set] method;
    # [ReconfigureAfter] is called when user changes a field value.

    # DoSet dict
    #
    # dict - Dictionary of field names and values to set.
    #
    # Actually sets the field values, updating selectors and so forth,
    # in response to a programmatic [$df set] call.  Returns
    # a pair: a list of the traversed IDs, and a list of the names of the 
    # fields that really changed.

    method DoSet {dict} {
        # FIRST, save the current values, so we can see if there are 
        # any changes.
        set old [$self get]

        # NEXT, start at the top and work down, assigning values to fields.
        set ids [$self Traverse {
            # FIRST, We're only interested in field widgets.
            if {![dict get $idict widget]} {
                continue
            }

            # NEXT, since we know we've got a field, we can retrieve its
            # name.
            set f [dict get $idict field]

            # NEXT, reconfigure the field.  The vdict is accumulated by
            # Traverse.
            $self ReconfigureField $vdict $id $idict

            # NEXT, see if there's a new value.
            if {[dict exists $dict $f]} {
                # FIRST, set the new value
                $info(w-$id) set [dict get $dict $f]

                # NEXT, if there's a load command, load subsequent values.
                set loadcmd [dict get $idict loadcmd]

                if {$loadcmd ne ""} {
                    # FIRST, get the dictionary of loaded values.
                    set loaded [{*}$loadcmd $idict [$info(w-$id) get]] 
                    
                    # NEXT, explicitly set values have priority; so
                    # merge the explicitly set values into the loaded
                    # values.
                    set dict [dict merge $loaded $dict]
                }
            }
        }]

        # NEXT, Determine what changed 
        set changed [list]

        dict for {field value} [$self get] {
            if {$value ne [dict get $old $field]} {
                lappend changed $field
            }
        }

        return [list $ids $changed]
    }


    # ReconfigureAfter cid 
    #
    # cid  - The item ID of the field changed interactively by the user,
    #        or "".
    #
    # When a field is changed interactively by the user, this routine is
    # called.  It is responsible for reconfiguring any downstream fields
    # with a -listcmd or -dictcmd, as these can depend on upstream field
    # values.  
    #
    # This routine is also called on creation, to do the initial
    # configuration.
    #
    # Returns a list of the IDs of the traversed items.
    
    method ReconfigureAfter {cid} {
        # FIRST, fields with -loadcmd's might provide new values for
        # downstream fields.  The changed field, in particular, might
        # have a load command.  Begin to build up a dict of loaded data.
        set newdata [dict create]

        if {$cid ne ""} {
            set loadcmd [dynaform item $cid loadcmd]

            if {$loadcmd ne ""} {
                set newdata [{*}$loadcmd [dynaform item $cid] \
                                [$info(w-$cid) get]]
            }
        }

        # NEXT, fields up to and including cid don't need to be reconfigured.
        # So we need to detect that.  If cid is "", then everything needs
        # to be reconfigured.

        set gotCid [expr {$cid eq ""}] 

        # NEXT, we need to do the usual traversal, starting at the top.
        set ids [$self Traverse {
            # FIRST, We're only interested in field widgets.
            if {![dict get $idict widget]} {
                continue
            }
            
            # NEXT, since we know we've got a field, we can retrieve its
            # name.
            set f [dict get $idict field]

            # NEXT, if we haven't gotten past the cid yet,
            # just check to see if this is it.  Otherwise, reconfigure
            # the field.
            if {!$gotCid} {
                if {$id eq $cid} {
                    set gotCid 1
                }
            } else {
                # The vdict is accumulated by Traverse.
                $self ReconfigureField $vdict $id $idict
            }

            # NEXT, see if it has a new value.
            if {[dict exists $newdata $f]} {
                # FIRST, set the new value
                $info(w-$id) set [dict get $newdata $f]

                # NEXT, if there's a load command, load subsequent values.
                set loadcmd [dict get $idict loadcmd]

                if {$loadcmd ne ""} {
                    # FIRST, get the dictionary of loaded values.
                    set loaded [{*}$loadcmd $idict [$info(w-$id) get]] 
                    
                    # NEXT, merge the loaded values into the set
                    # of new values.
                    set newdata [dict merge $newdata $loaded]
                }
            }
        }]

        return $ids
    }

    # ReconfigureField vdict id idict
    #
    # vdict - The value dictionary up to this point.
    # id    - A field ID, or ""
    # idict - The item's definition dictionary.
    #
    # Determines whether the field needs reconfiguration, and if so
    # does it.   As part of reconfiguration, if the field is empty and 
    # there is a default value, the default value is set.

    method ReconfigureField {vdict id idict} {
        # FIRST, configure the field
        switch -exact -- [dict get $idict itype] {
            selector {
                set listcmd [dict get $idict listcmd]

                if {$listcmd ne ""} {
                    set dict [dict create]
                    foreach case [::dynaform::formcall $vdict $listcmd] {
                        dict set dict $case \
                            [dict get $idict dict $case]
                    }

                    if {$dict ne [$info(w-$id) cget -values]} {
                        $info(w-$id) configure -values $dict 
                    }
                }
            }

            field {
                set ft [dict get $idict ft]

                $ft reconfigure $info(w-$id) $idict $vdict

                if {$options(-state) eq "normal" &&
                    ![dict get $idict context]
                } {
                    if {[$ft ready $info(w-$id) $idict]} {
                        $info(w-$id) configure -state normal
                    } else {
                        $info(w-$id) configure -state disabled
                    }
                }
            }

            default {
                # Other fields never need reconfiguring, so this
                # is not an error.
            }
        }

        # NEXT, set default value, if need be.
        if {[$info(w-$id) get] eq ""} {
            $info(w-$id) set [dict get $idict defvalue]
        }
    }

    #-------------------------------------------------------------------
    # Helper Routines

    # SelectedItems
    #
    # This routine returns a list of the IDs of the items on the 
    # selected line of descent.  Traverse does the same thing, when
    # called with no body; but Traverse also updates variables in the
    # caller's scope, which can be surprising.

    method SelectedItems {} {
        return [$self Traverse {}]
    }

    # Traverse script
    #
    # script - A script to execute for each visible item ID
    #
    # Traverses the visible items, starting with the toplevel items
    # and working down, handling selector cases.  The script is called
    # for each item.  Returns a list of the IDs of the items on the
    # selected line of descent.
    #
    # The script is executed in the caller's context, so that the caller's
    # variables are visible.  In addition, the following variables are
    # made available to the script:
    #
    #   id     - The current item's ID
    #   idict  - The current item's definition dictionary
    #   itype  - The current item's item type
    #   vdict  - Field value dictionary.
    #
    # The vdict is accumulated as the traversal proceeds.  It is used
    # as the context for -listcmd and -dictcmd calls by the relevant
    # algorithms.  Note that a field's value is put in the vdict
    # AFTER it has been processed by the user's script.

    method Traverse {script} {
        # FIRST, make the relevant variables visible in the caller
        upvar 1 id id
        upvar 1 idict idict
        upvar 1 itype itype
        upvar 1 vdict vdict

        # NEXT, prepare to accumulate field values.
        set vdict [dict create]

        # NEXT, get the list of candidate items.
        set candidates [dynaform topitems $ftype]
        set ids [list]

        while {[llength $candidates] > 0} {
            # FIRST, get the data for this item
            set id    [lshift candidates]
            set idict [dynaform item $id]
            set itype [dict get $idict itype]

            lappend ids $id

            # NEXT, is there a script?
            if {$script ne ""} {
                # NEXT, call the user's script, handling "continue".
                set code [catch {uplevel 1 $script} result erropts]

                # If they returned normally, we're OK.  If they "continue"'d,
                # they've already skipped the code they wanted to skip,
                # so again we're OK.  If they did anything else, including
                # "break", we need to rethrow.

                if {$code == 2} {
                    # Make an explicit return return through the caller.
                    dict incr erropts -level
                    return {*}$erropts $result
                } elseif {$code != 0 && $code != 4} {
                    return {*}$erropts $result
                }
            }
            
            # NEXT, add the field's current value to the value dictionary.
            if {[dict get $idict widget]} {
                dict set vdict \
                    [dict get $idict field] \
                    [string trim [$info(w-$id) get]]
            }

            # NEXT, Insert child items into the list.
            set case ""

            if {[dict get $idict itype] eq "selector"} {
                set case [$info(w-$id) get]
            } elseif {[dict get $idict itype] eq "when"} {
                set expr [dict get $idict expr]
                set case [::marsutil::dynaform::formexpr $vdict $expr] 
            }

            if {$case ne ""} {
                set children [dict get $idict cases $case]
                set candidates [concat $children $candidates]
            }
        }
        
        return $ids
    }


    # ShowState
    #
    # Sets the field widget -state's consistent with the main widget's
    # own -state.

    method ShowState {} {
        foreach id [dynaform allitems $ftype] {
            set idict [dynaform item $id]

            if {[dict get $idict itype] ne "field" ||
                [dict get $idict context]
            } {
                continue
            }

            if {[info exists info(w-$id)]} {
                set ft [dict get $idict ft]
                set state $options(-state)

                if {![$ft ready $info(w-$id) $idict]} {
                    $info(w-$id) configure -state disabled
                } else {
                    $info(w-$id) configure -state $options(-state)
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # clear
    #
    # Clears all values in the widget, and sets default values (if any)

    method clear {} {
        # FIRST, set all fields to their default values, except for
        # context items. 
        foreach id [dynaform allitems $ftype] {
            if {[dynaform item $id widget] &&
                ![dynaform item $id context] 
            } {
                $info(w-$id) set "" 
            }
        }

        # NEXT, clear the status data.
        set info(itemsInLayout) [list]
        set info(current) ""
        set info(invalid) [list]

        # NEXT, reconfigure everything.
        $self Layout [$self ReconfigureAfter ""]
    }

    # refresh
    #
    # Refreshes the contents of the form in response to application
    # data changes.

    method refresh {} {
        set dict [$self get]
        $self clear
        $self set $dict
    }

    # get
    #
    # Retrieves the value of the form: a dictionary of field names and
    # values.  Fields not on the selected line
    # of descent will have empty values.

    method get {} {
        set result [dict create]

        foreach field [dynaform fields $ftype] {
            dict set result $field ""
        }

        foreach id [$self SelectedItems] {
            if {[info exists info(w-$id)]} {
                dict set result $info(f-$id) [$info(w-$id) get]
            }
        }

        return $result
    }

    # set dict
    # set field value...
    #
    # dict  - A dictionary of field names and values.
    # field - A field name
    # value - A field value
    #
    # Sets the form's value, changing the selected line of descent as
    # necessary, and calls -changecmd for the fields that actually changed.
    # Fields that turn out not be in the selected line of descent are ignored.
    #
    # The field values are specified as a dictionary, either as a single
    # argument or as individual arguments.

    method set {args} {
        # FIRST, mark that we're in the set method, so that we don't get
        # -changecmd called for each individual field.
        set info(inSet) 1

        # NEXT, if there's only argument it's a dictionary.
        if {[llength $args] == 1} {
            set dict [lindex $args 0]
        } else {
            set dict $args
        }

        # NEXT, process the data, being sure to clear the inSet flag even in
        # the case of error.
        try {
            lassign [$self DoSet $dict] ids changed
        } finally {
            set info(inSet) 0
        }

        # NEXT, layout the widget if need be.
        $self Layout $ids

        # NEXT, if any fields actually changed then call the -changecmd.
        if {[llength $changed] > 0} {
            callwith $options(-changecmd) $changed
        }
    }

    # current
    #
    # Returns the name of the field that most recently received the
    # input focus. If none has it, return the first editable widget.

    method current {} {
        set id ""

        if {$info(current) ne ""} {
            set id $info(current)
        } else {
            # Find a visible widget
            foreach id [$self SelectedItems] {
                if {[info exists info(w-$id)] &&
                    ![dynaform item $id invisible]
                } {
                    break
                }
            }
        }

        if {$id ne ""} {
            return [dynaform item $id field]
        } else {
            # Every dynaform should have at least one editable widget; but
            # if it doesn't, here we are.
            return ""
        }
    }

    # invalid ?fields...?
    #
    # fields - A list of zero or more field names, as a single argument
    #          or multiple arguments.
    #
    # Marks particular fields as invalid.  If called with no arguments,
    # returns the list of invalid fields.  Call with an empty list
    # to mark all fields valid.  Labels of invalid fields are displayed 
    # in red.

    method invalid {args} {
        # FIRST, if there are no arguments return the list of
        # invalid fields.
        if {[llength $args] == 0} {
            return $info(invalid)
        }

        # NEXT, get the list of invalid fields
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        set info(invalid) $args

        # NEXT, mark them invalid.
        foreach field [dynaform fields $ftype] {
            if {$field in $info(invalid)} {
                $self SetLabelClass $field invalid
            } else {
                $self SetLabelClass $field normal 
            }
        }

        # NEXT, return the list. 
        return $info(invalid)
    }

    # SetLabelClass field class
    #
    # field  - A field name
    # class  - A CSS class
    #
    # Sets the CSS class of all labels -for the given the
    # field to the given class.

    method SetLabelClass {field class} {
        foreach node [$hf search "label\[for=\"$field\"\]"] {
            $node attribute class $class
        }
    }

    # getlabel field
    #
    # field  - A field name
    #
    # Returns the first label associated with the named field, or "".

    method getlabel {field} {
        set node [lindex [$hf search "label\[for=\"$field\"\]"] 0]

        if {$node ne ""} {
            set tnode [lindex [$node children] 0]

            if {$tnode ne ""} {
                return [string trim [$tnode text] ":"]
            }
        }

        return ""
    }
}

