#-----------------------------------------------------------------------
# TITLE:
#    mkicon.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Module for creating icon images and files from text input.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export mkicon mkiconfile
}

#-----------------------------------------------------------------------
# Public Commands


# mkicon cmd charmap colors ?suffix colors...?
#
# cmd       Name of icon command to create.  If "", a name is 
#           generated automatically.
# charmap   A list of strings, one string for each row of the GIF image.
#           Each string contains one character for each pixel in the
#           row.
# colors    A dictionary of characters and hex colors, e.g., #ffffff is
#           white.  The special color "trans" indicates that the pixel
#           should be transparent.  Each character in the charmap needs
#           to be represented in the dictionary.
# suffix     A suffix to be added to name
# mod        A partial dictionary of colors to use for suffix.
#
# Creates and returns a family of Tk photo images based on the
# charmap and colors.

proc ::marsgui::mkicon {cmd charmap colors args} {
    # FIRST, make sure the name is fully qualified.
    if {$cmd ne "" && ![string match "::*" $cmd]} {
        set ns [uplevel 1 {namespace current}]

        if {$ns eq "::"} {
            set cmd "::$cmd"
        } else {
            set cmd "${ns}$cmd"
        }
    }

    set result [list]
    
    lappend result [mkicon_MakeIcon $cmd $charmap $colors] 
    
    foreach {suffix mod} $args {
        lappend result \
            [mkicon_MakeIcon ${cmd}$suffix $charmap [dict merge $colors $mod]]
    }

    return $result
}

proc ::marsgui::mkicon_MakeIcon {cmd charmap colors} {
    # FIRST, get the number of rows and columns
    set rows [llength $charmap]
    set cols [string length [lindex $charmap 1]]
    
    # NEXT, create an image of that size
    if {$cmd ne ""} {
        set icon [image create photo $cmd -width $cols -height $rows]
    } else {
        set icon [image create photo -width $cols -height $rows]
    }

    # NEXT, build up the pixels
    set r -1
    foreach row $charmap {
        incr r

        set c -1
        foreach char [split $row ""] {
            incr c

            set color [dict get $colors $char]
            if {$color eq "trans"} {
                $icon transparency set $c $r 1
            } else {
                $icon put $color -to $c $r
            }
        }
    }

    return $icon
}

# mkiconfile name fmt charmap colors ?suffix mod...?
#
# name      The file name
# fmt       gif|png
# charmap   A list of strings, one string for each row of the GIF image.
#           Each string contains one character for each pixel in the
#           row.
# colors    A dictionary of characters and hex colors, e.g., #ffffff is
#           white.  The special color "trans" indicates that the pixel
#           should be transparent.  Each character in the charmap needs
#           to be represented in the dictionary.
# suffix     A suffix to be added to name
# mod        A partial dictionary of colors to use for suffix.
#
# Creates one or more image files of the specified format.  By default,
# the files will be created in the current working directory.  Returns a
# list of the absolute paths to the icon files.

proc ::marsgui::mkiconfile {name fmt charmap colors args} {
    set result [list]
    set args [linsert $args 0 {} {}]
    
    foreach {suffix mod} $args {
        # FIRST, make the icon
        set icon [mkicon_MakeIcon "" $charmap [dict merge $colors $mod]]

        # NEXT, save the image to disk, and delete the image object.
        set fname [file rootname $name]$suffix[file extension $name]
        $icon write $fname -format $fmt
        image delete $icon
        lappend result [file normalize $name]
    }
    
    return $result
}
