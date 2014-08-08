#!/bin/sh
# -*-tcl-*-
# The next line restarts using wish \
exec wish8.4 "$0" "$@"

package require marsgui

namespace import ::marsutil::* ::marsutil::* ::marsgui::*

# FIRST, create a CLI and pack it on the bottom.

cli .cli      \
    -height 8 \
    -width 80

pack .cli -side bottom -fill x -expand 1

# NEXT, create a toolbar and a finder, and pack them on the top

frame .bar

finder .bar.finder               \
    -width   15                  \
    -findcmd [list .rotext find] \
    -msgcmd  puts

pack .bar.finder -side right
pack .bar -side top -fill x -expand 1

# NEXT, create a rotext and fill in the rest with it.
rotext .rotext                          \
    -wrap none                          \
    -highlightthickness 1               \
    -borderwidth 1                      \
    -relief sunken                      \
    -yscrollcommand [list .yscroll set] \
    -foundcmd [list .bar.finder found]

ttk::scrollbar .yscroll                \
    -orient vertical              \
    -command [list .rotext yview]

pack .yscroll -side right -fill y
pack .rotext -side right -fill both -expand 1

# NEXT, load some text into the rotext
.rotext ins end [readfile rotext_test.tcl]

.rotext see 1.0



