#-----------------------------------------------------------------------
# FILE: test_checkfield.tcl
#
#   checkfield(n) test script
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

lappend auto_path [file join [file dirname [info script]] ..] 

package require marsutil
package require marsgui

namespace import marsutil::*
namespace import marsgui::*


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    checkfield .first \
        -text "First" \
        -changecmd [list echo First]

    checkfield .second \
        -text "Second" \
        -changecmd [list echo Second]

    checkfield .third \
        -text "Third" \
        -state disabled \
        -changecmd [list echo Third]

    pack .first -side top
    pack .second -side top
    pack .third -side top

    . configure -width 300 -height 300

    bind . <Control-F10> {debugger new}
}

#-------------------------------------------------------------------
# Invoke the program

main $argv









