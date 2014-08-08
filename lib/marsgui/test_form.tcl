#-----------------------------------------------------------------------
# FILE: test_form.tcl
#
#   form(n) test script
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

#-----------------------------------------------------------------------
# Required packages

package require marsutil
package require marsgui

namespace import marsutil::*
namespace import marsgui::*

#-------------------------------------------------------------------
# Layouts

set layouts {
    "Field Types" layout_ftypes
    "Stack"       layout_stack
    "Fancy"       layout_fancy
}

proc layout_ftypes {} {
    .form clear
    .form field create mykey "My Key" key \
        -db     ::db               \
        -table  sat_ngc            \
        -keys   {n g c}            \
        -widths {6 6 4}
    .form field create mynew "New Key" newkey \
        -db        ::db              \
        -universe  nbgroups_universe \
        -table     nbgroups          \
        -keys      {n g}             \
        -widths    {8 8}             \

    .form field create mytext "My Text" text -width 20
    .form field create myenum "My Enum" enum -width 10 \
        -values {"This" "That" "The Other" "And So On"}

    .form layout
}

proc layout_stack {} {
    .form clear
    .form field create f00 "Apple"  text -width 10
    .form field create f01 "Banana" text -width 10
    .form field create f10 "Cherry" text -width 10
    .form field create f11 "Date"   text -width 10

    .form field create v00 "Carrot" text -width 10
    .form field create v01 "Radish" text -width 10
    .form field create v10 "Turnip" text -width 10
    .form field create v11 "Beet"   text -width 10

    .form layout
}

proc layout_fancy {} {
    .form clear
    .form field create f00 "Apple"  text -width 10
    .form field create f01 "Banana" text -width 10
    .form field create f10 "Cherry" text -width 10
    .form field create f11 "Date"   text -width 10

    .form field create v00 "Carrot" text -width 10
    .form field create v01 "Radish" text -width 10
    .form field create v10 "Turnip" text -width 10
    .form field create v11 "Beet"   text -width 10

    .form layout {
        at 0,0 labelframe "Fruit" {
            at 0,0 labelfield f00
            at =,+ labelfield f01
            at +,0 labelfield f10
            at =,+ labelfield f11
            at +,0 text       "Explanatory text string" -columnspan 4
        }

        at +,0 labelframe "Veggies" {
            at 0,0 labelfield v00
            at =,+ labelfield v01
            at +,0 labelfield v10
            at =,+ labelfield v11
        }
    }
}


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    # FIRST, open a test DB
    sqldocument db
    db open "./test.db"

    db eval {
        CREATE TEMPORARY VIEW nbgroups_universe AS
        SELECT n, g FROM nbhoods JOIN groups WHERE gtype = 'CIV';
    }

    # NEXT, create a form
    form .form \
        -changecmd   ::ChangeCmd \
        -currentcmd  ::CurrentCmd  \
        -relief      sunken      \
        -borderwidth 1           \
        -padding     2


    # NEXT, create a radiobox.  Each button will show a different
    # layout.

    set box [ttk::frame .box \
                 -relief sunken \
                 -borderwidth 1]

    set count 0
    set ::layoutCounter 0

    dict for {label command} $::layouts {
        ttk::radiobutton $box.rb$count  \
            -text     $label            \
            -command  $command          \
            -value    $count            \
            -variable ::layoutCounter

        pack $box.rb$count -side top

        incr count
    }

    # NEXT, lay them out

    pack .box -side left -fill y
    pack .form -fill both

    # NEXT, do the first layout
    set first [lindex [dict keys $::layouts] 0]
    [dict get $::layouts $first]

    # NEXT, allow for debugger
    bind all <Control-F12> {debugger new}
}

proc ChangeCmd {fields} {
    puts "Field changed: <[join $fields ,]>"
    
    set dict [.form get]

    foreach field $fields {
        puts "   $field: <[dict get $dict $field]>"
    }
}

proc CurrentCmd {field} {
    puts "Current Field: <$field>"
}



#-------------------------------------------------------------------
# Invoke the program

main $argv









