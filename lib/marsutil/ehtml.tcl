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

# Create the macro namespace ASAP

namespace eval ::marsutil::ehtml::macro {}

snit::type ::marsutil::ehtml {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Components

    typecomponent exp    ;# The textutil::expander

    delegate typemethod cget        to exp
    delegate typemethod cis         to exp
    delegate typemethod cname       to exp
    delegate typemethod cpop        to exp
    delegate typemethod cpush       to exp
    delegate typemethod cset        to exp
    delegate typemethod cvar        to exp
    delegate typemethod errmode     to exp
    delegate typemethod expand      to exp
    delegate typemethod lb          to exp
    delegate typemethod rb          to exp
    delegate typemethod setbrackets to exp
    delegate typemethod where       to exp

    #-------------------------------------------------------------------
    # Type Variables

    # info Array, for scalars
    #
    #  pass      The pass number, 1 or 2 (while expanding, only)
    #  xrefhook  Called with xref ID for unknown xrefs.

    typevariable info -array {
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

    typevariable xreflinks

    # manroots Array: Allows easy links to man pages via the "xref"
    # macro.
    #
    # Keys are "<root>:<section>" and values are base URLs, e.g.,
    #
    #     mars:n --> mars/mann

    typevariable manroots

    #-------------------------------------------------------------------
    # Application Initializer

    # init
    #
    # Initialize the module.

    typemethod init {} {
        # FIRST, create the expander
        set exp [textutil::expander ${type}::exp]

        # NEXT, macros appear in double angle-brackets.
        $exp setbrackets "<<" ">>"

        # NEXT, macros are evaluated in the ::ehtml::macro namespace,
        # which allows macros to be defined such that they don't
        # affect the global namespace.

        $exp evalcmd [list namespace eval ::marsutil::ehtml::macro]

        # NEXT, make ehtml available in the macro namespace
        namespace eval ::marsutil::ehtml::macro {
            namespace import ::marsutil::ehtml
        }
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # import args
    #
    # args     A list of "namespace import" arguments
    #
    # Imports the listed command patterns into the macro namespace

    typemethod import {args} {
        namespace eval ::marsutil::ehtml::macro \
            [list namespace import {*}$args]
    }

    # macro name arglist ?initbody? args
    #
    # Defines a template(n) template in the macro namespace.
    
    typemethod macro {name arglist args} {
        template ${type}::macro::$name $arglist {*}$args
    }

    # expandFile name
    #
    # name    An input file name
    #
    # Process a file and return the expanded output.

    typemethod expandFile {name} {
        set input [readfile $name]

        # Pass 1 -- for indexing
        set info(pass) 1
        $exp expand $input

        # Pass 2 -- for output
        set info(pass) 2
        return [$exp expand $input]
    }

    # pass
    #
    # Returns the current pass number

    typemethod pass {} {
        return $info(pass)
    }

    # textToID text
    #
    # Converts a generic string to an ID string.  Leading and trailing
    # whitespace and internal punctuation is removed, internal whitespace
    # is converted to "_", and the text is converted to lower case.
    
    typemethod textToID {text} {
        # First, trim any white space and convert to lower case
        set text [string trim [string tolower $text]]
        
        # Next, substitute "_" for internal whitespace, and delete any
        # non-alphanumeric characters (other than "_", of course)
        regsub -all {[ ]+} $text "_" text
        regsub -all {[^a-z0-9_/]} $text "" text
        
        return $text
    }

    # nbsp text
    #
    # text    A text string
    #
    # Makes a string nonbreaking, normalizing spaces.

    typemethod nbsp {text} {
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

    typemethod quote {text} {
        string map {& &amp; < &lt; > &gt;} $text
    }

    # hrule
    #
    # Horizontal rule

    template typemethod hrule {} {<p><hr></p>}

    # link url ?anchor?
    #
    # url     The URL to link to
    # anchor  The text to display, if different
    #
    # Creates an HTML link

    template typemethod link {url {anchor ""}} {
        if {$anchor eq ""} {
            set anchor $url
        }
    } {<a href="$url">$anchor</a>}

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

    typemethod xrefhook {args} {
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
    typemethod xrefset {id anchor url} {
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

    typemethod xref {id {anchor ""}} {
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
                    append url "#[ehtml textToID $anchor]"
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

    typemethod manroots {roots} {
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
    # Return the left bracket sequence
    proc macro::lb {} { 
        return [ehtml quote [ehtml lb]]
    }

    # rb
    #
    # Return the right bracket sequence

    proc macro::rb {} { 
        return [ehtml quote [ehtml rb]]
    }


    # nbsp text
    #
    # text    A text string
    #
    # Makes a string nonbreaking, normalizing spaces.

    proc macro::nbsp {text} {
        return [ehtml nbsp $text]
    }

    # hrule
    #
    # Horizontal rule

    proc macro::hrule {} {
        return [ehtml hrule]
    }

    # link url ?anchor?
    #
    # url     The URL to link to
    # anchor  The text to display, if different
    #
    # Creates an HTML link

    proc macro::link {url {anchor ""}} {
        return [ehtml link $url $anchor]
    }

    # xref id ?anchor?
    #
    # id       The XREF id of the page to link to
    # anchor   The anchor text, if different
    #
    # Links to some cross-referenced page.  The "id" may be
    # any ID entered using xrefset.  If the ID is unrecognized,
    # the xrefhook is called.

    proc macro::xref {id {anchor ""}} {
        return [ehtml xref $id $anchor]
    }

    # xrefset id anchor url
    #
    # id        Name to be used in <<xref ...>> macro
    # anchor    The text to be displayed as an anchor
    # url       The URL to link to.
    #
    # Define an ad-hoc cross reference.
    proc macro::xrefset {id anchor url} {
        ehtml xrefset $id $anchor $url
        
        return ""
    }

    #-------------------------------------------------------------------
    # Change Log Macros

    # changelog
    #
    # Begins a change log 

    template proc macro::changelog {} {
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

    template proc macro::/changelog {} {
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

    proc macro::change {date status initiator} {
        ehtml cpush change
        ehtml cset date      [ehtml nbsp $date]
        ehtml cset status    [ehtml nbsp $status]
        ehtml cset initiator [ehtml nbsp $initiator]
        return
    }

    # Ends a change entry
    template proc macro::/change {} {
        variable itemCounter

        if {[incr itemCounter] % 2 == 0} {
            set rowclass evenrow
        } else {
            set rowclass oddrow
        }

        set date      [ehtml cget date]
        set status    [ehtml cget status]
        set initiator [ehtml cget initiator]

        set description [ehtml cpop change]
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

    template proc macro::procedure {} {
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
    template proc macro::step {} {
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

    template proc macro::/step/ {} {
        |<--
        </td><td>
    }

    # /step
    #
    # Ends the step.

    template proc macro::/step {} {
        |<--
        </td>
        </tr>
    }

    # /procedure
    #
    # Ends the procedure
    
    template proc macro::/procedure {} {
        |<--
        </table border="1" cellspacing="0" cellpadding="2">
    }
    
}














