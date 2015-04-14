#-----------------------------------------------------------------------
# TITLE:
#    scrollinglog.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Scrolling Log Browser widget.
#
#    This widget displays an application's current log file;
#    it allows scrolling, filtering, and searching.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export scrollinglog
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::scrollinglog {
    hulltype ttk::frame
    
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::logger  ;# need log levels
    }

    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option -borderwidth    to hull
    delegate option -relief         to hull
    delegate option *               to hull

    # Options delegated to the logdisplay widget
    delegate option -format             to log
    delegate option -tags               to log
    delegate option -font               to log
    delegate option -height             to log
    delegate option -width              to log
    delegate option -foreground         to log
    delegate option -background         to log
    delegate option -insertbackground   to log
    delegate option -insertwidth        to log
    delegate option -autowidth          to log

    # Options we'd like to delegate to loglist but can't since loglist is
    # optional.  They'll be "propagated" instead.
    option -defaultappdir                  -configuremethod SetLogListOpts
    option -formattext    -default "no"    -configuremethod SetLogListOpts
    option -logpattern    -default "*.log" -configuremethod SetLogListOpts
    option -rootdir                        -configuremethod SetLogListOpts
    option -showapplist   -default "no"    -readonly yes

    # Options progagated to both log and loglist.
    option -updateinterval -default 1000   -configuremethod SetOpts 
    option -parsecmd                       -configuremethod SetOpts
    option -showtitle      -default "no"   -readonly yes

    # -title
    #
    # Title label for toolbar

    option -title -default "Log"

    # -logcmd
    #
    # Specifies a command that the scrolling log can use to output
    # messages, typically to the messageline.  It should take one
    # argument, a message string.

    option -logcmd

    # -loglevel
    #
    # Maximum log level (verbosity) to show.

    option -loglevel -default "normal" -configuremethod SetLogLevel

    # -showloglist
    #
    # Flag indicating whether or not to include a loglist(n)
    option -showloglist -default "false" -type snit::boolean -readonly yes

    #-------------------------------------------------------------------
    # Components

    component bar            ;# The title/tool bar
    component log            ;# The scrolling text widget
    component loglist        ;# The optional loglist

    #-------------------------------------------------------------------
    # Instance variables

    variable logfile        ""     ;# Name of the log file being displayed
    variable scrollbackFlag 1      ;# Var for $bar.scrollback
    variable verbosities -array {} ;# Controls which levels to display
    variable colindex -array {}    ;# Column index by column name

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {        
        # FIRST, create the components

        # Title Bar
        install bar using ttk::frame $win.bar

        # Get the -parsecmd, -format, -tags and -showtitle values, specifying
        # the scrollinglog(n) default.
        set parseCmd [from args -parsecmd [myproc LogParser]]
        set format   [from args -format {
            {zulu  12 yes}
            {v      7 yes}
            {c      7 yes}
            {m      0 yes}
        }]
        set tags     [from args -tags {
            {fatal   -background red}
            {error   -background orange}
            {warning -background yellow}
        }]
        set showTitle [from args -showtitle]
        
        # From the -format, determine which column is which
        set i -1
        foreach record $format {
            set colindex([lindex $record 0]) [incr i]
        }

        # NEXT, determine if a loglist should be included.
        set loglist ""
        set options(-showloglist) [from args -showloglist]

        # NEXT, Name the log display based on the parent
        if {$options(-showloglist)} {
            # Paner to contain the loglist and log
            set paner [ttk::panedwindow $win.paner -orient horizontal]

            set dlogName $paner.dlog
        } else {
            # The log display will be a child of the hull in this case
            set dlogName $win.dlog
        }

        install log using logdisplay $dlogName          \
            -foreground     black                       \
            -background     white                       \
            -height         24                          \
            -width          80                          \
            -insertwidth    0                           \
            -font           codefont                    \
            -msgcmd         [mymethod LogCmd]           \
            -autoupdate     1                           \
            -autoscroll     $scrollbackFlag             \
            -filtercmd      [mymethod LogFilter]        \
            -foundcmd       [list $bar.finder found]    \
            -parsecmd       $parseCmd                   \
            -format         $format                     \
            -tags           $tags                       \
            -showtitle      $showTitle

        # NEXT, create the loglist if need be.
        if {$options(-showloglist)} {
            # Get the -showapplist value for loglist(n).
            set showAppList [from args -showapplist "no"]

            install loglist using loglist $paner.loglist  \
                -msgcmd           [mymethod LogCmd]       \
                -selectcmd        [mymethod ListSelectCB] \
                -autoupdate       1                       \
                -autoload         $scrollbackFlag         \
                -showtitle        $showTitle              \
                -showapplist      $showAppList            \
                -parsecmd         $parseCmd               \
                -filtercmd        [mymethod LogFilter]    \
                -formatcmd        [list $log format]
            
            # NOTE: Propagated options handled via configurelist below
        }

        # Tool bar contents
        menubox $bar.loglevel                            \
            -textvariable [myvar options(-loglevel)]     \
            -values       [lrange [logger levels] 1 end] \
            -width        7                              \
            -command      [mymethod HandleLogLevel]

        ttk::checkbutton $bar.scrollback                  \
            -style    Toolbutton                          \
            -image    {
                         ::marsgui::icon::unlocked
                selected ::marsgui::icon::locked}         \
            -variable [myvar scrollbackFlag]              \
            -offvalue 1                                   \
            -onvalue  0                                   \
            -command [mymethod SetScrollback]
        
        DynamicHelp::add $bar.scrollback \
            -text "Scroll Lock/Unlock"

        finder $bar.finder              \
            -findcmd  [list $log find]  \
            -msgcmd   [mymethod LogCmd] \
            -width    20                \
            -loglist  $loglist

        filter $bar.filter \
            -filtercmd [mymethod FilterHandler] \
            -msgcmd    [mymethod LogCmd]        \
            -width     20

        # NEXT, pack the components
        pack $bar.loglevel   -side left  -padx 1
        pack $bar.scrollback -side right -padx 1
        pack $bar.finder     -side right -padx 1 -pady 2 -padx {4 0}
        pack $bar.filter     -side right -padx 1 -pady 2

        pack $bar -side top -fill x

        if {$options(-showloglist)} {
            # Add a separator
            frame $win.sep -height 2 -relief sunken -borderwidth 2
            pack  $win.sep -side top -fill x

            $paner add $loglist
            $paner add $log
            
            pack $paner -side top -fill both -expand 1
        } else {
            # We only have the log display
            pack $log -side top -fill both -expand 1
        }

        # NEXT, process the arguments
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Private Methods

    # SetOpts 
    #
    # Sets the options that are potentially propagated to both log and
    # loglist.

    method SetOpts  {option value} {
        set options($option) $value

        $log configure $option $value

        if {$options(-showloglist) && $loglist ne {}} {
            $loglist configure $option $value
        }
    }

    # SetLogListOpts 
    #
    # Sets the options of the loglist component if it exists.

    method SetLogListOpts  {option value} {
        set options($option) $value

        if {$options(-showloglist) && $loglist ne {}} {
            $loglist configure $option $value
        }
    }

    # SetLogLevel 
    #
    # Sets the log level.

    method SetLogLevel {option value} {
        set options(-loglevel) $value

        $self HandleLogLevel
    }

    # HandleLogLevel 
    #
    # Adjusts the verbosities array according to -loglevel and calls redisplay.

    method HandleLogLevel {} {
        set levels [logger levels]
        set lognum [lsearch $levels $options(-loglevel)]
        foreach level $levels {
            set verbosities($level) 1
            if {[lsearch $levels $level] > $lognum} {
                set verbosities($level) 0
            }
        }

        $log redisplay
    }

    # SetScrollback
    #
    # Updates the logdisplay's -autoscroll and sets -autoupdate based on 
    # the scrollback flag updating the icon as well.

    method SetScrollback {} {
        $log configure -autoscroll $scrollbackFlag
        
        # Set the scrollback button's bitmap to match and set -autoupdate.
        if {$scrollbackFlag} {
            $log configure -autoupdate on

            if {$loglist ne ""} {
                $loglist configure -autoload on 
            }

            # During the time scrollback was disabled either the log contents
            # or the most recent file may have changed.  Load again to
            # handle either case.
            if {$logfile ne ""} {
                $log load $logfile
            }
        } else {
            $log configure -autoupdate off

            if {$loglist ne ""} {
                $loglist configure -autoload off
            }
        }
    }

    # FilterHandler
    #
    # Trigger refiltration

    method FilterHandler {} {
        $log redisplay
    }

    # LogFilter entryStr
    #
    # entryStr   The string to filter on.
    #
    # Returns 1 if the entryStr passes the filter, and 0 otherwise.

    method LogFilter {entryStr} {
        #  Filter by verbosity.
        set verb [lindex $entryStr $colindex(v)]
        
        if {![info exists verbosities($verb)] || !$verbosities($verb)} {
            return 0
        }

        return [$bar.filter check $entryStr]
    }

    # listSelectCB filepath showend
    #
    # filepath  Full pathname of the selected file.
    # showend   Indicates a desire to show the most recent content
    # 
    # Loads the specified log file.

    method ListSelectCB {filepath showend} {
        set logfile $filepath
        $log load $filepath $showend
    }

    # LogCmd args
    #
    # Passes the finger and logdisplay's logcmd onward.

    method LogCmd {msg} {
        if {$options(-logcmd) ne ""} {
            set cmd $options(-logcmd)
            lappend cmd $msg
            uplevel \#0 $cmd
        }
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # LogParser text
    #
    # text    A block of log lines
    #
    # Parses the lines and returns a list of lists.
    
    proc LogParser {text} {
        set lines [split [string trimright $text] "\n"]
    
        set lineList {}

        foreach line $lines {
            set fields [list \
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
    # Public Methods

    delegate method field to log

    # load  filename
    #
    # filename  A logfile to load
    #
    # Insructs the logdisplay to load the new file if autoscroll is on.
    method load {filename} {
        set logfile $filename
        
        if {$scrollbackFlag} {
            $log load $logfile
        }
    }
    
    # lock ?flag?
    #
    # flag   A boolean flag
    #
    # Queries/sets the scroll lock (called "scrollback" above).
    
    method lock {{flag ""}} {
        if {$flag ne ""} {
            set scrollbackFlag [expr {!$flag}]
            $self SetScrollback
        }
        
        return [expr {!$scrollbackFlag}]
    }
}







