#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_sql(1) Main Application Window
#
#    This module defines app, the application ensemble.  app encapsulates 
#    all of the functionality of the mars_sql(1) main window, 
#    including the application's start-up behavior.  To invoke the 
#    application,
#
#        package require mars_sql
#        app init $argv
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

# All needed packages are required in app_sql.tcl.

#-------------------------------------------------------------------
# Global Variables

set outputMode mc              ;# Default output mode
set execMode   execute         ;# Default execution mode

#-----------------------------------------------------------------------
# app ensemble

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Components

    typecomponent cli       ;# The CLI pane
    typecomponent msgline   ;# The message line

    #-------------------------------------------------------------------
    # Type variables
    typevariable createFlag  0  ;# -create  flag: create file option

    #-------------------------------------------------------------------
    # Application Initializer

    # init argv
    #
    # argv  Command line arguments (if any)
    #
    # Initializes the application.
    typemethod init {argv} {

        # FIRST, check for the -create option
        if {[llength $argv] == 2 && 
            [lindex $argv 1] eq "-create"} {
            set createFlag 1
        }

        # NEXT, check arg count and get the file name.
        if {!$createFlag && [llength $argv] != 1} {
            app usage
            exit 1
        }

        set filename [lindex $argv 0]

        # NEXT, reject -create if the file already exists
        if {$filename ne ":memory:" &&
            [file exists $filename] &&
            $createFlag} {
            puts "File already exists: $filename"
            exit 1
        }

        # NEXT, make sure the file exists if -create not specified  
        if {$filename ne ":memory:"  && 
            ![file exists $filename] &&
            !$createFlag} {
            puts "File does not exist: $filename"
            exit 1
        }

        # NEXT, create an sqldocument.
        sqldocument ::rdb \
            -autotrans off \
            -rollback  on

        if {[catch {rdb open $filename} result]} {
            puts "Could not open $filename:\n--> $result"
            exit 1
        }

        # NEXT, when the main window is destroyed, exit.
        wm protocol . WM_DELETE_WINDOW [list app exit]

        # NEXT, Build the GUI
        wm title . "mars sql: [file tail $filename]"

        # Row 0: Menu/Toolbar
        frame .toolbar \
            -relief flat \
            -borderwidth 0

        # File menu
        menubutton .toolbar.file  \
            -text        "File"   \
            -underline   0        \
            -direction   "below"  \
            -borderwidth 1        \
            -menu        .toolbar.file.menu
        
        set mnu [menu .toolbar.file.menu]

        $mnu add command           \
            -label        "Exit"   \
            -underline    1        \
            -accelerator  "Ctrl+Q" \
            -command      [list app exit]
        bind . <Control-q> [list app exit]

        # Edit menu
        menubutton .toolbar.edit \
            -text "Edit" \
            -underline 0 \
            -direction below \
            -borderwidth 1   \
            -menu .toolbar.edit.menu

        set mnu [menu .toolbar.edit.menu]
        
        $mnu add command \
            -label "Cut" \
            -underline 2 \
            -accelerator "Ctrl+X" \
            -command {event generate [focus] <<Cut>>}

        $mnu add command \
            -label "Copy" \
            -underline 0 \
            -accelerator "Ctrl+C" \
            -command {event generate [focus] <<Copy>>}

        $mnu add command \
            -label "Paste" \
            -underline 0 \
            -accelerator "Ctrl+V" \
            -command {event generate [focus] <<Paste>>}
        
        $mnu add separator
        
        $mnu add command \
            -label "Select All" \
            -underline 7 \
            -accelerator "Ctrl+Shift+A" \
            -command {event generate [focus] <<SelectAll>>}

        # View menu
        menubutton .toolbar.view  \
            -text        "View"   \
            -underline   0        \
            -direction   "below"  \
            -borderwidth 1        \
            -menu        .toolbar.view.menu
        
        set mnu [menu .toolbar.view.menu]

        $mnu add radiobutton                  \
            -label        "Multicolumn Mode"  \
            -underline    0                   \
            -accelerator  "F2"                \
            -value        "mc"                \
            -variable     ::outputMode

        $mnu add radiobutton           \
            -label        "List Mode"  \
            -underline    0            \
            -accelerator  "F3"         \
            -value        "list"       \
            -variable     ::outputMode

        $mnu add separator

        $mnu add radiobutton              \
            -label        "Execute Mode"  \
            -underline    1               \
            -accelerator  "F4"            \
            -value        "execute"       \
            -variable     ::execMode

        $mnu add radiobutton              \
            -label        "Explain Mode"  \
            -underline    0               \
            -accelerator  "F5"            \
            -value        "explain"       \
            -variable     ::execMode

        #  Exec Mode buttons
        ttk::radiobutton .toolbar.execute           \
            -style       Toolbutton                 \
            -image       ::marsgui::icon::exclaim22 \
            -value       "execute"                  \
            -variable    ::execMode
        bind . <F4> {set ::execMode execute}
        DynamicHelp::add .toolbar.execute \
            -text "Execute SQL queries\nas usual"

        ttk::radiobutton .toolbar.explain            \
            -style       Toolbutton                  \
            -image       ::marsgui::icon::question22 \
            -value       "explain"                   \
            -variable    ::execMode
        bind . <F5> {set ::execMode explain}
        DynamicHelp::add .toolbar.explain \
            -text "Explain the query plan\nfor SQL queries"

        # Output Mode buttons
        ttk::radiobutton .toolbar.mc    \
            -style       Toolbutton     \
            -image       ::marsgui::icon::mc22 \
            -value       "mc"           \
            -variable    ::outputMode
        bind . <F2> {set ::outputMode mc}
        DynamicHelp::add .toolbar.mc \
            -text "Display output in\nmultiple columns"

        ttk::radiobutton .toolbar.list         \
            -style       Toolbutton     \
            -image       ::marsgui::icon::list22 \
            -value       "list"           \
            -variable    ::outputMode
        bind . <F3> {set ::outputMode list}
        DynamicHelp::add .toolbar.list \
            -text "Display output as\na list of records."

        # Pack the toolbar contents
        pack .toolbar.list -side right -pady 2
        pack .toolbar.mc   -side right -pady 2 -padx {15 0}

        pack .toolbar.explain -side right -pady 2
        pack .toolbar.execute -side right -pady 2

        pack .toolbar.file -side left
        pack .toolbar.edit -side left
        pack .toolbar.view -side left

        # Row 1: separator
        frame .sep1 -height 2 -relief sunken -borderwidth 2

        # Row 2: CLI

        cli .cli                       \
            -maxlines    10000         \
            -promptcmd   ::promptCmd   \
            -completecmd ::completeCmd \
            -evalcmd     ::evalCmd

        # Row 3: separator
        frame .sep3 -height 2 -relief sunken -borderwidth 2

        # Row 4: Message line
        messageline .msgline


        pack .toolbar -side top -fill x    -expand no
        pack .sep1    -side top -fill x    -expand no
        pack .cli     -side top -fill both -expand yes
        pack .sep3    -side top -fill x    -expand no
        pack .msgline -side top -fill x    -expand no
    }

    # usage
    #
    # Displays the application's command-line syntax
    
    typemethod usage {} {
        puts "Usage: mars sql sqlfile \[-create\]"
        puts ""
        puts "See mars_sql(1) for more information."
    }

    # exit ?code?
    #
    # Does a normal exit, closing the db gracefully.

    typemethod exit {{code 0}} {
        # If the db is open, commit and close.
        if {[info exists rdb]} {
            rdb close
        }

        exit $code
    }
}

#-----------------------------------------------------------------------
# Other Main Line Routines

# promptCmd
#
# Returns the CLI prompt.

proc promptCmd {} {
    return "sql>"
}

# completeCmd input
#
# input        Command input
#
# Determines whether input contains a complete command or not.
# If input begins with a ".", the rest is assumed to have Tcl syntax;
# otherwise it's assumed to be an SQL statement.

proc completeCmd {input} {
    if {[string index $input 0] == "."} {
        return [info complete [string range $input 1 end]]
    } else {
        return [rdb complete $input]
    }
}

# evalCmd input
#
# input        Command input
#
# Evaluates the input as a command, returning the result or throwing
# an error.  If input begins with a ".", the remainder of the command
# is assumed to be a Tcl command; otherwise, it's treated as an SQL 
# statement.

proc evalCmd {input} {
    global outputMode
    global execMode

    # FIRST, handle Tcl commands.
    if {[string index $input 0] == "."} {
        return [uplevel \#0 [string range $input 1 end]]
    } elseif {$execMode eq "explain"} {
        set input "EXPLAIN QUERY PLAN $input"
        set result [rdb query $input -mode mc -maxcolwidth 0]

        if {$result eq ""} {
            set result "Nothing to explain."
        }

        return $result
    } else {
        return [rdb query $input -mode $outputMode]
    }
}


#-------------------------------------------------------------------
# User Commands
#
# The following commands are defined for use by the user via the
# "." mechanism.


# tables
#
# Returns a formatted list of the tables defined in the database.

proc tables {} {
    join [rdb tables] \n
}

# schema ?table?
#
# table    A table name or glob pattern
#
# Returns the SQL schema for the tables, views, and indices that match
# pattern, or simply all of them.

proc schema {{table *}} {
    rdb schema $table
}

# mode ?newMode?
#
# newMode     mc|list, the new output mode
#
# Sets or retrieves the output mode.

proc mode {{newMode ""}} {
    global outputMode

    if {$newMode ne ""} {
        if {$newMode ne "mc" && $newMode ne "list"} {
            error "invalid mode, should be one of mc, list: \"$newMode\""
        }

        set outputMode $newMode
        return
    } else {
        return $outputMode
    }
}












