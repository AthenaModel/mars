#-----------------------------------------------------------------------
# TITLE:
#    htmlframe.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n) package: geometry manager widget using HTML/CSS
#    to control layout of widgets.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export htmlframe
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ::marsgui::htmlframe {
    typeconstructor {
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Options

    # Delegate all options to the hull frame
    delegate option * to hull

    # -styles css
    #
    # Sets the user's styles.

    option -styles \
        -configuremethod ConfigureStyles

    # -background
    #
    # Sets the background color of the frame.  Defaults to the usual
    # marsgui(n) background color, which derives from the OS default.

    option -background \
        -configuremethod ConfigureStyles

    method ConfigureStyles {opt val} {
        set options($opt) $val

        set fullStyles \
            "BODY { background-color: $options(-background) }\n"

        append fullStyles $options(-styles)

        $hull configure -styles $fullStyles
    }
    
    #-------------------------------------------------------------------
    # Instance Variables

    # TBD

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the hull.
        installhull using htmlviewer \
            -shrink yes

        # NEXT, add a node handler for <input> tags.
        $hull handler node input [mymethod InputCmd]

        # NEXT, set the default background color
        $self configure -background $::marsgui::defaultBackground

        # NEXT, get the user's options
        $self configurelist $args
    }

    # InputCmd node
    # 
    # node    - htmlviewer node handle
    #
    # An <input> element was found in the input.  This callback replaces the
    # element with the child widget having the same name as the element,
    # should the child exist.

    method InputCmd {node} {
        # FIRST, get the attributes of the object.
        set name [$node attribute -default "" name]

        if {$name ne ""} {
            set iwin $win.$name

            if {[winfo exists $iwin]} {
                $node replace $iwin
            }
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method *      to hull
    delegate method layout to hull as set


    # set id attribute value
    #
    # id         - An element id, set using the "for", "id" or "name" attribute
    # attribute  - An attribute name
    # value      - A new attribute value
    #
    # Sets the attribute value for the first element with the given ID
    # or NAME.  Looks for ID first.

    method set {id attribute value} {
        set node [$self FindNode $id]

        require {$node ne ""} "unknown element id: \"$id\""

        $node attribute $attribute $value
        return
    }
    
    # get id attribute
    #
    # id         - An element id, set using the "id" or "name" attribute
    # attribute  - An attribute name
    #
    # Gets the value of the named attribute for the first element with 
    # the given ID or NAME.  Looks for ID first.

    method get {id attribute} {
        set node [$self FindNode $id]

        require {$node ne ""} "unknown element id: \"$id\""

        return [$node attribute $attribute]
    }

    # FindNode id
    #
    # id    - Value of an "id" or "name" attribute.
    #
    # Returns a node identified by "id".  It looks in this order:
    #
    # * For any element with id=$id
    # * For any element with name=$id

    method FindNode {id} {
        set node [lindex [$hull search "#$id"] 0]

        if {$node eq ""} {
            set node [lindex [$hull search "\[name=\"$id\"\]"] 0]
        }

        return $node
    }
}



