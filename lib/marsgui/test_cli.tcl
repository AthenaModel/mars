#!/bin/sh
# -*-tcl-*-
# The next line restarts using wish \
exec wish8.4 "$0" "$@"

package require marsgui

wm title . "CLI Test Window"

proc timePrompt {fmt} {
    set t [clock format [clock seconds] -format $fmt]

    return "cli $t>"
}

button .injector \
    -text "info patchlevel" \
    -command [list .cli inject {info patchlevel}]

::marsgui::cli .cli \
    -promptcmd [list timePrompt "%H:%M:%S"] \
    -commandlist [info commands]

pack .injector -side top -fill x
pack .cli -fill both -expand 1


