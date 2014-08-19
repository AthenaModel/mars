#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mars_icons(1) Application
#
#    This module defines app, the application ensemble.
#
#        package require app_icons
#        app init $argv
#
#    This program is a tool for displaying the icons in a namespace.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# app ensemble

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Components
    
    # TBD

    #-------------------------------------------------------------------
    # Application Initializer

    # init argv
    #
    # argv         Command line arguments
    #
    # This the main program.

    typemethod init {argv} {
        # FIRST get the argument, if any.
        if {[llength $argv] == 0} {
            set ns ::marsgui::icon
        } elseif {[llength $argv] == 1} {
            set ns [lindex $argv 0]
        } else {
            puts "Usage: mars icons ?namespace?"
            exit 1
        }
        
        # NEXT, get a list of the icons
        set icons [list]
        
        foreach name [lsort [info commands ${ns}::*]] {
            # Skip non images
            if {[catch {image type $name}]} {
                continue
            }
            
            # Skip images that are too big
            if {[image width $name] > 50 ||
                [image height $name] > 50
            } {
                puts "Skipped $name: too big, [image width $name]x[image height $name]"
                continue     
            }
            
            lappend icons $name
        }
        
        # NEXT, did we find any?
        set len [llength $icons]
        
        if {$len == 0} {
            puts "No icons found in $ns."
            exit 0
        }
        
        # NEXT, set the window title
        wm title . "Mars Icon Browser: ${ns}::*"

        # NEXT, create a title label
        ttk::label .title  \
            -anchor center \
            -text "Icons in ${ns}::*"

        # NEXT, create the treectrl
        treectrl .itree \
            -width          400                           \
            -height         400                           \
            -borderwidth    0                             \
            -relief         flat                          \
            -background     $::marsgui::defaultBackground \
            -usetheme       1                             \
            -showheader     0                             \
            -showroot       0                             \
            -showrootlines  0                             \
            -itemwidthequal yes                           \
            -wrap           window                        \
            -orient         vertical                      \
            -xscrollcommand [list .xscroll set]

        ttk::scrollbar .xscroll \
            -orient  horizontal            \
            -command [list .itree xview]
            
        # NEXT, create the elements and styles.

        # Elements
        .itree element create itemText text  \
            -font    codefont                \
            -fill    black

        .itree element create itemIcon image

        # itemStyle: icon and text

        .itree style create itemStyle
        .itree style elements itemStyle {itemIcon itemText}
        .itree style layout itemStyle itemIcon
        .itree style layout itemStyle itemText \
            -iexpand nse                       \
            -ipadx   4                         \
            -ipady   4

        # Column 0
        .itree column create \
            -itemstyle itemStyle

        # NEXT, lay out the widgets
        grid .title -row 0 -column 0 -pady 8 -padx 5 -sticky ew
        grid .itree -row 1 -column 0 -sticky nsew -padx 5
        grid .xscroll -row 2 -column 0 -sticky ew -padx 5

        grid rowconfigure    . 1 -weight 1
        grid columnconfigure . 0 -weight 1

        # NEXT, populate the tree
        foreach name $icons {
            set id [.itree item create \
                        -parent root]

            .itree item text $id 0 [namespace tail $name]
            .itree item element configure $id 0 itemIcon \
                -image $name
        }
        
    }
}



