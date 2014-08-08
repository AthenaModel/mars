#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

lappend auto_path ~/mars/lib

package require marsutil
package require marsgui

# FIRST, create the data source

set db {
    u/1  {unit u/1 g BLUE  personnel  10 rating  20}
    u/2  {unit u/2 g BLUE  personnel  20 rating 118}
    u/3  {unit u/3 g BLUE  personnel  30 rating  22}
    u/4  {unit u/4 g OPFOR personnel  40 rating 116}
    u/5  {unit u/5 g OPFOR personnel  50 rating  24}
    u/6  {unit u/6 g SHIA  personnel  60 rating 114}
    u/7  {unit u/7 g SHIA  personnel  70 rating  26}
    u/8  {unit u/8 g SUNN  personnel  80 rating 112}
    u/9  {unit u/9 g SUNN  personnel  90 rating  28}
    u/A  {unit u/A g KURD  personnel 100 rating 110}
    u/B  {unit u/B g KURD  personnel 110 rating  30}
}

proc GetUIDs {} {
    variable db
    return [dict keys $db]
}

proc GetRecord {uid} {
    variable db
    dict get $db $uid
}


# NEXT, define the layoutSpec, if they want one.
set layoutSpec {
    {unit      "Unit"}
    {g         "Group"}
    {personnel "Personnel" -align right -sortmode integer}
    {rating    "Rating" -sortmode integer}
}

# NEXT, define some utility commands and create the browser.
proc ::displaycmd {rindex data} {
    puts "-displaycmd $rindex [list $data]"
}

proc ::selectioncmd {} {
    puts "-selectioncmd [.browser uid curselection]"
}

marsgui::databrowser .browser       \
    -sourcecmd ::GetUIDs            \
    -dictcmd   ::GetRecord          \
    -layout         $layoutSpec     \
    -selectioncmd   ::selectioncmd  \
    -displaycmd     ::displaycmd    \
    -titlecolumns   1               \
    -columnsorting  on

pack .browser -fill both -expand yes

set tbar [.browser toolbar]

ttk::label $tbar.label -text "Sample databrowser"

pack $tbar.label -side left

marsgui::debugger new

raise .
