#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

package require marsutil
package require marsgui
namespace import kiteutils::* marsutil::*

# FIRST, create the database, and put some data into it.

marsutil::sqldocument db
db open :memory:

db eval {
    CREATE TABLE units(u TEXT PRIMARY KEY,g,personnel INTEGER,foo,bar,baz);
    INSERT INTO units VALUES('u/1','BLUE',10,'this','that','the other');
    INSERT INTO units VALUES('u/2','BLUE',20,'this','that','the other');
    INSERT INTO units VALUES('u/3','BLUE',30,'this','that','the other');
    INSERT INTO units VALUES('u/4','OPFOR',40,'this','that','the other');
    INSERT INTO units VALUES('u/5','OPFOR',50,'this','that','the other');
    INSERT INTO units VALUES('u/6','SHIA',60,'this','that','the other');
    INSERT INTO units VALUES('u/7','SHIA',70,'this','that','the other');
    INSERT INTO units VALUES('u/8','SUNN',80,'this','that','the other');
    INSERT INTO units VALUES('u/9','SUNN',90,'this','that','the other');
    INSERT INTO units VALUES('u/A','KURD',100,'this','that','the other');
    INSERT INTO units VALUES('u/B','KURD',110,'this','that','the other');
    
    CREATE VIEW units_blue  AS SELECT * FROM units WHERE g='BLUE';
    CREATE VIEW units_opfor AS SELECT * FROM units WHERE g='OPFOR';
    CREATE VIEW units_shia  AS SELECT * FROM units WHERE g='SHIA';
    CREATE VIEW units_sunn  AS SELECT * FROM units WHERE g='SUNN';
    CREATE VIEW units_kurd  AS SELECT * FROM units WHERE g='KURD';
}

# NEXT, define the layoutSpec, if they want one.
if {[lindex $argv 0] eq "-layout"} {
    set layoutSpec {
        {u "Unit"}
        {g "Group"}
        {personnel "Personnel" -align right -sortmode integer}
        {foo "Foo!"}
    }
} else {
    set layoutSpec {}
}

# NEXT, define some utility commands and create the browser.
proc ::displaycmd {rindex data} {
    puts "-displaycmd $rindex [list $data]"
}

proc ::selectioncmd {} {
    puts "-selectioncmd [.browser uid curselection]"
}

marsgui::sqlbrowser .browser        \
    -db   ::db                      \
    -view units                     \
    -views {
        units       "All Units"
        units_blue  "Blue Units"
        units_opfor "OPFOR Units"
        units_shia  "Shia Units"
        units_sunn  "Sunni Units"
        units_kurd  "Kurd Units"
    }                               \
    -layout         $layoutSpec     \
    -selectioncmd   ::selectioncmd  \
    -displaycmd     ::displaycmd    \
    -titlecolumns   1               \
    -uid            u               \
    -filterbox      on              \
    -columnsorting  on

pack .browser -fill both -expand yes

set tbar [.browser toolbar]

ttk::label $tbar.label -text "Sample sqlbrowser"

pack $tbar.label -side left

marsgui::debugger new

raise .
