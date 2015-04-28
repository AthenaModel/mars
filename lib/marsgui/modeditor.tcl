#-----------------------------------------------------------------------
# TITLE:
#    modeditor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    modeditor(n): This is an on-the-fly source coder editor, as an
#    aid to writing mods.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsgui:: {
    namespace export modeditor
}

#-----------------------------------------------------------------------
# modeditor widget

snit::widget ::marsgui::modeditor {
    hulltype ttk::frame
    
    #-------------------------------------------------------------------
    # Type Constructor
    
    typeconstructor {
        namespace import ::marsutil::*
    }
    
    #-------------------------------------------------------------------
    # Components
    
    component bar        ;# Tool Bar
    component codename   ;# The code name entry
    component grabbtn    ;# The get code button
    component clearbtn   ;# The clear button
    component savebtn    ;# The save button
    component sourcebtn  ;# The source code button
    component editor     ;# Text widget for editing the code.

    #-------------------------------------------------------------------
    # Group: Options
    
    delegate option * to hull
    
    # Option: -defaultdir
    #
    # The default directory in which to save mods.  If not set,
    # you get the current working directory.
    
    option -defaultdir \
        -default ""
    
    # Option: -formatcmd
    #
    # If set, this command is called on save, and is passed one
    # additional argument, the code to save.  The command can format
    # the code as it likes; the return value is what is actually saved.
    
    option -formatcmd \
        -default ""
    
    # Option: -logcmd
    #
    # A command that takes one additional argument, a status message
    # to be displayed to the user.
    
    option -logcmd \
        -default ""
    
    #-------------------------------------------------------------------
    # Instance Variables
    
    # Info array
    #
    #   grabbed    List of commands that have been grabbed.
    
    variable info -array {
        grabbed {}
    }
    
    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        $self configurelist $args
        
        # Tool Bar
        install bar using ttk::frame $win.bar
        
        ttk::label $bar.namelab \
            -text "Code Name:"
        
        install codename using ttk::entry $bar.codename    \
            -width 60                                      \
            -font  TkFixedFont
        
        install grabbtn using ttk::button $bar.grabbtn     \
            -style   Toolbutton                            \
            -text    "Grab"                                \
            -state   disabled                              \
            -command [mymethod GrabCode]
        
        install clearbtn using ttk::button $bar.clearbtn   \
            -style   Toolbutton                            \
            -text    "Clear"                               \
            -command [mymethod ClearCode]
        
        install savebtn using ttk::button $bar.savebtn     \
            -style   Toolbutton                            \
            -text    "Save"                                \
            -command [mymethod SaveCode]
        
        install sourcebtn using ttk::button $bar.sourcebtn \
            -text    "Source"                              \
            -style   Toolbutton                            \
            -command [mymethod SourceCode]
        
        pack $bar.namelab -side left  -padx {0 2}
        pack $codename    -side left  -padx {3 2}
        pack $grabbtn     -side left  -padx {3 2}
        pack $clearbtn    -side right -padx {3 2}
        pack $savebtn     -side right -padx {3 2}
        pack $sourcebtn   -side right -padx {3 0}
        
        ttk::separator $win.sep1 \
            -orient horizontal
        
        install editor using texteditor $win.editor     \
            -borderwidth        1                       \
            -highlightthickness 0                       \
            -relief             sunken                  \
            -yscrollcommand     [list $win.yscroll set]
        
        ttk::scrollbar $win.yscroll \
            -command [list $editor yview]
        
        grid $bar         -row 0 -column 0 -columnspan 2 -sticky ew
        grid $win.sep1    -row 1 -column 0 -columnspan 2 -sticky ew -pady 2
        grid $editor      -row 2 -column 0 -sticky nsew
        grid $win.yscroll -row 2 -column 1 -sticky ns

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 2 -weight 1
        
        # NEXT, Behavior
        
        # Get button is only enabled if there's something in the name field.
        bind $codename <KeyRelease> [mymethod SetButtonState]
        bind $codename <Return>     [mymethod GrabCode]
        
        # Active incremental searching
        isearch enable $editor
        isearch logger $editor [mymethod Log]
    }
    
    destructor {
        isearch disable $editor
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

    # GrabCode
    #
    # Gets the code, and inserts it in the editor
    
    method GrabCode {} {
        $self grab [$codename get]
    }
    
    # SourceCode
    #
    # Gets the edited code, and tries to source it.
    
    method SourceCode {} {
        # FIRST, make sure they really want to do this
        set message [normalize {
            Source the grabbed code back into the application?
        }]
        
        set answer [messagebox popup \
                        -buttons {yes "Source the code" no "Please don't"} \
                        -icon          question          \
                        -title         "Are you sure?"   \
                        -parent        $win              \
                        -default       no                \
                        -ignoretag     ${type}::source   \
                        -ignoredefault yes               \
                        -message       $message]
        
        if {$answer eq "no"} {
            return
        }
        
        # NEXT, do it.
        set text [$editor get 1.0 "end - 1 chars"]
        
        if {![catch {
            namespace eval :: $text
        } result]} {
            return
        }
        
        messagebox popup \
            -buttons {ok "OK"}       \
            -icon    warning         \
            -title   "Error in Code" \
            -parent  $win            \
            -message "Cannot source the edited code:\n\n$result"
    }
    
    # ClearCode
    #
    # Clears the grabbed code.
    
    method ClearCode {} {
        # FIRST, make sure they really want to do this
        set message [normalize {
            Clear all text from the editor?
        }]
        
        set answer [messagebox popup \
                        -buttons {yes "Clear the editor" no "Leave it alone"} \
                        -icon          question         \
                        -title         "Are you sure?"  \
                        -parent        $win             \
                        -default       no               \
                        -ignoretag     ${type}::clear   \
                        -ignoredefault yes              \
                        -message       $message]
        
        if {$answer eq "no"} {
            return
        }
        
        # NEXT, do it.
        $editor delete 1.0 end
        set info(grabbed) [list]
    }

    # SaveCode
    #
    # Saves the grabbed code.
    
    method SaveCode {} {
        set filename [tk_getSaveFile \
                          -filetypes        { {"Mod File" .tcl} } \
                          -defaultextension .tcl                  \
                          -initialdir       $options(-defaultdir) \
                          -initialfile      mod.tcl               \
                          -parent           $win                  \
                          -title            "Save Mod As"]
        
        if {$filename eq ""} {
            return
        }

        set text [$editor get 1.0 "end - 1 chars"]

        if {$options(-formatcmd) ne ""} {
            set text [{*}$options(-formatcmd) $filename $text $win]
        }
        
        set f [open $filename w]
        puts $f $text
        close $f
    }

    # SetButtonState
    #
    # Enable/Disable buttons
    
    method SetButtonState {} {
        if {[normalize [$codename get]] ne ""} {
            $grabbtn configure -state normal
        } else {
            $grabbtn configure -state disabled
        }
    }
    
    # EditorTab
    #
    # Inserts a four-space tab into the text widget.
    
    method EditorTab {} {
        lassign [split [$editor index insert] .] line column
        
        set num [expr {4 - $column % 4}]
        $editor insert insert [string repeat " " $num]
        
        # Return break, to terminate the handling of the event.
        return -code break
    }
    
    #-------------------------------------------------------------------
    # Public Methods
    
    # grab name
    #
    # name   The name of a command, as for codeget(n)
    #
    # Grabs the named code, and puts it in the editor.
    
    method grab {name} {
        # FIRST, get the name.
        set name [normalize $name]
        
        # NEXT, have they grabbed it before?  If so, confirm that they
        # really want to grab it again.
        if {$name in $info(grabbed)} {
            set message [normalize {
                You've already grabbed the selected code.  Are you
                sure you want to grab it again?
            }]
            
            set answer [messagebox popup \
                            -buttons {yes "Grab it again" no "Never mind"} \
                            -icon          question        \
                            -title         "Are you sure?" \
                            -parent        $win            \
                            -default       no              \
                            -ignoretag     ${type}::grab   \
                            -ignoredefault yes             \
                            -message       $message]
            
            if {$answer eq "no"} {
                return
            }
        }
        
        # NEXT, update the codename field to show it.
        $codename delete 0 end
        $codename insert 0 $name
        
        # NEXT, grab it.
        set deflist [cmdinfo getcode $name -related]

        if {[llength $deflist] == 0} {
            set msg [lindex [cmdinfo origin $name] 2]
            messagebox popup \
                -buttons {ok "OK"}       \
                -icon    warning         \
                -title   "No Such Code"  \
                -parent  $win            \
                -message "Cannot grab \"$name\":\n\n$msg"

            return
        }

        lappend info(grabbed) $name
        set text "#[string repeat - 65]\n# BEGIN: $name\n\n"
        foreach def $deflist {
            append text "$def\n"
        }
        append text "# END: $name\n#[string repeat - 65]\n\n"

        $editor insert 1.0 "$text"
        $editor yview moveto 1.0
        $editor see 1.0
    }
}
