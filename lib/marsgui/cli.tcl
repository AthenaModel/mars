#-----------------------------------------------------------------------
# TITLE:
#    cli.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Command-Line Interface (CLI) widget.
#
#    This widget provides a "terminal" window for entering
#    typed commands and displaying the result.
#
#    The caller may specify an arbitrary command for evaluating 
#    commands entered by the user; by default, the commands are
#    simply evaluated as Tcl commands at global scope.
#
#    At present, the CLI presumes that all typed commands have
#    Tcl syntax, and won't try to execute them until the entire command
#    is complete. 
#
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export cli
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::cli {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Add defaults to the option database
        option add *Cli.borderWidth        1
        option add *Cli.relief             flat
        option add *Cli.background         black
        option add *Cli.Foreground         "#5FDB00"
        option add *Cli.font               codefont
        option add *Cli.width              80
        option add *Cli.height             24
        option add *Cli.errorForeground    red
        option add *Cli.errorBackground    black
        option add *Cli.hullbackground     $::marsgui::defaultBackground
    }

    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option -borderwidth    to hull
    delegate option -relief         to hull
    delegate option -hullbackground to hull as -background

    # Options delegated to the text widget
    delegate option -font               to log
    delegate option -height             to log
    delegate option -width              to log
    delegate option -foreground         to log
    delegate option -background         to log
    delegate option {-insertbackground insertBackground Foreground} to log

    # -errorforeground color
    # -errorbackground color
    #
    # Colors used to display error text.
    option {-errorforeground errorForeground ErrorForeground}
    option {-errorbackground errorBackground ErrorBackground}

    # -promptcmd cmd
    #
    # cmd          A command that returns the prompt string
    #
    # Use this to modify the user's prompt.  The command should take
    # no arguments.  If undefined, the prompt defaults to ">".
    option -promptcmd

    # -completecmd cmd
    #
    # cmd          A command that determines whether the input is
    #              complete or not.
    #
    # The command should take one argument, the current input, and
    # return 1 if it is complete and 0 otherwise.  By default, Tcl
    # syntax is assumed.
    option -completecmd [list info complete]


    

    # -evalcmd cmd
    #
    # cmd     A command which takes one argument.
    #
    # Specifies a command which will be used to evaluate commands entered
    # in the CLI.  The command should take one argument, the command to
    # evaluate, and should return the evaluated value or throw an error.
    # Either response will be logged.
    #
    # The default behavior is to evaluate the command in the global
    # context.
    
    option -evalcmd -default {uplevel \#0}

    # -maxlines num
    #
    # num   Some positive number of lines.
    #
    # After every command, the oldest lines in the scrollback buffer 
    # will be deleted to bring the total number of lines down to num.
    
    option -maxlines -default 500

    # -commandlist names
    #
    # names    List of command names
    #
    # List of command names for tab completion.  By default, the
    # list is empty, and tab-completion isn't done.

    option -commandlist -default {}

    # -maxhistory num
    #
    # The maximum number of commands to keep in the history list.
    
    option -maxhistory -default 100

    #-------------------------------------------------------------------
    # Components

    component log               ;# The scrolling text widget

    #-------------------------------------------------------------------
    # Instance Variables

    variable history {}         ;# List of entered commands.
    variable hp      -1         ;# History pointer

    variable savedtags {}       ;# Saved bind tags.

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Create the text widget and scroll bar
        install log using text $win.log \
            -wrap               char    \
            -highlightthickness 0       \
            -borderwidth        1       \
            -relief             sunken  \
            -yscrollcommand     [list $win.yscroll set]

        ttk::scrollbar $win.yscroll \
            -orient  vertical \
            -command [list $log yview]

        # NEXT, get the options
        $self configurelist $args

        # NEXT, define styles
        $self DefineStyles

        # NEXT, pack everything.
        pack $win.yscroll -side right -fill y
        pack $log -side right -fill both -expand 1

        # NEXT, set keyboard bindings.
        bind $log <KeyPress>            [mymethod KeyPress %A %K]
        bind $log <Control-KeyPress>    [mymethod ControlKey]
        bind $log <BackSpace>           [mymethod BackSpace]
        bind $log <Return>              [mymethod Return]
        bind $log <Tab>                 [mymethod Tab]
        bind $log <Up>                  [mymethod Up]
        bind $log <Down>                [mymethod Down]
        bind $log <Escape>              [mymethod Escape]
        bind $log <Control-u>           [mymethod Escape]
        bind $log <Control-a>           [mymethod Control-a]
        bind $log <Home>                [mymethod Control-a]
        bind $log <<Cut>>               [mymethod Cut]
        bind $log <Delete>              [mymethod Delete]
        bind $log <<Paste>>             [mymethod Paste]
        bind $log <<PasteSelection>>    [mymethod ButtonRelease2 @%x,%y]
        bind $log <ButtonRelease-2>     [mymethod ButtonRelease2 @%x,%y] 
        bind $log <<SelectAll>>         [mymethod selectAll]
       
        # NEXT, Hack the FocusIn and ButtonRelease-1 events to put the
        # insertion cursor at the end of the last line when the $log
        # receives focus.
        bind focusHack <FocusIn>        [mymethod FocusHackCB]
        bind focusHack <ButtonPress-1>  [mymethod FocusHackCB]
       
        # Insert the focusHack bindtag after the Text bindtag.
        bindtags $log [linsert [bindtags $log] "end-2" focusHack]

        # Finally, write the first prompt
        $self Prompt
    }
    
    #-------------------------------------------------------------------
    # Destructor

    destructor {
    
        # Destroy the focusHack bindings.  This prevents an error when
        # <destroy> button of the parent window is clicked.
        bind focusHack <FocusIn>        ""
        bind focusHack <ButtonPress-1>  ""
    }

    #-------------------------------------------------------------------
    # Private Methods

    # DefineStyles
    #
    # Defines the styles used by the widget.
    #
    # TBD: This should be executed whenever the error colors
    # change.
    method DefineStyles {} {
        $log tag configure error \
            -foreground $options(-errorforeground) \
            -background $options(-errorbackground)

        # Raise the selection tag above the others, so it dominates.
        $log tag raise sel
    }

    # ControlKey
    #
    # This is bound to all control keys for $log; it does nothing.
    # It ensures that control keys not bound by $log get passed along
    # to the later bindtags.
    method ControlKey {} {
        return
    }

    # KeyPress key keynum
    #
    # key    The Unicode character
    # keynum The keysym as a decimal number.
    #
    # Moves the insert point to the end of the input if it's in the
    # historical region and a printable character is typed.  This causes
    # the character to go at the end of the input.
    method KeyPress {key keynum} {
        # Done if the key is not printable, e.g., left shift.
        if {$key eq ""} {
            return
        }
        
        if {[lsearch -exact [$log mark names] prompt] == -1 ||
            [$log compare insert < "prompt + 1 char"]} {
            # FIRST, clear the selection, if any; otherwise, "insert"
            # won't be associated with "sel".
            $log tag remove sel 1.0 end

            # NEXT, put us at the end of the input.
            $log mark set insert "end - 1 char"
        }
    }

    # BackSpace
    #
    # Called whenever BackSpace is pressed; ignores the BackSpace
    # if the user isn't in the editable part of the window.
    method BackSpace {} {
    
        if {[$self BeforePrompt]} {
        
            return -code break
        }
    }

    # Return
    #
    # This is called whenever the Return key is pressed.  It moves
    # the insertion point to the end of the input, collects everything
    # the prompt and the insertion point, and evaluates it as a command.
    # The result (whether normal or error) is written back to the
    # CLI.
    method Return {} {
        # FIRST, if we're in the non-editable region jump to
        # the end.
        if {[$self BeforePrompt]} {
            $log mark set insert "end - 1 char"
        }
        
        # NEXT, get the current input and append it to the
        # current partial command.
        set input [string trim [$log get prompt end]]

        # NEXT, add an explicit carriage return.  Do an update idletasks
        # so that it's visible.
        $self append "\n"

        update idletasks

        # NEXT, if the partialCommand is a complete command,
        # evaluate it; otherwise, wait for the next line.
        # The "\n" allows "\" to be used as a continuation character.

        if {[$self Complete "$input\n"]} {
            $self Eval $input
        }

        # NEXT, delete excess lines from the scrollback buffer
        $self DeleteExcessLines

        # NEXT, Break so that the carriage return doesn't get inserted.
        return -code break
    }

    # Complete input
    #
    # input        An input string.
    #
    # Returns true if the input is complete, and false otherwise.

    method Complete {input} {
        if {[llength $options(-completecmd)] == 0} {
            return 1
        }

        set cmd $options(-completecmd)
        lappend cmd $input
        return [uplevel \#0 $cmd]
    }


    # Tab
    #
    # Called when the user presses Tab.  Attempts to do 
    # tab completion on the text typed by the user.

    method Tab {} {
        # FIRST, do nothing if we aren't in the editable region.
        if {[$self BeforePrompt]} {
            return -code break
        }

        # NEXT, get the text between the prompt and the insertion
        # cursor.
        set input [$log get "prompt + 1 char" insert]

        # NEXT, get all matches from the command list.
        set pat "$input*"
        set matches [lsearch -all -inline -glob $options(-commandlist) $pat]
        
        # NEXT, compare the input to the command list.
        # 
        # * If it matches none of the entries, beep and do 
        #   nothing
        #
        # * If it matches several, insert any additional
        #   characters that are the same and beep;
        # 
        # * If it matches exactly one, insert any additional
        #   characters followed by a space.
        
        set len [string length $input]

        if {[llength $matches] == 0} {
            bell
        } elseif {[llength $matches] == 1} {
            set match [lindex $matches 0]
            set extra [string range $match $len end]
            $log insert insert "$extra "
        } else {
            bell
            set match [LongestCommonPrefix $matches]
            set extra [string range $match $len end]
            $log insert insert $extra
        }

        return -code break
    }

    # Up
    #
    # Called when the user presses the Up arrow.  Substitutes the
    # previous item in the history list (if any) for the current text.
    #
    # If the user is not in the command line, handle this normally.
    # When this is executed, the insert hasn't been moved yet.
    
    method Up {} {
    
        # FIRST, check the insert position.
        if {[$log compare "insert linestart" != "prompt linestart"] ||
            [$log compare "insert" < "prompt + 1 char"]             } {
    
            # Not in the edit area of the prompt line, move the insert up.
            $log mark set insert "insert - 1 line"

            if {[$log compare "insert" <  "prompt + 1 char"]  &&
                [$log compare "insert" >= "prompt linestart"] } {
            
                # In the prompt; move insert to end of prompt.
                $log mark set insert "prompt + 1 char"  
            }
            
            # Done.
            return -code break
        }

        # NEXT, see if there's a previous command. If not, there's nothing
        # to do.
        if {[llength $history] == 0 || [incr hp] == [llength $history]} {
            bell
            incr hp -1
            return -code break
        }

        set command [lindex $history $hp]

        # NEXT, delete the old command text and insert the new.
        $log delete "prompt + 1 char" end
        $log insert end $command
        $log mark set insert "end - 1 char"
        
        # Make sure the insertion cursor is visible.
        $log see insert

        return -code break
    }

    # Down
    #
    # Called when the user presses the Down arrow.  Substitutes the
    # next item in the history list (if any) for the current text.
    #
    # If the user is not in the command line, handle this normally.
    # When this is executed, the insert hasn't been moved yet.
    
    method Down {} {
    
        # FIRST, check the insert position.
        if {[$log compare "insert linestart" != "end -1 line linestart"]} {
        
            # Not in the last line, move the cursor down one line.
            $log mark set insert "insert + 1 line"
            
            if {[$log compare "insert" <  "prompt + 1 char"]  &&
                [$log compare "insert" >= "prompt linestart"] } {
            
                # In the prompt; move insert to end of prompt.
                $log mark set insert "prompt + 1 char"  
            }
        
            # Done.
            return -code break
        }
        
        # In the last line of the command edit area.  Access the command 
        # history.
        
        # NEXT, see if we've any place to go.
        if {$hp == -1} {
            bell
            return -code break
        }

        # NEXT, get the next command.
        incr hp -1

        if {$hp == -1} {
            set command ""
        } else {
            set command [lindex $history $hp]
        }

        # NEXT, delete the old command text and insert the new.
        $log delete "prompt + 1 char" end
        $log insert end $command
        $log mark set insert "end - 1 char"

        # Make sure the insertion cursor is visible.
        $log see insert

        return -code break
    }

    # Escape
    #
    # Clears the input.

    method Escape {} {
        $log delete "prompt + 1 char" end
        $log mark set insert "end - 1 char"
        $log see insert
        
        return -code break
    }

    # Control-a
    #
    # This is called when the user presses Control-a or Home.  If we're
    # on the prompt line, then it goes to prompt + 1 char, rather
    # than linestart.

    method Control-a {} {
        if {[$log compare "insert linestart" == "prompt linestart"]} {
            $log mark set insert "prompt + 1 char"
            return -code break
        }
    }
    
    # FocusHackCB
    #
    # This is called when the cli receives focus, either by keyboard input
    # or mouse input.  Sets the insertion point at the end of $log.
    method FocusHackCB {} {
        
        if {[$self BeforePrompt]} {$log mark set insert "end - 1 char"}
    }

    # BeforePrompt ?index?
    #
    # index     X-Y index.
    #
    # Determines whether the insertion point or index is before or after
    # the prompt.
    method BeforePrompt {{index ""}} {
    
        if {[lsearch -exact [$log mark names] prompt] == -1} {
        
            return 1
            
        } else {
        
            return [$log compare insert <= "prompt + 1 char"]
        }
    }

    # Output the prompt.
    method Prompt {} {
        if {$options(-promptcmd) ne ""} {
            set promptString [uplevel \#0 $options(-promptcmd)]
        } else {
            set promptString ">"
        }

        $self append $promptString
        $log mark set prompt "end - 1 char"
        $log mark gravity prompt left
        $self append " "
    }

    # Cut
    #
    # Handle <<Cut>> virtual events.  If any of the uneditable text is
    # involved, don't cut.
    
    method Cut {} {
    
        set selstart [lindex [$log tag ranges sel] 0]

        # Only perform the cut when a selection is active
        if {$selstart ne "" &&
            [$log compare $selstart >= "prompt + 1 char"]
        } {
            tk_textCut $log
        }

        return -code break
    }
    
    # Delete
    #
    # Handle <Delete> events.  Aborts any cut if the selection includes
    # non-editable text.
    
    method Delete {} {
    
        # Get the selection range.
        set selstart [lindex [$log tag ranges sel] 0]
        set selend   [lindex [$log tag ranges sel] 1]
        
        if {$selstart eq ""} {
        
            # No selection.  Check the insertion point.        
            if {[$log compare insert > prompt]         && 
                [$log compare insert < "end - 1 char"] } {
            
                # Insert is in editable area; delete 1 char.
                $log delete insert
            
            } else {
            
                # Insert is in non-editable area, or at end.
                bell
            }
        
        } elseif {[$log compare $selstart > prompt]} {
        
            # Selection OK, make the cut.
            $log delete $selstart $selend
        
        } else {
        
            # Selection includes prompt or pre-prompt text.
            bell
        }
    
        return -code break
    }

    # Paste
    #
    # Handles <<Paste>> virtual events.  The text 
    # should be appended, and the cursor put at the bottom of the text.
    
    method Paste {} {
        if {[$log compare insert <= prompt]} {
            # Remove the selection, if any
            $log tag remove sel 1.0 end

            # Move the insert cursor to the end.
            $log mark set insert "end - 1 char"
        }

        if {[llength [$log tag ranges sel]] != 0} {
            if {[$log compare sel.first < prompt]} {
                eval $log tag remove sel 1.0 end
                $log mark set insert "end - 1 char"
            } else {
                $log delete sel.first sel.last
            }
        }

        tk_textPaste $log
        
        return -code break
    }
    
    # ButtonRelease2 index
    #
    # index     X-Y coordinates of event.
    #
    # Handles <ButtonRelease-2> events, returning if the release was 
    # before the prompt in the uneditable region.
    
    method ButtonRelease2 {index} {
    
        if {[$log compare [$log index $index] < "prompt + 1 char"]} { 
        
            return -code break
        }   
    }

    # selectAll
    #
    # Selects all text in the widget

    method selectAll {} {
        $log tag add sel 1.0 end
        update idletasks
    }

    # Eval cmd
    #
    # Evaluates a command using -evalcmd.  The result or error
    # is logged.
    method Eval {cmd} {
        # FIRST, unset the prompt mark.  (Is this still necessary?)
        $log mark unset prompt

        set fullcmd $options(-evalcmd)
        lappend fullcmd $cmd

        # NEXT, evaluate the command and display the result.
        #
        # If the cli is connected to a remote interpreter, we enter
        # the event loop while waiting for the response...which means
        # that the GUI is live while we're waiting.  Consequently,
        # clear the $log widget's bindtags temporarily, so that they
        # can't interact with the widget before the response is
        # received.  (Don't forget to restore them afterwards!)
        #
        # TBD: This approach is a little too broad.  What we're really
        # trying to do is prevent the user from inserting or deleting
        # while we're waiting.  Other bindings (e.g., copy) should work
        # fine.  This also relates to some of the paste issues we have...
        # things would be simpler if we adapted the text widget and
        # handled "insert" and "delete" specially.

        set savedTags [bindtags $log]
        bindtags $log {. all}  ;# Retain normal app behavior....

        if {[catch {uplevel \#0 $fullcmd} result]} {
            $self append "$result\n" error
        } elseif {$result ne ""} {
            $self append "$result\n"
        }

        bindtags $log $savedTags

        # NEXT, update the history list (unless this is a duplicate)
        if {$cmd ne [lindex $history 0]} {
            set history [linsert $history 0 $cmd]
            set history [lrange $history 0 $options(-maxhistory)]
        }

        # NEXT, we're back at the bottom of the history list.
        set hp -1

        # NEXT, output the new prompt.
        $self Prompt
    }

    # DeleteExcessLines
    #
    # If there are more than -maxlines lines in the widget, delete
    # the oldest lines.
    
    method DeleteExcessLines {} {
        set lines [lindex [split [$log index end] "."] 0]

        set excessLines [expr {$lines - $options(-maxlines)}]

        if {$excessLines > 0} {
            $log delete 1.0 ${excessLines}.0
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method get to log

    # append text ?style?
    #
    # text     Text to write to the CLI
    # style    Option style: bold, error
    #
    # Appends text to the CLI, optionally with a particular style

    method append {text {style ""}} {
        $log insert end "$text" $style
        $log see "end - 1 char"
        $log mark set insert "end - 1 char"
    }

    # clear
    #
    # Clears the text from the CLI, but remembers what was last typed but
    # not sent via a <Return> event.
    
    method clear {} {
        # FIRST, remember keystrokes made but not entered.
        if {[lsearch -exact [$log mark names] prompt] != -1} {
            set last [string trim [$log get prompt end]]
        } else {
            set last ""
        }

        # NEXT, clear the CLI
        $log delete 1.0 end
        
        # NEXT, show prompt and previously made keystrokes
        $self Prompt

        if {$last ne ""} {
            $self append $last
        }
    }

    # inject command
    #
    # command    A command to be processed
    #
    # Puts the command into the CLI as though it had been typed, and
    # then executes it as though Enter was pressed.

    method inject {command} {
        # FIRST, delete the old command text and insert the new.
        $log delete "prompt + 1 char" end
        $log insert end $command
        $log mark set insert "end - 1 char"

        # NEXT, generate the Return keypress
        set oldFocus [focus]
        focus $log
        event generate $log <KeyPress-Return>
        focus $oldFocus
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # saveable checkpoint ?-saved?
    #
    # Returns the CLI's history stack.  -saved is ignored.

    method {saveable checkpoint} {{option ""}} {
        return $history
    }

    # saveable restore checkpoint ?-saved?
    #
    # checkpoint    The return value of "saveable checkpoint"
    #
    # Restores the history data.  -saved is ignored.

    method {saveable restore} {checkpoint {option ""}} {
        $self clear
        set history $checkpoint
        set hp -1
    }

    # saveable changed
    #
    # Always returns 0: saving the history is a convenience, not a
    # necessity, so there are never unsaved changes.

    method {saveable changed} {} {
        return 0
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # LongestCommonPrefix strings
    #
    # strings    A list of strings
    #
    # Returns the longest common prefix of all of the strings.
    proc LongestCommonPrefix {strings} {
        set res {}
        set i 0
        foreach char [split [lindex $strings 0] ""] {
            foreach string [lrange $strings 1 end] {
                if {[string index $string $i] != $char} {
                    return $res
                }
            }
            append res $char
            incr i
        }
        return $res
    } 


}






