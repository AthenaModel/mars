
#-----------------------------------------------------------------------
# TITLE:
#   messageline.tcl
#
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Messageline widget.
# 
#   This widget provides a message line to be used at the bottom of
#   application windows.  The messageline will usually be blank.
#   On request it will display a single line of text, which will remain
#   until replaced or until a programmer-defined interval elapses.
# 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export messageline
}


#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::marsgui::messageline {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Components

    component display   ;# The text widget which actually displays the text.
    component blanker   ;# The timeout(n) that blanks the display.
    
    #-------------------------------------------------------------------
    # Options

    # Delegated options
    delegate option -font to display
    delegate option -blankinterval to blanker as -interval
    
    #-------------------------------------------------------------------
    # Instance Variables
    
    variable message ""    ;# The displayed message text

    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    constructor {args} {
        # FIRST, Create the text widget
        install display using ttk::label $win.display \
            -font         messagefont                 \
            -textvariable [myvar message]
                            
        grid $display -sticky nsew
        grid columnconfigure $win 0 -weight  1

        # NEXT, create the blanker timeout.  Name it so that it will
        # be destroyed automatically.
        install blanker using timeout ${selfns}::blanker \
            -interval 4000                               \
            -command [mymethod BlankDisplay]
    
        # NEXT, process the options
        $self configurelist $args
    }

    # Destructor - not needed yet.

    #-------------------------------------------------------------------
    # Private Methods

    # BlankDisplay
    #
    # Blanks the display

    method BlankDisplay {} {
        set message ""
    }

    #-------------------------------------------------------------------
    # Public Methods
            
    # puts msg
    #
    # msg    The message to be logged.
    #
    # Displays the message, replacing any previous message.  The message
    # will be blanked after -blankinterval msecs, unless it's already been
    # replaced.
    method puts {msg} {
        # FIRST, ignore blank messages
        if {[string is space $msg]} {
            return
        }
        
        # NEXT, display the message.
        set message [normalize $msg]

        update idletasks
        
        # NEXT, schedule the blanker, cancelling any previously
        # schedule
        $blanker cancel
        $blanker schedule
        
        return
    }
}








