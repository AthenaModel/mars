#-----------------------------------------------------------------------
# FILE: test_dynaview.tcl
#
#   Test script for dynaview(n) -- Dynamic Form Widget
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
#-----------------------------------------------------------------------

lappend auto_path ~/mars/lib 
package require marsutil
package require marsgui

namespace import marsutil::* marsgui::* 

source test_dynaview_samples.tcl

proc FormChanged {fields} {
    puts "FormChanged($fields) {"
    puts "    [.df get]"
    puts "}"
}

proc CurrentField {field} {
    puts "CurrentField($field)"
}

puts "Defined form types:"
puts "  [dynaform types]\n"

if {[llength $argv] == 0} { 
    exit
}

set ftype [lindex $argv 0]
puts [dynaform dump $ftype]

label .lab -text "Dynaform" -width 80

dynaview .df \
    -formtype   $ftype \
    -changecmd  [list FormChanged] \
    -currentcmd [list CurrentField]

pack .lab -side top -fill x -expand yes
pack .df -fill both -expand yes -padx 5 -pady 5

bind all <F1> {debugger new}

