#-----------------------------------------------------------------------
# FILE: test_colorfield.tcl
#
#   colorfield(n) test script
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


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    ttk::label .lab -text "Satisfaction:"

    form .form \
        -changecmd ChangeCmd

    form register color ::marsgui::colorfield

    .form field create a "Color A" color
    .form field create b "Color B" color
    .form field create c "Color C" color

    .form layout

    ttk::button .clear \
        -text "Clear" \
        -command ClearFields

    grid .form  -row 0 -column 0 -sticky ew  -pady 4 -padx 4
    grid .clear -row 1 -column 0 -sticky ew  -pady 4 -padx 4

    grid columnconfigure . 0 -weight 1

    bind . <Control-F12> {debugger new}
}

proc ChangeCmd {fields} {
    foreach field $fields {
        puts "$field is now: <[.form field get $field]>"
    }
}

proc ClearFields {} {
    foreach field [.form field names] {
        .form set $field ""
    }
}

#-------------------------------------------------------------------
# Invoke the program

main $argv









