#-----------------------------------------------------------------------
# TITLE:
#    datagrid.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Data Display Frame
#
#    This widget provides a modified Tk frame customized for
#    displaying labels and data values in a grid.
#
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export datagrid
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::datagrid {
    #-------------------------------------------------------------------
    # Inherit frame behavior

    delegate option * to hull

    #-------------------------------------------------------------------
    # Instance Variables

    variable counter 0   ;# Counter used for generating widget names.
    variable lastRow 0   ;# Index of last row
    variable lastCol 0   ;# Index of last column
    variable widgets     ;# Array of widget names by r,c

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, process the options
        $self configurelist $args

        # NEXT, put the weight in the only row and column we have.
        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Position w r c
    #
    # w    A child widget name
    # r    Row index
    # c    Column index

    method Position {w r c} {
        # Check the inputs
        assert {$r >= 0 && $c >= 0}
        require {![info exists widgets($r,$c)]} "cell ($r,$c) is occupied."

        # Place the widget
        grid $w -row $r -column $c -sticky sw

        # Redo the weights if necessary
        if {$r > $lastRow} {
            grid rowconfigure $win $lastRow -weight 0
            set lastRow $r
            grid rowconfigure $win $lastRow -weight 1
        }

        if {$c > $lastCol} {
            grid columnconfigure $win $lastCol -weight 0
            set lastCol $c
            grid columnconfigure $win $lastCol -weight 1
        }
    }

    #-------------------------------------------------------------------
    # Datagrid Items

    # label r c ?options...?
    #
    # r         Grid row
    # c         Grid column
    # options   label options
    #
    # Creates a label in the specified cell.

    method label {r c args} {
        set w "$win.wid[incr counter]"

        ttk::label $w {*}$args

        $self Position $w $r $c
    }

    #-------------------------------------------------------------------
    # Value 

    # value r c ?options...?
    #
    # r         Grid row
    # c         Grid column
    # options   label options
    #
    # A Value is a label that displays a data value.  By default, values
    # are displayed using the "codefont".

    method value {r c args} {
        set w "$win.wid[incr counter]"

        ttk::label $w -font codefont -anchor w {*}$args

        $self Position $w $r $c
    }
}






