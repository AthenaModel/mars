#-----------------------------------------------------------------------
# TITLE:
#   statecontroller.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   marsutil(n) module: State Controller
#
#   A statecontroller is an object that controls the -state of one
#   or more other objects.  It has a -condition, a boolean expression
#   which indicates whether the controlled objects are enabled 
#   (-state normal) or disabled (-state disabled).  The controller
#   binds to one or more notifier(n) events, and re-evaluates the
#   state of each controlled object when any of the events is 
#   received. 
#
#   The expression may refer to the controlled object as $obj.  In
#   addition, each object may specify an object dictionary, or objdict,
#   of values to which the expression may also refer.
#
#   Menu items are a special case: the object is specified as a pair,
#   a menu instance, and the item's label.  In this case, $obj is
#   set to the menu instance command.  The "menuitem" command is
#   provided to make it easier to create and control widgets as
#   one operation.
#
#   There is no "forget" or "uncontrol" method; if there's an error
#   when setting an object's state, and it turns out that the object
#   no longer exists, the object is quietly forget.  Otherwise, bgerror
#   is called.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsutil:: {
    namespace export statecontroller menuitem
}

#-------------------------------------------------------------------
# menuitem

# menuitem menu itemtype label ?options...?
#
# menu      A Tk menu
# itemtype  The item type, e.g., "command"
# label     The -label
# options   Other menu item options, as defined in menu(n)
#
# Creates a menu item and returns the pair "$menu $label".

proc ::marsutil::menuitem {menu itemtype label args} {
    $menu add $itemtype -label $label {*}$args

    return [list $menu $label]
}


#-----------------------------------------------------------------------
# statecontroller type

snit::type ::marsutil::statecontroller {
    #-------------------------------------------------------------------
    # Options

    # -condition expr
    #
    # A boolean expression which will be evaluated for each controlled
    # object.  It may refer to the variable $obj (the object being
    # controlled) as well as any of the entries in the objdict.

    option -condition \
        -readonly yes

    # -events eventlist
    #
    # eventlist is a flat list of subjects and notifier event names.
    # The controller will update all controlled widgets whenever any
    # of the listed events is sent.  Event arguments are ignored.

    option -events \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance Variables

    # objdicts: Object dictionary by object spec

    variable objdicts -array { }
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        $self configurelist $args

        foreach {subject event} $options(-events) {
            notifier bind $subject $event $self [mymethod EventUpdate]
        }
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Methods

    # control object ?key value ...?
    #
    # object        An object command, or for menu items a {menu label} pair
    # key value...  The object dictionary
    #
    # The statecontrol assumes control of the -state of the object.

    method control {object args} {
        # FIRST, add the object itself to the object dictionary
        dict set args obj [lindex $object 0]

        # NEXT, save the object and its dictionary
        set objdicts($object) $args
    }

    # update ?objects?
    #
    # objects   Specific objects to update.
    #
    # Updates the state of controlled objects.  If objects is missing
    # or {}, updates all controlled objects; otherwise, those listed.

    method update {{objects ""}} {
        if {$objects eq ""} {
            set objects [array names objdicts]
        }

        foreach objspec $objects {
            lassign $objspec obj label

            if {[llength [info commands $obj]] == 0} {
                unset objdicts($objspec)
                continue
            }

            if {[Evaluate $options(-condition) $objdicts($objspec)]} {
                set state normal
            } else {
                set state disabled
            }

            if {$label eq ""} {
                $obj configure -state $state
            } else {
                $obj entryconfigure $label -state $state
            }
        }
    }

    # EventUpdate ?args...?
    #
    # args     Event args; ignored
    #
    # Updates all controlled objects.
    
    method EventUpdate {args} {
        $self update
    }
    

    # Evaluate condition objdict
    #
    # condition      An expression
    # objdict        A dictionary
    #
    # Evalutes the expression given the dictionary, and returns the
    # result.

    proc Evaluate {condition objdict} {
        dict with objdict {
            return [expr $condition]
        }
    }
}




