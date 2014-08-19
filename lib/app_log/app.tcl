#-----------------------------------------------------------------------
# FILE: app.tcl
#
# Main Application Module
#
# PACKAGE:
#   app_log(n) -- mars_log(1) implementation package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: app
#
# This module defines app, the application ensemble.  app contains
# the application start-up code, as well a variety of subcommands
# available to the application as a whole.  To invoke the 
# application,
#
# > package require app_log
# > app init $argv
#
# Note that app_log is usually invoked by mars(1).

snit::type app {
    pragma -hasinstances 0
    
    #-------------------------------------------------------------------
    # Group: Type Components
    
    # Type component: log
    #
    # The scrollinglog(n) widget.
    typecomponent log
    
    # Type component: msgline
    #
    # The messageline(n) widget.
    typecomponent msgline
    
    #-------------------------------------------------------------------
    # Group: Type Variables

    # Type variable: opts
    #
    # The application's configuration options:
    #
    # -appname name       - The application name, as entered at the
    #                       command prompt.
    # -defaultappdir dir  - The default application directory in log/.
    # -manpage name       - The application's man page name, for use
    #                       in error messages.
    # -project            - The application's project name, for use in
    #                       the GUI.
    
    typevariable opts -array {
        -appname       "mars log"
        -defaultappdir ""
        -manpage       "mars_log(1)"
        -project       "Mars"
    }
    
    # Type variable: fieldFlags
    #
    # An array of flags, indicating whether to show or hide the named field.
    
    typevariable fieldFlags -array {
        t      0
        zulu   1
        v      1
        c      1
    }

    # Type variable: scrollLockFlag
    #
    # Do we auto-update and scroll, or not?
    typevariable scrollLockFlag 0
    
    #-------------------------------------------------------------------
    # Group: Application Initializer

    # Type method: init
    #
    # Initializes the application, and processes the command line.
    #
    # Syntax:
    #   init _argv_
    #
    #   argv - Command line arguments (if any)
    #
    # The application expects a single argument, the root of the log
    # directory tree; if absent, it defaults to "./log".

    typemethod init {argv} {
        # FIRST, get the log directory.
        if {[llength $argv] == 0} {
            set logdir log
        } elseif {[llength $argv] == 1} {
            set logdir [lshift argv]
        } else {
            app usage
            exit 1
        }


        # NEXT, is this a directory of log files, or a directory of
        # application log directories?  If the latter, set parentFlag
        # to true.
        
        if {[llength [glob -nocomplain [file join $logdir *.log]]] > 0} {
            set parentFlag 0
        } elseif {[llength [glob -nocomplain [file join $logdir * *.log]]] > 0} {
            set parentFlag 1
        } else {
            set parentFlag 0
        }
        
        # NEXT, set the default window title
        wm title . "$opts(-project) Log: [file normalize $logdir]"

        # NEXT, Exit the app when this window is closed, if it's a 
        # main window.
        wm protocol . WM_DELETE_WINDOW [list app exit]
        
        # NEXT, create the menus
        
        # Menu Bar
        set menubar [menu .menubar -relief flat]
        . configure -menu $menubar
        
        # File Menu
        set mnu [menu $menubar.file]
        $menubar add cascade -label "File" -underline 0 -menu $mnu

        $mnu add command                       \
            -label       "Exit"                \
            -underline   1                     \
            -accelerator "Ctrl+Q"              \
            -command     [list app exit]
        bind . <Control-q> [list app exit]
        bind . <Control-Q> [list app exit]

        # Edit menu
        set mnu [menu $menubar.edit]
        $menubar add cascade -label "Edit" -underline 0 -menu $mnu

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
        
        # View Menu
        set mnu [menu $menubar.view]
        $menubar add cascade -label "View" -underline 2 -menu $mnu
        
        $mnu add checkbutton \
            -label    "Set Scroll Lock"                 \
            -variable [mytypevar scrollLockFlag]        \
            -command  [mytypemethod SetScrollLock]
        
        $mnu add separator

        $mnu add checkbutton \
            -label    "Show Wall Clock Time"            \
            -variable [mytypevar fieldFlags(t)]         \
            -command  [mytypemethod ShowHideField t]

        $mnu add checkbutton \
            -label    "Show Zulu Time"                  \
            -variable [mytypevar fieldFlags(zulu)]      \
            -command  [mytypemethod ShowHideField zulu]

        $mnu add checkbutton \
            -label    "Show Verbosity"                  \
            -variable [mytypevar fieldFlags(v)]         \
            -command  [mytypemethod ShowHideField v]

        $mnu add checkbutton \
            -label    "Show Component"                  \
            -variable [mytypevar fieldFlags(c)]         \
            -command  [mytypemethod ShowHideField c]

        # NEXT, create the components
        
        # ROW 0 -- separator
        ttk::separator .sep0 -orient horizontal
        
        # ROW 1 -- Scrolling log
        set log .log
        scrollinglog .log                           \
            -relief        flat                     \
            -height        24                       \
            -logcmd        [mytypemethod puts]      \
            -loglevel      normal                   \
            -showloglist   yes                      \
            -showapplist   $parentFlag              \
            -defaultappdir $opts(-defaultappdir)    \
            -rootdir       [file normalize $logdir] \
            -parsecmd      [myproc LogParser]       \
            -format        {
                {t     20 no}
                {zulu  12 yes}
                {v      7 yes}
                {c      9 yes}
                {m      0 yes}
             }
             
        # ROW 2 -- separator
        ttk::separator .sep2 -orient horizontal
        
        # ROW 3 -- message line
        set msgline [messageline .msgline]

        # NEXT, grid the components in
        grid .sep0    -row 0 -column 0 -sticky ew
        grid .log     -row 1 -column 0 -sticky nsew -pady 2
        grid .sep2    -row 2 -column 0 -sticky ew
        grid .msgline -row 3 -column 0 -sticky ew
        
        grid rowconfigure    . 1 -weight 1 ;# Content
        grid columnconfigure . 0 -weight 1
        
        # NEXT, addition behavior
        bind all <Control-F12> [list debugger new]
    }
    
    #-------------------------------------------------------------------
    # Group: Event Handlers
    
    # Type method: SetScrollLock
    #
    # Locks/Unlocks the scrolling log's scroll lock.
    
    typemethod SetScrollLock {} {
        $log lock $scrollLockFlag
    }

    # Type method: ShowHideField
    #
    # Shows/Hides the named field
    #
    # Syntax:
    #   ShowHideField _name_
    #
    #   name - The name of a log field.
    
    typemethod ShowHideField {name} {
        if {$fieldFlags($name)} {
            $log field show $name
        } else {
            $log field hide $name
        }
    }
    
    # Proc: LogParser
    #
    # Parses the log lines for the <log> and returns a list of lists.
    #
    # Syntax:
    #   LogParser _text_
    #
    #   text - A block of log lines
    
    proc LogParser {text} {
        set lines [split [string trimright $text] "\n"]
    
        set lineList {}

        foreach line $lines {
            set fields [list \
                            [lindex $line 0] \
                            [lindex $line 4] \
                            [lindex $line 1] \
                            [lindex $line 2] \
                            [lindex $line 3] \
                            [lindex $line 1]]
            
            lappend lineList $fields
        }
        
        return $lineList
    }
    #-------------------------------------------------------------------
    # Group: Application Framework
    
    # Type method: configure
    #
    # Sets/gets application framework options, which are stored in the
    # <opts> variable.
    #
    # Syntax:
    #   configure _option ?value? ?option value...?_
    #
    #   option - A configuration option
    #   value  - A new value for the option
    
    typemethod configure {args} {
        if {[llength $args] == 1} {
            return $opts([lindex $args 0])
        }
        
        # NEXT, get the options
        while {[llength $args] > 0} {
            set opt [lshift args]
            
            switch -exact -- $opt {
                -appname       -
                -defaultappdir -
                -manpage       -
                -project       {
                    set opts($opt) [lshift args]
                }
                
                default {
                    error "Unrecognized option: $opt"
                }
            }
        }
    }
    
    
    #-------------------------------------------------------------------
    # Group: Utility Type Methods
    
    # Type method: exit
    #
    # Exits the program, with the specified exit code.
    #
    # Syntax:
    #   exit _?code?_
    #
    #   code - The exit code.  Defaults to 0.
    
    typemethod exit {{code 0}} {
        # TBD: Put any special exit handling here.
        exit $code
    }
    
    # Type method: puts
    #
    # Display the _msg_ in the message line
    #
    # Syntax:
    #   puts _msg_
    #
    #   msg - A text string
    
    typemethod puts {msg} {
        $msgline puts $msg        
    }

    # Type method: usage
    #
    # Displays the application's command-line syntax
    
    typemethod usage {} {
        puts "Usage: $opts(-appname) \[logdir\]"
        puts ""
        puts "See $opts(-manpage) information."
    }

}



