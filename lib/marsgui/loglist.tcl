#-----------------------------------------------------------------------
# TITLE:
#   loglist.tcl
# 
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
#   Jon Stinzel
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Loglist widget.
# 
#   This widget displays a list of logs available for browsing.
#   At the top, a list of applications which produce logs is provide as
#   an option; at the bottom is the list of logs for the currently 
#   selected application.
#
#   A log file name has this structure
#
#   <rootdir>/<appdir>/log<nnnn>.log
#
#   There is a single <rootdir>; it may contain any number of 
#   <appdir>'s, one per application; and within each <appdir> are
#   an arbitrary number of serially numbered log files.
# 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export loglist
}


#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::loglist {

    #-------------------------------------------------------------------
    # Components

    component updater         ;# timeout(n): controls -autoupdate
    component applist         ;# List of applications with logs       
    component loglist         ;# List of log files for this application

    #-------------------------------------------------------------------
    # Options

    # Delegated options
    delegate option -updateinterval to updater as -interval

    # -width num
    #
    # The character width of the loglist window.
    option -width -default 25 -readonly yes
    
    # -height num
    #
    # The character height of the loglist window, roughly.
    option -height -default 15 -readonly yes
    
    # -showtitle
    #
    # Flag indicating whether to include a button at the top of the list.
    option -showtitle -default yes -type snit::boolean -readonly yes

    # -showapplist
    #
    # Flag indicating whether or not an app list should be shown.
    option -showapplist -default yes -type snit::boolean -readonly yes

    # -rootdir dir
    #
    # The root of the log directory tree
    option -rootdir -configuremethod ConfigureRootDir
    
    method ConfigureRootDir {option value} {
        set options($option) $value
        
        # Update the loglist if this happens after creation.
        if {$initialized} {
            $self update
        }
    }
    
    # -defaultappdir dir
    #
    # Look for and select this dir when updating the loglist.
    option -defaultappdir -default "" -configuremethod ConfigureAppDir
    
    method ConfigureAppDir {option value} {
        set options($option) $value
        set currentAppDir    $value

        # Update the loglist if this happens after creation.
        if {$initialized} {
            $self update
        }
    }
    
    # -logpattern pattern
    # 
    # The glob pattern string used to filter log files in the
    # application directory.
    option -logpattern -default "*.log" -configuremethod ConfigureLogPattern

    method ConfigureLogPattern {option value} {
        set options($option) $value
        
        # Update the loglist if this happens after creation.
        if {$initialized} {
            $self update
        }
    }
    
    # -msgcmd cmd
    # 
    # The log command for reporting messages--usually the window's
    # message line.
    option -msgcmd -default ""

    # -selectcmd cmd
    # 
    # A command to execute whenever a log is selected.
    # The file's full pathname is appended as an argument.  If no log
    # is selected (i.e., if none are found) then
    # the -selectcmd will be called and passed the empty string.
    option -selectcmd -default ""

    # -formattext
    # 
    # When set true searchlogs will parse and format the text of a log 
    # file prior to searching.  This parse/format will be done according
    # to -parsecmd and -formatcmd.  Setting this to true will generally 
    # be a big performance hit so it should be used sparingly.  The
    # intended purpose is to enable accurate search results when the 
    # search string spans multiple columns.
    option -formattext -type snit::boolean -default "no"

    # -parsecmd cmd
    # 
    # cmd
    # 
    # The command used to parse the contents of a log file.
    # This will be used only if -formattext is true.
    option  -parsecmd

    # -formatcmd cmd
    # 
    # cmd
    # 
    # The command used to format the parsed contents of a log file.  
    # This will be used only if -formattext is true and a -parsecmd has 
    # been specified.
    option  -formatcmd

    # -filtercmd cmd
    # 
    # cmd
    # 
    # The command used to filter the parsed contents of a log file.
    # This command will be used by searclogs when searching earlier/later
    # log files.
    option  -filtercmd

    # -title title
    # 
    # Specifies the text displayed on the update button displayed 
    # at the top of the widget.
    option -title -default "Applications:"
    
    # -autoload boolean
    #
    # This indicates whether or not to automatically load the most 
    # recent log file in the list.
    option -autoload -default "true" -type snit::boolean \
        -configuremethod ConfigureAutoLoad

    method ConfigureAutoLoad {option value} {
        set options(-autoload) $value
    }

    # -autoupdate boolean
    #
    # Automatically refresh the loglist every few seconds.
    option -autoupdate -default "off" -type snit::boolean \
        -configuremethod ConfigureAutoUpdate

    method ConfigureAutoUpdate {option value} {
        set options(-autoupdate) $value

        if {$options(-autoupdate)} {
            $updater schedule
        } else {
            $updater cancel
        }
    }
    
    #-------------------------------------------------------------------
    # Variables

    variable initialized    0   ;# 1 after construction is complete.

    variable appDirs        ""  ;# Bare names of the app directories.
    variable currentAppDir  ""  ;# Bare name of the current app directory.

    variable lastLogSize    0   ;# Size of the most recent log 

    variable logFile        ""  ;# Full path of the currently selected log 
    variable logFiles       {}  ;# List of full paths of logs displayed
                                 # in the log list.
    variable numLogs        0   ;# The number of logs displayed in the
                                 # log list.
    variable selectedLog    -1  ;# Number (1 to numLogs) of the currently 
                                 # selected log, or -1 if none.

    variable stopFlag       0   ;# "inactive", "active", or "stop". 
    
    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    constructor {args} {
        # FIRST, create the updater.
        set options(-showapplist) [from args -showapplist]
        set updateMethod \
            [expr {$options(-showapplist) ? "AppListUpdate" : "LoadFiles"}]

        install updater using timeout ${selfns}::updater \
            -command [mymethod $updateMethod] \
            -repetition yes

        # NEXT, Save the constructor options.
        $self configurelist $args
        
        # NEXT, set the default height
        set height $options(-height)

        # NEXT, create the widgets

        # Applist -- optional list of application subdirectories
        if {$options(-showapplist)} {
            # Paner which contains the applist and loglist
            set pane [ttk::panedwindow $win.paner -orient vertical]

            # Split the overall height
            set height [expr $options(-height) / 2]
            
            frame $pane.appfrm -borderwidth 0
            $pane add $pane.appfrm
            
            install applist using text $pane.appfrm.applist   \
                -wrap           none                          \
                -xscrollcommand [list $pane.appfrm.xbar1 set] \
                -yscrollcommand [list $pane.appfrm.ybar1 set] \
                -cursor         left_ptr                      \
                -width          $options(-width)              \
                -height         $height                       \
                -state          disabled                      \
                -font           codefont

            ttk::scrollbar $pane.appfrm.xbar1  \
                -orient  horizontal            \
                -command [list $applist xview]
            
            ttk::scrollbar $pane.appfrm.ybar1  \
                -orient  vertical              \
                -command [list $applist yview]

            grid $applist            $pane.appfrm.ybar1 -sticky nsew
            grid $pane.appfrm.xbar1  x                  -sticky nsew

            grid rowconfigure    $pane.appfrm 0 -weight 1
            grid columnconfigure $pane.appfrm 0 -weight 1

            bind $applist <ButtonPress-1> [mymethod SelectAppCB @%x,%y]

            # Disable the applist's normal selection, and add a selection
            # tag we'll use to show the selected appdir.
            $applist configure \
                -selectbackground [$applist cget -background]
            $applist tag configure SELECTED \
                -background black \
                -foreground white

            # Loglist: list of logfiles
            set logfrm [frame $pane.logfrm -borderwidth 0]
            $pane add $logfrm
        } else {
            # In the simple case, loglist is a direct child of the hull
            set logfrm [frame $win.logfrm -borderwidth 0]
        }

        # Loglist -- list of log files
        install loglist using text $logfrm.loglist       \
            -wrap               none                     \
            -xscrollcommand     [list $logfrm.xbar2 set] \
            -yscrollcommand     [list $logfrm.ybar2 set] \
            -cursor             left_ptr                 \
            -width              $options(-width)         \
            -height             $height                  \
            -state              disabled                 \
            -font               codefont
            
        ttk::scrollbar $logfrm.xbar2       \
            -orient  horizontal            \
            -command [list $loglist xview]
                
        ttk::scrollbar $logfrm.ybar2       \
            -orient  vertical              \
            -command [list $loglist yview]

        grid $loglist       $logfrm.ybar2 -sticky nsew
        grid $logfrm.xbar2  x             -sticky nsew        

        grid rowconfigure    $logfrm 0 -weight 1
        grid columnconfigure $logfrm 0 -weight 1

        bind $loglist <ButtonPress-1> [mymethod SelectLogCB @%x,%y]

        # Disable the loglist's normal selection, and add the tags we'll
        # use to highlight the selected log file and animate searches.

        $loglist configure \
            -selectbackground [$loglist cget -background]

        $loglist tag configure SEARCHING \
            -background yellow -foreground black
        $loglist tag configure SELECTED \
            -foreground white
            
        # NEXT, handle the optional elements
        set listrow 0
        
        # Update button
        if {$options(-showtitle)} {
            button $win.update                        \
                -textvariable [myvar options(-title)] \
                -command      [mymethod update]

            grid $win.update  -sticky nsew
            incr listrow
        }

        # Applist+loglist or loglist only?
        if {$options(-showapplist)} {
            grid $pane   -sticky nsew
        } else {
            grid $logfrm -sticky nsew
        }

        grid rowconfigure    $win $listrow -weight 1
        grid columnconfigure $win 0        -weight 1

        # NEXT, note the default app dir
        set currentAppDir $options(-defaultappdir)

        # Schedule the first update--we always want to do one update
        # whether -autoupdate is enabled or not.  Note that if
        # -autoupdate is enabled, the first auto update will occur after
        # the -updateinterval elapses.
        #
        # Do this as an idle task; it makes the GUI startup smoother.
        after idle [mymethod update]

        # NEXT, we are now fully initialized.
        set initialized 1
    }

    # destructor -- not yet needed.

    #-------------------------------------------------------------------
    # Private Methods

    # AppListUpdate
    #
    # ?showend?   Force most recent content to be displayed
    #
    # Update the applist with all subdirectories in the file directory, and 
    # then update the loglist for the current or default appdir.
    method AppListUpdate {{showend 0}} {
        # FIRST, Enable and clear the applist
        $applist configure -state normal
        $applist delete 1.0 end
        
        # NEXT, Get the list app directories--just the bare names.
        set dirs [lsort [glob -nocomplain -directory $options(-rootdir) */]]

        set appDirs {}

        foreach path $dirs {
            # Extract the subdir name.
            set appDir [file tail [string trimright $path /]]

            lappend appDirs $appDir
        }

        # NEXT, if there are no app directories note that; otherwise,
        # list them.
        
        if {[llength $appDirs] == 0} {
            $applist insert end "No applications found\n"
        } else {
            foreach appDir $appDirs {
                $applist insert end "$appDir\n"
            }

            # Select the appropriate app
            if {$currentAppDir in $appDirs} {
                $self SelectApp $currentAppDir $showend
            } else {
                $self SelectApp [lindex $appDirs 0] $showend
            }
        }
        
        # Disable the applist widget.
        $applist configure -state disabled
    }

    # SelectAppCB index
    #
    # index     @X,Y coordinates of the button 1 press event.
    #
    # Selects the app dir under $index and loads the relevant files.

    method SelectAppCB {index} {
        # FIRST, get the line number that they clicked on.
        set appNum [lindex [split [$applist index $index] "."] 0]

        # NEXT, decrement, to match the indexing of appDirs
        incr appNum -1

        # NEXT, if they clicked in a region with no app names, just return.
        if {$appNum >= [llength $appDirs]} {
            return
        }

        $self SelectApp [lindex $appDirs $appNum] 1
    }

    # SelectApp name ?showend?
    #
    # name        An application directory name from appDirs
    # ?showend?   Force most recent content to be displayed
    #
    # Selects the named application, and displays the relevant log files.

    method SelectApp {name {showend 0}} {
        set num [lsearch -exact $appDirs $name]

        if {$num == -1} {
            error "Unknown application directory: \"$name\""
        }

        # Only if this is a change, clear our memory of the selected log 
        # since it's no longer valid.
        if {$currentAppDir ne $name} {
            set selectedLog -1
        }

        # Update the current dir.
        set currentAppDir $name
        
        # Configure tags to highlight the selection.
        set index "[expr {$num + 1}].0"

        $applist tag remove SELECTED 1.0 end
        $applist tag add    SELECTED \
            "$index linestart" "$index+1 lines linestart"
        $applist see $index
     
        # Load the logslist with the application directory.
        $self LoadFiles $showend
    }

    # SelectLogCB index
    #
    # index     @X,Y coordinates of the button press event in loglist.
    #
    # Callback method for loglist button events.  Convert the @x,y index 
    # to a number, and invoke the SelectLog to select the log.
    method SelectLogCB {index} {
        # FIRST, get the line number that they clicked on.
        set lognum [lindex [split [$loglist index $index] "."] 0]

        # NEXT, if they clicked in a region with no logs, just return.
        if {$lognum > $numLogs} {
            return
        }

        $self SelectLog $lognum
    }

    # SelectLog num ?changed?
    #
    # num      Number of the entry to select, 1 to numLogs
    # changed  True if num changed, false otherwise
    #
    # Interpret the given coordinates, highlight the selected list entry, and
    # return the pathname of the selected file.  Invoke the appropriate button
    # command if specified.
    
    method SelectLog {num {changed 1}} {
        if {$num < 1 || $num > $numLogs} {
            error "invalid log number: \"$num\""
        }

        # Convert index into a line coordinate ($index may be an integer).
        set logIndex "$num.0"

        # Save the selected log number.
        set selectedLog $num

        set logFile [lindex $logFiles [expr {$num - 1}]]

        # If this is the most recent file, save the size
        if {$num == $numLogs} {
            catch {set lastLogSize [file size $logFile]}
        }
        
        # Configure tags to highlight the selection.  Set the SELECTED tag
        # background to grey indicating the start of the select command.
        $loglist tag configure SELECTED -background grey
        $loglist tag remove    SELECTED 1.0 end

        $loglist see $logIndex
        
        $loglist tag add       SELECTED \
            "$logIndex linestart" "$logIndex+1 lines linestart"

        update idletasks
        
        # Invoke the -selectcmd and indicate if this is a change.
        $self CallSelectCmd $logFile $changed

        # Configure the SELECTED tag background to black, indicating the
        # completion of the button command.
        $loglist tag configure SELECTED -background black
        
        # Return the selected entry.
        return $logFile
    }


    # LoadFiles ?showend?
    #
    # ?showend?    Force most recent content to be displayed
    # 
    # Load the logslist with all logs matching -logpattern in the current
    # app directory.  Select the last if appropriate.
    method LoadFiles {{showend 0}} {
        # FIRST, get the full path of the app directory
        set dir [file join $options(-rootdir) $currentAppDir]

        # FIRST, Enable and clear the loglist.
        $loglist   configure -state normal

        # NEXT, no log is selected.
        set prevSelectedLog $selectedLog
        set selectedLog -1
            
        # NEXT, Get a sorted list of all logs matching the -logpattern.
        set logFiles \
            [lsort [glob -nocomplain -directory $dir $options(-logpattern)]]

        set prevNumLogs $numLogs
        set numLogs     [llength $logFiles]
        
        # NEXT, Keep the loglist updated;
        # if there are no entries just note the fact.
        if {$numLogs == 0} {
            $loglist   delete 1.0 end
            $loglist insert end "No log files found\n"
            
            # Notify clients that no log is selected.
            $self CallSelectCmd ""
        } else {
            catch {set size [file size \
                                 [lindex $logFiles [expr {$numLogs - 1}]]]}

            # Rebuild the list and show the latest if requested or this is
            # the first time for the current app. Only autoload latest
            # if there's a new latest or the content of the latest changed.
            if {$showend || $prevSelectedLog == -1 ||
                ($options(-autoload) && 
                 ($numLogs > $prevNumLogs || $size != $lastLogSize))
            } {
                $loglist   delete 1.0 end

                foreach filepath $logFiles {
                    set file [file tail $filepath]
                    $loglist insert end "$file\n"
                }
                $self SelectLog $numLogs 1
            } else {
                # Otherwise just keep the list updated with new entries.
                # This will be the case if the user has taken control 
                # of logdisplay(n) by enabling scroll-lock.
                if {$numLogs > $prevNumLogs} {
                    foreach filepath [lrange $logFiles $prevNumLogs end] {
                        set file [file tail $filepath]
                        $loglist insert end "$file\n"
                    }
                }

                # Remember the selected log
                set selectedLog $prevSelectedLog
            }
        }
        
        # NEXT, Disable the loglist again
        $loglist configure -state disabled
    }

    # CallSelectCmd logfile ?changed?
    #
    # logfile    Selected log file, or ""
    # ?changed?  Indicates the file changed or desire to pretend so
    #
    # Calls the -selectcmd, passing it the selected log file, or
    # passing it "" to indicate that no log is selected.

    method CallSelectCmd {logfile {changed 0}} {
        if {$options(-selectcmd) ne ""} {
            set cmd $options(-selectcmd)
            lappend cmd $logfile $changed
            uplevel \#0 $cmd
        }
    }
    
    # Message text
    #
    # text    A one-line text message
    #
    # Passes the text to -msgcmd, if any.
    method Message {text} {
        if {$options(-msgcmd) ne ""} {
            set cmd $options(-msgcmd)
            lappend cmd $text
            uplevel \#0 $cmd
        }
    }

    #-------------------------------------------------------------------
    # Public Methods
        
    # update 
    #
    # If the applist is enabled, update it with all subdirectories in the 
    # root directory. Always update the loglist for the current or default 
    # appdir.
    method update {} {

        if {$options(-showapplist)} {
            $self AppListUpdate 1
        } else {
            # Clear our memory of the selected log since it's no longer valid.
            set selectedLog -1
     
            # Load the logslist with the application directory.
            $self LoadFiles
        }

    }
    
    # searchlogs direction target ?searchtype?
    #
    # direction     "earlier" or "later".
    # target        Regexp search target.
    # searchtype    "exact", "wildcard", or "regexp".  Defaults to "exact".
    #
    # Searches the logs of the current subdirectory in the specified direction
    # for the given regexp target.
    method searchlogs {direction target {searchtype "exact"}} {
    
        # Throw an error if $direction isn't valid.
        switch -exact $direction {
            "earlier"   {set delta -1}
            "later"     {set delta 1}
            default     {error "Invalid direction: '$direction'."}
        }
        
        # Throw an error if $type isn't valid.
        switch -exact $searchtype {
            "exact"     {
                set pattern "***=$target"
            }
            
            "wildcard"  {
                set pattern [::marsutil::wildToRegexp $target]
            }
                         
            "regexp"    {
                set pattern $target
            }
            
            default     {error "Invalid type: '$type'."}
        }
        
        # Return if no log has been selected.
        if {$selectedLog == -1} {
            bell            
            return 0
        }
        
        # Start the search.
        set stopFlag 0
    
        # Log the start of the search.
        $self Message "Searching $direction logs for '$target'."
        
        
        # Loop over the logs.
        for {set i $selectedLog; incr i $delta} \
            {$i > 0 && $i <= $numLogs}           \
            {incr i $delta}                      {
        
            # Highlight the log being searched. 
            $loglist tag remove SEARCHING 1.0    end
            $loglist tag add    SEARCHING "$i.0" "$i.0 +1 lines linestart"
            $loglist see $i.0
            update idletasks
            
            # Get the pathname of the log being searched.
            set log [lindex $logFiles [expr {$i - 1}]]

            # Get the raw contents of this file
            if {[set text [$self ReadLog $log]] eq ""} {
                continue
            }
            
            # Do the search.
            set hits 0
            if {!$options(-formattext)} {
                # Is there a match in the raw text?
                catch {set hits [regexp -line $pattern $text]}

                # If so, check again if a filtercmd has been provided
                if {$hits > 0 && $options(-filtercmd) ne ""} {
                    catch {set hits \
                               [regexp -line $pattern [$self Filter $text]]}
                }
            } else {
                # Fully format the text prior to looking for a match
                catch {set hits [regexp $pattern [$self Format $text]]}
            }

            if {$hits > 0} {
                # Got hits.
                $loglist tag remove SEARCHING 1.0 end
                $self SelectLog $i
                
                return 1
            }
            
            # Stop if requested.  Update call gets latest value of 
            # stopFlag, which may have changed while this loop was active.
            # TBD: Break this into a sequence of idletasks.
            update
            
            if {$stopFlag} {
                break
            }
        }
        
        # Log the search failure.
        $self Message \
            "Failed to find '$target' in $direction logs ($searchtype search)."
        
        # Clean up the search tags.
        $loglist tag remove SEARCHING 1.0    end
        
        # Reset the stop flag.
        set stopFlag 0
        
        # Show the selected log.
        $loglist see "$selectedLog.0"
        
        # Search failed.
        return 0
    }
    
    # stopsearch
    #
    # Stops the current log search by setting the stop flag.  If there is
    # an active search, it will query the stop flag after each log and 
    # terminate if it's set.
    method stopsearch {} {
        set stopFlag 1
    }

    # ReadLog file
    #
    # file    The name of the file to read
    #
    # Returns the raw contents of the file provided there are no errors
    # opening or reading the file.
    method ReadLog  {file} {

        # Open the file, and configure it explicitly for "lf" mode.
        # This way, carriage returns in the data don't cause trouble.
        if {[catch {set handle [open $file]} result]} {
            $self Message "Error opening [file tail $file]: $result"
            return ""
        }
        fconfigure $handle -translation lf
        
        # Read the file contents. 
        if {[catch {set contents [read -nonewline $handle]} result]} {
            $self Message "Error reading [file tail $file]: $result"
            catch {close $handle}
            return ""
        }
        
        # Close the file.
        catch {close $handle}
        
        return $contents
    }

    # Format file
    # 
    # contents    text to be formatted
    #
    # Returns the raw, parsed or formatted contents based on which
    # options have been provided.
    method Format {contents} {

        # Without a parser return the raw contents
        if {$options(-parsecmd) eq ""} {
            return $contents
        } 
        
        # Parse the contents
        set cmd $options(-parsecmd)
        lappend cmd $contents
        set parsed [uplevel \#0 $cmd]
        
        # Without a formatter return the parsed contents
        if {$options(-formatcmd) eq ""} {
            return $parsed
        } 

        # Format the parsed contents
        set formated [list]
        foreach entry $parsed {
            set cmd $options(-formatcmd)
            lappend cmd $entry
            set entry [uplevel \#0 $cmd]

            if {$entry ne ""} {
                lappend formated $entry
            }
        }

        return $formated
    }

    # Filter contents
    #
    # contents    text to be filtered
    #
    # Returns the raw, parsed or filtered text based on which options
    # have been provided.
    method Filter {contents} {

        # Without a parser return the raw contents
        if {$options(-parsecmd) eq ""} {
            return $contents
        } 
        
        # Parse the contents
        set cmd $options(-parsecmd)
        lappend cmd $contents
        set parsed [uplevel \#0 $cmd]
        
        # Without a filter return the parsed contents
        if {$options(-filtercmd) eq ""} {
            return $parsed
        } 

        # Pass each entry through the supplied filter
        set filtered [list]
        foreach entry $parsed {
            set cmd $options(-filtercmd)
            lappend cmd $entry
            
            # Does this entry pass through the filter?
            if {[uplevel \#0 $cmd]} {
                lappend filtered $entry
            }
        }

        return $filtered
    }

}











