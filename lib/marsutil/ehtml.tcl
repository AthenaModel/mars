#-----------------------------------------------------------------------
# TITLE:
#    ehtml.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsutil(n) Package: ehtml processor
#
#    This module customizes a textutil::expander object to 
#    process ehtml.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export ehtml
}

#-----------------------------------------------------------------------
# ehtml ensemble

snit::type ::marsutil::ehtml {
    #-------------------------------------------------------------------
    # Components

    component interp ;# The smartinterp for macros

    delegate method alias       to interp
    delegate method ensemble    to interp
    delegate method eval        to interp
    delegate method proc        to interp
    delegate method smartalias  to interp

    component exp    ;# The textutil::expander

    delegate method cget        to exp
    delegate method cis         to exp
    delegate method cname       to exp
    delegate method cpop        to exp
    delegate method cpush       to exp
    delegate method cset        to exp
    delegate method cvar        to exp
    delegate method errmode     to exp
    delegate method lb          to exp
    delegate method rb          to exp
    delegate method setbrackets to exp
    delegate method where       to exp

    #-------------------------------------------------------------------
    # Type Variables

    # info Array, for scalars
    #
    #  pass      The pass number, 1 or 2 (while expanding, only)
    #  xrefhook  Called with xref ID for unknown xrefs.

    variable info -array {
        pass     1
        xrefhook {}
    }

    # xreflinks Array: Predefined cross-references.  The index
    # is the link "ID", as given to xrefset.  The
    # data is a dictionary with the following elements:
    #
    #    id        The ID
    #    anchor    The anchor text
    #    url       The URL to link to

    variable xreflinks

    # manroots Array: Allows easy links to man pages via the "xref"
    # macro.
    #
    # Keys are "<root>:<section>" and values are base URLs, e.g.,
    #
    #     mars:n --> mars/mann

    variable manroots

    #-------------------------------------------------------------------
    # Constructor

    # constructor
    #
    # Initialize the object.

    constructor {} {
        # FIRST, create the expander
        install exp using textutil::expander ${selfns}::exp

        # NEXT, create the smartinterp
        $self InitializeInterpreter

        # NEXT, macros appear in double angle-brackets.
        $exp setbrackets "<<" ">>"

        # NEXT, macros are evaluated in the smartinterp.
        $exp evalcmd [list $interp eval]
    }

    #-------------------------------------------------------------------
    # Public Methods

    # clear
    #
    # Re-initializes the interpreter.

    method clear {} {
        $interp destroy
        set interp ""

        $self InitializeInterpreter
    }

    # InitializeInterpreter
    #
    # Creates and initializes the macro interpreter.

    method InitializeInterpreter {} {
        # FIRST, create the interpreter
        install interp using smartinterp ${selfns}::interp \
            -cli     no  \
            -trusted yes

        # NEXT, Basic Macros.
        $interp smartalias hrule 0 0 {} \
            [myproc hrule]

        $interp smartalias lb 0 0 {} \
            [myproc lb]

        $interp smartalias link 1 2 {url ?anchor?} \
            [myproc link]

        $interp smartalias nbsp 1 1 {text} \
            [myproc nbsp]

        $interp smartalias quote 1 1 {text} \
            [myproc quote]

        $interp smartalias rb 0 0 {} \
            [myproc rb]

        $interp smartalias xref 1 2 {id ?anchor?} \
            [mymethod xref]

        $interp smartalias xrefset 3 3 {id anchor url} \
            [mymethod xrefset]

        # NEXT, Macro definitions
        $interp proc swallow {body} {
            uplevel 1 $body
            return
        }

        # This is just template(n)'s "template" command
        # TODO: Add "import" command to smartinterp(n), to pull in a
        # proc's definition.
        $interp proc macro {name arglist initbody {template ""}} {
            # FIRST, have we an initbody?
            if {"" == $template} {
                set template $initbody
                set initbody ""
            }

            # NEXT, define the body of the new proc so that the initbody, 
            # if any, is executed and then the substitution is 
            set body "$initbody\n    tsubst [list $template]\n"

            # NEXT, define
            uplevel 1 [list proc $name $arglist $body]
            return
        }

        # This is just template(n)'s "tsubst" command.
        $interp proc tsubst {tstring} {
            # If the string begins with the indent mark, process it.
            if {[regexp {^(\s*)\|<--[^\n]*\n(.*)$} $tstring dummy leader body]} {

                # Determine the indent from the position of the indent mark.
                if {![regexp {\n([^\n]*)$} $leader dummy indent]} {
                    set indent $leader
                }

                # Remove the ident spaces from the beginning of each indented
                # line, and update the template string.
                regsub -all -line "^$indent" $body "" tstring
            }

            # Process and return the template string.
            return [uplevel 1 [list subst $tstring]]
        }

        # NEXT, Change Log macros
        $interp smartalias changelog 0 0 {} \
            [mymethod Macro changelog]

        $interp smartalias change 3 3 {date status initiator} \
            [mymethod Macro change]

        $interp smartalias /change 0 0 {} \
            [mymethod Macro /change]

        $interp smartalias /changelog 0 0 {} \
            [mymethod Macro /changelog]

        # NEXT, Procedure macros
        $interp smartalias procedure 0 0 {} \
            [mymethod Macro procedure]

        $interp smartalias step 0 0 {} \
            [mymethod Macro step]

        $interp smartalias /step/ 0 0 {} \
            [mymethod Macro /step/]

        $interp smartalias /step 0 0 {} \
            [mymethod Macro /step]

        $interp smartalias /procedure 0 0 {} \
            [mymethod Macro /procedure]
    }

    # expand text
    #
    # text    A text string
    #
    # Expands a text string in two passes.

    method expand {text} {
        # Pass 1 -- for indexing
        set info(pass) 1
        $exp expand $text

        # Pass 2 -- for output
        set info(pass) 2
        return [$exp expand $text]
    }

    # expandFile name
    #
    # name    An input file name
    #
    # Process a file and return the expanded output.

    method expandFile {name} {
        $self expand [readfile $name]
    }

    # pass
    #
    # Returns the current pass number

    method pass {} {
        return $info(pass)
    }

    # textToID text
    #
    # Converts a generic string to an ID string.  Leading and trailing
    # whitespace and internal punctuation is removed, internal whitespace
    # is converted to "_", and the text is converted to lower case.
    
    method textToID {text} {
        # First, trim any white space and convert to lower case
        set text [string trim [string tolower $text]]
        
        # Next, substitute "_" for internal whitespace, and delete any
        # non-alphanumeric characters (other than "_", of course)
        regsub -all {[ ]+} $text "_" text
        regsub -all {[^a-z0-9_/]} $text "" text
        
        return $text
    }


    #-------------------------------------------------------------------
    # Cross-Reference Management

    # xrefhook ?hook?
    #
    # hook     An xref hook command
    #
    # Sets/queries the xrefhook.  The hook is a command that takes
    # two additional arguments, the xref ID and the optional anchor
    # text.  It returns a list of the URL and the default anchor
    # text for the reference; or a list of two empty strings if
    # it can't relate the ID to anything.

    method xrefhook {args} {
        # TBD: Define wrongNumArgs!
        if {[llength $args] > 1} {
            error "wrong \# args: should be \"$type xrefhook ?hook?\""
        }
        
        if {[llength $args] == 1} {
            set info(xrefhook) [lindex $args 0]
        }

        return $info(xrefhook)
    }

    # xrefset id anchor url
    #
    # id        Name to be used in <<xref ...>> macro
    # anchor    The text to be displayed as an anchor
    # url       The URL to link to.
    #
    # Define an ad-hoc cross reference.
    method xrefset {id anchor url} {
        set xreflinks($id) [dict create id $id anchor $anchor url $url]
        
        # Return nothing, so that this can be used in macros.
        return ""
    }

    # xref id ?anchor?
    #
    # id       The XREF id of the page to link to
    # anchor   The anchor text, if different
    #
    # Links to some cross-referenced page.  The "id" may be
    # any ID entered using xrefset.  If the ID is unrecognized,
    # the xrefhook is called.

    method xref {id {anchor ""}} {
        if {$info(pass) == 1} {
            return
        }

        set url ""

        # FIRST, is it an explicit xrefset.
        if {[info exists xreflinks($id)]} {
            set url [dict get $xreflinks($id) url]
            set defaultAnchor [dict get $xreflinks($id) anchor]
        } 

        # NEXT, is it a man page?
        if {$url eq "" &&
            [regexp {^([^:]+:)?([^()]+)\(([1-9a-z]+)\)$} $id \
                 dummy root name section]
        } {
            set root [string trim $root ":"]

            set pattern ""

            if {[info exists manroots($root:$section)]} {
                set pattern $manroots($root:$section)
            } elseif {[info exists manroots($root:)]} {
                set pattern $manroots($root:)
            } 

            if {$pattern ne ""} {
                set url [string map [list %s $section %n $name] $pattern]

                if {$anchor ne ""} {
                    append url "#[$self textToID $anchor]"
                }

                set defaultAnchor "${name}($section)"
            }
        }

        # NEXT, can the xrefhook look it up?
        if {$url eq "" && $info(xrefhook) ne ""} {
            lassign [{*}$info(xrefhook) $id $anchor] url defaultAnchor
        }

        if {$url eq ""} {
            # TBD: This is ugly; need a mechanism for this kind
            # of reporting.
            puts "Warning: xref: unknown id '$id'"
            return "[$exp lb]xref $id[$exp rb]"
        }
        
        if {$anchor eq ""} {
            set anchor $defaultAnchor
        }

        return "<a href=\"$url\">$anchor</a>"
    }

    #-------------------------------------------------------------------
    # Man Page Access
    #
    # Man pages are accessed as "[<root>:]<name>(<section>)"
    # If no <root> is specified, then the default root, "", is used.
    # If no manroot command is called, then man page references are
    # not looked up.

    # manroots roots
    #
    # roots    A list of man page root names and URL patterns.
    #
    # Adds the roots to the set of manpage roots.  Each root is
    # specified as follows:
    #
    #    [<root>]:[<section>] <pattern>
    #
    # The pattern is a URL into which the following substitutions 
    # can be made:
    #
    #    %s   The section, e.g., "n"
    #    %n   The man page name, e.g., "ehtml".
    #
    # If <root> is omitted, then the patternUrl is for the default root,
    # i.e., for man page references in which no root is specified.
    #
    # If <section> is omitted, then the pattern is for any section.
    #
    # TODO: Make this an option

    method manroots {roots} {
        foreach {spec pattern} $roots {
            if {![string match "*:*" $spec]} {
                error "Invalid root specification: \"$spec\""
            }

            lassign [split $spec :] root section

            set manroots($root:$section) $pattern
        }
    }
    
    #-------------------------------------------------------------------
    # Basic Macros

    # lb
    #
    # Returns the left macro bracket, quoted for output.

    proc lb {} {
        return "&lt;&lt;"
    }

    # rb
    #
    # Returns the right macro bracket, quoted for output.

    proc rb {} {
        return "&gt;&gt;"
    }

    # nbsp text
    #
    # text    A text string
    #
    # Makes a string nonbreaking, normalizing spaces.

    proc nbsp {text} {
        set text [string trim $text]
        regsub {\s\s+} $text " " text

        return [string map {" " &nbsp;} $text]
    }

    # quote text
    #
    # text    A text string
    #
    # Quotes "<", ">", and "&" characters in text for display
    # in HTML.

    proc quote {text} {
        string map {& &amp; < &lt; > &gt;} $text
    }

    # hrule
    #
    # Horizontal rule

    template proc hrule {} {<p><hr></p>}

    # link url ?anchor?
    #
    # url     The URL to link to
    # anchor  The text to display, if different
    #
    # Creates an HTML link

    template proc link {url {anchor ""}} {
        if {$anchor eq ""} {
            set anchor $url
        }
    } {<a href="$url">$anchor</a>}

    #-------------------------------------------------------------------
    # Change Log Macros

    # changelog
    #
    # Begins a change log 

    template method {Macro changelog} {} {
        variable itemCounter
        set itemCounter 0
    } {
        |<--
        <table class="pretty" width="100%" cellpadding="5" cellspacing="0">
        <tr class="header">
        <th align="left" width="10%">Status</th>
        <th align="left" width="70%">Nature of Change</th>
        <th align="left" width="10%">Date</th>
        <th align="left" width="10%">Initiator</th>
        </tr>
    }

    # /changelog
    #
    # Ends a change log

    template method {Macro /changelog} {} {
        |<--
        </table><p>
    }

    # change date status initiator
    #
    # date       Date of change
    # status     Kind of change
    # initiator  Author of the change.
    #
    # Begins a change entry.  The description appears between
    # <<change>> and <</change>>.

    method {Macro change} {date status initiator} {
        $self cpush change
        $self cset date      [nbsp $date]
        $self cset status    [nbsp $status]
        $self cset initiator [nbsp $initiator]
        return
    }

    # Ends a change entry
    template method {Macro /change} {} {
        variable itemCounter

        if {[incr itemCounter] % 2 == 0} {
            set rowclass evenrow
        } else {
            set rowclass oddrow
        }

        set date      [$self cget date]
        set status    [$self cget status]
        set initiator [$self cget initiator]

        set description [$self cpop change]
    } {
        |<--
        <tr class="$rowclass" valign=top>
        <td>$status</td>
        <td>$description</td>
        <td>$date</td>
        <td>$initiator</td>
        </tr>
    }

    #-------------------------------------------------------------------
    # Procedure Macros
    #
    # <<procedure>>
    #
    # <<step>> 
    # Directions 
    # <</step/>> 
    # Example 
    # <</step>>
    #    ...
    #
    # <</procedure>>

    # procedure
    #
    # Begins a procedure

    template method {Macro procedure} {} {
        variable stepCounter
        set stepCounter 0
    } {
        |<--
        <table border="1" cellspacing="0" cellpadding="2">
    }

    # step
    #
    # Begins a step in a procedure.  The text following the tag
    # should describe what is to be done.  Steps are numbered.
    template method {Macro step} {} {
        variable stepCounter
        incr stepCounter
    } {
        |<--
        <tr valign="top">
        <td><b>$stepCounter.</b></td>
        <td>
    }

    # /step/
    #
    # Ends the description and begins the example.  The text
    # following should give an example of the commands to enter.

    template method {Macro /step/} {} {
        |<--
        </td><td>
    }

    # /step
    #
    # Ends the step.

    template method {Macro /step} {} {
        |<--
        </td>
        </tr>
    }

    # /procedure
    #
    # Ends the procedure
    
    template method {Macro /procedure} {} {
        |<--
        </table border="1" cellspacing="0" cellpadding="2">
    }
    
}














