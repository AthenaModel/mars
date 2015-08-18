#-----------------------------------------------------------------------
# FILE: test_textfield.tcl
#
#   textfield(n) test script
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

namespace import kiteutils::*
namespace import marsutil::*
namespace import marsgui::*


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    ttk::label .lab -text "File Name:"
    filefield .file -width 20 \
        -title     "Select an Athena Scenario to Compare" \
        -changecmd ::ChangeCmd \
        -filetypes {
            { {Athena Scenario} {.adb} }
        }

    pack .lab -side left 
    pack .file -side left

    bind . <Control-F12> {debugger new}
}

proc ChangeCmd {args} {
    puts "filefield changed: <$args>"
}

#-------------------------------------------------------------------
# Invoke the program

main $argv









