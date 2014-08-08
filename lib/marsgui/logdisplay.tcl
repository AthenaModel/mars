#-----------------------------------------------------------------------
# TITLE:
#   logdisplay.tcl
# 
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Logdisplay widget.
# 
#   This widget provides a widget for displaying the content of
#   generic log files.
# 
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export logdisplay
}


#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::logdisplay {
    hulltype ttk::frame
    
    #-------------------------------------------------------------------
    # Components

    component reader         ;# The logreader(n) component
    component rotext         ;# The rotext(n) widget used to display the 
                              # log entries.
    component updater        ;# The timeout(n) component used for
                              # -autoupdate.
    
    #-------------------------------------------------------------------
    # Options

    # -tags datalist
    # 
    # A list of text(n) tag configuration data. Each entry of the form:
    # {<tag name> <config option> <config data> ...}.  Note that the
    # -parsecmd chooses a tag for each parsed entry; these options
    # define how the tagged entries are displayed.
    option -tags        
    
    # -filtercmd cmd
    # 
    # A command prefix to which a log entry is appended as a single
    # argument.  Must return 1 if the entry passes the filter, else 0.
    option -filtercmd
        
    # -msgcmd cmd
    # 
    # Specifies a log command for reporting messages.    
    option -msgcmd -default ""
    
    # -format formatlist
    # 
    # Used to format the display of log entries.  There must be one entry in
    # formatlist for each field in the log entries returned by the parsing
    # command.  Each entry in formatlist must be of the form: 
    # 
    #        {field name} {field width} {show field}.  
    # 
    # The <field name> is currently unused, <field width> is the character 
    # display width, and <show field> is a flag indicating whether or not to
    # display this field.
    option -format -readonly 1
    
    # -showtitle flag
    # 
    # If <flag> is set, displays the pathname of the current log file in a 
    # title button above the text widget.  Pressing the button updates
    # the currently loaded file, loading any new entries.
    option -showtitle -default "no" -readonly yes
    
    # -autoupdate    boolean
    #
    # Automatically get any new log entries every few seconds.
    # Note: if loglist(n) is used and has -autoupdate on, this 
    # need not be on.
    option -autoupdate -default "off" -configuremethod ConfigureAutoUpdate

    method ConfigureAutoUpdate {option value} {
        set options(-autoupdate) $value

        if {$options(-autoupdate)} {
            $updater schedule
        } else {
            # Cancel the next update, AND close the current log file.
            $updater cancel
        }
    }
    
    # -autoscroll boolean
    #
    # Automatically scroll the log down to display new entries on update.
    option -autoscroll -default no
    
    # Delegate the remaining options.
    delegate option -foundcmd       to rotext
    delegate option -parsecmd       to reader
    delegate option -updateinterval to updater as -interval
    delegate option *               to rotext
    
    #-------------------------------------------------------------------
    # Variables

    variable logFile             ""  ;# Pathname of the displayed log.
    variable title               ""  ;# Title string in title/update button.
    variable numDisplayed        0   ;# Number of entries displayed.
    variable logEntries          {}  ;# List of log entries.
    variable numFields           0   ;# Number of fields in each log entry.
    variable fieldNames              ;# List of field names
    variable fieldWidths             ;# List of corresponding field widths.
    variable fieldDisplayFlags       ;# List of corresponding display flags.
    variable findCount           0   ;# Number of find hits.
    
    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    constructor {args} {
        # FIRST, Install the logreader component; name it so that it gets
        # destroyed automatically.
        install reader using ::marsutil::logreader ${selfns}::reader

        # NEXT, create the updater; name it so that it gets destroyed
        # automatically.
        install updater using timeout ${selfns}::updater \
            -command [mymethod GetNewEntries]            \
            -repetition yes
        
        # NEXT, Install the rotext widget.
        install rotext using ::marsgui::rotext $win.text \
            -wrap               none                     \
            -selectborderwidth  0                        \
            -xscrollcommand     [list $win.xbar set]     \
            -yscrollcommand     [list $win.ybar set]     \
            -borderwidth        1                        \
            -relief             sunken          

        # NEXT, Save the constructor options.
        $self configurelist $args
        
        # NEXT, Create the other widgets
        if {$options(-showtitle)} {
            button $win.title                   \
                -borderwidth  1                 \
                -textvariable [myvar title]     \
                -command      [mymethod GetNewEntries 1]
        }

        ttk::scrollbar $win.xbar              \
            -orient      horizontal           \
            -command     [list $rotext xview]
                
        ttk::scrollbar $win.ybar              \
            -orient      vertical             \
            -command     [list $rotext yview]
    
        # NEXT, lay out the widgets; the layout depends on whether
        # there's a title button or not.
        if {$options(-showtitle)} {
            grid $win.title - -sticky nsew
            set rotextRow 1
        } else {
            set rotextRow 0        
        }

        grid $rotext    $win.ybar -sticky nsew
        grid $win.xbar  x         -sticky nsew
        
        grid rowconfigure    $win $rotextRow -weight 1
        grid columnconfigure $win 0          -weight 1

        # NEXT, parse the -format and save information about the
        # text fields.
        set numFields [llength $options(-format)]
        set fieldNames        {}
        set fieldWidths       {}
        set fieldDisplayFlags {}
        
        foreach fieldFormat $options(-format) {
            lappend fieldNames        [lindex $fieldFormat 0]
            lappend fieldWidths       [lindex $fieldFormat 1]           
            lappend fieldDisplayFlags [lindex $fieldFormat 2]
        }
        
        # NEXT, Configure the user-defined -tags for display.
        # Lower them below the tags defined by the $rotext itself.
        foreach tag $options(-tags) {
            eval [linsert $tag 0 $rotext tag configure]
            $rotext tag lower [lindex $tag 0]
        }
        
        # NEXT, Raise the "sel" tag so that the selection is always visible.
        $rotext tag raise sel
    }
     
    # Default Destructor is adequate.

    #-------------------------------------------------------------------
    # Private Methods

    # ClearDisplay
    #
    # Clear the display, but retain the current logEntries.

    method ClearDisplay {} {
        # Zero the number of displayed entries.
        set numDisplayed 0
        
        # Clear the display.
        $rotext del 1.0 end
    }
 
    # GetNewEntries ?showend?
    #
    # ?showend?     Forces display of last log entry.
    #
    # Gets a list of new log entries from the reader and appends them into
    # the display.
    method GetNewEntries {{showend 0}} {
        # Check that a log file has been specified.
        if {$logFile eq ""} {
            return
        }
        
        # Get the new entries from the reader.
        if {[catch {$reader newentries $logFile} result]} {
            # Log the error and return.
            $self Message $result
            return
        } else {
            set newEntries $result
        }
        
        set logEntries [concat $logEntries $newEntries]
        
        # Update the display with the new entries stored in $result.
        $self Append $newEntries $showend
    }
    
    # Append newEntries ?showend?
    #
    # newEntries    List of new log entries.
    # ?showend?     Forces display of last log entry.
    #
    # Filter and append into the display the new log entries.
    method Append {newEntries {showend 0}} {
        ::marsutil::assert {$logFile ne ""}

        # If we aren't displaying any entries at present, clear the
        # display (so as to get rid of any previous message.
        if {$numDisplayed == 0} {
            $self ClearDisplay
        }

        # Assume all the entries pass the filter.
        incr numDisplayed [llength $newEntries]
        
        # Loop over the entries.
        foreach entry $newEntries {
            # Reset the entry variables.
            set newlineOffset 0
            set entryStr      [$self format $entry]
            
            # Ignore blank entries.
            if {$entryStr eq ""} {
                incr numDisplayed -1
                continue
            }

            # Insert the entry and add the tag.
            # The entry tag is the last item in the entry.
            $rotext ins end "$entryStr\n" [lindex $entry end]
        }
        
        # If the display is empty, determine and log the reason.
        if {[llength $logEntries] == "0"} {
            $self ClearDisplay
            $rotext ins end "No entries in log file."
        } elseif {$numDisplayed == 0} {
            $self ClearDisplay
            $rotext ins end "All entries filtered out."
        }

        # If nothing new and we're not being forced to show the latest
        # simply return.  We're done.
        if {[llength $newEntries] == 0 && !$showend} {
            return
        }
                
        set oldCount $findCount

        # Force highlighting of the last match if autoscrolling.
        # Otherwise just update the count
        if {$options(-autoscroll)} {
            $rotext find update 1
        } else {
            $rotext find update 0
        }
        set findCount [$rotext find count]

        # If nothing was found go to the end if appropriate.
        # Otherwise highlight the most recent match if the count changed 
        # or we're being told explicitly to do so.
        if {$findCount == 0 && ($options(-autoscroll) || $showend)} {
            $rotext see end
        } elseif {$findCount != $oldCount || $showend} {
            $rotext find update 1
        }
    }    
    
    # SetFields fields setting
    #
    # fields    A list of fields names.
    # setting   A boolean value.
    #
    # Set the listed fields' display flags to the specified setting and 
    # redisplay the log.
    method SetFields {fields setting} {
        # Loop over the fields.
        foreach field $fields {
            set i [lsearch -exact $fieldNames $field]

            if {$i == -1} {
                error "Unknown field: \"$field\""
            }

            # If there is a match, set the field's display flag.
            lset fieldDisplayFlags $i $setting
        }
        
        # Regenerate the display.
        $self redisplay
    }

    
    # Message msg
    #
    # msg   A message string
    #
    # Logs a message using the -msgcmd.
    method Message {msg} {
        if {$options(-msgcmd) ne ""} {
            set cmd $options(-msgcmd)
            lappend cmd $msg
            uplevel \#0  $cmd
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Delegated methods
    delegate method find to rotext

    # field list
    #
    # Returns a list of field names.
    method {field list} {} {
        return $fieldNames
    }
    
    # field show fields
    #
    # fields    List of field names to show.
    #
    # Set the fieldDisplayFlags of the listed fields and redisplay.
    method {field show} {fields} {
        $self SetFields $fields yes
    }
    
    # field hide fields
    #
    # fields    List of field names to hide.
    #
    # Unset the fieldDisplayFlags of the listed fields and redisplay.
    method {field hide} {fields} {
        $self SetFields $fields no
    }
    
    # field isshown field
    #
    # field     The field name to query
    #
    # Return the fieldDisplayFlag of the specified field.
    method {field isshown} {field} {
        set i [lsearch -exact $fieldNames $field]
        
        if {$i == -1} {
            error "Unknown field: \"$field\""
        }

        return [lindex $fieldDisplayFlags $i]
    }

    # format entry
    #
    # entry    A raw log entry to format
    #
    # Filter and format the log entry.  Allows an external client
    # to get a formated version of a log entry without knowing the
    # details itself.  This is especially useful for loglist(n) when doing
    # searchlogs. 
    method format {entry} {
        
        # Reset the entry variables.
        set newlineOffset 0
        set entryStr      ""

        # Don't bother with empty entries.
        if {$entry eq ""} {
            return ""
        }

        # Filter the entry if a filter exists.
        if {$options(-filtercmd) ne ""} {
            # Setup the entry filter command.
            set filterCmd $options(-filtercmd)
            lappend filterCmd $entry
            
            # Don't bother formatting if the entry is filtered out
            if {![uplevel \#0 $filterCmd]} {
                return ""
            }
        }
        
        # Loop over the fields.  Concatenate each field in the entry 
        # onto the entryStr.  If a filterable field fails its filter, 
        # skip to the next entry.
        for {set f 0} {$f < $numFields} {incr f} {
            # Skip fields whose display flag is unset.
            if {![lindex $fieldDisplayFlags $f]} {
                continue
            }
            
            # Extract the field width for convenience.
            set width [lindex $fieldWidths $f]
            
            # Extract the raw field string.
            set fieldStr [lindex $entry $f]
            
            # The last field gets handled differently to deal with 
            # newline characters.
            if {$f == [expr $numFields - 1]} {
                
                # Split the raw field string into lines.
                set lines [split [::marsutil::logger unflatten $fieldStr] "\n"]
                
                # Reset the field string.
                set fieldStr ""
                
                # Process each line.
                foreach line $lines {
                    # Trim each line to width if width != 0.
                    if {$width} {
                        set line [format "%-.${width}s" $line]
                    }
                    
                    # Append the line to the field string with the
                    # proper newline and offset spacing.
                    set line "$line\n [string repeat " " $newlineOffset]"
                    
                    set fieldStr "$fieldStr$line"
                }
                
                # Remove the last newline and offset spacing.
                set fieldStr \
                    [string range $fieldStr 0 "end-[expr $newlineOffset+2]"]
            } elseif {$width} {
                # Format the field to width.
                set fieldStr [format "%-${width}.${width}s" $fieldStr]
            }
            
            # Append the formatted fieldStr to entryStr.
            set entryStr "$entryStr $fieldStr"                
            
            # Increment the newline offset by the field width plus one
            # extra for the space between fields.
            incr newlineOffset [expr $width + 1]
        }

        return $entryStr
    }    
        
    # load  filename  ?showend?
    #
    # filename    A logfile to load
    # ?showend?   Force display of most recent content
    # 
    # Loads the specified file in the most efficient manner.  If "filename"  
    # matches the current logfile, and the current logfile is open, only the 
    # new entries are parsed and appended into the display.  Otherwise the 
    # display is cleared and the new data parsed and displayed entirely.
    # If "filename" is "", the logdisplay is cleared.
    method load {filename {showend 0}} {
        # FIRST, clear the log if there's no file name.  Then return.
        if {$filename eq ""} {
            # FIRST, Clear the GUI.
            $self ClearDisplay
            $rotext ins end "No log file specified."

            # NEXT, delete the old data.
            set logEntries {}
            set logFile    ""
            set title      ""

            # NEXT, close the reader, so that if the next log we open
            # is the same as the previous, we'll read the data.
            $reader close

            return
        }

        # NEXT, if we've already loaded this file, just get new entries.
        if {$filename eq $logFile} {
            # Just get any new entries of the current log.
            $self GetNewEntries $showend
            
            return        
        }
        
        # NEXT, we're loading a new log file
        # Save the new log file.
        set logFile $filename
    
        # Clear the old log entries.
        set logEntries {}
    
        # Set the title to display the pathname of the log file.
        set title "Log File: $logFile"
        
        # Display the new lines.
        $self ClearDisplay
        $self GetNewEntries

        # Display the end unless there's an active find.
        set findCount [$rotext find count]
        if {$findCount == 0} {
            $rotext see end
        }
    }
        
    # redisplay
    #
    # Redisplay the log.

    method redisplay {} {
        # FIRST, if there's no log being displayed don't bother
        if {$logFile eq ""} {
            return
        }

        # NEXT, clear the GUI and redisplay the log entries using the
        # new filter.
        $self ClearDisplay
        $self Append $logEntries
    }
    
}







