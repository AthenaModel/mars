#-----------------------------------------------------------------------
# TITLE:
#    htmlviewer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n): HTML Viewer based on Tkhtml3 widget
#
#-----------------------------------------------------------------------

namespace eval ::marsgui:: {
    namespace export htmlviewer
}

snit::widgetadaptor ::marsgui::htmlviewer {
    #-------------------------------------------------------------------
    # Lookup tables

    # default CSS styles; these are added to the Tkhtml 3 widget's own
    # default styles.
    typevariable defStyles {
        /* Links */
        A[href] {
            color: black;
            text-decoration: none;
        }

        A[href]:link {
            color: blue;
            text-decoration: none;
        }

        A[href]:visited {
            color: purple;
            text-decoration: none;
        }

        /* Image Padding. 
        ** Left and right aligned images get no padding at the top because
        ** they usually appear at the beginning of paragraphs. */

        IMG[align="center"] {
            padding-top:    0.4em;
            padding-bottom: 0.4em;
            
        }

        IMG[align="left"] {
            padding-top:    0em;
            padding-right:  1em;
            padding-bottom: 0.4em;
        }

        IMG[align="right"] {
            padding-top:    0em;
            padding-left:   1em;
            padding-bottom: 0.4em;
        }

        /* Inline image */
        IMG[align="middle"] {
            vertical-align: middle;
        }

        /* Form input elements */
        INPUT {
            border: 0px;
            vertical-align: middle;
        }
        
        INPUT[type="text"] {
            border: 0px;
            vertical-align: middle;
        }
        
        
        INPUT[type="submit"] {
            border: 0px;
            padding: 0px;
        }

        /* Object elements */
        OBJECT {
            vertical-align: middle;
        }

        /* List indentation */
        OL, UL, DD {
            padding-left: 1em;
        }

        /* Spans for different entity states */

        SPAN.disabled {
            text-decoration: line-through;
            color: #999999;
        }

        SPAN.invalid {
            text-decoration: line-through;
            color: #C7001B;
        }

        SPAN.error {
            color: #C7001B;
        }

        /* Table Formatting Classes: "pretty" 
         * Border around the outside, even/odd striping, no internal
         * border lines.
         */
        TABLE.pretty {
            border: 1px solid black;
            border-spacing: 0;
        }

        TABLE.pretty TR.header {
            font-weight: bold;
            color: white;
            background-color: #000099;
        }

        TABLE.pretty TR.oddrow {
            color: black;
            background-color: white;
        }

        TABLE.pretty TR.evenrow {
            color: black;
            background-color: #EEEEEE;
        }
    }

    #-------------------------------------------------------------------
    # Type Variables

    # tinfo: Type Info Array
    #
    # The following items are keyed to a specific instance, and are
    # used by the standard widget bindings.
    # 
    # sweep-$w    - The "node -index" of the start of the selection,
    #               while sweeping out a selection.
    # start-$w    - The "node -index" of the start of a completed 
    #               selection. 
    # end-$w      - The "node -index" of the end of a completed selection.
    # href-$w     - Value of a[href] when hovering over an <a> tag,
    #               and "" otherwise.
    # src-$w      - Value of img[src] when hovering over an <img> tag,
    #               and "" otherwise.

    typevariable tinfo -array {}

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # FIRST, define the bindings needed by Tkhtml 3
        bind Html <ButtonPress-1>   [myproc ButtonPress-1 %W %x %y]
        bind Html <Motion>          [myproc Motion %W %x %y]
        bind Html <ButtonRelease-1> [myproc ButtonRelease-1 %W %x %y]

        bind Html <Key-Down>        {%W yview scroll  1 units}
        bind Html <Key-Up>          {%W yview scroll -1 units}
        bind Html <Key-Next>        {%W yview scroll  1 pages}
        bind Html <Key-Prior>       {%W yview scroll -1 pages}
        bind Html <Key-Home>        {%W yview moveto 0}
        bind Html <Key-End>         {%W yview moveto 1}
        bind Html <Left>            {%W xview scroll -1 units}
        bind Html <Right>           {%W xview scroll  1 units}

        bind Html <<Copy>>          [myproc Copy %W]
    }

    #-------------------------------------------------------------------
    # Standard Binding Procs

    # ButtonPress-1 w x y
    #
    # w     - The htmlviewer3 widget (%W)
    # x,y   - The %x,%y mouse coordinates
    #
    # Handles mouse clicks in the window.  In particular, it:
    #
    # * Sets the focus to this window
    # * Clears any old selection, including one being swept out.
    # * Calls the -hyperlinkcmd, if they clicked on a link
    # * Begins a new selection.

    proc ButtonPress-1 {w x y} {
        # FIRST, this window should have the focus.
        focus $w

        # NEXT, clear any old selection.
        $w tag delete selection
        set tinfo(sweep-$w) {}
        set tinfo(start-$w) {}
        set tinfo(end-$w)   {}
        
        # NEXT, Did they click on a link?
        set node [GetNodeWithAttr a href $w $x $y]

        if {$node ne ""} {
            callwith [$w cget -hyperlinkcmd] [$node attribute href]
            return
        }

        # NEXT, Begin to sweep out a new selection.
        set tinfo(sweep-$w) [$w node -index $x $y]
    }

    # Motion w x y
    #
    # w     - The htmlviewer3 widget (%W)
    # x,y   - The %x,%y mouse coordinates
    #
    # Handles mouse motion.  In particular:
    #
    # * When sweeping out a selection, extends the selection to the new
    #   index.  
    # * Sets the mouse cursor 
    # * Calls the -hovercmd.

    proc Motion {w x y} {
        # FIRST, continue sweeping out any selection
        if {$tinfo(sweep-$w) ne ""} {
            ExtendSelection $w $x $y
        }

        # NEXT, Are we hovering over a link?  If so, and it's a new link,
        # call -hovercmd.
        set node [GetNodeWithAttr a href $w $x $y]

        if {$node ne ""} {
            # FIRST, set the cursor to a hand
            [winfo toplevel $w] configure -cursor hand2

            # NEXT, get the link URL
            set href [$node attribute href]

            if {$href ne $tinfo(href-$w)} {
                set tinfo(href-$w) $href
                callwith [$w cget -hovercmd] href $href
            }
            return
        }

        # NEXT, Are we hovering over an image?  If so, and it's a
        # new image, call -hovercmd.
        set node [GetNodeWithAttr img src $w $x $y]

        if {$node ne ""} {
            set src [$node attribute src]

            if {$src ne $tinfo(src-$w)} {
                set altText [$node attribute -default "" alt]
                set tinfo(src-$w) $src
                callwith [$w cget -hovercmd] image [list $altText $src]
            }

            return
        }

        # NEXT, We aren't hovering over anything of interest.
        [winfo toplevel $w] configure -cursor {}

        if {$tinfo(href-$w) ne "" ||
            $tinfo(src-$w) ne ""
        } {
            set tinfo(href-$w) ""
            set tinfo(src-$w)  ""
            callwith [$w cget -hovercmd] "" ""
        }

        return
    }

    # ButtonRelease-1 w x y
    #
    # w     - The htmlviewer3 widget (%W)
    # x,y   - The %x,%y mouse coordinates
    #
    # Completes a selection, if any is in progress.

    proc ButtonRelease-1 {w x y} {
        # FIRST, are we sweeping out a selection?  If so, extend it.
        if {$tinfo(sweep-$w) ne ""} {
            ExtendSelection $w $x $y
        }

        # NEXT, either way, we're not sweeping out a selection now.
        set tinfo(sweep-$w) ""
    }

    # Copy w
    # 
    # w     - The htmlviewer3 widget (%W)
    #
    # Copies the current selection, if any, to the clipboard.

    proc Copy {w} {
        # FIRST, ignore empty selections
        if {$tinfo(start-$w) eq ""} {
            return
        }

        # NEXT, get the text offsets of the start and end of the
        # selection.
        set soff [$w text offset {*}$tinfo(start-$w)]
        set eoff [$w text offset {*}$tinfo(end-$w)]

        # NEXT, get the selected text.  Note that the order in which
        # they swept the text matters.
        if {$soff < $eoff} {
            incr eoff -1
            set text [string range [$w text text] $soff $eoff]
        } else {
            incr soff -1
            set text [string range [$w text text] $eoff $soff]
        }

        # NEXT, save it to the clipboard.
        clipboard clear -displayof $w
        clipboard append -displayof $w $text
    }


    #-------------------------------------------------------------------
    # Helper Functions used in Binding Procs

    # GetNodeWithAttr elem attr w x y
    #
    # elem  - An HTML element tag, e.g., "a"
    # attr  - An HTML element attribute, e.g., "href".
    # w     - The htmlviewer3 widget (%W)
    # x,y   - The %x,%y mouse coordinates
    #
    # If there's an $elem node with a $attr attribute enclosing the mouse 
    # position, return its node id.

    proc GetNodeWithAttr {elem attr w x y} {
        # Look at all the nodes at that x,y
        foreach n [$w node $x $y] {
            # And look at their parents as well
            for {set m $n} {$m ne ""} {set m [$m parent]} {
                if {[$m tag] eq $elem &&
                    [$m attribute -default "" $attr] ne ""
                } {
                    return $m
                }
            }
        }

        return ""
    }

    # ExtendSelection
    #
    # w     - The htmlviewer3 widget (%W)
    # x,y   - The %x,%y mouse coordinates
    #
    # Extends the selection to x,y.  Requires that we're sweeping
    # out a selection.  Returns the "node -index" corresponding to x,y.

    proc ExtendSelection {w x y} {
        # Get new end point.  If it's outside the widget, ignore it.
        set endNI [$w node -index $x $y]

        if {$endNI eq ""} {
            # Mouse pointer is outside the widget.  In my experience,
            # this means that it's before the beginning of the widget,
            # but I can't depend on that.  So just ignore it; to select
            # data in the widget, they need to be a little more precise.
            return
        }

        # Clear old selection and add new selection.
        set tinfo(start-$w) $tinfo(sweep-$w)
        set tinfo(end-$w) $endNI

        $w tag delete selection
        $w tag add selection {*}$tinfo(start-$w) {*}$tinfo(end-$w)

        # Make it look right
        # TBD: These should be configurable, or set according
        # to the current ttk::theme.
        $w tag configure selection \
            -foreground black \
            -background cyan

        return $endNI
    }

    #===================================================================
    # Instance Code

    #-------------------------------------------------------------------
    # Options

    # Wraps tkhtml3
    delegate option * to hull
    delegate method * to hull

    # -hyperlinkcmd command
    #
    # Command to be called when a link is clicked.  Takes one 
    # additional argument, the URL to link to.

    option -hyperlinkcmd \
        -default {}

    # -hovercmd command
    #
    # Command to be called when the mouse hovers over a link or
    # image.  The command takes two additional arguments, "href|image"
    # and the URL value.  When the mouse is no longer hovering, this
    # is called with an empty string as the object type.

    option -hovercmd \
        -default {}

    # -isvisitedcmd command
    #
    # Command to be called when an a[href] node is parsed.  It is passed
    # one argument, an href, and should return 1 if the URL has already been
    # visited and 0 otherwise.

    option -isvisitedcmd \
        -default {}
    
    # -styles css
    #
    # Specifies additional styles to be used as defaults by the widget, 
    # overriding the widget defaults (but not an <style>...</style> 
    # scripts in the input).  Changes to this option take places on
    # the next [$hv set].

    option -styles \
        -default {}

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    # styleCounter - Counter used to name CSS scripts included in the
    #                HTML input.

    variable info -array {
        styleCounter 0
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the Tkhtml 3 widget and configure the creation
        # arguments.
        installhull [html $win \
                         -fonttable {7 8 9 10 12 14 16}]
        $self configurelist $args

        # NEXT, install the CSS stylesheet handler
        $hull handler script style [mymethod Handler_style]

        # NEXT, install the link watcher
        $hull handler node a [mymethod Handler_a]

        # NEXT, bind to <MouseWheel> events in the document
        bind $win.document <MouseWheel> [mymethod MouseWheel %D]

        # NEXT, prepare for the bindings to fire.
        set tinfo(href-$win)  {}
        set tinfo(src-$win)   {}

        $self reset
    }

    #------------------------------------------------------------------
    # Event Bindings

    # MouseWheel d
    #
    # d  - amount of scroll in the mouse wheel event
    #
    # Scrolls the window in response to MouseWheel events.

    method MouseWheel {d} {
        $win yview scroll [expr -$d/120] units
    }

    #-------------------------------------------------------------------
    # Node Handlers
    #
    # Tkhtml lets you define handlers for the various HTML node types.

    # Handler_style adict css
    #
    # adict    - Dictionary of element attributes (ignored)
    # css      - The body of the style sheet.
    #
    # Gives the style sheet to the HTML widget so that it takes
    # effect.  Without this handler, the CSS text is displayed in the 
    # body of the page, with no other effect.

    method Handler_style {adict css} {
        # Each style sheet added needs an ID, so that they can
        # be applied in order.
        set id [format "author.%.4d.9999" [incr info(styleCounter)]]
        $hull style -id $id $css
    }

    # Handler_a node
    #
    # node   - Node handle
    #
    # If the node has a non-empty href, sets the "link" or the 
    # "visited" attribute.

    method Handler_a {node} {
        # FIRST, does it have an href?
        set href [$node attribute -default "" href]
        
        if {$href eq ""} {
            return
        }

        # NEXT, find out if it's visited or not.
        if {$options(-isvisitedcmd) ne "" &&
            [{*}$options(-isvisitedcmd) $href]
        } {
            set flag visited
        } else {
            set flag link
        }

        $node dynamic set $flag
    }

    #-------------------------------------------------------------------
    # Public Methods

    # reset
    #
    # Clears the browser, halting any on-going interactions.

    method reset {} {
        set tinfo(sweep-$win) {}
        set tinfo(start-$win) {}
        set tinfo(end-$win)   {}

        $hull reset
    }

    # set html
    #
    # html    An HTML-formatted text string
    #
    # Displays the HTML text, replacing any previous contents.
    # To clear the widget, set it to "".
    
    method set {html} {
        # FIRST, clear the previous contents.
        $self reset

        # NEXT, add the default styles we prefer, on top of the
        # widget's own defaults.
        $hull style -id agent.0001.9999 $defStyles

        # NEXT, add the client's default styles.
        if {$options(-styles) ne ""} {
            $hull style -id agent.0002.9999 $options(-styles)
        }

        # NEXT, if there's any HTML data, display it.
        if {$html ne ""} {
            $hull parse -final $html
        }
    }

    # setanchor anchor
    #
    # anchor - An internal link anchor ID
    #
    # Scrolls to the given anchor.

    method setanchor {anchor} {
        set node [$hull search "a\[name=\"$anchor\"\]"]

        if {$node ne ""} {
            $hull yview $node
        } else {
            $hull yview moveto 0.0
        }
    }
}
