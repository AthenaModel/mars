#-----------------------------------------------------------------------
# TITLE:
#    menubox.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n): menubox widget
#
#    A menubox is a ttk::combobox configured as a simple readonly
#    pulldown.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsgui:: {
    namespace export menubox
}

#-------------------------------------------------------------------
# menubox

snit::widgetadaptor ::marsgui::menubox {
    #---------------------------------------------------------------
    # Options and Methods
    
    delegate option * to hull
    delegate method * to hull
    
    # -command cmd
    #
    # Callback when item is selected interactively.
    
    option -command
    
    #---------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, create the hull
        installhull using ttk::combobox \
            -style Menubox.TCombobox \
            -state readonly
        
        # NEXT, apply the options
        $self configurelist $args
        
        # NEXT, prepare for selection
        bind $win <<ComboboxSelected>> [mymethod Selected]
    }
    
    #-------------------------------------------------------------------
    # Event handlers
    
    # Selected
    #
    # User chooses an item from the pull down.
    
    method Selected {} {
        # FIRST, the combobox likes to select the display text at
        # this time.  Make it stop.
        $win selection clear
        
        # NEXT, call the user's callback, if any.
        callwith $options(-command)
    }
}

