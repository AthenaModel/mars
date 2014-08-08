#-----------------------------------------------------------------------
# FILE: test_keyfield.tcl
#
#   keyfield(n) test script
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
    sqldocument db
    db open "./test.db"

    db eval {
        CREATE TEMPORARY VIEW sat_ngc_view AS
        SELECT n, g, c, 
               '*' || n || '*' AS nv,
               '+' || g || '+' AS gv,
               '=' || c || '=' AS cv
        FROM sat_ngc
    }

    ttk::label .lab -text "Curve:"
    keyfield .key                     \
        -db        ::db               \
        -table     sat_ngc_view       \
        -keys      {n g c}            \
        -dispcols  {nv gv cv}         \
        -widths    {6 6 4}            \
        -changecmd GotChanges

    grid .lab -row 0 -column 0 -sticky w   -pady 4 -padx 4
    grid .key -row 0 -column 1 -sticky ew  -pady 4 -padx 4
    grid columnconfigure . 1 -weight 1

    bind . <Control-F12> {debugger new}
}

proc GotChanges {value} {
    puts "Key changed: <$value>"
}

#-------------------------------------------------------------------
# Invoke the program

main $argv









