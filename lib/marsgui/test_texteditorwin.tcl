#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh8.5 "$0" "$@"

package require Tk 8.5
package require marsgui

wm title . "Test"

label .lab \
    -font {Helvetica 40} \
    -text "texteditor test"

pack .lab

::marsgui::debugger new

if {[llength $argv] == 0} {
    ::marsgui::texteditorwin .%AUTO% -title "Test Editor"
} else {
    set win [::marsgui::texteditorwin .%AUTO% -title "Test Editor"]

    $win open [lindex $argv 0]
}





