#-----------------------------------------------------------------------
# TITLE:
#    enumfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: Enum data entry field
#
#    An enumfield is a combobox with a (possibly dynamic) set of values.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export enumfield
}

#-----------------------------------------------------------------------
# enumfield

snit::widget ::marsgui::enumfield {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Global widget bindings

        # Focussing on the widget should focus on the combobox.
        bind Enumfield <FocusIn> {focus %W.combo}
    }



    #-------------------------------------------------------------------
    # Components

    component combo   ;# The combobox


    #-------------------------------------------------------------------
    # Options

    delegate option -background  to hull
    delegate option -borderwidth to hull
    delegate option *            to combo

    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val
        
        if {$val eq "normal"} {
            $combo configure -state readonly
        } elseif {$val eq "disabled"} {
            $combo configure -state disabled
        } else {
            error "Invalid -state: \"$val\""
        }
    }

    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new value is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    # -enumtype enumtype
    #
    # Specifies an enumeration type to provide values.  This option
    # overrides -valuecmd.

    option -enumtype

    # -valuecmd command
    #
    # Specifies a command to be called dynamically to provide values.

    option -valuecmd

    # -values values
    #
    # Specifies a list of valid values; or, if -displaylong, a list
    # of values and display labels.

    option -values \
        -configuremethod ConfigValues

    method ConfigValues {opt val} {
        set options($opt) $val

        $self GetValues
    }

    # -displaylong flag
    #
    # If 1, displays -enumtype or -value's long name.
    
    option -displaylong -default 0 \
        -configuremethod ConfigValues

    # -autowidth flag
    #
    # If yes, compute -width automatically.

    option -autowidth \
        -type            snit::boolean \
        -default         no            \
        -configuremethod ConfigValues

    #-------------------------------------------------------------------
    # Instance Variables

    variable oldValue ""   ;# Used to detect changes.

    variable d2v -array {} ;# values by display label
    variable v2d -array {} ;# display labels by value

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, install the hull
        install combo using menubox $win.combo \
            -exportselection yes                     \
            -takefocus       1                       \
            -width           20                      \
            -postcommand     [mymethod GetValues]    \
            -command         [mymethod DetectChange]

        pack $combo -fill both -expand yes

        # NEXT, configure the arguments
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # GetValues
    #
    # Retrieves the valid values when a -valuecmd or -enumtype is 
    # specified (otherwise, does nothing).
    #
    # This is called when the dropdown list is posted, and when 
    # the value is to be set explicitly.
    
    method GetValues {} {
        if {$options(-enumtype) ne ""} {
            set vs [{*}$options(-enumtype) names]

            if {$options(-displaylong)} {
                set ds [{*}$options(-enumtype) longnames]
            } else {
                set ds $vs
            }
        } elseif {$options(-valuecmd) ne ""} {
            set vs [uplevel \#0 $options(-valuecmd)]
            set ds $vs
        } elseif {$options(-values) ne ""} {
            if {$options(-displaylong)} {
                set vs [list]
                set ds [list]
                foreach {v d} $options(-values) {
                    lappend vs $v
                    lappend ds $d
                }
            } else {
                set vs $options(-values)
                set ds $vs
            }
        } else {
            set vs ""
            set ds ""
        }

        array unset v2d
        array unset d2v

        foreach v $vs d $ds {
            set v2d($v) $d
            set d2v($d) $v
        }

        $combo configure -values $ds


        if {[$combo get] ni $ds} {
            $combo set ""
        }

        # NEXT, if -autowidth, set the width properly.
        if {$options(-autowidth)} {
            set width [lmaxlen [$combo cget -values]]

            if {$width > 0} {
                $combo configure \
                    -width [expr {$width + 3}]
            }
        }
    }

    # DetectChange
    #
    # Calls the change command if the field's value has changed.

    method DetectChange {} {
        set value [$self get]

        if {$value eq $oldValue} {
            return
        }

        set oldValue $value

        if {$options(-changecmd) ne ""} {
            {*}$options(-changecmd) $value
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # get
    #
    # Retrieves the current value.

    method get {} {
        set d [$combo get]

        if {[info exists d2v($d)]} {
            return $d2v($d)
        } else {
            return $d
        }
    }

    # set value ?-silent?
    #
    # value    A new value
    #
    # Sets the combobox value, first retrieving valid values.  If 
    # the new value isn't one of the valid values, it's ignored.
    #
    # If -silent is included, the -changecmd isn't called.

    method set {value {opt ""}} {
        # FIRST, retrieve valid values if need be
        $self GetValues

        # NEXT, is this value valid?  If not, set the value to ""
        if {![info exists v2d($value)]} {
            $combo set ""
        } else {
            $combo set $v2d($value)
        }

        # NEXT, detect changes
        if {$opt eq "-silent"} {
            set oldValue $value
        } else {
            $self DetectChange
        }
    }
}



