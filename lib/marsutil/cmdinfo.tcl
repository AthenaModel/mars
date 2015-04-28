#-----------------------------------------------------------------------
# TITLE:
#   cmdinfo.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   marsutil(n) Tcl Command Introspector
#
#   cmdinfo(n) is an ensemble command whose subcommands are used for
#   introspection of Tcl commands and namespaces.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export cmdinfo
}

#-----------------------------------------------------------------------
# cmdinfo

snit::type ::marsutil::cmdinfo {
    # Make it an ensemble
    pragma -hasinstances no -hastypedestroy no

    #-------------------------------------------------------------------
    # Public Methods

    # exists name
    #
    # name    - A command name in the caller's scope?
    #
    # Returns 1 if there is a command by that name in the caller's
    # scope, and 0 otherwise.

    typemethod exists {name} {
        set result [uplevel 1 [list info commands $name]]
        expr {[llength $result] == 1}
    }


    # type name
    #
    # name   - A command name
    #
    # Returns the command type, one of the following:
    #
    #   proc            - A normal proc
    #   oo-object       - A TclOO object (note that classes are objects)
    #   snit-type       - A Snit type (also an NSE)
    #   snit-instance   - An instance of a Snit type (also an NSE)
    #   snit-typemethod - A proc that is a snit typemethod
    #   snit-method     - A proc that is a snit method
    #   nse             - A namespace ensemble
    #   alias           - A command alias in this interpreter
    #   unknown         - A binary command or an alias in a parent interp.
    #
    # In order to determine the available subcommands, options, and so
    # forth for various widget types, the BWidget package creates
    # a number of undisplayed widgets of various types with odd names
    # containing "#" characters.  This command refers to these as 
    # "BWidget special widgets", or bwid's.

    typemethod type {name} {
        # FIRST, Get and use the fully qualified name.  If it simply 
        # doesn't exist, it's unknown.
        try {
            set name [uplevel 1 [list namespace origin $name]]
        } on error {} {
            return "unknown"
        }

        # NEXT, get and use the absolute name

        if {[cmdinfo is snit-typemethod $name]} {
            return "snit-typemethod"
        } elseif {[cmdinfo is snit-method $name]} {
            return "snit-method"
        } elseif {[cmdinfo is proc $name]} {
            return "proc"
        } elseif {[cmdinfo is oo-object $name]} {
            return "oo-object"
        } elseif {[cmdinfo is snit-type $name]} {
            return "snit-type"
        } elseif {[cmdinfo is snit-instance $name]} {
            return "snit-instance"
        } elseif {[cmdinfo is nse $name]} {
            return "nse"
        } elseif {[cmdinfo is alias $name]} {
            return "alias"
        } else {
            # We don't know what it really is, but we won't be able to
            # retrieve a code body.
            return "unknown"
        }
    }

    # origin cmdline
    #
    # cmdline   - A Tcl command line
    # 
    # Given a command line in the caller's scope, attempts to discover the
    # ultimate source of the code body that will be called.
    #
    # The result is a list {type command ?method?} where command is
    # the ultimate command that will be called, and type is its type,
    # one of: unknown, proc, oo-objmethod, oo-method, snit-typemethod, or 
    # snit-method.
    #
    # For the latter four, the "method" will be the name of a subcommand
    # of the object.
    #
    # Essentially, this command traces alias and nse links to try to 
    # determine the source.

    typemethod origin {cmdline} {
        # FIRST, Get and use the fully qualified name.  If it simply 
        # doesn't exist, it's unknown.
        try {
            set command \
                [uplevel 1 [list namespace origin [lindex $cmdline 0]]]
        } on error {result} {
            return [list unknown [lindex $cmdline 0] $result]
        }

        # NEXT, get the argument list.
        set arglist [lrange $cmdline 1 end]

        # NEXT, get the command's type.
        set ctype [cmdinfo type $command]

        # NEXT, if we already know what it is we're done.
        if {$ctype in {"proc" "unknown"}} {
            return [list $ctype $command]
        }

        # NEXT, if it's an alias, look up the alias and try again.
        if {$ctype eq "alias"} {
            set cmdline [concat [cmdinfo getalias $command] $arglist]
            return [cmdinfo origin $cmdline]
        }


        # NEXT, if it's a TclOO object, return it with its method.
        if {$ctype eq "oo-object"} {
            # FIRST, get the method name, which is required.
            set method [lshift arglist]

            if {$method eq ""} {
                return [list unknown $command "no method specified"]
            }

            # NEXT, get the first link in the call chain
            set calldata [lindex [GetCallChain $command $method] 0]

            if {[llength $calldata] == 0} {
                return [list unknown $command "no such method: \"$method\""]
            }

            lassign $calldata mtype dummy cls imp

            # NEXT, the mtype must be either "method" or "unknown"
            # (we've already removed filters from the callchain).
            if {$mtype eq "unknown"} {
                # The call is processed by the object's unknown method,
                # if there is one.
                if {$imp eq {core method: "unknown"}} {
                    # There isn't one.
                    return [list unknown $command "no such method: \"$method\""]
                }

                # Go look up the unknown method.
                return [cmdinfo origin [list $command unknown]]
            }
 
            # NEXT, is this an object method or a class method?
            if {$cls eq "object"} {
                if {$imp eq "forward"} {
                    return [cmdinfo origin \
                        [concat [info object forward $command $method] \
                                $arglist]]
                } else {
                    return [list oo-objmethod $command $method]
                }
            } else {
                if {$imp eq "forward"} {
                    return [cmdinfo origin \
                        [concat [info class forward $cls $method] \
                                $arglist]]
                } else {
                    return [list oo-method $cls $method]
                }
            }
        }

        # NEXT, if it's a snit typemethod, break it into type and name.
        if {$ctype in {"snit-method" "snit-typemethod"}} {
            set stype [namespace qualifiers $command]
            set procname [namespace tail $command]

            if {[Chop procname Snit_typemethod]} {
                set method $procname
            } elseif {[Chop procname Snit_htypemethod]} {
                set method [split $procname _]
            } elseif {[Chop procname Snit_method]} {
                set method $procname
            } elseif {[Chop procname Snit_hmethod]} {
                set method [split $procname _]
            } else {
                # Should never be here.
                error "What? stype:$stype procname:<$procname>"
            }

            return [list $ctype $stype $method]
        }

        # NEXT, if it's a namespace ensemble, follow the delegation trail.
        # For snit type and instances, this will find definitions of both
        # organic and delegated methods, provided that they have been 
        # called (snit caches definitions in the object NSE as they are 
        # used.)

        if {$ctype in {"nse" "snit-type" "snit-instance"}} {
            # FIRST, get the method, which is required.
            set method [lshift arglist]

            if {$method eq ""} {
                return [list unknown $command "no method specified"]
            }

            # NEXT, look it up.
            set map [cmdinfo nsemap $command]

            if {[dict exists $map $method]} {
                return [cmdinfo origin [concat [dict get $map $method] $arglist]]
            } elseif {$ctype eq "nse"} {
                # It's just an ensemble; we've got no recourse.
                return [list unknown $command "no such method: \"$method\""]
            } else {
                # It's a snit type or instance; we can keep looking.
            }
        }

        # NEXT, if it's a snit type or snit instance and the method is 
        # organic we can still look it up.
        set method [lrange $cmdline 1 end]

        if {$ctype eq "snit-type"} {
            if {[FindSnitTypemethod $command $method] ne ""} {
                return [list snit-typemethod $command $method]
            }
        } elseif {$ctype eq "snit-instance"} {
            set stype [$command info type]

            if {[FindSnitMethod $stype $method] ne ""} {
                return [list snit-method $stype $method]
            }
        }

        # NEXT, we couldn't find anything.
        return [list unknown $command "no definition identified"]
    }

    # GetCallChain object method
    #
    # object - A TclOO object
    # method - A method called on the object
    #
    # Returns the callchain, as returned by [info object call], skipping
    # any filter methods (which are irrelevant for our purposes).

    proc GetCallChain {object method} {
        set chain [list]

        foreach calldata [info object call $object $method] {
            if {[lindex $calldata 0] ne "filter"} {
                lappend chain $calldata
            }
        }

        return $chain
    }

    # Chop stringvar prefix
    #
    # stringvar   - A string variable
    # prefix      - A prefix
    #
    # If the string begins with the prefix, removes it, updates the variable,
    # and returns 1, and 0 otherwise.

    proc Chop {stringvar prefix} {
        upvar 1 $stringvar string

        if {[string first $prefix $string] == 0} {
            set string [string range $string [string length $prefix] end]
            return 1
        }
        return 0
    }

    # FindSnitTypemethod objtype subcmd
    #
    # objtype  - A Snit type
    # subcmd   - A Snit typemethod name, possibly multi-token
    #
    # Formats and returns the name of the proc that corresponds to this
    # type and typemethod.  If no such proc exists, returns ""

    proc FindSnitTypemethod {objtype subcmd} {
        if {[llength $subcmd] == 1} {
            set procName "${objtype}::Snit_typemethod${subcmd}"
        } else {
            set procName "${objtype}::Snit_htypemethod[join $subcmd _]"
        }

        if {[llength [info commands $procName]] != 1} {
            return ""
        }

        return $procName
    }

    # FindSnitMethod objtype subcmd
    #
    # objtype  - A Snit type
    # subcmd   - A Snit method name, possibly multi-token
    #
    # Formats and returns the name of the proc that corresponds to this
    # type and method.  If no such proc exists, returns ""
    
    proc FindSnitMethod {objtype subcmd} {
        if {[llength $subcmd] == 1} {
            set procName "${objtype}::Snit_method${subcmd}"
        } else {
            set procName "${objtype}::Snit_hmethod[join $subcmd _]"
        }

        if {[llength [info commands $procName]] != 1} {
            return ""
        }

        return $procName
    }

    # list ns
    #
    # ns  - A fully-qualified namespace
    #
    # Returns a list of the commands in a namespace, including child
    # namespaces.  The list has the form "name cmdtype name cmdtype...",
    # where name is the fully-qualified name and cmdtype is a type
    # as returned by [cmdinfo type] (for commands) or "ns" for namespaces.
    # Note that a namespace can appear twice, once as a namespace and
    # once as a namespace ensemble.
    #
    # TBD: Add filtering!

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


    # nsemap nse
    #
    # nse    A fully-qualified namespace ensemble
    #
    # Returns a dictionary of the subcommands of the ensemble, with their
    # mappings.

    typemethod nsemap {nse} {
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

    # getalias alias
    #
    # alias   - An alias in this interpreter
    #
    # Returns the command to which the alias translates.  If the given
    # alias begins with "::", as it probably does, we'll try translating
    # it with and without.

    typemethod getalias {alias} {
        set trans [interp alias {} $alias]
        if {[llength $trans] > 0} {
            return $trans
        }

        set alias [string trimleft $alias :]

        set trans [interp alias {} $alias]
        if {[llength $trans] > 0} {
            return $trans
        }

        error "not an alias: \"$alias\""
    }

    #-------------------------------------------------------------------
    # Code Retrieval

    # getcode cmdline -related
    #
    # cmdline   - A Tcl command line, a command with arguments.
    # -related  - Retrieve all related code.
    #
    # By default, getcode returns the command definition that precisely 
    # matches the given command line, returning "" if no code is available.
    #
    # If the -related option is included, getcode returns a list of code
    # definitions, starting with the primary command definition but also
    # including other related definitions.
    #
    # * If the command is a snit type, and the arguments name an instance
    #   method, the instance method's definition will be included.  If
    #   the type defines both a type method and an instance method with
    #   the same name, both will be included.
    #
    # * If the command is a TclOO object, the output will include as many
    #   definitions as possible from the call-chain, excluding filters.
    #
    # * If the command is a TclOO class, and the arguments name an 
    #   instance method of that class, the output will include the
    #   instance method's definition.

    typemethod getcode {cmdline {opt ""}} {
        # FIRST, handle the default case: get the primary definition or 
        # throw an error.
        set prime [uplevel 1 [list cmdinfo origin $cmdline]]

        if {$opt ne "-related"} {
            if {[lindex $prime 0] ne "unknown"} {
                return [GetDefinition $cmdline $prime]
            } else {
                return ""
            }
        }

        # NEXT, begin to build up the result.
        lassign $prime ctype cls method

        set deflist [list]

        # Add the prime definition.
        if {[lindex $prime 0] ne "unknown"} {
            lappend deflist [GetDefinition $cmdline $prime]
        }

        # NEXT, for TclOO class methods, add the call chain.
        if {$ctype eq "oo-method"} {
            set n 0
            foreach {t m c i} [info class call $cls $method] {
                # FIRST, skip anything that isn't a normal method
                if {$t ne "method" || $i ne "method"} {
                    continue
                }

                # NEXT, get the method definition
                incr n
                set origin [list oo-method $cls $m]

                if {$origin eq $prime} {
                    continue
                }
                set memo "$cmdline, chain #$n"
                lappend deflist [GetDefinition $memo $origin]
            }
        }

        # NEXT, for TclOO object methods, add the call chain.
        if {$ctype eq "oo-objmethod"} {
            set n 0
            foreach {t m c i} [info object call $cls $method] {
                # FIRST, skip anything that isn't a normal method
                if {$t ne "method" || $i ne "method"} {
                    continue
                }

                # NEXT, get the method definition
                incr n
                if {$c eq object} {
                    set origin [list oo-objmethod $cls $m]
                } else {
                    set origin [list oo-method $cls $m]
                }

                if {$origin eq $prime} {
                    continue
                }

                set memo "$cmdline, chain #$n"
                lappend deflist [GetDefinition $memo $origin]
            }
        }

        # NEXT, we found a snit typemethod; add the instance method as well.
        if {$ctype eq "snit-typemethod"} {
            set origin [list snit-method $cls $method]
            set memo "$cmdline, instance method"
            set def [GetDefinition $memo $origin]

            if {$def ne ""} {
                lappend deflist $def
            }
        }

        if {$ctype eq "oo-objmethod"} {
            set origin [list oo-method $cls $method]
            set memo "$cmdline, instance method"
            set def [GetDefinition $memo $origin]

            if {$def ne ""} {
                lappend deflist $def
            }
        }

        # NEXT, suppose we didn't find anything the first time.  Look
        # for the arguments as an instance method.
        if {$ctype eq "unknown"} {
            set command $cls
            set arglist [lrange $cmdline 1 end]

            if {[cmdinfo type $cls] eq "snit-type"} {
                set origin [list snit-method $cls $arglist]
                set memo "$cmdline, instance method"
                set def [GetDefinition $memo $origin]
            } elseif {[info object isa class $cls]} {
                set origin [list oo-method $cls $arglist]
                set memo "$cmdline, instance method"
                set def [GetDefinition $memo $origin]
            } else {
                set def ""
            }

            if {$def ne ""} {
                lappend deflist $def
            }
        }
    
        return $deflist
    }

    # GetDefinition memo origin
    #
    # memo      - A description of this definition
    # origin    - A command origin
    #
    # Retrieves the code associated with the origin, and returns it
    # in a form that can be evaluated to recreate it (within reason).

    proc GetDefinition {memo origin} {
        lassign $origin ctype command method

        set title "# source: $memo => $origin"

        switch -exact -- $ctype {
            proc            {set def [GetProc           $command]        }
            snit-typemethod {set def [GetSnitTypemethod $command $method]}
            snit-method     {set def [GetSnitMethod     $command $method]}
            oo-method       {set def [GetOoMethod       $command $method]}
            oo-objmethod    {set def [GetOoObjMethod    $command $method]}
            default         {error "Unexpected ctype: \"$ctype\""        }
        }

        if {$def ne ""} {
            return "$title\n$def\n"
        } else {
            return ""
        }

    }

    # GetProc name
    #
    # name   - A fully qualified proc name
    #
    # Returns the code to redefine the proc.

    proc GetProc {name} {
        set arglist [GetArgList $name]

        return [list proc $name $arglist [info body $name]]
    }

    # GetSnitTypemethod objtype method
    #
    # objtype  - The Snit type
    # method   - The full method name
    #
    # Returns the code to define the typemethod.

    proc GetSnitTypemethod {objtype method} {
        # FIRST, get the procedure name.
        set procName [FindSnitTypemethod $objtype $method]

        if {$procName eq ""} {
            return ""
        }

        # NEXT, get the argument list, skipping the implicit 
        # "type" argument
        set arglist [lrange [GetArgList $procName] 1 end]

        # NEXT, get the body of the method, remove the Snit
        # prolog, and reindent.
        set body [info body $procName]

        regsub {^.*\# END snit method prolog\n} $body {} body

        set body [ReindentBody $body]

        # NEXT, return the definition
        return [list snit::typemethod $objtype $method $arglist $body]
    }


    # GetSnitMethod objtype method
    #
    # objtype  - The Snit type
    # method   - The full method name
    #
    # Returns the code to define the method.

    proc GetSnitMethod {objtype method} {
        # FIRST, get the procedure name.
        set procName [FindSnitMethod $objtype $method]

        if {$procName eq ""} {
            return ""
        }


        # NEXT, get the argument list, skipping the implicit 
        # arguments
        set arglist [lrange [GetArgList $procName] 4 end]

        # NEXT, get the body of the method, remove the Snit
        # prolog, and reindent.
        set body [info body $procName]

        regsub {^.*\# END snit method prolog\n} $body {} body
        
        set body [ReindentBody $body]

        # NEXT, return the result.
        return [list snit::method $objtype $method $arglist $body]
    }

    # GetOoMethod cls method
    #
    # cls      - A TclOO class name
    # method   - The full method name
    #
    # Returns the code to define the method.

    proc GetOoMethod {cls method} {
        try {
            lassign [info class definition $cls $method] arglist body
        } on error {} {
            return ""
        }

        set body [ReindentBody $body]
        return [list oo::define $cls method $method $arglist $body]
    }

    # GetOoObjMethod obj method
    #
    # obj      - A TclOO object name
    # method   - The full method name
    #
    # Returns the code to define the method.

    proc GetOoObjMethod {obj method} {
        try {
            lassign [info object definition $obj $method] arglist body
        } on error {} {
            return ""
        }

        set body [ReindentBody $body]
        return [list oo::objdefine $obj method $method $arglist $body]
    }

    # GetArgList name
    #
    # name  - A fully-qualified proc name
    #
    # Returns the argument list in normal form.

    proc GetArgList {name} {
        set arglist {}

        foreach arg [info args $name] {
            if {[info default $name $arg defvalue]} {
                lappend arglist [list $arg $defvalue]
            } else {
                lappend arglist $arg
            }
        }


        return $arglist
    }

    # ReindentBody body
    #
    # body    The body of a proc or method
    #
    # Outdents the body, then re-indents it four spaces.

    proc ReindentBody {body} {
        set lines [list]
        foreach line [split [outdent $body] \n] {
            lappend lines "    $line"
        }
        
        return "\n[join $lines \n]\n"
    }
    

    #-------------------------------------------------------------------
    # Predicates

    # is proc cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a proc, and 0 otherwise.

    typemethod {is proc} {cmd} {
        expr {[llength [info procs $cmd]] == 1}
    }

    # is snit-typemethod cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a proc that implements a 
    # snit::typemethod, and 0 otherwise.

    typemethod {is snit-typemethod} {cmd} {
        expr {
            [cmdinfo is proc $cmd] &&
            ([string match "*::Snit_typemethod*" $cmd] ||
             [string match "*::Snit_htypemethod*" $cmd])
        }
    }

    # is snit-method cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a proc that implements a 
    # snit::method, and 0 otherwise.

    typemethod {is snit-method} {cmd} {
        expr {
            [cmdinfo is proc $cmd] &&
            ([string match "*::Snit_method*" $cmd] ||
             [string match "*::Snit_hmethod*" $cmd])
        }
    }


    # is oo-object cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a TclOO object or class, and 0 otherwise.

    typemethod {is oo-object} {cmd} {
        expr {[info object isa object $cmd]}
    }

    # is snit-type cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a snit::type, and 0 otherwise.

    typemethod {is snit-type} {cmd} {
        expr {
            [cmdinfo is nse $cmd] && 
            [cmdinfo exists ${cmd}::Snit_typeconstructor]
        }
    }

    # is snit-instance cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is an instance of a snit::type, and 
    # 0 otherwise.
    #
    # If it's an instance, it should have a the "info type" subcommand;
    # and that type should be a snit::type.

    typemethod {is snit-instance} {cmd} {
        if {![cmdinfo is nse $cmd]} {
            return 0
        }
        try {
            set stype [$cmd info type]
            return [expr {$cmd in [$stype info instances]}]            
        } on error {result} {
            # do nothing
        }

        return 0
    }

    # is nse cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a namespace ensemble, and 0 otherwise.

    typemethod {is nse} {cmd} {
        expr {[namespace ensemble exists $cmd]}
    }

    # is alias cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is an alias, and 0 otherwise.
    #
    # Note: Assumes that aliases are 

    typemethod {is alias} {cmd} {
        # FIRST, the command will usually be fully qualified.  See if
        # that works.
        if {[llength [interp alias {} $cmd]] > 0} {
            return 1
        }

        # NEXT, you have to look up an alias by the exact name that
        # was used to define it.  Try trimming the leading colons.
        set cmd [string trimleft $cmd :]

        return [expr {[llength [interp alias {} $cmd]] > 0}]
    }


    # is window cmd
    #
    # cmd   - A fully-qualified command name
    #
    # Returns 1 if the command is a Tk window name, and 0 otherwise.
    
    typemethod {is window} {cmd} {
        # FIRST, remove leading "::"; window names don't include them.
        set cmd [string trimleft $cmd ":"]

        # It's only a window if Tk is loaded and Tk says it's a window.
        expr {[cmdinfo exists ::winfo] && [winfo exists $cmd]}
    }

    # is dummyWindow cmd 
    #
    # cmd   - A fully-qualified command name
    #
    # In order to determine the available subcommands, options, and so
    # forth for various widget types, the BWidget package creates
    # a number of undisplayed widgets of various types with odd names
    # containing "#" characters.  We don't want to include these when
    # displaying window hierarchies.
    #
    # Returns 1 if the command is one of these, and 0 otherwise.

    typemethod {is dummyWindow} {cmd} {
        expr {[$type is window $cmd] && [string first "\#" $cmd] > -1}
    }
}





