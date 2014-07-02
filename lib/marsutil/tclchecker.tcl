#-----------------------------------------------------------------------
# TITLE:
#    tclchecker.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) module: tclchecker(n), a "lint" checker for
#    simple Tcl scripts.  The checker works with a -tclchecker
#    to provide lint checking for scripts meant to run in the 
#    interp.
#
#    This module also has some useful commands for analyzing
#    scripts.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export tclchecker
}

#-----------------------------------------------------------------------
# tclchecker

snit::type ::marsutil::tclchecker {
    pragma -hasinstances no


    #-------------------------------------------------------------------
    # Type Components

    typecomponent synterp  ;# Interpreter used for syntax checking.
    typecomponent expander ;# textutil::expander used to pull interpolated
                            # commands out of command arguments while
                            # lint checking.


    #-------------------------------------------------------------------
    # Type Variables
    

    # trans - Transient array used during script checking.
    #
    #    client    - A client interpreter
    #
    #    ilist     - A list of interpolated commands found by
    #                the expander when checking an argument of a command.
    #
    #    validCmds - A list of valid command names in :: in the interp.
    #
    #    ulist     - A list of commands found while processing an
    #                expression.

    typevariable trans -array {
        client    {}
        ilist     {}
        validCmds {}
        ulist     {}
    }

    #-------------------------------------------------------------------
    # Script Manipulation 

    # scriptsplit script ?firstline?
    #
    # text       - A Tcl script
    # firstline  - The line number of the first line of the script.
    #              defaults to 1.
    #
    # Splits the script into consecutive top-level commands, returning
    # a dictionary of commands by starting line number.  Does not
    # recurse into control structures.  Multiple commands per line
    # are treated as a single command.
    #
    # Throws UNTERMINATED if it finds an unterminated command.

    typemethod scriptsplit {script {firstline 1}} {
        # FIRST, split the script into lines and initialize the line counter
        set lc $firstline
        set lines [split $script "\n"]
        set result [dict create]

        # Decrement lc so that when we increment after getting the
        # first line, we get the right value
        incr lc -1
        while {[llength $lines] > 0} {
            set line [lshift lines]
            incr lc

            set tline [string trim $line]

            if {$tline eq ""} {
                # Skip blank lines.
                continue
            }

            if {[string match "\#*" $tline]} {
                # Skip normal comments.
                continue
            }

            # At this point we've got a command on this line.
            # Now, grab the whole command.

            set cmd $line
            set firstCmdLine $lc
            while {![IsComplete $cmd]} {
                if {[llength $lines] == 0} {
                    throw [list UNTERMINATED $firstCmdLine] \
                        "Unterminated command in script"
                }

                set line [lshift lines]
                incr lc
                append cmd "\n$line"
            }

            dict set result $firstCmdLine [string trim $cmd]
        }

        return $result
    }

    # IsComplete cmd
    #
    # cmd   - A full or partial command
    #
    # The command is complete if [info complete] is true
    # AND if it doesn't end with a backslash.

    proc IsComplete {cmd} {
        set last [string index $cmd end]
        expr {[info complete $cmd] && $last ne "\\"}
    }


    # cmdsplit cmd ?num?
    #
    # cmd - A single Tcl command
    # num - The line number where the command begins; defaults to 1
    #
    # Splits a single Tcl command string into its component words, 
    # returning a list of two items: the list of command words,
    # and the list of starting line numbers for each word.
    #
    # The task is complicated because this is intended for use
    # with unevaluated scripts, where a single command might not
    # have list syntax because of interpolated commands.

    typemethod cmdsplit {cmd {num 1}} {
        set tokens [GetCommandTokens $cmd]

        set lineCounter $num
        set words [list]
        set nums [list]

        set word ""

        while {[llength $tokens] > 0} {
            set next [lshift tokens]

            if {$word eq "" && [string first ";#" $next] == 0} {
                # Skip end-line comment.
                break;
            }

            # Skip continuation characters, but increment line numbers.
            if {$next eq "\\\n"} {
                incr lineCounter
                continue
            }
            
            append word " " $next

            if {[info complete $word]} {
                set word [string trim $word]

                # skip extraneous blanks
                if {$word ne ""} {
                    lappend words $word
                    lappend nums $lineCounter
                    set len [LineCount $word]
                    set lineCounter [expr {$lineCounter + $len - 1}]
                }
                set word ""
            }
        }

        if {$word ne ""} {
            # This shouldn't happen, as the caller should pass us only
            # valid commands.
            error "bad command \"$cmd\""
        }

        return [list $words $nums]
    }

    # GetCommandTokens command
    #
    # command  - A full, possibly multi-line command
    #
    # Returns a list of individual tokens, eliminating empty
    # tokens and putting separating end-of-line backslashes from
    # the token to which they are attached.

    proc GetCommandTokens {command} {
        set tokens [list]

        foreach token [split $command " \t"] {
            # Skip blank tokens
            if {$token eq ""} {
                continue
            }

            # If a token ends with a continuation, save it as
            # two tokens.
            if {[string range $token end-1 end] eq "\\\n"} {
                set code [string range $token 0 end-2]
                lappend tokens $code "\\\n"
            } else {
                lappend tokens $token
            }
        }

        return $tokens
    }


    # LineCount string
    # 
    # string - A string
    #
    # Returns the number of lines in the string.

    proc LineCount {string} {
        return [llength [split $string \n]]
    }

    #-------------------------------------------------------------------
    # Command Syntax Checking

    # check client script ?firstline?
    #
    # client    - A client smartinterp(n)
    # script    - a Tcl script
    # firstline - The line number of the first line in the script.
    #
    # Does a lint check on the script in the context of the client,
    # returning a flat list of line numbers and error messages.  Note 
    # that the same line number can appear multiple times.

    typemethod check {client script {firstline 1}} {
        # FIRST, save the client, since it's used at varying depths.
        set trans(client) $client 

        # NEXT, get a list of the commands defined in the interpreter.
        set trans(validCmds) [$trans(client) eval {info commands}]

        # NEXT, Check the script
        return [$type CheckScript $script $firstline]
    }

    # CheckScript script firstline
    #
    # client    - A client smartinterp(n)
    # script    - a Tcl script
    # firstline - The line number of the first line in the script.
    #
    # Checks a script using the current client.

    typemethod CheckScript {script {firstline 1}} {
        set errlist [dict create]

        # FIRST, split the script into commands.  If there is an unterminated
        # command, scriptsplit will throw UNTERMINATED.
        if {[catch {
            set cdict [$type scriptsplit $script $firstline]
        } result eopts]} {
            lassign [dict get $eopts -errorcode] code lineNumber

            # If it is an UNTERMINATED command, that's a syntax error to
            # report to the user.  Otherwise, it's an unexpected error;
            # rethrow it.
            if {$code eq "UNTERMINATED"} {
                lappend errlist $lineNumber \
                    "Unterminated command"

                return $errlist
            }

            return {*}$eopts $result
        }

        # NEXT, check each command.
        dict for {num fullCommand} $cdict {
            $type CheckOneCommand errlist $num $fullCommand
        }

        # FINALLY, return the accumulated errors, if any.
        return $errlist
    }

    # CheckOneCommand errlistVar num fullCommand
    #
    # errlistVar     - Name of the caller's error list variable
    # num            - The line number on which the command begins.
    # fullCommand    - The full command.
    #
    # Does all checking on this single command.

    typemethod CheckOneCommand {errlistVar num fullCommand} {
        upvar 1 $errlistVar errlist

        # FIRST, are there syntax errors in this specific command?
        set err [$type SynterpCommand $fullCommand]

        if {$err ne ""} {
            lappend errlist $num $err
            return
        }

        # NEXT, split the command into pieces
        lassign [$type cmdsplit $fullCommand $num] \
            words nums

        set cmdname  [lindex $words 0]
        set firstnum [lindex $nums 0]

        # NEXT, if the command name is unknown in the interpreter, 
        # flag it.

        if {[$type CommandIsUnknown $cmdname]} {
            lappend errlist $firstnum \
                "Warning, undefined command: \"$cmdname\""
        }

        # NEXT, check the number of arguments, if there's any point.
        if {![FindSplat $words]} {
            set msg [$type CheckNumArgs $fullCommand $words]

            if {$msg ne ""} {
                lappend errlist $firstnum $msg
                return
            }
        }

        # NEXT, do special handling for control structures.
        set prefix [$type GetPrefix $fullCommand]

        switch -exact -- $prefix {
            "dict for"   { $type CheckDictFor  errlist $words $nums }
            "dict with"  { $type CheckDictWith errlist $words $nums }
            "expr"       { $type CheckExpr     errlist $words $nums }
            "for"        { $type CheckFor      errlist $words $nums }
            "foreach"    { $type CheckForeach  errlist $words $nums }
            "if"         { $type CheckIf       errlist $words $nums }
            "proc"       { $type CheckProc     errlist $words $nums }
            "switch"     { $type CheckSwitch   errlist $words $nums }
            "while"      { $type CheckWhile    errlist $words $nums }
            default      { 
                # Look for interpolated commands in arguments
                foreach word $words num $nums {
                    foreach cmd [$type getembedded $word] {
                        $type CheckOneCommand errlist $num $cmd
                    }
                }
            }
        }
    }

    # CommandIsUnknown word
    #
    # word   - The first word of a command
    #
    # Returns 1 if the command is unknown in the client interpreter,
    # and 0 otherwise.  If the word begins with "$" or "[", we don't
    # know what the command is going to be, so we assume it's known.

    typemethod CommandIsUnknown {word} {
        if {[string index $word 0] in [list \[ \$]} {
            return 0
        }

        return [expr {$word ni $trans(validCmds)}]
    }


    # CheckNumArgs command words
    #
    # command - A full command
    # words   - The command broken into words.
    #
    # Retrieves the siginfo, if any, for this command, and does
    # the argument checking.  Returns the error message if an
    # error is found, and "" otherwise.

    typemethod CheckNumArgs {command words} {
        set siginfo [$trans(client) siginfo $command]

        if {[dict size $siginfo] == 0} {
            return ""
        }

        dict with siginfo {}

        set numCmdWords [llength $prefix]
        set words       [lrange $words $numCmdWords end]
        set numargs     [llength $words]

        if {$numargs < $min || ($max ne "-" && $numargs > $max)} {
            return "wrong # args: should be \"$prefix $argsyn\""
        }

        return
    }

    # GetPrefix words
    #
    # Queries the signature info from the smart interp to get
    # the appropriate command prefix.

    typemethod GetPrefix {cmd} {
        set sdict [$trans(client) siginfo $cmd]

        if {[dict exists $sdict prefix]} {
            return [dict get $sdict prefix]
        } else {
            return ""
        }
    }

    # FindSplat list
    #
    # list   - A list of command arguments
    #
    # Returns 1 if at least one of the arguments begins with the
    # {*} operator, and 0 otherwise.

    proc FindSplat {list} {
        foreach word $list {
            if {[string first "{*}" $word] == 0} {
                return 1
            }
        }

        return 0
    }


    #-------------------------------------------------------------------
    # Checkers for specific commands
    
    # CheckDictFor errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a [dict for] call.

    typemethod CheckDictFor {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        $type BodyChecker errlist [lindex $nums 4] [lindex $words 4]
    }

    # CheckDictWith errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a [dict with] call.

    typemethod CheckDictWith {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        $type BodyChecker errlist [lindex $nums end] [lindex $words end]
    }

    # CheckExpr errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks an [expr] call.

    typemethod CheckExpr {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        # Check only if the expression is braced (i.e., is one
        # word)

        if {[llength $words] > 2} {
            return
        }

        $type ExprChecker errlist [lindex $nums 1] [lindex $words 1]
    }

    # CheckFor errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a for loop, recursing into its body.

    typemethod CheckFor {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        # start
        $type BodyChecker errlist [lindex $nums 1] [lindex $words 1]

        # test
        $type ExprChecker errlist [lindex $nums 2] [lindex $words 2]

        # next
        $type BodyChecker errlist [lindex $nums 3] [lindex $words 3]

        # body
        $type BodyChecker errlist [lindex $nums 4] [lindex $words 4]
    }


    # CheckForeach errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a foreach loop, recursing into its body.

    typemethod CheckForeach {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        # NEXT, could check the command syntax in more detail, but
        # let's not.

        # NEXT, check the body, returning any errors
        $type BodyChecker errlist [lindex $nums end] [lindex $words end]
    }


    # CheckIf errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks an if statement, and recurses into its bodies.

    typemethod CheckIf {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        set lookingFor literal
        set num [lindex $nums 0]
        set counter -1
        set after ""
        while {[llength $words] > 0} {
            set word [lshift words]

            set num  [lshift nums]
            incr counter

            # puts "if: looking for $lookingFor, got word $counter = <$word>"

            if {$lookingFor eq "literal"} {
                switch -exact -- $word {
                    if     -
                    elseif {
                        set after $word
                        set lookingFor expr
                    }

                    else {
                        set after $word
                        set lookingFor body
                    }

                    default {
                        lappend errlist $num \
                            "unexpected token: \"$word\""
                        return $errlist
                    }
                }

                continue
            }

            if {$lookingFor eq "expr"} {
                $type ExprChecker errlist $num $word
                set lookingFor body

                continue
            }

            if {$lookingFor eq "body"} {
                # Skip "then".

                if {$word ne "then"} {
                    $type BodyChecker errlist $num $word
                    set lookingFor literal
                }
                continue
            }
        }

        if {$lookingFor eq "expr"} {
            lappend errlist $num "missing expression after \"$after\""
        } elseif {$lookingFor eq "body"} {
            lappend errlist $num "missing body after \"$after\""
        }
    }

    # CheckProc errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a proc, and recurses into its body.

    typemethod CheckProc {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        # NEXT, could check the arglist.
        # TBD

        # NEXT, check the body, returning any errors
        $type BodyChecker errlist [lindex $nums end] [lindex $words end]
    }

    # CheckSwitch errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a [switch] call.

    typemethod CheckSwitch {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        # FIRST, skip the command itself
        lshift words
        lshift nums

        # NEXT, skip options
        while {[string index [lindex $words 0] 0] eq "-"} {
            lshift words
            lshift nums
        }

        # NEXT, skip the string
        lshift words
        lshift nums

        # NEXT, if there's nothing left, we're done.  If there's
        # one thing left, it's the switch body, which we need to
        # split into words.  Otherwise, it should
        # be a list of cases and bodies.
        if {[llength $words] == 0} {
            return
        }

        if {[llength $words] == 1} {
            lassign [$type SwitchSplitter [lindex $words 0] [lindex $nums 0]] \
                words nums
        }

        # NEXT, every second word is a body.
        foreach {cnum bnum} $nums {case body} $words {
            if {$bnum ne ""} {
                $type BodyChecker errlist $bnum $body
            }
        }
    }

    # SwitchSplitter sbody firstline
    #
    # sbody     - A switch body of cases and bodies
    # firstline - The line number of the first line of the switch body.
    #
    # Splits the switch body into a flat list of words {case case_body ...}
    # and returns two lists, the words and the numbers.

    typemethod SwitchSplitter {sbody firstline} {
        set words [list]
        set nums  [list]

        # FIRST, split the sbody into "commands"; each command is
        # necessary a case and case body.  Remove the braces first.

        set sbody [string range $sbody 1 end-1]

        dict for {num command} [$type scriptsplit $sbody $firstline] {
            # FIRST, split the command into words.
            lassign [$type cmdsplit $command $num] cwords cnums

            lappend words {*}$cwords
            lappend nums {*}$cnums
        }

        return [list $words $nums]
    }

    # CheckWhile errlistVar words nums
    #
    # errlistVar  - Name of the caller's error list variable
    # words       - List of command words
    # nums        - List of word line numbers
    #
    # Checks a while loop, recursing into its body.

    typemethod CheckWhile {errlistVar words nums} {
        upvar 1 $errlistVar errlist

        $type ExprChecker errlist [lindex $nums 1] [lindex $words 1]
        $type BodyChecker errlist [lindex $nums end] [lindex $words end]
    }

    # BodyChecker errlistVar num body
    #
    # errlistVar  - Name of the caller's error list variable
    # num         - The line number of the command whose body this is
    # body        - The script body to check
    #
    # Recursively checks for errors in the body.

    typemethod BodyChecker {errlistVar num body} {
        upvar 1 $errlistVar errlist

        set char [string index $body 0]

        if {$char ni {"\"" "\{"}} {
            return
        }

        set body [string range $body 1 end-1]

        lappend errlist {*}[$type CheckScript $body $num]

        return
    }

    # ExprChecker errlistVar num expr
    #
    # errlistVar  - Name of the caller's error list variable
    # num         - The line number of the command containing this expr
    # expr        - The expression to check
    #
    # Checks for errors in the expression.

    typemethod ExprChecker {errlistVar num expr} {
        upvar 1 $errlistVar errlist

        # FIRST, get the expression by itself.
        set char [string index $expr 0]

        if {$char in {"\"" "\{"}} {
            set expr [string range $expr 1 end-1]
        }


        # NEXT, look for syntax errors
        set msg [$type SynterpExpression $expr]

        if {$msg ne ""} {
            lappend errlist $num $msg
            return
        }

        # NEXT, check interpolated commands
        foreach cmd [$type getembedded $expr] {
            $type CheckOneCommand errlist $num $cmd
        }

        # NEXT, check functions
        foreach command $trans(ulist) {
            # FIRST, skip non-functions, as we've already checked them.
            # 
            # NOTE: we don't check non-functions, i.e., interpolated
            # commands, this way because we can't check for the presence
            # of "{*}" in the results.

            if {![string match "tcl::mathfunc::*" $command]} {
                continue
            }

            # NEXT, check the number of args for the function.
            $type CheckOneFunction errlist $num $command
        }

        return
    }


    # CheckOneFunction errlistVar num command
    #
    # errlistVar  - Name of the caller's error list variable
    # num         - The line number of the command containing the expr
    # command     - The function call as a command
    #
    # Gets signature info, and validates the number of arguments
    # to the function.

    typemethod CheckOneFunction {errlistVar num command} {
        upvar 1 $errlistVar errlist

        # FIRST, get the command name, and the number of arguments.
        # The command name has the form tcl::mathfunc::<funcname>.
        set cmdname [lshift command]
        set numargs [llength $command]
        set func    [namespace tail $cmdname]

        # NEXT, get the siginfo for the function's command.
        set siginfo [$trans(client) siginfo $cmdname]

        if {[dict size $siginfo] == 0} {
            lappend errlist $num "unknown function: ${func}()"
            return
        }

        dict with siginfo {}

        if {$numargs < $min || ($max ne "-" && $numargs > $max)} {
            set call ${func}([join $argsyn ,])
            lappend errlist $num \
            "error in function ${func}(), wrong # args, should be \"$call\""
        }
    }

    #-------------------------------------------------------------------
    # Syntax Interpreter
    

    # SynterpReset
    #
    # Creates an interpreter in which to do syntax checks.  The synterp
    # is an interpreter that's empty of commands, except for "unknown",
    # which is specially defined.

    typemethod SynterpReset {} {
        # FIRST, destroy the existing interpreter if need be.
        if {$synterp ne ""} {
            interp delete $synterp
        }

        # NEXT, create a new slave interpreter
        set synterp [interp create -safe ${type}::synterp]

        # NEXT, hide all of the commands.
        # TBD: We might want to hide commands in namespaces as well.
        foreach cmd [$synterp eval {info commands}] {
            $synterp hide $cmd
        }

        foreach cmd [$synterp invokehidden info commands tcl::mathfunc::*] {
            $synterp invokehidden rename $cmd ""
        }

        # NEXT, insert a null unknown handler.
        $synterp alias unknown $type SynterpUnknown

        # NEXT, clear the ulist.
        set trans(ulist) [list]
    }

    # SynterpUnknown args
    #
    # An unknown command that saves unknown commands and returns 1.

    typemethod SynterpUnknown {args} {
        lappend trans(ulist) $args
        return 1
    }    

    # SynterpCommand command
    #
    # Checks the syntax of the command.  Returns an error message, or
    # "" if no error is found.  Does not worry about whether the 
    # commands or variables actually exist.

    typemethod SynterpCommand {command} {
        # FIRST, reset the interp
        $type SynterpReset

        while {
            [catch {$synterp eval $command} result eopts]
        } {
            switch -regexp -matchvar match -- $result {
                {^can't read "(.*)": no such variable$} {
                    lassign $match dummy varname
                    $synterp invokehidden set $varname ""
                }

                default {
                    return $result
                }
            }
        }
    }
    
    # SynterpExpression expression
    #
    # expression  - A Tcl expression
    #
    # Checks the syntax of the expression.  Returns an error message, or
    # "" if no error is found.  Does not worry about whether the 
    # commands or variables actually exist.

    typemethod SynterpExpression {expression} {
        # FIRST, reset the interp
        $type SynterpReset

        while {
            [catch {$synterp invokehidden expr $expression} result eopts]
        } {
            switch -regexp -matchvar match -- $result {
                {^can't read "(.*)": no such variable$} {
                    lassign $match dummy varname
                    $synterp invokehidden set $varname 1
                }

                default {
                    # At this point we either have a real syntax error,
                    # or the expression is syntactically correct but
                    # we have an arithmetic error.  We cannot assess
                    # the validity of arithmetic errors here, so we'll
                    # ignore them.  Either way, we've done all we can.

                    set code [dict get $eopts -errorcode]

                    if {[string match "ARITH *" $code]} {
                        return ""
                    } else {
                        # It's a real error; return it.
                        return [normalize $result]
                    }
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Expander for retrieving interpolated command strings


    # ExpanderEvalCmd macro 
    #
    # macro  - An interpolated command in a command argument.
    #
    # Saves the command in the interpolated commands list.

    proc ExpanderEvalCmd {macro} {
        lappend trans(ilist) $macro

        # We don't really care about the return value; but if we do it
        # this way we get the original input back again.
        return \[$macro\]
    }

    # getembedded arg
    #
    # arg    - A command argument
    #
    # Returns a list of the interpolated commands in this argument.

    typemethod getembedded {arg} {
        if {$expander eq ""} {
            set expander [textutil::expander ${type}::expander]
            $expander evalcmd [myproc ExpanderEvalCmd] 
        }

        set trans(ilist) [list]
        $expander expand $arg
        return $trans(ilist)
    }

    
}




