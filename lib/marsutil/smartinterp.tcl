#-----------------------------------------------------------------------
# TITLE:
#    smartinterp.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) module: smartinterp(n), Smart Interps
#
#    A smart interp is a standard Tcl interp wrapped in a Snit object,
#    with added features for defining aliases.  The biggest of these
#    is the "smartalias" feature, which provides much better error
#    messages when a command is called with too many or too few 
#    arguments.
#
#    In addition, smartinterp(n) has tools for analyzing and validating
#    scripts and expressions with respect to the interpreter.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export smartinterp
}

#-----------------------------------------------------------------------
# smartinterp

snit::type ::marsutil::smartinterp {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # TBD: Needed?
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Signature Catalogs

    # Signatures for built-in functions
    variable functionSigs -array {
        abs    x
        acos   x
        asin   x
        atan   x
        atan2  y,x
        bool   flag
        ceil   x
        cos    x
        cosh   x
        double x
        entier x
        exp    x
        floor  x
        fmod   x,y
        hypot  x,y
        int    x
        isqrt  x
        log    x
        log10  x
        max    a,b,...
        min    a,b,...
        pow    x,y
        rand   ""
        round  x
        sin    x
        sinh   x
        sqrt   x
        srand  n
        tan    x
        tanh   x
        wide   x
    }

    # command signatures catalog
    #
    # The purpose of this catalog is to provide signature information
    # to support "lint" checking of commands and scripts written
    # by the user, in conjunction with other checking and analysis
    # code.  Thus, the signatures and argument numbers that appear
    # here are sometimes more restrictive than Tcl requires; for 
    # example, calling [return] with multiple arguments is likely
    # to be an error.

    variable commandSigs -array {
        append                {1 - "varName ?value value ...?"}
        array                 {2 - "subcommand arrayName ?...?"}
        "array get"           {1 1 "arrayName"}
        "array set"           {2 2 "arrayName dictionary"}
        "array unset"         {1 2 "arrayName ?pattern?"}
        break                 {0 0 ""}
        catch                 {1 3 "script ?resultVar? ?optionsVar?"}
        concat                {0 - "?args ...?"}
        continue              {0 0 ""}
        dict                  {1 - "subcommand ?...?"}
        "dict append"         {2 - "dictVar key ?string ...?"}
        "dict create"         {0 - "?key value ..."}
        "dict exists"         {2 - "dict key ?key ...?"}
        "dict for"            {3 3 "{keyVar valueVar} dict body"}
        "dict get"            {2 - "dict key ?key ...?"}
        "dict incr"           {2 - "dictVar key ?increment?"}
        "dict keys"           {1 2 "dict ?pattern?"}
        "dict lappend"        {2 - "dictVar key ?value ...?"}
        "dict merge"          {0 - "?dict ...?"}
        "dict remove"         {2 - "dict key ?key ...?"}
        "dict replace"        {1 - "dict ?key value ...?"}
        "dict set"            {3 - "dictVar key ?key ...? value"}
        "dict size"           {1 1 "dict"}
        "dict unset"          {2 - "dictVar key ?key ...?"}
        "dict values"         {1 2 "dict ?pattern?"}
        "dict with"           {2 - "dictVar ?key ...? body"}
        error                 {1 3 "message ?info? ?code?"}
        expr                  {1 1 "expression"}
        for                   {4 4 "start test next body"}
        foreach               {3 - "varName list body"}
        format                {1 - "formatString ?arg ...?"}
        if                    {2 - "expr1 body1 ?elseif expr2 body2 ... ?else bodyN?"}
        incr                  {1 2 "varName ?increment?"}
        join                  {1 2 "list ?joinString?"}
        lappend               {1 - "varName ?value ...?"}
        lassign               {2 - "list varName ?varName ...?"}
        lindex                {2 - "list index ?index ...?"}
        linsert               {3 - "list index element ?element ...?"}
        list                  {0 - "?arg ...?"}
        llength               {1 1 "list"}
        lrange                {3 3 "list first last"}
        lsearch               {2 - "?options ...? list pattern"}
        lset                  {2 - "varName ?index ...? newValue"}
        lsort                 {1 - "?options? list"}
        proc                  {3 3 "name args body"}
        return                {0 1 "?result?"}
        set                   {1 2 "varName ?newValue?"}
        source                {1 1 "filename"}
        split                 {1 2 "string ?splitChars?"}
        string                {2 - "subcommand string ?...?"}
        "string compare"      {2 - "?options? string1 string2"}
        "string equal"        {2 - "?options? string1 string2"}
        "string first"        {2 3 "needleString haystackString ?startIndex?"}
        "string index"        {2 2 "string charIndex"}
        "string last"         {2 3 "needleString haystackString ?startIndex?"}
        "string length"       {1 1 "string"}
        "string map"          {2 3 "?-nocase? mapping string"}
        "string match"        {2 3 "?-nocase? pattern string"}
        "string range"        {3 3 "string first last"}
        "string repeat"       {2 2 "string count"}
        "string replace"      {3 4 "string first last ?newstring?"}
        "string reverse"      {1 1 "string"}
        "string tolower"      {1 3 "string ?first? ?last?"}
        "string totitle"      {1 3 "string ?first? ?last?"}
        "string toupper"      {1 3 "string ?first? ?last?"}
        "string trim"         {1 2 "string ?chars?"}
        "string trimleft"     {1 2 "string ?chars?"}
        "string trimright"    {1 2 "string ?chars?"}
        "switch"              {2 - "?options? string {pattern body ?pattern body ...?}"}
        upvar                 {2 - "?level? otherVar myVar ?...?"}
        while                 {2 2 "expression body"}
        tcl::mathfunc::abs    {1 1 "x"}
        tcl::mathfunc::acos   {1 1 "x"}
        tcl::mathfunc::asin   {1 1 "x"}
        tcl::mathfunc::atan   {1 1 "x"}
        tcl::mathfunc::atan2  {1 1 "y x"}
        tcl::mathfunc::bool   {1 1 "flag"}
        tcl::mathfunc::ceil   {1 1 "x"}
        tcl::mathfunc::cos    {1 1 "x"}
        tcl::mathfunc::cosh   {1 1 "x"}
        tcl::mathfunc::double {1 1 "x"}
        tcl::mathfunc::entier {1 1 "x"}
        tcl::mathfunc::exp    {1 1 "x"}
        tcl::mathfunc::floor  {1 1 "x"}
        tcl::mathfunc::fmod   {1 1 "x y"}
        tcl::mathfunc::hypot  {1 1 "x y"}
        tcl::mathfunc::int    {1 1 "x"}
        tcl::mathfunc::isqrt  {1 1 "x"}
        tcl::mathfunc::log    {1 1 "x"}
        tcl::mathfunc::log10  {1 1 "x"}
        tcl::mathfunc::max    {2 - "a b ..."}
        tcl::mathfunc::min    {2 - "a b ..."}
        tcl::mathfunc::pow    {1 1 "x y"}
        tcl::mathfunc::rand   {0 0 ""}
        tcl::mathfunc::round  {1 1 "x"}
        tcl::mathfunc::sin    {1 1 "x"}
        tcl::mathfunc::sinh   {1 1 "x"}
        tcl::mathfunc::sqrt   {1 1 "x"}
        tcl::mathfunc::srand  {1 1 "n"}
        tcl::mathfunc::tan    {1 1 "x"}
        tcl::mathfunc::tanh   {1 1 "x"}
        tcl::mathfunc::wide   {1 1 "x"}

    }


    #-------------------------------------------------------------------
    # Components

    component interp   ;# The Tcl interp we're wrapping

    #-------------------------------------------------------------------
    # Options

    # -trusted flag
    #
    # The flag indicates whether the interpreter is trusted or not.  
    # Interps are untrusted (i.e., interp create -safe) by default.

    option -trusted \
        -default  no            \
        -readonly yes           \
        -type     snit::boolean

    # -cli flag
    #
    # The flag indicates whether the interpreter is attached to a CLI
    # or not.  If it's attached to the CLI, the error messages become
    # more readable.  By default the flag is "no", and the error messages
    # are similar to those produced by Tcl.

    option -cli \
        -default no            \
        -type    snit::boolean

    #-------------------------------------------------------------------
    # Instance Variables

    # aliases    Array of alias data
    #
    #   prefix-$alias    The command prefix for which $alias is an alias.

    variable aliases -array {}

    # ensembles   Array of ensemble data
    #
    #   subs-$alias      List of known subcommands

    variable ensembles -array {}

    # trans - Transient array used during script checking.
    #
    #    ilist     - A list of interpolated commands found by
    #                the expander when checking an argument of a command.
    #
    #    validCmds - A list of valid command names in :: in the interp.
    #
    #    ulist     - A list of commands found while processing an
    #                expression.

    variable trans -array {
        ilist     {}
        validCmds {}
        ulist     {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        # NEXT, create and configure the interpreter
        if {$options(-trusted)} {
            set interp [interp create]
        } else {
            set interp [interp create -safe]
        }

        # NEXT, define a private namespace to work in
        $interp eval {
            namespace eval ::_smart_:: { }
        }

        # NEXT, redefine the [expr] command
        $interp eval {
            rename ::expr ::_smart_::Expr_

            proc ::expr {args} {
                if {[llength $args] > 1} {
                    set expression $args
                } else {
                    set expression [lindex $args 0]
                }

                set cmd [list ::_smart_::Expr_ $expression]

                if {![catch {uplevel 1 $cmd} result eopts]} {
                    return $result
                }

                set message [::_smart_::TranslateExprError $result]

                return {*}$eopts $message
            }
        }

        $interp alias ::_smart_::TranslateExprError $self TranslateExprError
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Delegated methods
    delegate method alias        to interp
    delegate method expose       to interp
    delegate method hide         to interp
    delegate method hidden       to interp
    delegate method invokehidden to interp

    # eval script
    #
    # Evaluate the argument as a script in the context of the interpreter.

    method eval {script} {
        $interp eval $script
    }

    # evalargs args...
    #
    # Evaluate the concatenated arguments as a script in the context of the 
    # interpreter.

    method evalargs {args} {
        $interp eval $args
    }

    # function name min max argsyn prefix
    #
    # name   - A new function name
    # min       min number of arguments, >= 0
    # max       max number of arguments >= min, or "-" for unlimited.
    # argsyn    Argument syntax, as for a command.
    # prefix - The client's command prefix to which the function arguments
    #          will be added.
    #
    # Defines a new function tcl::mathfunc::$name as an alias to the
    # caller's command, saving the signature information.

    method function {name min max argsyn prefix} {
        $interp alias ::tcl::mathfunc::$name {*}$prefix
        $self setsig tcl::mathfunc::$name $min $max $argsyn
    } 

    # expr eval expression
    #
    # expression   - An expr expression
    #
    # Evaluates the expression in the smartinterp.

    method {expr eval} {expression} {
        return [$interp eval [list expr $expression]]
    }

    # expr validate expression
    #
    # expression  - An expr expression
    #
    # Attempts to validate the expression.  It cannot catch run-time errors
    # or perhaps even all syntax errors, but it's better than nothing.  The
    # approach is to evaluate the expression, catching any errors.  If there
    # are none, the expression is valid.  Otherwise, we report the error,
    # filtering out false positives.  For example, if we get a divide by
    # zero that means the expression must be syntactically valid.
    #
    # NOTE: This method is intended for validating a single expression in
    # the context of the smart interpreter's global namespace in a 
    # running application.  The expression should have no side effects.  
    # Variable references will be flagged as errors unless the variables
    # exist in the global namespace.

    method {expr validate} {expression} {
        if {![catch {$self expr eval $expression} result eopts]} {
            return $expression
        }

        set message [$self FilterExprErrors $result $eopts]

        if {$message eq ""} {
            return $expression
        } else {
            throw INVALID $message
        }
    }

    # FilterExprErrors message eopts
    #
    # message - An expr error message
    # eopts   - The error options
    #
    # Filters out non-syntax errors.  Returns "" if the expression
    # is syntactically valid, and the desired error message otherwise.

    method FilterExprErrors {message eopts} {
        # FIRST, rule out arithmetic errors.
        set code [dict get $eopts -errorcode]
        if {[string match "ARITH *" $code]} {
            return ""
        }

        # NEXT, return the error message we started with.
        # TBD: It's possible that there might be message translation
        # we want to do here instead of in TranslateExprError, but
        # so far I've not seen any.

        return $message
    }

    # proc name arglist body
    #
    # name      A proc name
    # arglist   A proc arglist
    # body      A proc body
    #
    # Defines a proc in the context of the interp, just as if a
    # proc command were passed to eval.

    method proc {name arglist body} {
        $interp eval [list proc $name $arglist $body]
    }

    # ensemble alias
    #
    # alias       An ensemble alias of one or more tokens.
    #
    # Defines an ensemble to which aliases can be added.

    method ensemble {alias} {
        require {![info exists aliases(prefix-$alias)]} \
            "can't redefine smartalias as an ensemble: \"$alias\""

        if {[llength $alias] > 1} {
            set parent [lrange $alias 0 end-1]
            require {[info exists ensembles(subs-$parent)]} \
       "can't define ensemble \"$alias\", no parent ensemble \"$parent\""
            lappend ensembles(subs-$parent) [lindex $alias end]
        }

        set ensembles(subs-$alias) {}

        $self setsig $alias 1 - "subcommand ?...?"

        if {[llength $alias] == 1} {
            $interp alias $alias   $self EnsembleHandler $alias
        }
    }
    
    
    # smartalias alias min max argsyn prefix
    #
    # alias     The command to define in the interp.
    # min       min number of arguments, >= 0
    # max       max number of arguments >= min, or "-" for unlimited.
    # argsyn    Argument syntax
    # prefix    The command prefix to which the alias's arguments will be
    #           lappended.
    #
    # Defines a new command called $alias in the interp.  The alias
    # must be called with at least min arguments and no more than
    # max (if max isn't "-").  If the number of arguments is wrong,
    # the error "wrong # args: $alias $argsyn" is thrown.
    #
    # The $prefix is the command prefix in the parent interpreter which
    # corresponds to $alias in the slave, and to which the args of $alias
    # will be appended.

    method smartalias {alias min max argsyn prefix} {
        require {![info exists ensembles(subs-$alias)]} \
            "can't redefine ensemble as a smartalias: \"$alias\""

        if {[llength $alias] > 1} {
            set parent [lrange $alias 0 end-1]

            require {[info exists ensembles(subs-$parent)]} \
               "can't define alias \"$alias\", no parent ensemble \"$parent\""

            lappend ensembles(subs-$parent) [lindex $alias end]
        }

        # FIRST, save the values.
        set aliases(prefix-$alias) $prefix

        $self setsig $alias $min $max $argsyn

        # NEXT, alias it into the interp.
        if {[llength $alias] == 1} {
            $interp alias $alias   $self SmartAliasHandler $alias
        }
    }

    # SmartAliasHandler alias args...
    #
    # alias    The alias to handle
    # args     The args it was called with
    #
    # Validates the number of args and calls the target command.

    method SmartAliasHandler {alias args} {
        set len [llength $args]
        lassign $commandSigs($alias) min max argsyn

        if {$len < $min || ($max ne "-" && $len > $max)} {
            set syntax $alias
            
            if {$argsyn ne ""} {
                append syntax " "
                append syntax $argsyn
            }

            if {$options(-cli)} {
                error [tsubst {
                    |<--
                    Wrong number of arguments.

                    [$self help $alias]}]
            } else {
                error "wrong \# args: should be \"$syntax\""
            }
        }

        return [uplevel \#0 $aliases(prefix-$alias) $args]
    }

    # EnsembleHandler alias args...
    #
    # alias     The aliased ensemble name
    # args      The arguments to the ensemble.
    #
    # Calls the correct alias in this ensemble

    method EnsembleHandler {alias args} {
        # FIRST, there must be a subcommand.
        while {[llength $args] > 0} {
            # FIRST, get the subcommand.
            set sub [lindex $args 0]
            set args [lrange $args 1 end]

            # NEXT, either we have an alias, another ensemble, or 
            # it's an error.
            set subalias [concat $alias $sub]

            if {[info exists aliases(prefix-$subalias)]} {
                return [eval [list $self SmartAliasHandler $subalias] $args]
            }

            if {![info exists ensembles(subs-$subalias)]} {
                if {$options(-cli)} {
                    error [tsubst {
                        |<--
                        Invalid subcommand: "$sub"

                        [$self help $alias]}]
                } else {
                    set subs [join $ensembles(subs-$alias) ", "]

                    error "bad subcommand \"$sub\", should be one of: $subs"
                }
            }

            # NEXT, go round again.
            set alias $subalias
        }

        if {$options(-cli)} {
            error [tsubst {
                |<--
                Missing subcommand.
                
                [$self help $alias]}]
        } else {
            set subs [join $ensembles(subs-$alias) ", "]

            error "wrong \# args: should be \"$alias subcommand ?args...?\", valid subcommands: $subs"
        }
    }

    # help command
    #
    # command - A smart alias or other command
    #
    # Returns help text for the command, if any.

    method help {command} {
        set sdict [$self siginfo $command]

        # FIRST, what kind of command is it?
        if {[info exists ensembles(subs-$command)]} {
            # It's an ensemble
            set subs [join $ensembles(subs-$command) ", "]

            return [tsubst {
                |<--
                Usage: $command subcommand ?args...?
                Valid subcommands: $subs}]
        } elseif {[dict size $sdict] > 0} {
            # It's a normal command
            set prefix [dict get $sdict prefix]
            set argsyn [dict get $sdict argsyn]
            return "Usage: $prefix $argsyn"
        } else {
            # It's neither.
            error "No help found: \"$command\""
        }
    }

    # cmdinfo alias
    #
    # alias         A smart alias
    #
    # Returns implementation details for the alias.

    method cmdinfo {alias} {
        return [$self InfoWithLeader $alias ""]
    }

    # InfoWithLeader alias leader
    #
    # leader    Leading whitespace for each line.

    method InfoWithLeader {alias leader} {
        # FIRST, what kind of alias is it?
        if {[info exists ensembles(subs-$alias)]} {
            lappend out [list ensemble $alias of:]
            foreach sub $ensembles(subs-$alias) {
                lappend out [$self InfoWithLeader "$alias $sub" "    "]
            }
        } elseif {[info exists aliases(prefix-$alias)]} {
            # It's a normal smart alias
            lappend out [list alias $alias {*}$commandSigs($alias)]
        } else {
            error "No info found: \"$alias\""
        }

        return "$leader[join $out \n$leader]"
    }

    #-------------------------------------------------------------------
    # Expression Error Handling
    

    # TranslateExprError message
    #
    # message   - An error message from expr
    #
    # Translates the error message to make it more user-friendly,
    # and returns the new message.

    method TranslateExprError {message} {
        switch -regexp -matchvar match -- $message {
            {^wrong # args:.*\"tcl::mathfunc::(\S+) (.*)\"$} {
                lassign $match dummy func arglist
                set call ${func}([join $arglist ,])
                return \
            "error in function ${func}(), wrong # args, should be \"$call\""
            }

            {^too \w+ arguments for math function \"(\w+)\"$} {
                lassign $match dummy func
                set call "${func}($functionSigs($func))"
                return \
            "error in function ${func}(), wrong # args, should be \"$call\""
            }

            {^invalid command name \"tcl::mathfunc::(\S+)\"$} {
                lassign $match dummy func
                return "unknown function: \"${func}()\""
            }

            {^invalid command name \"(.+)\"$} {
                return "unknown command: \"[lindex $match 1]\""
            }

            {^(invalid bareword \"[^\"]+\").*} {
                return [lindex $match 1]
            }


            default {
                return [normalize $message]
            }
        }
    }

    #-------------------------------------------------------------------
    # Signature Info

    # setsig prefix min max argsyn
    #
    # prefix   - The command prefix, e.g., "set", "string equal"
    # min      - The minimum number of arguments required.
    # max      - The maximum number of arguments required, or "-"
    #            for no obvious maximum.
    # argsyn   - The argument syntax, e.g., "varName ?newValue?"
    #            for [set].
    # 
    # Saves the signature information for the given command prefix.

    method setsig {prefix min max argsyn} {
        set commandSigs($prefix) [list $min $max $argsyn]
    }

    # siginfo command
    #
    # command - A command or command prefix.
    #
    # Returns signature info for the given command, reading as many
    # tokens of the command as needed to do the best job given the
    # information available to the interp.  The info is returned as
    # a dictionary with the following keys:
    #
    #    prefix   - The command prefix, e.g., "set", "string equal"
    #    min      - The minimum number of arguments required.
    #    max      - The maximum number of arguments required, or "-"
    #               for no obvious maximum.
    #    argsyn   - The argument syntax, e.g., "varName ?newValue?"
    #               for [set].
    #
    # Note that the prefix and argsyn are separate so that code that
    # retrieves the info can format them differently for display.

    method siginfo {command} {
        # FIRST, we need to treat the command as a list of words; make 
        # sure it's a valid list.  If it isn't, we can't do anything
        # with it anyway.
        if {[catch {
            lassign [tclchecker cmdsplit $command] words lineNumbers
        }]} {
            return {}
        }

        # NEXT, do the words match a standard Tcl command for which we have
        # catalog info?
        set prefix [$self FindPrefix $words]
        
        if {[llength $prefix] > 0} {
            return [$self StandardSigInfo $prefix]
        }

        # NEXT, is the initial word the name of a proc?  Assume it is;
        # the routine will return the empty string if not.
        return [$self ProcSigInfo [lindex $words 0]]
    }


    # StandardSigInfo prefix
    #
    # prefix   - A cataloged command prefix
    #
    # Returns the siginfo dictionary for the given prefix.

    method StandardSigInfo {prefix} {
        lassign $commandSigs($prefix) min max argsyn
        dict create \
            prefix $prefix \
            min    $min     \
            max    $max     \
            argsyn $argsyn
    }

    # ProcSigInfo procname
    #
    # procname   - A procedure name
    #
    # Returns the siginfo dictionary for the given proc in the interp.

    method ProcSigInfo {procname} {
        set result [dict create prefix $procname]

        # FIRST, get the list of argument names.
        if {[catch {
            $self evalargs info args $procname
        } arglist]} {
            return {}
        }

        # NEXT, get the maximum number.
        if {[lindex $arglist end] eq "args"} {
            # Arbitrary number of arguments
            set max "-"

            set arglist [lrange $arglist 0 end-1]
        } else {
            set max [llength $arglist]
        }

        # NEXT, the minimum number is usually the number of args.
        set min [llength $arglist]

        # NEXT, build up the signature; and decrement min for each
        # optional argument.
        set argsyn [list]

        foreach arg $arglist {
            set dflag [$self evalargs info default $procname $arg dummy]

            if {$dflag} {
                lappend argsyn "?$arg?"
                incr min -1
            } else {
                lappend argsyn $arg
            }
        }

        if {$max eq "-"} {
            lappend argsyn "..."
        }

        dict set result min    $min
        dict set result max    $max
        dict set result argsyn $argsyn

        return $result
    }

    # FindPrefix words
    #
    # words    - A command, split into words
    #
    # Finds the prefix that matches a cataloged standard Tcl command, if any,
    # and returns it.  If there are multiple (e.g., "array" vs. 
    # "array get"), returns the longest.  Returns "" on failure.

    method FindPrefix {words} {
        set command [list]

        while {[llength $words] > 0} {
            set next [lshift words]
            set candidate $command
            lappend candidate $next

            if {[info exists commandSigs($candidate)]} {
                # We have a command, we might have a
                # sub-command.
                set command $candidate
                continue
            }

            # It's neither an command nor an alias
            break
        }

        return $command
    }
}




