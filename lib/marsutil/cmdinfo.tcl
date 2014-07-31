#-----------------------------------------------------------------------
# TITLE:
#    cmdinfo.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) Tcl Command Introspector
#
#    cmdinfo(n) is an ensemble command whose subcommands are used for
#    introspection of Tcl commands and namespaces.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export cmdinfo
}

#-----------------------------------------------------------------------
# cmdinfo

snit::type ::marsutil::cmdinfo {
    # Make it an ensemble
    pragma -hasinstances no -hastypeinfo no -hastypedestroy no

    #-------------------------------------------------------------------
    # Public Methods

    # exists name
    #
    # name     A command name
    #
    # Returns 1 if there is a command by that name, and 0 otherwise.

    typemethod exists {name} {
        set result [uplevel 1 [list info commands $name]]
        expr {[llength $result] == 1}
    }

    # type name
    #
    # name     A command name
    #
    # Returns the command type, one of the following:
    #
    #   proc   A normal proc
    #   wproc  A normal proc (Tk widget)
    #   nse    A namespace ensemble
    #   wnse   A namespace ensemble (Tk widget)
    #   alias  A command alias in this interpreter
    #   walias A command alias in this interpreter (Tk widget)
    #   bin    A binary command
    #   wbin   A binary command (Tk widget)
    #   bwid   A BWidget special widget
    #   ns     A namespace.
    #
    # Note that "ns" is never actually returned by this command;
    # however, it's used by other commands.
    #
    # In order to determine the available subcommands, options, and so
    # forth for various widget types, the BWidget package creates
    # a number of undisplayed widgets of various types with odd names
    # containing "#" characters.  This command refers to these as 
    # "BWidget special widgets", or bwid's.

    typemethod type {name} {
        # FIRST, get and use the absolute name
        set name [uplevel 1 [list namespace origin $name]]

        # NEXT, is it a window name?
        set wpre ""

        if {[string match "::.*" $name] &&
            [cmdinfo exists ::winfo]
        } {
            # FIRST, is it a window name?
            set wname [string range $name 2 end]
            if {[winfo exists $wname]} {
                set wpre "w"

                # If the name includes "#", it's a Bwidget special widget
                if {[string first "\#" $wname] > -1} {
                    return "bwid"
                }
            }
        }

        # NEXT, is it a proc?
        if {[llength [info procs $name]] == 1} {
            return "${wpre}proc"
        }
        
        # NEXT, is it a namespace ensemble?
        if {[namespace ensemble exists $name]} {
            return "${wpre}nse"
        }

        # NEXT, is it an alias?
        set target [interp alias {} $name]

        if {[llength $target] > 0} {
            return "${wpre}alias"
        }

        # NEXT, we don't know what it is, but it isn't a proc
        return "${wpre}bin"
    }

    # list ns
    #
    # ns    A fully-qualified namespace
    #
    # Returns a list of the commands in a namespace, including child
    # namespaces.  The list has the form "name cmdtype name cmdtype...",
    # where name is the fully-qualified name and cmdtype is a type
    # as returned by [cmdinfo type] (for commands) or "ns" for namespaces.
    # Note that a namespace can appear twice, once as a namespace and
    # once as a namespace ensemble.

    typemethod list {ns} {
        # FIRST, qualify the namespace name.
        if {![string match "::*" $ns]} {
            error "namespace is not fully qualified, \"$ns\""
        }

        # NEXT, make sure it ends with "::".
        if {![string match "*::" $ns]} {
            append ns "::"
        }

        # NEXT, get a list of child namespaces
        set nodes [list]

        foreach child [namespace children $ns] {
            lappend nodes [list ${child}:: ns]
        }

        # NEXT, add the commands
        foreach name [info commands ${ns}*] {
            lappend nodes [list $name [cmdinfo type $name]]
        }

        # NEXT, sort the entries alphabetically
        set nodes [lsort -dictionary -index 0 $nodes]

        # NEXT, flatten the list
        concat {*}$nodes
    }

    # submap nse
    #
    # nse    A fully-qualified namespace ensemble
    #
    # Returns a dictionary of the subcommands of the ensemble, with their
    # mappings.

    typemethod submap {nse} {
        # FIRST, what are the subcommands?  If -subcommands is
        # defined, then it lists the subcommands:

        array set opts [namespace ensemble configure $nse]

        set subs $opts(-subcommands)

        # NEXT, if that didn't work, try -map.
        if {[llength $subs] == 0} {
            set subs [dict keys $opts(-map)]
        }

        # NEXT, if that didn't work, find out what's exported
        if {[llength $subs] == 0} {
            namespace eval ${type}::nselist_temp \
                [list namespace import ${opts(-namespace)}::*]

            set children [info commands ${type}::nselist_temp::*]

            namespace forget ${type}::nselist_temp

            foreach child $children {
                lappend subs [namespace tail $child]
            }
        }

        # NEXT, build retrieve the mapping and command type
        set result [dict create]

        foreach sub [lsort $subs] {
            if {[dict exists $opts(-map) $sub]} {
                set mapping [dict get $opts(-map) $sub]
                set cmd [lindex $mapping 0]
            } else {
                set mapping ${opts(-namespace)}::$sub
                set cmd $mapping
            }

            dict set result $sub $mapping
        }

        return $result
    }

}





