#-----------------------------------------------------------------------
# FILE: test_newkeyfield.tcl
#
#   newkeyfield(n) test script
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
# Look-up Tables

# rdbSchema -- Schema for the test RDB
#
# NOTE: This schema defines two sets of tables, both of which
# represent an i/j grid of data.  One uses numeric text strings
# as i/j indices; the other uses integers.  The thing to remember
# is that the data types used by the universe view need to match
# the data types used in the table.  Thus, if the INTEGER keyword
# is removed from the definition of the iidx table, the .ikey
# widget won't work properly.

set rdbSchema {
    CREATE TABLE tidx(n);
    INSERT INTO tidx VALUES('1');
    INSERT INTO tidx VALUES('2');
    INSERT INTO tidx VALUES('3');
    INSERT INTO tidx VALUES('4');    
    INSERT INTO tidx VALUES('5');    
    INSERT INTO tidx VALUES('6');    

    CREATE TABLE tgrid(
        i     TEXT,
        j     TEXT,
        value TEXT,
        PRIMARY KEY (i,j)
    );

    CREATE VIEW tgrid_universe AS
    SELECT I.n AS i, J.n AS j
    FROM tidx AS I JOIN tidx AS J;

    INSERT INTO tgrid VALUES('1','4','ART');
    INSERT INTO tgrid VALUES('2','5','BILL');
    INSERT INTO tgrid VALUES('3','6','CARL');


    CREATE TABLE iidx(n INTEGER);
    INSERT INTO iidx VALUES(1);
    INSERT INTO iidx VALUES(2);
    INSERT INTO iidx VALUES(3);
    INSERT INTO iidx VALUES(4);    
    INSERT INTO iidx VALUES(5);    
    INSERT INTO iidx VALUES(6);    

    CREATE TABLE igrid(
        i     INTEGER,
        j     INTEGER,
        value TEXT,
        PRIMARY KEY (i,j)
    );

    CREATE VIEW igrid_universe AS
    SELECT I.n AS i, J.n AS j
    FROM iidx AS I JOIN iidx AS J;

    INSERT INTO igrid VALUES(1,4,'ART');
    INSERT INTO igrid VALUES(2,5,'BILL');
    INSERT INTO igrid VALUES(3,6,'CARL');
}


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    # FIRST, Create a test RDB.
    sqldocument rdb
    rdb open :memory:
    rdb clear

    rdb eval $::rdbSchema

    # NEXT, add some fields.

    ttk::label .tlab -text "New TGrid:"
    newkeyfield .tkey \
        -db        ::rdb          \
        -universe  tgrid_universe \
        -table     tgrid          \
        -keys      {i j}          \
        -widths    {3 3}          \
        -labels    {TI TJ}        \
        -changecmd {Echo TGrid}

    ttk::label .ilab -text "New IGrid:"
    newkeyfield .ikey \
        -db        ::rdb          \
        -universe  igrid_universe \
        -table     igrid          \
        -keys      {i j}          \
        -widths    {3 3}          \
        -labels    {II IJ}        \
        -changecmd {Echo IGrid}

    grid .tlab -row 0 -column 0 -sticky w   -pady 4 -padx 4
    grid .tkey -row 0 -column 1 -sticky ew  -pady 4 -padx 4
    grid .ilab -row 1 -column 0 -sticky w   -pady 4 -padx 4
    grid .ikey -row 1 -column 1 -sticky ew  -pady 4 -padx 4

    grid columnconfigure . 1 -weight 1

    bind . <Control-F12> {debugger new}
}


# Echo args...
#
# Writes a message to stdout with its arguments

proc Echo {args} {
    puts "$args"
}


#-------------------------------------------------------------------
# Invoke the program

main $argv









