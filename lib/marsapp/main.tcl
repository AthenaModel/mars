#-----------------------------------------------------------------------
# TITLE:
#   main.tcl
#
# PROJECT:
#   athena-mars - Mars Simulation Support Library
#
# DESCRIPTION:
#   marsapp(n) Package, main module.
#
#   This is the main program for the mars(1) tool.  It consists of an
#   application loader that [package requires] an "app_<name>" package
#   and then hands control over to it.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Application Metadata

set metadata {
    cmtool {
        text     "cellmodel(5) Tool"
        applib   app_cmtool
        mode     cmdline
    }

    icons {
        text     "Icon Browser"
        applib   app_icons
        mode     gui
    }

    log {
        text     "Log Browser"
        applib   app_log
        mode     gui
    }

    sql {
        text     "SQL Workbench"
        applib   app_sql
        mode     gui
    }

    uram {
        text     "URAM Workbench"
        applib   app_uram
        mode     gui
    }
}

#-----------------------------------------------------------------------
# Commands

# main argv
#
# argv       Command line arguments
#
# This is the main program; it is invoked at the bottom of the file.
# It determines the application to invoke, and does so.

proc main {argv} {
    global metadata

    #-------------------------------------------------------------------
    # Get the Metadata

    array set meta $metadata

    #-------------------------------------------------------------------
    # Application Mode.

    # FIRST, assume the mode is "cmdline": Tk is not needed, nor is the
    # Tcl event loop.

    set appname ""
    set mode cmdline

    # NEXT, Extract the appname, if any, from the command line arguments
    if {[llength $argv] >= 1} {
        set appname [lindex $argv 0]
        set argv [lrange $argv 1 end]

        # If we know it, then we know the mode; otherwise, cmdline is right.
        if {[info exists meta($appname)]} {
            set mode [dict get $meta($appname) mode]
        }
    }

    #-------------------------------------------------------------------
    # Require Packages

    # FIRST, Require Tk if this is a GUI.
    #
    # NOTE: There's a bug in the current basekit such that if sqlite3
    # is loaded before Tk things get horribly confused.  In particular,
    # when loading Tk we get an error:
    #
    #    version conflict for package "Tcl": have 8.5.3, need exactly 8.5
    #
    # This logic works around the bug. We're not currently building
    # a starpack based on this script, but it's best to be prepared.

    if {$mode eq "gui"} {
        # FIRST, get all Non-TK arguments from argv, leaving the Tk-specific
        # stuff in place for processing by Tk.
        set argv [nonTkArgs $argv]

        # NEXT, load Tk.
        package require Tk 8.5
    }

    # NEXT, if no app was requested, show usage.
    if {$appname eq ""} {
        ShowUsage
        exit
    }

    # NEXT, if the appname is unknown, show error and usage
    if {![info exists meta($appname)]} {
        puts "Error, no such application: \"mars $appname\"\n"

        ShowUsage
        exit 1
    }

    # NEXT, make sure the current state meets the requirements for
    # this application.

    # NEXT, we have the desired application.  Invoke it.
    package require {*}[dict get $meta($appname) applib]
    app init $argv
}

# from argvar option ?defvalue?
#
# Looks for the named option in the named variable.  If found,
# it and its value are removed from the list, and the value
# is returned.  Otherwise, the default value is returned.

proc from {argvar option {defvalue ""}} {
    upvar $argvar argv

    set ioption [lsearch -exact $argv $option]

    if {$ioption == -1} {
        return $defvalue
    }

    set ivalue [expr {$ioption + 1}]
    set value [lindex $argv $ivalue]
    
    set argv [lreplace $argv $ioption $ivalue] 

    return $value
}


# nonTkArgs arglist
#
# arglist        An argument list
#
# Removes non-Tk arguments from arglist, leaving only Tk options like
# -display and -geometry (with their values, of course); these are
# assigned to ::argv.  Returns the non-Tk arguments.

proc nonTkArgs {arglist} {
    set ::argv {}

    foreach opt {-colormap -display -geometry -name -sync -visual -use} {
        set val [from arglist $opt]

        if {$val ne ""} {
            lappend ::argv $opt $val
        }
    }

    return $arglist
}

# ShowUsage
#
# Displays the command-line syntax.

proc ShowUsage {} {
    global metadata

    # Get the list of apps in the order defined in the metadata
    set apps [dict keys $metadata]

    puts ""
    puts "=== Mars [kiteinfo version] ==="
    puts ""

    puts {Usage: mars <appname> ?args...?}
    puts ""

    puts ""
    puts "The following applications are available:"
    puts ""

    puts "Application       Man Page             Description"
    puts "----------------  -------------------  ------------------------------------"

    foreach app [dict keys $metadata] {
        puts [format "mars %-11s  %-19s  %s"      \
                  $app                            \
                  mars_${app}(1)                  \
                  [dict get $metadata $app text]]
    }
    puts ""
}


