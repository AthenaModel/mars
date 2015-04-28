#-----------------------------------------------------------------------
# FILE: cmdbrowser.tcl
#
# Browser for Tcl commands and Snit objects.
#
# PACKAGE:
#   marsgui(n) -- Mars GUI Infrastructure Package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsgui:: {
    namespace export cmdbrowser
}

#-----------------------------------------------------------------------
# Widget: cmdbrowser
#
# cmdbrowser(n) is an experimental widget for browsing Tcl commands
# and Snit objects.
#
# FUTURE:
#    * Should preserve location on Populate, if possible
#    * Might want to use a treectrl instead of Tree, so that we can 
#      have multiple columns.
#    * Would like better support for Snit types and instances.
#    * Would like better support for TclOO types and instances.
#

snit::widget ::marsgui::cmdbrowser {
    #-------------------------------------------------------------------
    # Typeconstructor

    typeconstructor {
        namespace import ::marsutil::* ::marsgui::*
    }

    #-------------------------------------------------------------------
    # Type Variables

    typevariable cmdcolors -array {
        proc               #000000
        snit-typemethod    #000000
        snit-method        #000000
        snit-type          #000000
        snit-instance      #000000
        oo-object          #000000
        nse                #0066FF
        sub                #00CCFF
        alias              #00CCFF
        unknown            #FF0000
        ns                 #009900
    }



    #-------------------------------------------------------------------
    # Components

    component bar        ;# The toolbar
    component editbtn    ;# The Edit button.
    component tree       ;# The tree of window data
    component tnb        ;# Tabbed notebook for window data

    #-------------------------------------------------------------------
    # Group: Options

    delegate option * to hull
    
    # Option: -editcmd
    #
    # A command that takes one argument, the name of the command to
    # edit.  Called when the "Edit" button is pressed; the command
    # is the name of the currently selected command.
    
    option -editcmd \
        -default ""
    
    # Option: -logcmd
    #
    # A command that takes one additional argument, a status message
    # to be displayed to the user.
    
    option -logcmd \
        -default ""

    #-------------------------------------------------------------------
    # Instance Variables

    variable pages    ;# Array of text pages for data display

    # Array of data; the indices are as follows:
    #
    # counter     Counter for node IDs
    # imports     1 if imported commands should be shown, and 0 otherwise.
    # node        Current node command

    variable info -array {
        counter 0
        imports 0
        wid     0
        alias   0
        bin     0
        bwid    0
        node    {}
    }

    # Array of data for each browsed command, indexed by tree node ID.
    variable cmds

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the widgets
        ttk::panedwindow $win.paner \
            -orient     horizontal

        # Toolbar
        install bar using ttk::frame $win.bar

        ttk::checkbutton $bar.imports        \
            -style    Toolbutton             \
            -text     "Imports"              \
            -variable [myvar info(imports)]  \
            -command  [mymethod Populate]

        ttk::checkbutton $bar.wid            \
            -style    Toolbutton             \
            -text     "Widgets"              \
            -variable [myvar info(wid)]      \
            -command  [mymethod Populate]

        ttk::checkbutton $bar.alias          \
            -style    Toolbutton             \
            -text     "Aliases"              \
            -variable [myvar info(alias)]    \
            -command  [mymethod Populate]

        ttk::checkbutton $bar.bin            \
            -style    Toolbutton             \
            -text     "BinCmds"              \
            -variable [myvar info(bin)]      \
            -command  [mymethod Populate]

        ttk::checkbutton $bar.bwid           \
            -style    Toolbutton             \
            -text     "BWid\#"               \
            -variable [myvar info(bwid)]     \
            -command  [mymethod Populate]
        
        ttk::button $bar.edit                \
            -style    Toolbutton             \
            -text     "Edit"                 \
            -command  [mymethod EditCommand]
        set editbtn $bar.edit


        pack $win.bar.imports -side left  -padx 1 -pady 1
        pack $win.bar.wid     -side left  -padx 1 -pady 1
        pack $win.bar.alias   -side left  -padx 1 -pady 1
        pack $win.bar.bin     -side left  -padx 1 -pady 1
        pack $win.bar.bwid    -side left  -padx 1 -pady 1
        pack $win.bar.edit    -side right -padx 1 -pady 1

        ttk::frame $win.paner.treesw
        $win.paner add $win.paner.treesw

        install tree using Tree $win.paner.treesw.tree     \
            -background     white                          \
            -width          40                             \
            -borderwidth    0                              \
            -deltay         16                             \
            -takefocus      1                              \
            -selectcommand  [mymethod SelectNode]          \
            -opencmd        [mymethod OpenNode]            \
            -yscrollcommand [list $win.paner.treesw.y set] \
            -xscrollcommand [list $win.paner.treesw.x set]
        
        ttk::scrollbar $win.paner.treesw.y \
            -command [list $tree yview]
        ttk::scrollbar $win.paner.treesw.x \
            -orient  horizontal            \
            -command [list $tree xview]
        
        grid columnconfigure $win.paner.treesw 0 -weight 1
        grid rowconfigure    $win.paner.treesw 0 -weight 1
        
        grid $win.paner.treesw.tree -row 0 -column 0 -sticky nsew
        grid $win.paner.treesw.y    -row 0 -column 1 -sticky ns
        grid $win.paner.treesw.x    -row 1 -column 0 -sticky ew

        install tnb using ttk::notebook $win.paner.tnb \
            -padding   2 \
            -takefocus 1
        $win.paner add $tnb

        $self AddPage code
        
        grid rowconfigure    $win 1 -weight 1
        grid columnconfigure $win 0 -weight 1

        grid $win.bar     -row 0 -column 0 -sticky ew
        grid $win.paner   -row 1 -column 0 -sticky nsew

        # NEXT, get the options
        $self configurelist $args

        # NEXT, populate the tree
        $self Populate

        # NEXT, activate the first item.
        $tree selection set cmd1
    }
    
    # EditCommand
    #
    # Called when the edit button is pressed.  Gets the current command
    # name, and passes to the edit command.
    
    method EditCommand {} {
        set cmd $cmds($info(node))
        set name [dict get $cmd name]

        callwith $options(-editcmd) $name
    }

    # Method: Log
    #
    # Logs a status message by calling the <-logcmd>.
    #
    # Syntax:
    #   Log _msg_
    #
    #   msg     A short text message
    
    method Log {msg} {
        callwith $options(-logcmd) $msg
    }

    # AddPage name label
    #
    # name      The page name
    #
    # Adds a page to the tabbed notebook

    method AddPage {name} {
        set sw $tnb.${name}sw

        ttk::frame $sw

        $tnb add $sw \
            -sticky  nsew     \
            -padding 2        \
            -text    $name

        set pages($name) \
            [rotext $sw.text \
                -insertwidth        1                 \
                -width              50                \
                -height             15                \
                -font               codefont          \
                -highlightthickness 1                 \
                -yscrollcommand     [list $sw.y set]  \
                -xscrollcommand     [list $sw.x set]]
        
        isearch enable $sw.text
        isearch logger $sw.text [mymethod Log]

        ttk::scrollbar $sw.y \
            -command [list $sw.text yview]
        ttk::scrollbar $sw.x \
            -orient  horizontal            \
            -command [list $sw.text xview]
        
        grid columnconfigure $sw 0 -weight 1
        grid rowconfigure    $sw 0 -weight 1
        
        grid $sw.text -row 0 -column 0 -sticky nsew
        grid $sw.y    -row 0 -column 1 -sticky ns
        grid $sw.x    -row 1 -column 0 -sticky ew
    }


    #-------------------------------------------------------------------
    # Methods

    # refresh
    #
    # Refreshes the content of the display

    method refresh {} {
        # FIRST, get the current item
        set node [lindex [$tree selection get] 0]
        set name [dict get $cmds($node) name]

        # NEXT, repopulate
        $self Populate

        # NEXT, see the current item or "cmd1"
        if {$node eq ""                           || 
            ![$tree exists $node]                 ||
            [dict get $cmds($node) name] ne $name
        } {
            set node cmd1
        }

        $tree selection set $node
        $tree see $node
    }

    # Populate
    #
    # Populate the listbox with the windows

    method Populate {} {
        array unset cmds
        set info(counter) 0

        $self GetNsNodes root ::
    }

    # GetNsNodes parent ns
    #
    # parent  A parent node
    # ns      A fully-qualified namespace
    #
    # Gets the tree nodes for the children of ns, and adds them
    # under parent.

    method GetNsNodes {parent ns} {
        $tree delete [$tree nodes $parent]
        
        foreach {name ctype} [cmdinfo list $ns] {
            # Filter out unwanted commands:
            # TBD: Add this to cmdinfo?
            if {$ctype ne "ns"} {
                if {(!$info(imports) && $name ne [namespace origin $name]) ||
                    (!$info(wid)   && [cmdinfo is window $name])           ||
                    (!$info(bwid)  && [cmdinfo is dummyWindow $name])      ||
                    (!$info(alias) && $ctype in {alias walias})            ||
                    (!$info(bin)   && $ctype eq "unknown")
                } {
                    continue
                }
            }

            # Display the command in the tree
            set id cmd[incr info(counter)]

            set cmd [dict create id $id name $name ctype $ctype]

            $tree insert end $parent $id  \
                -text "$name    ($ctype)" \
                -fill $cmdcolors($ctype)  \
                -font codefont            \
                -padx 0

            if {$ctype in {"ns" "nse" "snit-type" "snit-instance"}} {
                # We'll get the child nodes on request.  
                # Mark it unexpanded, and create a dummy child so that
                # we get the open icon.
                dict set cmd expanded 0

                $tree insert end $id $id-dummy
            }

            set cmds($id) $cmd

        }
    }

    # GetNseNodes parent nse
    #
    # parent  A parent node
    # nse     A fully-qualified namespace ensemble
    #
    # Gets the tree nodes for the subcommands of nse, and adds them
    # under parent.

    method GetNseNodes {parent nse} {
        $tree delete [$tree nodes $parent]
        
        foreach {sub mapping} [cmdinfo nsemap $nse] {
            set id cmd[incr info(counter)]

            set cmd [dict create           \
                         id     $id        \
                         name   $sub       \
                         ctype  sub        \
                         mapping $mapping]

            $tree insert end $parent $id  \
                -text "$sub    (sub)"     \
                -fill $cmdcolors(sub)     \
                -font codefont            \
                -padx 0

            set cmds($id) $cmd
        }
    }


    # OpenNode node
    #
    # node    The node to open.  
    # 
    # If the node hasn't been expanded, expand it.
    
    method OpenNode {node} {
        if {[dict get $cmds($node) expanded]} {
            return
        }

        dict with cmds($node) {
            set expanded 1

            if {$ctype eq "ns"} {
                $self GetNsNodes $id $name
            } elseif {$ctype in {"nse" "snit-type" "snit-instance"}} {
                $self GetNseNodes $id $name
            }
        }
    }

    # SelectNode w nodes
    #
    # w        The Tree widget
    # nodes    The selected items; should only be one.
    #
    # Puts the proc info into the rotext.

    method SelectNode {w nodes} {
        # FIRST, get the node
        if {[llength $nodes] == 0} {
            return
        }

        # NEXT, display it.
        set info(node) [lindex $nodes 0]
        $self DisplayNode [lindex $nodes 0]
    }

    # DisplayNode node
    #
    # node    A node in the tree
    #
    # Gets the info for the node, and displays it on the code
    # page.

    method DisplayNode {node} {
        set cmd $cmds($node)
        set name [dict get $cmd name]
        
        $editbtn configure -state disabled

        set ctype [dict get $cmd ctype]

        if {$ctype eq "unknown" && [cmdinfo is window $cmd]} {
            set ctype tkwin
        } elseif {[cmdinfo is dummyWindow $cmd]} {
            set ctype bwid
        }

        switch -exact -- [dict get $cmd ctype] {
            proc {
                set text [cmdinfo getcode $name]
                
                if {$options(-editcmd) ne ""} {
                    $editbtn configure -state normal
                }
            }

            oo-object {
                set text "TclOO Object or Class"
            }

            snit-type {
                set text "Snit Type"
            }

            snit-instance {
                set text "Snit Instance"
            }

            nse {
                set opts [namespace ensemble configure $name]

                set text "namespace ensemble: $name\n\n"
                foreach {opt val} $opts {
                    append text [format "%-12s %s\n" $opt $val]
                }
            }

            sub {
                set text "maps to -> [dict get $cmds($node) mapping]"
            }

            alias {
                set text "alias -> [interp alias {} [dict get $cmd name]]"
            }

            unknown {
                set text "Binary command, etc."
            }

            tkwin {
                set text "Tk Widget"
            }

            bwid {
                set text "BWidget special widget"
            }

            ns {
                set text "namespace"
            }

            default {
                set text "Unknown type: $ctype"
            }
        }

        $self Display code $text
    }

   

    # reindent text ?indent?
    #
    # text      A block of text
    # indent    A new indent for each line; defaults to ""
    #
    # Removes leading and trailing blank lines, and any
    # whitespace margin at the beginning of each line, and
    # then indents each line according to "indent".

    proc reindent {text {indent ""}} {
        set text [outdent $text]
        
        set lines [split $text "\n"]

        set out [join [split $text "\n"] "\n$indent"]

        return "${indent}$out"
    }

    # Display text
    #
    # page 
    # text       A text string
    #
    # Displays the text string in the rotext widget

    method Display {page text} {
        $pages($page) del 1.0 end
        $pages($page) ins 1.0 $text
        $pages($page) see 1.0
        $pages($page) yview moveto 0
    }
}






