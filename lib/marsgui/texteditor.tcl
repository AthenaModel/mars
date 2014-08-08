#-----------------------------------------------------------------------
# TITLE:
#    texteditor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Mars marsgui(n) package: Tk text(n) widget, with additional
#    features as a text editor.
#
#    * Undo enabled by default
#    * <Tab> indents four spaces.
#
#    No doubt this list will grow over time.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export texteditor
}


#-----------------------------------------------------------------------
# The Texteditor Widget Type

snit::widgetadaptor ::marsgui::texteditor {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        installhull using text           \
            -borderwidth        0        \
            -highlightthickness 0        \
            -relief             flat     \
            -background         white    \
            -foreground         black    \
            -font               codefont \
            -width              80       \
            -height             24       \
            -wrap               none     \
            -undo               1        \
            -autoseparators     1

        # Handle the command-line arguments
        $self configurelist $args
        
        # TBD: Perhaps we should create a new set of bindings.
        bind $win <Tab>         [myproc EditorTab %W]
        bind $win <<SelectAll>> [myproc EditorSelectAll %W]
    }

    #-------------------------------------------------------------------
    # Private Methods
    
    # EditorTab
    #
    # Inserts a four-space tab into the text widget.
    
    proc EditorTab {w} {
        lassign [split [$w index insert] .] line column
        
        set num [expr {4 - $column % 4}]
        $w insert insert [string repeat " " $num]
        
        # Return break, to terminate the handling of the event.
        return -code break
    }
    
    # EditorSelectAll w
    #
    # Selects the entire contents of the widget
    
    proc EditorSelectAll {w} {
        $w tag add sel 1.0 end
    }
    
    #-------------------------------------------------------------------
    # Public Methods
    
    delegate method * to hull

}




