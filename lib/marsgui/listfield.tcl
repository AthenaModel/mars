#-----------------------------------------------------------------------
# TITLE:
#    listfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Multiple-list selection data entry field
#
#    A listfield is a data entry field that allows the user to
#    select multiple items from a list.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export listfield
}

#-------------------------------------------------------------------
# listfield

snit::widget ::marsgui::listfield {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Components

    component left       ;# Left-hand list (omit)
    component right      ;# Right-hand list (include)
    component includebtn ;# Button: include selected items
    component omitbtn    ;# Button: omit selected items
    component clearbtn   ;# Button: Clear right-hand list

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val

        $self UpdateState
    }

    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new list is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    # -itemdict dict
    #
    # Dictionary of items to choose from.  The lists display
    # "key: value" or "value" depending on the -showkeys setting.
    # "set" and "get" set and return lists of keys.

    option -itemdict \
        -configuremethod ConfigItemDict

    method ConfigItemDict {opt val} {
        set options($opt) $val
        
        $self UpdateDisplay
    }

    # -showkeys flag
    #
    # If yes, the left and right lists show "key: value" for each
    # item; otherwise, just "value".

    option -showkeys \
        -configuremethod ConfigShowKeys \
        -default         yes

    method ConfigShowKeys {opt val} {
        set options($opt) $val
        
        $self UpdateDisplay
    }

    # -height num
    #
    # Number of rows to display in the right and left list
    
    option -height \
        -configuremethod ConfigLists \
        -default         5

    # -stripe flag
    #
    # If 1, the lists are striped; otherwise not.

    option -stripe \
        -configuremethod ConfigLists \
        -default         1


    # -width num
    #
    # Width in characters of each list
    
    option -width \
        -configuremethod ConfigLists \
        -default         15

    method ConfigLists {opt val} {
        set options($opt) $val

        $left  configure -height $options(-height)
        $right configure -height $options(-height)
        
        $left  configure -width $options(-width)
        $right configure -width $options(-width)

        if {$options(-stripe)} {
            $left  configure -stripeheight 1
            $right configure -stripeheight 1
        } else {
            $left  configure -stripeheight 0
            $right configure -stripeheight 0
        }
    }



    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    # current - List of currently included keys

    variable info -array {
        current {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the components
        install left using $self MakeTableList $win.left \
            -columns        {0 "Omit" left}              \
            -yscrollcommand [list $win.leftscroll set]

        bind $left <<TablelistSelect>> [mymethod UpdateState]
        

        ttk::scrollbar $win.leftscroll  \
            -orient  vertical           \
            -command [list $left yview]

        ttk::frame $win.buttons

        install includebtn using ttk::button $win.buttons.include \
            -image     [Icon right]                               \
            -state     disabled                                   \
            -width     1                                          \
            -takefocus 0                                          \
            -command   [mymethod MoveItems include]

        DynamicHelp::add $includebtn \
            -text "Include items"


        install omitbtn using ttk::button $win.buttons.omit \
            -image     [Icon left]                          \
            -state     disabled                             \
            -width     1                                    \
            -takefocus 0                                    \
            -command   [mymethod MoveItems omit]

        DynamicHelp::add $omitbtn \
            -text "Omit items"


        install clearbtn using ttk::button $win.buttons.clear \
            -image     [Icon clear]                           \
            -state     disabled                               \
            -width     1                                      \
            -takefocus 0                                      \
            -command   [mymethod MoveItems clear]

        DynamicHelp::add $clearbtn \
            -text "Clear list of included items"


        pack $includebtn -side top -fill x
        pack $omitbtn    -side top -fill x
        pack $clearbtn   -side top -fill x

        install right using $self MakeTableList $win.right \
            -columns        {0 "Include" left}             \
            -yscrollcommand [list $win.rightscroll set]

        bind $right <<TablelistSelect>> [mymethod UpdateState]

        ttk::scrollbar $win.rightscroll  \
            -orient  vertical            \
            -command [list $right yview]

        grid $left            -column 0 -row 0 -sticky nsew -pady 4 -padx {4 0}
        grid $win.leftscroll  -column 1 -row 0 -sticky ns   -pady 5 -padx {0 4}
        grid $win.buttons     -column 2 -row 0              -pady 4 -padx 4
        grid $right           -column 3 -row 0 -sticky nsew -pady 4 -padx {4 0}
        grid $win.rightscroll -column 4 -row 0 -sticky ns   -pady 5 -padx {0 4}

        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1
        grid columnconfigure $win 3 -weight 1
        
        # NEXT, configure options
        $self configurelist $args

        # NEXT, update the state
        $self UpdateState
    }

    # MakeTableList w ?options...?
    #
    # w            - The name of the widget to create
    # options...   - tablelist options and values
    #
    # Creates a tablelist widget with standard settings for this
    # widget.  Returns the widget name.

    method MakeTableList {w args} {
        if {$options(-stripe)} {
            set stripeHeight 1
        } else {
            set stripeHeight 0
        }

        tablelist::tablelist $w                             \
            -height           $options(-height)             \
            -width            $options(-width)              \
            -borderwidth      1                             \
            -relief           sunken                        \
            -background       white                         \
            -labelbackground  $::marsgui::defaultBackground \
            -labelborderwidth 1                             \
            -activestyle      none                          \
            -font             codefont                      \
            -showlabels       1                             \
            -selectbackground black                         \
            -selectforeground white                         \
            -selectmode       extended                      \
            -selecttype       row                           \
            -exportselection  no                            \
            -stripeheight     $stripeHeight                 \
            -stripebackground #CCFFBB                       \
            {*}$args

        $w columnconfigure 0 -width 2 -stretchable yes -wrap 1 

        return $w
    }

    # Icon name
    #
    # Given the base name of an icon, returns a list setting
    # both the normal and disabled icon values.

    proc Icon {name} {
        return [list ::marsgui::icon::$name \
                    disabled ::marsgui::icon::${name}d]
    }
        

    #-------------------------------------------------------------------
    # Private Methods

    # UpdateDisplay
    #
    # This method is called when a new -itemdict or -showkeys
    # value is given.  It clears any included values, and resets the
    # display.

    method UpdateDisplay {} {
        # FIRST, make sure the tablelists are enabled, so that we can
        # adjust their content.
        $left configure -state normal
        $right configure -state normal

        # NEXT, delete all content from them, and clear the current
        # value.
        $left  delete 0 end
        $right delete 0 end

        set info(current) [list]

        # NEXT, populate the two lists.
        if {[dict size $options(-itemdict)] > 0} {
            set items [list]

            dict for {key value} $options(-itemdict) {
                if {$options(-showkeys)} {
                    lappend items [list "$key: $value"]
                } else {
                    lappend items [list $value]
                }
            }

            $left  insertlist end $items
            $right insertlist end $items
            
            $right togglerowhide 0 end
        }

        # NEXT, update the state of the widgets
        $self UpdateState
    }

    # UpdateState
    #
    # This routine sets the -state of the various components, based
    # on the widget's -state and the selections.

    method UpdateState {} {
        # FIRST, if -state is disabled, everything's disabled.
        if {$options(-state) eq "disabled"} {
            $left       configure -state "disabled"
            $right      configure -state "disabled"
            $includebtn configure -state "disabled"
            $omitbtn    configure -state "disabled"
            $clearbtn   configure -state "disabled"        

            return
        }

        # NEXT, the lists are normal
        $left  configure -state "normal"
        $right configure -state "normal"

        # NEXT, Set the button states
        DisableIf $includebtn {[llength [$left  curselection]] == 0}
        DisableIf $omitbtn    {[llength [$right curselection]] == 0}
        DisableIf $clearbtn   {[llength $info(current)] == 0}
    }

    # DisableIf w expr
    #
    # w     - A widget
    # expr  - A boolean expression
    #
    # Sets the widget's -state to "disabled" if the expression is
    # true, and "normal" otherwise.

    proc DisableIf {w expr} {
        if {[uplevel 1 [list expr $expr]]} {
            $w configure -state disabled
        } else {
            $w configure -state normal
        }
    }


    # MoveItems op
    #
    # op - include | omit | clear
    #
    # Moves the items between the Omit list and the Include list

    method MoveItems {op} {
        # FIRST, move things around.
        switch $op {
            include {
                set items [$self GetSelectedItems $left]

                $left  togglerowhide $items
                $right togglerowhide $items
            }

            omit {
                set items [$self GetSelectedItems $right]

                $left  togglerowhide $items
                $right togglerowhide $items
            }

            clear {
                for {set i 0} {$i < [$left size]} {incr i} {
                    $left  rowconfigure $i -hide 0
                    $right rowconfigure $i -hide 1
                }
            }
        }

        # NEXT, clear the selections; otherwise we can get items
        # selected in both widgets, and that looks odd.
        $left selection clear 0 end
        $right selection clear 0 end

        # NEXT, notify the client of what changed.
        $self ValueChanged
    }

    # GetSelectedItems list
    #
    # list   - Either the $left or $right tablelist.
    #
    # Retrieves the indices of the selected items for the given list,
    # ignoring hidden items.
    #
    # Tablelist 5.5 was changed so that selections include hidden items.
    # Thus, if items 3 and 4 are hidden and I shift-select 2 through 5,
    # I get 3 and 4 as well.  Move the selected items will then result
    # in moving 3 and 4 back to the other list.  Thus, I need to purge
    # hidden items from the list of selected items for use by
    # MoveItems.

    method GetSelectedItems {list} {
        set result [list]

        foreach i [$list curselection] {
            if {![$list rowcget $i -hide]} {
                lappend result $i
            }
        }

        return $result
    }

    # ValueChanged
    #
    # Does housekeeping when the widget's value changes, and
    # notifies the user.

    method ValueChanged {} {
        # FIRST, cache the new value
        set info(current) [list]

        for {set i 0} {$i < [$right size]} {incr i} {
            if {![$right rowcget $i -hide]} {
                lappend info(current) \
                    [lindex [dict keys $options(-itemdict)] $i]
            }
        }

        # NEXT, update the state of the widget
        $self UpdateState

        # NEXT, notify the user
        callwith $options(-changecmd) $info(current)
    }


    #-------------------------------------------------------------------
    # Public Methods

    # get
    #
    # Returns a list of the keys of the include items.

    method get {} {
        return $info(current)
    }

    # set values
    #
    # values - The list of keys to be included.
    #
    # Sets the included list to the specifies keys.
    
    method set {values} {
        # FIRST, if there's no change ignore it.
        if {[lsort $values] eq [lsort $info(current)]} {
            return
        }

        # NEXT, clear the current set of included items.
        for {set i 0} {$i < [$left size]} {incr i} {
            $left  rowconfigure $i -hide 0
            $right rowconfigure $i -hide 1
        }

        # NEXT, get the row IDs for the included items
        set keys [dict keys $options(-itemdict)]

        set items [list]

        foreach key $values {
            set ndx [lsearch -exact $keys $key]

            if {$ndx > -1} {
                # Ignore items that that aren't in the valid set.
                # Note: don't throw an error; this is equivalent to
                # clearing an enumfield when set to something that's
                # no longer in the enum.
                lappend items $ndx
            }
        }

        # NEXT, toggle the list items
        $left  togglerowhide $items
        $right togglerowhide $items

        # NEXT, the value changed.
        $self ValueChanged
    }
}




