#-----------------------------------------------------------------------
# TITLE:
#   commandentry.tcl
# 
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Command entry widget.
# 
#   This widget implements a general purpose customization of the
#   Tk entry with a bash/tcsh-style command history accessible
#   via the up and down arrow keys.  The creator may define two 
#   callbacks: the -returncmd, which is called when the command should
#   be executed (e.g., when <Return> is pressed), and -keycmd, which
#   is called on every <KeyRelease>.
# 
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export commandentry
}


#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::commandentry {
    hulltype ttk::frame
        
    #-------------------------------------------------------------------
    # Components

    component bgframe   ;# The bgframe widget
    component entry     ;# The actual Tk entry widget.
    component clearbtn  ;# The clear button
    
    #-------------------------------------------------------------------
    # Options

    # -clearbtn
    #
    # Flag; specifies whether to create the "clear" button or not.
    option -clearbtn -default 0 -readonly 1

    # -returncmd
    #
    # Specifies a command to call when the "command" in the entry is
    # "executed", e.g., when the user presses <Return>, or when the
    # execute method is called explicitly.  The "command" in the
    # entry is appended as an argument to the -returncmd.
    option -returncmd -default ""
    
    # -keycmd
    #
    # Specifies a command to execute on all <KeyRelease> events.  The
    # character value and keysym are appended as arguments.  The 
    # test [string is print $char] indicates whether the key was a real
    # character or some kind of control key.
    option -keycmd -default ""

    # -changecmd
    #
    # Specifies a command to be called whenever the content of the
    # entry changes for any reason.  The new text is appended to the
    # command as a single argument.
    option -changecmd -default ""
    
    # -history
    #
    # Specifies the maximum number of commands to save in the history
    # stack.
    option -history -default 20
    
    # Delegate border-related options to the hull
    delegate option -borderwidth         to hull
    delegate option -relief              to hull
    
    # Delegate all remaining options to the entry, as they can be used
    # to affect the appearance.
    delegate option * to entry

    #-------------------------------------------------------------------
    # Instance Variables
    
    variable explicitChg 0  ;# 1 if "set" or "clear" called explicitly.
    variable contents    "" ;# Current contents of the commandentry
    variable oldContents "" ;# Previous contents of the command entry
    variable history     {} ;# The command history list
    variable index       -1 ;# Index of the history entry being displayed
    variable buffer      "" ;# Preserves unsaved input when <Up> is pressed
                             # and no history is showing.  Restored if
                             # <Down> is pressed at the bottom of the
                             # history stack.

    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    constructor {args} {
        # FIRST, configure the hull
        $hull configure         \
            -borderwidth 1      \
            -relief      sunken
        
        # NEXT, add a background frame to hold the other components
        install bgframe using frame $win.bgframe \
            -background white
        pack $bgframe -fill both -expand yes
        
        # FIRST, Install the entry component.
        install entry as entry $bgframe.entry \
            -textvariable       [myvar contents] \
            -relief             flat             \
            -borderwidth        0                \
            -highlightthickness 0                \
            -background         white
        
        # NEXT, Save the constructor options.
        $self configurelist $args
        
        # NEXT, create the clear button
        if {$options(-clearbtn)} {
            install clearbtn using ttk::button $bgframe.clear \
                -image        {
                    ::marsgui::icon::clear
                    disabled ::marsgui::icon::cleard }        \
                -command      [mymethod ClearEntry]           \
                -style        Entrybutton.Toolbutton          \
                -state        disabled

            pack $bgframe.clear -side right -padx 2
        }

        pack $bgframe.entry -fill x -expand yes
        
        # NEXT, assign the key bindings.
        bind $entry <KeyRelease-Return> [mymethod execute]
        bind $entry <KeyRelease>        [mymethod KeyRelease %A %K]
        bind $entry <Up>                [mymethod Up]   
        bind $entry <Down>              [mymethod Down]
        bind $entry <Escape>            [mymethod ClearEntry]
        bind $entry <Control-u>         [mymethod ClearEntry]

        # NEXT, support the <<SelectAll>> protocol
        bind $entry <<SelectAll>>       [mymethod SelectAll]
    }

    # Destructor - Not needed
    
    #-------------------------------------------------------------------
    # Private Methods

    # DetectChange
    #
    # Calls -changecmd if the contents have actually changed.

    method DetectChange {} {
        # FIRST, if there's no change do nothing.
        if {$contents eq $oldContents} {
            return
        }

        # NEXT, save the new contents
        set oldContents $contents
        
        # NEXT, call the -changecmd, unless this was an explicit change.
        if {!$explicitChg && $options(-changecmd) ne ""} {
            set cmd $options(-changecmd)
            lappend cmd $contents
            uplevel \#0 $cmd
        }

        # NEXT, enable/disable the clear button
        if {$options(-clearbtn)} {
            if {$contents eq ""} {
                $clearbtn configure -state disabled
            } else {
                $clearbtn configure -state normal
            }
        }

        return
    }

    # ClearEntry
    #
    # Clear the displayed contents of the commandentry.
    method ClearEntry {} {
        # FIRST, update the state variables
        set contents ""
        set index    -1
        set buffer   ""

        $self DetectChange

        return
    }
    

    # Save
    #
    # Save the dislayed contents of the commandentry in its history.
    method Save {} {
        # FIRST, get the contents.  If it's empty or whitespace, or if
        # it matches the command most recently added to the history,
        # there's no need to save it.
        if {[string is space $contents] ||
            $contents eq [lindex $history 0]} {
            return
        }
        
        # NEXT, Push the new command onto the stack.
        set history [linsert $history 0 $contents]
        
        # NEXT, Trim history if needed.
        if {[llength $history] > $options(-history)} {
            set history [lrange $history 0 end-1]
        }
        
        # NEXT, update the state: we're ready for a new input.
        set buffer ""
        set index  -1
    }
    
    # Up
    #
    # Show the previous entry in the history.  Beep if there isn't one.
    method Up {} {
        # FIRST, If we're already at the earliest entry in the history
        # just beep at them.
        if {$index >= [expr {[llength $history] - 1}]} {
            bell
            return
        }
        
        # NEXT, If we're not in the history yet, save the user's 
        # current input so that we can restore it later.
        if {$index == -1} {
            set buffer $contents
        }
        
        # NEXT, Display the previous entry in the history stack.
        set contents [lindex $history [incr index]]

        $self DetectChange
    }
    
    # Down
    #
    # Show the next entry in the history.  Beep if there isn't one.
    method Down {} {
        # FIRST, If we're not in the history stack just beep at them.
        if {$index < 0} {
            bell
            return
        }
        
        # NEXT, Decrement the index and show the next history command,
        # or the buffer if we're at the bottom.
        if {[incr index -1] == -1} {
            set contents $buffer
        } else {
            set contents [lindex $history $index]
        }

        $self DetectChange
    }
    
    # KeyRelease char code
    #
    # char      the displayed character
    # keysym    the key symbol
    #
    # Execute the -keycmd passing it the value and keysym of the 
    # released key.
    #
    # TBD: Should this really be a -changecmd?
    method KeyRelease {char keysym} {
        # FIRST, Execute the -keycmd, if any
        if {$options(-keycmd) ne ""} {
            # Append the char and keysym to the -keycmd and execute it.
            set cmd $options(-keycmd)
            lappend cmd $char $keysym
            uplevel \#0 $cmd
        }

        # NEXT, execute the -changecmd, if any.
        $self DetectChange
        
        return
    }

    # SelectAll
    #
    # Selects the entire contents of the entry.
    method SelectAll {} {
        $entry selection range 0 end
        update idletasks

        return
    }
    
    #-------------------------------------------------------------------
    # Public Methods
    
    # frame
    #
    # Returns the frame containing the Tk entry and clear button;
    # Other controls can then be inserted into it.
    
    method frame {} {
        return $bgframe
    }
    
    # set text
    #
    # text      text to display in the commandentry
    #
    # Set the displayed contents of the commandentry.
    method set {text} {
        # FIRST, Update the state variables
        set contents $text
        set index    -1
        set buffer   ""

        # NEXT, put the cursor at the end.
        $entry icursor end

        # NEXT, call the -changecmd
        set explicitChg 1
        $self DetectChange
        set explicitChg 0

        return
    }
    
    # clear
    #
    # Clear the displayed contents of the commandentry.
    method clear {} {
        set explicitChg 1
        $self ClearEntry
        set explicitChg 0

        return
    }
    
    # get
    #
    # Return the displayed contents of the commandentry.
    method get {} {
        return $contents
    }
    
    # execute
    #
    # Execute the -returncmd with the displayed contents.
    method execute {} {
        # FIRST, detect any change (i.e., from a mouse-paste)
        $self DetectChange
        
        # NEXT, Save the displayed contents to the history.
        $self Save 
        
        # NEXT, is there a -returncmd?
        if {$options(-returncmd) ne ""} {
            # Append the contents to the -returncmd and execute.
            set cmd $options(-returncmd)
            lappend cmd $contents
            uplevel \#0 $cmd
        }

        return
    }
}




