#-----------------------------------------------------------------------
# FILE: executive.tcl
#
# Executive Command Processor
#
# PACKAGE:
#   app_uram(n) -- mars_uram(1) implementation package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: executive
#
# The executive is the prouram's command processor.  It defines the
# set of commands available at the application's CLI in the
# main <appwin>.
#
# The executive is a wrapper around a smartinterpreter(n).  Unsafe
# Tcl commands are excluded.  Executive commands are of four types:
#
# * Standard Tcl commands defined in the executive interpreter.
# * Tcl procs defined in the executive interpreter by the executive
#   itself.
# * Smart aliases to commands defined elsewhere in the prouram.
# * Smart aliases to commands defined with the executive.
#
# The commands themselves are documented in the mars_uram1) man page.

snit::type executive {
    pragma -hasinstances no
    
    #-------------------------------------------------------------------
    # Type Components

    typecomponent interp    ;# Interpreter used for processing commands.

    #-------------------------------------------------------------------
    # Group: Type Variables

    # Type variable: stackTrace
    #
    # Tcl ::errorInfo for the most recent command error (if any).
    # This information is stored to support debugging of unexpected
    # errors (as opposed to errors due to invalid input).
    typevariable stackTrace {}

    #-------------------------------------------------------------------
    # Group: Initialization
    
    # Type method: init
    #
    # Initializes the executive at application start-up.  In particular,
    # this type method defines all of the commands available to the
    # executive.
    
    typemethod init {} {
        log normal exec "Initializing..."

        # FIRST, create the interpreter.  It's a safe interpreter but
        # most Tcl commands are retained, to allow scripting.  Allow
        # the "source" command.
        set interp [smartinterp ${type}::interp -cli yes]
        $interp expose source
        $interp expose file

        # NEXT, add commands that need to be defined in the slave itself.
        $interp proc call {script} {
            if {[file extension $script] eq ""} {
                append script ".tcl"
            }
            uplevel 1 [list source $script]
        }
        
        $interp proc select {args} {
            set query "SELECT $args"
            
            return [rdb query $query]
        }
        
        $interp proc profile {args} {
            set time [lindex [time {
                set result [{*}$args]  
            } 1] 0]
            
            log "profile: $time usec, $args"
            
            return $result
        }

        # NEXT, install the executive commands

        # =
        $interp smartalias = 1 - {expression...} \
            ::expr


        # bgerrtrace
        $interp smartalias bgerrtrace 0 0 {} \
            [mytypemethod bgerrtrace]

        # coop
        $interp ensemble coop

        # coop badjust
        $interp smartalias {coop badjust} 4 4 \
            {driver f g delta}                \
            [list ::sim coop adjust]

        # coop bset
        $interp smartalias {coop bset} 4 4 \
            {driver f g value}             \
            [list ::sim coop bset]

        # coop cset
        $interp smartalias {coop cset} 3 - \
            {f g value ?f g value...?}     \
            [list ::sim coop cset]

        # coop mass
        $interp smartalias {coop mass} 0 1 \
            {?driver?}                     \
            [list ::sim coop mass]

        # coop transient
        $interp smartalias {coop transient} 5 - \
            {driver cause f g mag ?option value...?} \
            [list ::sim coop transient]

        # debug
        $interp smartalias debug 0 - {?command...?} \
            [list ::marsgui::debugger debug]

        # errtrace
        $interp smartalias errtrace 0 0 {} \
            [mytypemethod errtrace]

        # help
        $interp smartalias help 1 - {?-info? command...} \
            [mytypemethod help]

        # hrel
        $interp ensemble hrel

        # hrel badjust
        $interp smartalias {hrel badjust} 4 4 \
            {driver f g delta}                \
            [list ::sim hrel adjust]

        # hrel bset
        $interp smartalias {hrel bset} 4 4 \
            {driver f g value}             \
            [list ::sim hrel bset]

        # hrel cset
        $interp smartalias {hrel cset} 3 - \
            {f g value ?f g value...?}     \
            [list ::sim hrel cset]

        # hrel mass
        $interp smartalias {hrel mass} 0 1 \
            {?driver?}                     \
            [list ::sim hrel mass]

        # hrel transient
        $interp smartalias {hrel transient} 5 5 \
            {driver cause f g mag} \
            [list ::sim hrel transient]


        # load
        $interp smartalias load 1 1 {dbfile} \
            [list ::sim load]

        # loadperf
        $interp smartalias loadperf 0 - {?options...?} \
            [list ::sim loadperf]

        # log
        $interp smartalias log 1 1 {text} \
            [list ::log normal user]

        # now
        $interp smartalias now 0 0 {} \
            [list ::sim now]

        # parm
        $interp ensemble parm

        # parm get
        $interp smartalias {parm get} 1 1 {parm} \
            [list ::parmdb get]

        # parm help
        $interp smartalias {parm help} 1 1 {parm} \
            [mytypemethod parm_help]

        # parm set
        $interp smartalias {parm set} 2 2 {parm value} \
            [list ::parmdb set]

        # parm names
        $interp smartalias {parm names} 0 1 {?pattern?} \
            [list ::parmdb names]

        # parm list
        $interp smartalias {parm list} 0 1 {?pattern?} \
            [list ::parmdb list]

        # parm load
        $interp smartalias {parm load} 0 0 {} \
            [list ::parmdb load]

        # parm reset
        $interp smartalias {parm reset} 0 0 {} \
            [list ::parmdb reset]

        # parm save
        $interp smartalias {parm save} 0 0 {} \
            [list ::parmdb save]

        # rdb
        $interp ensemble rdb

        # rdb eval
        $interp smartalias {rdb eval}  1 1 {sql} \
            [list ::rdb eval]

        # rdb query
        $interp smartalias {rdb query} 1 1 {sql} \
            [list ::rdb query]

        # rdb schema
        $interp smartalias {rdb schema} 0 1 {?table?} \
            [list ::rdb schema]

        # rdb tables
        $interp smartalias {rdb tables} 0 0 {} \
            [list ::rdb tables]

        # reset
        $interp smartalias reset 0 0 {} \
            [list ::sim reset]
        
        # sat
        $interp ensemble sat

        # sat badjust
        $interp smartalias {sat badjust} 4 4 \
            {driver g c delta}                \
            [list ::sim sat adjust]

        # sat bset
        $interp smartalias {sat bset} 4 4 \
            {driver g c value}             \
            [list ::sim sat bset]

        # sat cset
        $interp smartalias {sat cset} 3 - \
            {g c value ?g c value...?}     \
            [list ::sim sat cset]

        # sat mass
        $interp smartalias {sat mass} 0 1 \
            {?driver?}                     \
            [list ::sim sat mass]

        # sat transient
        $interp smartalias {sat transient} 5 - \
            {driver cause g c mag ?option value...?} \
            [list ::sim sat transient]

        # step
        $interp smartalias step 0 1 {?ticks?} \
            [list ::sim step]
        
        # super
        $interp smartalias super 1 - {arg ?arg...?} \
            [myproc super]

        # unload
        $interp smartalias unload 0 0 {} \
            [list ::sim unload]
        

        # vrel
        $interp ensemble vrel

        # vrel badjust
        $interp smartalias {vrel badjust} 4 4 \
            {driver g a delta}                \
            [list ::sim vrel adjust]

        # vrel bset
        $interp smartalias {vrel bset} 4 4 \
            {driver g a value}             \
            [list ::sim vrel bset]

        # vrel cset
        $interp smartalias {vrel cset} 3 - \
            {g a value ?g a value...?}     \
            [list ::sim vrel cset]

        # vrel mass
        $interp smartalias {vrel mass} 0 1 \
            {?driver?}                     \
            [list ::sim vrel mass]

        # vrel transient
        $interp smartalias {vrel transient} 5 - \
            {driver cause g a mag ?option value...?} \
            [list ::sim vrel transient]

    }

    #-------------------------------------------------------------------
    # Group: Public type methods
    #
    # These subcommands are available for use throughout the prouram.

    # Type method: help
    #
    # Outputs the calling syntax for a command.  Only smartalias'd
    # commands are supported.
    #
    # Syntax:
    #   executive help ?-info? _command..._
    #
    # -info      - If this option is included, the output will include
    #              the full command to which this _command_ is an alias.
    # command... - The name of the command; for ensemble commands, the
    #              command and its subcommand(s).

    typemethod help {args} {
        set getInfo 0

        if {[lindex $args 0] eq "-info"} {
            set getInfo 1
            set args [lrange $args 1 end]
        }

        set out [$interp help $args]

        if {$getInfo} {
            append out "\n\n[$interp cmdinfo $args]"
        }

        return $out
    }

    # Type method: eval
    #
    # Evaluates a _script_ in the context of the executive, throwing
    # an error or returning the script's result.  Either way, the
    # evaluation is logged.  Emptry scripts are ignored.
    #
    # Syntax:
    #   executive eval _script_
    #
    #   script - A script of executive commands.

    typemethod eval {script} {
        if {[string trim $script] eq ""} {
            return
        }

        log normal exec "Command: $script"

        # Make sure the command displays in the log before it
        # executes.
        update idletasks

        if {[catch {$interp eval $script} result]} {
            set stackTrace $::errorInfo
            log warning exec "Command error: $result"
            return -code error $result
        }

        return $result
    }

    # Type method: evalsafe
    #
    # Evaluates a _script_ of executive commands, just as <eval> does,
    # but swallows the return value or error (since it will be logged
    # anyway).
    #
    # Syntax:
    #   executive evalsafe _script_
    #
    #   script - A script of executive commands.

    typemethod evalsafe {script} {
        catch {$type eval $script}
    }

    # Type method: commands
    #
    # Returns a list of the commands defined in the Executive's 
    # interpreter

    typemethod commands {} {
        $interp eval {info commands}
    }

    # Type method: errtrace
    #
    # Returns the <stackTrace> from the most recent evaluation error.

    typemethod errtrace {} {
        log warning exec "errtrace: $stackTrace"
        return $stackTrace
    }
    
    #-------------------------------------------------------------------
    # Group: Executive Command Implementations
    #
    # These type methods and procs
    # implement all executive commands that aren't implemented
    # elsewhere.

    # Type method: bgerrtrace
    #
    # Implements the *bgerrtrace* command.
    # Returns the stack trace from the most recent <bgerror>.

    typemethod bgerrtrace {} {
        global bgErrorInfo
        
        if {[info exists bgErrorInfo]} {
            log error exec "bgerrtrace: $bgErrorInfo"
            return $bgErrorInfo
        } else {
            return "No bgerrors so far."
        }
    }
    
    # Type method: parm_help
    #
    # Implements the *parm help* command.  Returns help information
    # for the named <parm>.
    #
    # Syntax:
    #   parm_help _parm_
    #
    #   parm - The name of a parameter
    
    typemethod parm_help {parm} {
        # FIRST, get the docstring
        set doc [parmdb docstring $parm]
        
        # NEXT, strip HTML.
        regsub -all -- {<p>} $doc "\n\n" doc
        regsub -all -- {<[^<]+>} $doc "" doc
        
        # NEXT, replace entities
        set doc [string map {&lt; < &gt; > &amp; &} $doc]
        
        return $doc
    }
    
    # Proc: super
    #
    # Executes the _command_ in the global namespace.  This gives
    # the developer access to the application internals from the CLI,
    # while minimizing the risk of corrupting the application during
    # normal use.
    #
    # Syntax:
    #   super command _?args...?_
    #
    #   command - The command to execute.
    #   args... - The command's arguments.

    proc super {args} {
        namespace eval :: $args
    }

}








