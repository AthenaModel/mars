#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec wish "$0" "$@"

package require kiteutils
package require marsutil
package require marsgui
namespace import kiteutils::* marsutil::* marsgui::*

bind all <F1> {debugger new}

proc gridscroll {w {opt -y}} {
    set p [winfo parent $w]

    grid rowconfigure    $p 0 -weight 1
    grid columnconfigure $p 0 -weight 1

    grid $w -row 0 -column 0 -sticky nsew
    
    ttk::scrollbar $p.yscroll -command [list $w yview]
    $w configure -yscrollcommand [list $p.yscroll set]

    grid $p.yscroll -row 0 -column 1 -sticky ns

    if {$opt eq "-both"} {
        ttk::scrollbar $p.xscroll    \
            -orient  horizontal      \
            -command [list $w xview]
        $w configure -xscrollcommand [list $p.xscroll set]

        grid $p.xscroll -row 1 -column 0 -sticky ew
    }
}

ttk::frame .html

htmlviewer .html.content \
    -hyperlinkcmd {echo -hyperlinkcmd} \
    -hovercmd     {echo -hovercmd}     \
    -width        500 

gridscroll .html.content

ttk::frame .text

text .text.content \
    -width 80 \
    -height 50

ttk::button .refresh \
    -text "Refresh" \
    -command {.html.content set [.text.content get 1.0 end]}

gridscroll .text.content -both

grid .refresh -row 0 -column 0 -columnspan 2 -sticky ew
grid .html -row 1 -column 0 -sticky nsew
grid .text -row 1 -column 1 -sticky ns

grid columnconfigure . 0 -weight 1
grid rowconfigure    . 1 -weight 1

set filename [lindex $argv 0]

if {$filename ne ""} {
    set txt [readfile $filename]

    .text.content insert 1.0 $txt
    .text.content yview moveto 0.0

    .html.content set $txt
}
