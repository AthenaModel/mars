#-----------------------------------------------------------------------
# TITLE:
#    debugger.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Debugging Console
#
#    This widget provides a "terminal" window for interacting
#    with the main Tcl interpreter; it might add additional features
#    for debugging Tcl/Tk apps over time.
#
# FUTURE:
#    * It would be nice to have buttons to automatically set the pane
#      sizes in particular ways
#
#    * It would be nice to load a command found in the command browser
#      into the mod editor with a buttonpush.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export debugger
}


#-----------------------------------------------------------------------
# The Debugger Widget Type

snit::widget ::marsgui::debugger {
    hulltype toplevel

    #-------------------------------------------------------------------
    # Components

    component tnb     ;# The tabbed notebook
    component wb      ;# The winbrowser
    component cb      ;# The cmdbrowser
    component me      ;# The modeditor
    component cli     ;# The CLI shell
    component msgline ;# The messageline

    #-------------------------------------------------------------------
    # Options

    # Delegate most options to the hull toplevel
    delegate option * to hull
    
    delegate option -editordefaultdir to me as -defaultdir
    delegate option -editorformatcmd  to me as -formatcmd

    # -app flag
    #
    # If 1, this is an application window.  The application should
    # terminate when it goes down, and it should have a File/Exit
    # menu item rather than a File/Close Window menu item.

    option -app -type snit::boolean -default no -readonly yes 

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Handle the early options
        set options(-app) [from args -app 0]

        # NEXT, create the menu bar
        set menubar [menu $win.menubar]
        $win configure -menu $menubar

        # NEXT, create the File menu
        set filemenu [menu $menubar.file]
        $menubar add cascade -label "File" -underline 0 -menu $filemenu

        $filemenu add command         \
            -label "New Debugger..."  \
            -underline 0              \
            -accelerator "Ctrl+N"     \
            -command [mymethod NewDebugger]
        bind $win <Control-n> [mymethod NewDebugger]

        if {$options(-app)} {
            $filemenu add command     \
                -label "Exit"         \
                -underline 0          \
                -accelerator "Ctrl+Q" \
                -command [mymethod Exit]
            bind $win <Control-q> [mymethod Exit]
        } else {
            $filemenu add command     \
                -label "Close Window" \
                -underline 0          \
                -accelerator "Ctrl+W" \
                -command [mymethod Close]
            bind $win <Control-w> [mymethod Close]
        }

        # NEXT, create the Edit menu
        set editmenu [menu $menubar.edit]
        $menubar add cascade -label "Edit" -underline 0 -menu $editmenu
    
        $editmenu add command     \
            -label "Undo"         \
            -underline 0          \
            -accelerator "Ctrl+Z" \
            -command {event generate [focus] <<Undo>>}

        $editmenu add separator

        $editmenu add command     \
            -label "Cut"          \
            -underline 2          \
            -accelerator "Ctrl+X" \
            -command {event generate [focus] <<Cut>>}

        $editmenu add command     \
            -label "Copy"         \
            -underline 0          \
            -accelerator "Ctrl+C" \
            -command {event generate [focus] <<Copy>>}

        $editmenu add command     \
            -label "Paste"        \
            -underline 0          \
            -accelerator "Ctrl+V" \
            -command {event generate [focus] <<Paste>>}
        
        $editmenu add command           \
            -label "Select All"         \
            -underline 0                \
            -accelerator "Ctrl+Shift+A" \
            -command {event generate [focus] <<SelectAll>>}


        # NEXT, create the Browser menu
        set bmenu [menu $menubar.browser]
        $menubar add cascade -label "Browser" -underline 0 -menu $bmenu
    
        $bmenu add command \
            -label "Refresh" \
            -underline 0 \
            -accelerator "Ctrl+R" \
            -command [mymethod Refresh]

        bind $win <Control-r> [mymethod Refresh]
        bind $win <Control-R> [mymethod Refresh]


        # NEXT, create the paner
        ttk::panedwindow $win.paner \
            -orient vertical

        # NEXT, create the tabbed notebook for the browsers
        install tnb using ttk::notebook $win.paner.tnb \
                     -height    300                    \
                     -padding   2                      \
                     -takefocus 1
        $win.paner add $tnb

        # NEXT, create the winbrowser
        install wb using ::marsgui::winbrowser $tnb.wb \
            -logcmd [list $win.msgline puts]

        $tnb add $wb \
            -sticky  nsew      \
            -padding 2         \
            -text    "Widgets"
        
        # NEXT, create the cmdbrowser
        install cb using ::marsgui::cmdbrowser $tnb.cb \
            -editcmd [mymethod edit]                   \
            -logcmd  [list $win.msgline puts]

        $tnb add $cb \
            -sticky  nsew       \
            -padding 2          \
            -text    "Commands"

        # NEXT, create the mod editor
        install me using ::marsgui::modeditor $tnb.me \
            -logcmd [list $win.msgline puts]
        
        $tnb add $me \
            -sticky  nsew     \
            -padding 2        \
            -text    "Editor"

        # NEXT, create the CLI
        install cli using ::marsgui::cli $win.paner.cli \
            -height    15                   \
            -promptcmd [mymethod GetPrompt] \
            -commandlist [info commands]

        $win.paner add $cli
        
        # NEXT, the message line.
        
        install msgline using messageline $win.msgline

        # NEXT, grid everything.
        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1

        grid $win.paner -row 0 -column 0 -sticky nsew
        grid $msgline   -row 1 -column 0 -sticky ew

        # NEXT, set the window title.
        if {$options(-app)} {
            wm title $win "[wm title .]: Debugging Console"
        } else {
            wm title $win "[wm title .]: Debugger ($win)"
        }

        # NEXT, if this is an app, exit when the window is destroyed.
        if {$options(-app)} {
            wm protocol $win WM_DELETE_WINDOW [mymethod Exit]
        }
        
        # NEXT, set any other options.
        $self configurelist $args
        

        # NEXT, Allow the widget sizes to propagate to the toplevel, so
        # the window gets its default size; then turn off propagation.
        # From here on out, the user is in control of the size of the
        # window.
        update idletasks
        grid propagate $win off

    }
    
    #-------------------------------------------------------------------
    # Public Methods
    
    # edit name
    #
    # name     A command name
    #
    # This is the cmdbrowser's -editcmd.  It loads the command into
    # the editor.
    
    method edit {name} {
        # FIRST, show the editor
        $tnb select $me
        
        # NEXT, grab the code.
        $me grab $name
    }


    #-------------------------------------------------------------------
    # Private Methods
    
    # NewDebugger
    #
    # Creates a new debugger window with the same options
    
    method NewDebugger {} {
        debugger new \
            -editordefaultdir [$self cget -editordefaultdir] \
            -editorformatcmd  [$self cget -editorformatcmd]
    }

    # Close
    #
    # Destroy this console.
    
    method Close {} {
        destroy $win
    }

    # Exit
    #
    # Exit the app
    
    method Exit {} {
        exit
    }


    # GetPrompt
    #
    # Returns the prompt

    method GetPrompt {} {
        return  "dbg>"
    }

    # Refresh
    #
    # Refresh all of the browser components

    method Refresh {} {
        $wb refresh
        $cb refresh
    }
    

    #-------------------------------------------------------------------
    # Public typemethods
    
    # new ?option value...?
    #
    # Creates a new debugger window.

    typemethod new {args} {
        $type create .%AUTO% {*}$args
    }
    
    # debug ?command...?
    #
    # command     A command, to be loaded into the debugger's
    #             mod editor.
    #
    # Pops up the most recent, or creates a new one,
    # debugger, and loads the command into the editor.
    
    typemethod debug {args} {
        set dbg [lindex [$type info instances] end]
        
        if {$dbg eq ""} {
            set dbg [$type new]
        } else {
            wm withdraw $dbg
            wm deiconify $dbg
            raise $dbg
        }
        
        if {[llength $args] > 0} {
            $dbg edit $args
        }
    }

}




