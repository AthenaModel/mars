#-----------------------------------------------------------------------
# FILE: hbarchart.tcl
#   
#   Horizontal Bar Chart Widget
#
# PACKAGE:
#   marsgui(n) -- Mars GUI Infrastructure Package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

namespace eval ::marsgui:: {
    namespace export hbarchart
}

#-------------------------------------------------------------------
# Widget: hbarchart
#
# The hbarchart(n) widget plots one or more series of data values as
# horizontal bars against a set of entities, identified by label 
# strings.
#
# TBD:
#
# - Put layout parameters in a parmset(n).
#
#-----------------------------------------------------------------------

snit::widgetadaptor ::marsgui::hbarchart {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*

        # Create the button icons
        namespace eval ${type}::icon { }

        mkicon ${type}::icon::close {
            XX....XX
            XXX..XXX
            .XXXXXX.
            ..XXXX..
            ..XXXX..
            .XXXXXX.
            XXX..XXX
            XX....XX
        } { . white  X black }

    }

    #-------------------------------------------------------------------
    # Group: Components
    
    # Component: lu
    #
    # lazyupdater(n) which renders the output.

    component lu

    # Component: plot
    #
    # canvas(n) on which the actual data is plotted.

    component plot

    # Component: legend
    # 
    # canvas(n) on which the legend is drawn.
    component legend

    #-------------------------------------------------------------------
    # Group: Options


    delegate option -width          to hull
    delegate option -height         to hull
    delegate option -yscrollcommand to plot

    # Option: -ylabels
    #
    # The labels for the Y-axis.  Each label represents one "entity"
    # for which data will be plotted; thus, each series of data values
    # needs to contain exactly as many values as there labels.

    option -ylabels                                 \
        -type            {snit::listtype -minlen 1} \
        -default         {}                         \
        -configuremethod ConfigAndClear
    
    # Option: -title
    #
    # This is the chart's overall title.  It can be placed at the top
    # or the bottom.

    option -title                        \
        -default         {}              \
        -configuremethod ConfigAndRender

    # Option: -titlepos
    #
    # Title position, *n* or *s*.  The title is centered at the top
    # or bottom of the chart.

    option -titlepos                                \
        -type            {snit::enum -values {n s}} \
        -default         n                          \
        -configuremethod ConfigAndRender

    # Option: -xtext
    #
    # This is the overall label for the X-axis.

    option -xtext                        \
        -default         {}              \
        -configuremethod ConfigAndRender

    # Option: -ytext
    #
    # This is the overall label for the Y-axis.

    option -ytext                        \
        -default         {}              \
        -configuremethod ConfigAndRender

    # Option: -xformat
    #
    # format conversion specifier for formatting X values for display.
    option -xformat                      \
        -default         %.1f            \
        -configuremethod ConfigAndRender


    # Method: ConfigAndRender
    #
    # Saves the option value, and schedules a render timeout.  Used as
    # a -configuremethod for many of the options.
    #
    # Syntax:
    #   ConfigAndRender _opt val_
    #
    #   opt - The option name
    #   val - The new value

    method ConfigAndRender {opt val} {
        set options($opt) $val

        # Render later, when things have settled down.
        $lu update
    }


    # Method: ConfigAndClear
    #
    # Saves the option value, schedules a render timeout,
    # and clears the saved data.
    #
    # Syntax:
    #   ConfigAndClear _opt val_
    #
    #   opt - The option name
    #   val - The new value

    method ConfigAndClear {opt val} {
        $self ConfigAndRender $opt $val

        array unset series
        set series(names) [list]
        set series(min)   ""
        set series(max)   ""
    }

    #-------------------------------------------------------------------
    # Group: Instance Variables

    # Variable: parms
    #
    # This array contains the parameters used to layout the chart.
    # It might eventually be replaced by a parmset(n).
    #
    # chart.maxseries  - Maximum number of bars per entity
    # chart.left       - Left margin, in pixels
    # chart.right      - Right margin, in pixels
    # chart.top        - Top margin, in pixels
    # chart.bottom     - Bottom margin, in pixels
    # chart.fudge      - Fudge width in pixels; used when computing minimum
    #                    chart size.
    #
    # title.pad        - Vertical padding between the title and the 
    #                    next element, in pixels.
    # title.font       - Title font specification.
    #
    # ytext.pad        - Vertical padding between the ytext and the plot 
    #                    proper, in pixels.
    # ytext.font       - Font for the ytext label.
    #
    # xtext.pad        - Vertical padding between the xtext and the
    #                    plot proper, in pixels.
    # xtext.font       - Font for the xtext label.
    #
    # xaxis.pad        - Vertical padding between the X-axis labels and
    #                    the related tick-marks.
    # xaxis.ticklen    - Vertical length of the X-axis tick marks.
    # xaxis.font       - Font used for the X-axis labels.
    #
    # yaxis.pad        - Horizontal pad between the y-axis labels and the
    #                    axis itself, in pixels
    # yaxis.font       - Font used for y-axis labels
    #
    # data.barheight   - Height of each data bar, in pixels.
    # data.mingap      - Minimum vertical gap between successive bar groups
    #                    in pixels.
    # data.maxgap      - Maximum vertical gap between successive bar groups
    # data.color<n>    - Fill color for each data bar,
    #                    0...chart.maxseries.
    #
    # legend.linkfont  - Font for the "Click for Legend" link at the
    #                    top of the chart.
    # legend.linkcolor - Color for the "Click for Legend" link.
    # legend.font      - Font for the label text in the legend window
    #                    itself.
    # legend.gap       - Gap, in pixels, between successive entries in
    #                    the legend window, and between the color
    #                    block and its label text.
    # legend.margin    - Margin, in pixels, between the edge of the
    #                    legend window and its content.

    variable parms -array {
        chart.maxseries  10
        chart.left       5
        chart.right      5
        chart.top        5
        chart.bottom     5
        chart.fudge      100

        title.pad        2
        title.font       {"Nimbus Sans" -16}

        ytext.pad        2
        ytext.font       {"Nimbus Sans" -12}

        xtext.pad        2
        xtext.font       {"Nimbus Sans" -12}

        xaxis.pad        1
        xaxis.ticklen    6
        xaxis.font       {"Nimbus Sans" -10}

        yaxis.font       {"Nimbus Sans" -10}
        yaxis.pad        2

        data.mingap      1
        data.maxgap      10
        data.barheight   10
        data.color0      \#33FFFF
        data.color1      \#006633
        data.color2      \#996633
        data.color3      \#990099
        data.color4      \#3399FF
        data.color5      \#33CC66
        data.color6      \#999900
        data.color7      \#CC6633
        data.color8      \#FF6699
        data.color9      \#9999FF

        legend.linkfont  {"Nimbus Sans" -10 underline}
        legend.linkcolor blue
        legend.font      {"Nimbus Sans" -10}
        legend.gap       5
        legend.margin    6
    }

    # Variable: layout
    #
    # This array contains data pertaining to the current layout.
    #
    #    chartWidth    - The chart width
    #    chartHeight   - The chart height
    #    numSeries     - The number of data series (minimum 1)
    #    pymax         - The y coordinate of the bottom of the data 
    #                    on the plot canvas, in pixels.
    #    pxmin         - The x coordinate of the Y-axis line on the 
    #                    plot canvas; corresponds to xmin in the data.
    #    pybar-$entity - The y coordinate of the top of $entity's 
    #                    bar group on the plot canvas.
    #
    #    cxmin         - The x coordinate of the left edge of the 
    #                    plot area (excluding the left margin).
    #    cxmax         - The x coordinate of the right edge of the plot
    #                    area (excluding the right margin).
    #    cymin         - The y coordinate of the top of the plot
    #                    area on the main canvas.
    #    cymax         - The y coordinate of the bottom of the plot
    #                    area on the main canvas.
    #    xmax          - Maximum x data coordinate
    #    xmin          - Minimum x data coordinate
    #    pxmax         - The x coordinate, in pixels, of xmax in the data.
    #    ppu           - The number of pixels per data unit.

    variable layout -array { }

    # Variable: series
    #
    # This array contains the data for the plotted series.  The keys
    # are as follows.
    #
    #   names       - List of series names, in order of definition.
    #   label-$name - Human readable label for the named series
    #   data-$name  - List of data values for the named series.
    #   bar-$id     - List {ylabel series x} for the specified bar.
    #   rmin-$name  - Value of -rmin for named series, or ""
    #   rmax-$name  - Value of -rmax for named series, or ""
    #   dmin-$name  - Min data value for named series, or "" if -rmin
    #                 is given.
    #   dmax-$name  - Max data value for named series, or "" if -rmax
    #                 is given.

    variable series -array { 
        names {}
    }

    # Variable: info
    #
    # Array of other info about the chart.
    #
    #  plot   - Canvas ID of the plot window
    #  legend - Canvas ID of the legend window

    variable info -array {
        plot   ""
        legend ""
    }

    # Variable: trans
    #
    # Array of transient data; used by event bindings (e.g., drag
    # and drop)

    variable trans -array { }

    #-------------------------------------------------------------------
    # Group: Constructor

    # Constructor: constructor
    #
    # Creates a new instance of hbarchart(n), given the creation 
    # <Options>.

    constructor {args} {
        # FIRST, install the hull.
        installhull using canvas      \
            -background         white \
            -highlightthickness 0     \
            -borderwidth        0

        # NEXT, create the lazy updater
        install lu using lazyupdater ${selfns}::lu \
            -window   $win                         \
            -command  [mymethod Render]

        # NEXT, create the plot canvas and add it to the main canvas.
        # Use the "win" tag, so that we don't delete it later.
        install plot using canvas $win.plot \
            -background         white       \
            -highlightthickness 0           \
            -borderwidth        0

        set info(plot) [$hull create window 0 0 \
                            -tags   win         \
                            -anchor nw          \
                            -window $plot]


        # NEXT, create the legend canvas, positioning it outside the
        # scroll region.
        install legend using canvas $win.legend \
            -background         white           \
            -highlightthickness 0               \
            -borderwidth        1               \
            -relief             solid

        set info(legend) [$hull create window -10 0 \
                              -tags   win           \
                              -anchor ne            \
                              -window $legend]

        # NEXT, let the plot and legend canvases respond to
        # events on the main widget.
        bindtags $plot   [linsert [bindtags $plot]   0 $win]
        bindtags $legend [linsert [bindtags $legend] 0 $win]

        # NEXT, do event bindings.

        # redraw on configure
        bind $win <Configure> [list $lu update]

        $hull   bind legendlink <1> [mymethod PopupLegend]
        $legend bind closer     <1> [mymethod PopdownLegend]

        # Allow plot canvas to be dragged
        bind $plot <ButtonPress-1> {%W scan mark %x %y }
        bind $plot <B1-Motion>     {%W scan dragto %x %y 1}

        # Allow legend to be dragged
        bind $legend <ButtonPress-1>   [mymethod LegendMark %x %y]
        bind $legend <B1-Motion>       [mymethod LegendDrag %x %y]
        bind $legend <ButtonRelease-1> [mymethod LegendDrop]

        # Generate <<Context>>
        bind $win  <3>         [mymethod ContextClick %W %x %y %X %Y]
        bind $win  <Control-1> [mymethod ContextClick %W %x %y %X %Y]
        bind $plot <3>         [mymethod ContextClick %W %x %y %X %Y]
        bind $plot <Control-1> [mymethod ContextClick %W %x %y %X %Y]


        # Allow mouse wheel to scroll the plot widget.  For non-Linux,
        # the <MouseWheel> event is used; for Linux, it's Button-4 and
        # Button-5.
        bind $plot <MouseWheel> {
            if {%D >= 0} {
                %W yview scroll [expr {-%D/3}] pixels
            } else {
                %W yview scroll [expr {(2-%D)/3}] pixels
            }
        }

        bind $plot <Button-5> {%W yview scroll 2 units}
        bind $plot <Button-4> {%W yview scroll -2 units}

        # NEXT, configure the creation options
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Group: Rendering the Chart

    # Method: Render
    #
    # This method renders the chart given the currently available
    # data.

    method Render {} {
        # FIRST, if the legend if visible, get the relative location
        # of its upper right corner.
        if {[$self LegendIsVisible]} {
            lassign [$hull coords $info(legend)] x y
            let fx {$x / $layout(chartWidth)}
            let fy {$y / $layout(chartHeight)}
        }

        # FIRST, clear the canvas and the layout data.
        $hull delete !win
        $plot delete all
        array unset layout

        # NEXT, Render the Y-axis labels into the plot widget.
        $self RenderYAxis

        # NEXT, Render the boilerplate into the main canvas:
        # the title, text labels, and X-axis line (excluding the ticks).
        $self RenderBoilerplate

        # NEXT, Position the plot canvas on the main canvas, and
        # set its scroll region.
        $self PositionPlot

        # NEXT, Compute the X-axis bounds.
        $self ComputeXMinMax

        # NEXT, render the X-axis ticks and labels.
        $self RenderXAxis

        # NEXT, render the data (if any)
        $self RenderBars

        # NEXT, render the legend
        $self RenderLegend

        # NEXT, If we had a legend showing, display it again.
        if {[$self LegendIsVisible]} {
            let x {$fx * $layout(chartWidth)}
            let y {$fy * $layout(chartHeight)}

            $hull coords $info(legend) $x $y
        }
    }

    # Method: RenderYAxis
    #
    # This method renders the Y-axis into the plot canvas 
    # given the configuration options.  It saves the following
    # layout data:
    #
    #  - numSeries
    #  - pymax
    #  - pxmin
    #  - pybar-$ylabel
    #
    # The data consists of 1 or more bar groups, each consisting
    # of one or more bars.  Each bar group must be at least tall
    # enough for the set of bars and for the label text.  When
    # drawn, the label text and the related bars should be
    # vertically centered on the same horizontal line.

    method RenderYAxis {} {
        # FIRST, Determine the bar group height.  This is the maximum
        # of the label height and the height of the bars.
        let layout(numSeries) {max(1, [llength $series(names)])}

        let barHeight {$layout(numSeries)*$parms(data.barheight)}
        set labHeight [font metrics $parms(yaxis.font) -linespace]

        let grpHeight {max($barHeight,$labHeight)}

        # NEXT, compute the offsets from the top of the bar group's
        # bounding box for the midline of the label text and for
        # the top of the first bar.
        let labOffset {$grpHeight/2.0}
        let barOffset {max(0.0, ($grpHeight - $barHeight)/2.0)}

        # NEXT, lay out the labels, saving the Y-coordinate of the
        # upper left corner of each bargroup.  We'll draw the 
        # labels right justified at x = 0, then move them to the 
        # right.

        set pymax 0.0
        set xmin 0.0
        let baseGap {
            min($parms(data.mingap) + $layout(numSeries), $parms(data.maxgap))
        }

        let gap {
            max($baseGap - 2*$barOffset, 0)
        }

        foreach lab $options(-ylabels) {
            # Save the y-coordinate of the upper edge of each bar
            # group.
            let layout(pybar-$lab) {$pymax + $barOffset}

            let pylab {$pymax + $labOffset}

            set id [$plot create text 0.0 $pylab    \
                        -tags    ylabel             \
                        -anchor  e                  \
                        -justify right              \
                        -fill    black              \
                        -font    $parms(yaxis.font) \
                        -text    $lab]

            lassign [$plot bbox $id] x dummy dummy dummy
            
            let xmin {min($xmin, $x)}

            let pymax {$pymax + $grpHeight + $gap}
        }

        # NEXT, move all the ylabels to the right so that they
        # are "on screen"
        
        $plot move ylabel [expr {-$xmin + $parms(chart.left)}] 0.0

        let pxmin {-$xmin + $parms(chart.left) + $parms(yaxis.pad)}
        
        # NEXT, draw the y-axis line
        $plot create line $pxmin 0.0 $pxmin $pymax \
            -fill  black                           \
            -width 1

        # NEXT, save the remaining layout parameters
        set layout(pxmin) $pxmin
        set layout(pymax) $pymax
    }

    # Method: RenderBoilerplate
    #
    # This method renders the title, ytext, xtext, legend hyperlink,
    # and X-axis line into the main canvas.  It saves the following
    # layout data.
    #
    #  - chartWidth
    #  - chartHeight
    #  - cxmin
    #  - cxmax
    #  - cymin
    #  - cymax

    method RenderBoilerplate {} {
        # FIRST, compute the width and height of the chart.  Normally
        # this is the window size, but there are minimums.

        let layout(chartWidth) {
            max([winfo width $win], $layout(pxmin) + $parms(chart.fudge))
        }

        let layout(chartHeight) {
            max([winfo height $win], $parms(chart.fudge))
        }

        # NEXT, we work from the outside in.  Get the bounding box
        # for the data area of the main canvas.  Normally, this will
        # simply be the size of the window; but always make it at
        # least big enough for the plot canvas to have some width to
        # draw bars in.
        #
        # The bounding box limits are stored in cx0,cy0, cx1,cy1; 
        # as rendering progresses, these values will be moved inward
        # past previously rendered items.

        set cx0 0
        set cy0 0
        let cx1 $layout(chartWidth)
        let cy1 $layout(chartHeight)

        # NEXT, Render the margins by shrinking the bounding box.
        set cx0 $parms(chart.left)
        set cy0 $parms(chart.top)
        let cx1 {$cx1 - $parms(chart.right)}
        let cy1 {$cy1 - $parms(chart.bottom)}

        # NEXT, if there's a title, lay it out to the top or bottom.
        if {$options(-title) ne ""} {
            let cx {($cx0 + $cx1)/2.0}

            if {$options(-titlepos) eq "n"} {
                # Top
                set id [$hull create text $cx $cy0      \
                            -anchor  n                  \
                            -justify center             \
                            -fill    black              \
                            -font    $parms(title.font) \
                            -text    $options(-title)]

                lassign [$hull bbox $id] dummy dummy dummy cy

                let cy0 {$cy + $parms(title.pad)}
            } else {
                # Bottom
                set id [$hull create text $cx $cy1      \
                            -anchor  s                  \
                            -justify center             \
                            -fill    black              \
                            -font    $parms(title.font) \
                            -text    $options(-title)]


                lassign [$hull bbox $id] dummy cy dummy dummy

                let cy1 {$cy - $parms(title.pad)}
            }
        }

        # NEXT, lay out the legend link at the top right, only if
        # there are data series for the legend.
        if {[llength $series(names)] > 0} {
            $hull create text $cx1 $cy0          \
                -tags   legendlink               \
                -anchor ne                       \
                -fill   $parms(legend.linkcolor) \
                -font   $parms(legend.linkfont)  \
                -text   "Click for Legend"
        }

        # NEXT, if there's a ytext, lay it out at the top left.
        if {$options(-ytext) ne ""} {
            set id [$hull create text $cx0 $cy0      \
                        -anchor  nw                  \
                        -justify left                \
                        -fill    black               \
                        -font    $parms(ytext.font)  \
                        -text    $options(-ytext)]

            lassign [$hull bbox $id] dummy dummy dummy cy

            let cy0 {$cy + $parms(ytext.pad)}
        }

        # NEXT, if there's an xtext, lay it out at the lower right.
        if {$options(-xtext) ne ""} {
            set id [$hull create text $cx1 $cy1      \
                        -anchor  se                  \
                        -justify right               \
                        -fill    black               \
                        -font    $parms(xtext.font)  \
                        -text    $options(-xtext)]

            lassign [$hull bbox $id] dummy cy dummy dummy
            
            let cy1 {$cy - $parms(xtext.pad)}
        }

        # NEXT, leave space for the X Axis Text and ticks.  Delete
        # the placeholder once we've gotten its height.
        set id [$hull create text $cx1 $cy1     \
                    -anchor se                  \
                    -fill   black               \
                    -font   $parms(xaxis.font)  \
                    -text   "123456789.0"]
        
        lassign [$hull bbox $id] dummy cy dummy dummy

        $hull delete $id
        
        let cy1 {$cy - $parms(xaxis.pad) - $parms(xaxis.ticklen)}

        # NEXT, draw the X axis line.  Make it two pixels wide, because
        # the plot canvas will overlap it.
        $hull create line $cx0 $cy1 $cx1 $cy1 \
            -fill    black \
            -width   2

        # NEXT, save the limits of the data area.
        set layout(cxmin) $cx0
        set layout(cxmax) $cx1
        set layout(cymin) $cy0
        set layout(cymax) $cy1
    }

    # Method: PositionPlot
    #
    # This method positions the plot canvas on the main canvas.  The
    # plot canvas is the part that scrolls.  It's exactly as wide as
    # as the main canvas, so that X-axis scaling is identical for both.
    # If there's more data than will fit in the space available, the
    # plot widget fills the size available, and is set up to scroll
    # vertically.  Otherwise, it's positioned just above the X-axis
    # line.

    method PositionPlot {} {
        # FIRST, at this point we know the height of the data in
        # the plot widget.  We now need to fit it in to the space
        # available.  Either the data fits into the available space,
        # or it doesn't.  So first we compute the available space.

        let pwid [winfo width $win]
        let pht  {$layout(cymax) - $layout(cymin)}

        # NEXT, configure the plot widget's scroll region to encompass
        # all of the data: the height of the data, and the width of the
        # window.

        $plot configure \
            -scrollregion [list 0.0 0.0 $pwid $layout(pymax)]

        # NEXT, position the plot canvas.
        
        if {$pht < $layout(pymax)} {
            # Not enough room.  Make the plot widget fill the space.
            $hull coords $info(plot) 0 $layout(cymin)
            $hull itemconfigure $info(plot) \
                -width  $pwid               \
                -height $pht
        } else {
            # There's enough room.  Put the plot widget at the
            # bottom.
            let cy {$layout(cymax) - $layout(pymax)}

            $hull coords $info(plot) 0 $cy
            $hull itemconfigure $info(plot) \
                -width  $pwid               \
                -height $layout(pymax)
        }
    }

    # Method: ComputeXMinMax
    #
    # This method computes the minimum and maximum bounds for the
    # X-axis from the bounds for each plotted series, rounding the
    # extremes up as needed.    It saves the following layout data.
    #
    # - xmin
    # - xmax

    method ComputeXMinMax {} {
        # FIRST, if there are no series, just use defaults.
        if {[llength $series(names)] == 0} {
            set layout(xmin) 0.0
            set layout(xmax) 1.0
            return
        }

        # NEXT, we don't know the bounds.
        set xmin +Inf
        set xmax -Inf

        # NEXT, loop for the series, and determine the overall
        # bounds--and whether they are _a priori_ range bounds,
        # or are derived from the data.

        set dminFlag 0
        set dmaxFlag 0

        foreach name $series(names) {
            if {$series(rmin-$name) ne ""} {
                if {$series(rmin-$name) < $xmin} {
                    set xmin $series(rmin-$name)
                    set dminFlag 0
                }
            } elseif {$series(dmin-$name) ne ""} {
                if {$series(dmin-$name) < $xmin} {
                    set xmin $series(dmin-$name)
                    set dminFlag 1
                }
            }

            if {$series(rmax-$name) ne ""} {
                if {$series(rmax-$name) > $xmax} {
                    set xmax $series(rmax-$name)
                    set dmaxFlag 0
                }
            } elseif {$series(dmin-$name) ne ""} {
                if {$series(dmax-$name) > $xmax} {
                    set xmax $series(dmax-$name)
                    set dmaxFlag 1
                }
            }
        }

        # NEXT, if either extreme is still infinite then we need to
        # compute the extremes, but don't have enoug data.  Use the default
        # extremes.
        if {$xmin > $xmax} {
            set layout(xmin) 0.0
            set layout(xmax) 1.0
            return
        }

        # NEXT, if either extreme is based on data, compute and
        # apply the rounded extreme(s).
        if {$dminFlag || $dmaxFlag} {
            lassign [roundrange $xmin $xmax] rxmin rxmax

            if {$dminFlag} {
                set xmin $rxmin
            }

            if {$dmaxFlag} {
                set xmax $rxmax
            }
        }

        # FINALLY, save the computed extremes.
        set layout(xmin) $xmin
        set layout(xmax) $xmax
    }

    # Method: RenderXAxis
    #
    # This method renders the X-axis labels and ticks; as part of this,
    # it computes the scaling from the data range to the pixel range, 
    # pxmin to pxmax.
    #
    # It saves the following layout data.
    #
    # - pxmax
    # - ppu

    method RenderXAxis {} {
        # FIRST, pxmax is simply the width of the window minus the
        # margin.
        let layout(pxmax) $layout(cxmax)

        # NEXT, Compute pixels Per Unit
        let layout(ppu) {
            ($layout(pxmax) - $layout(pxmin)) /
            (double($layout(xmax)) - double($layout(xmin)))
        }

        # NEXT, draw ticks at pxmin, pxmax, and x=0
        $self DrawTick $layout(xmin)
        $self DrawTick $layout(xmax)

        if {$layout(xmin) < 0.0 &&
            $layout(xmax) > 0.0
        } {
            $self DrawTick 0.0

            set px0 [$self x2px 0.0]

            $plot create line $px0 0.0 $px0 $layout(pymax) \
                -fill  gray                                \
                -width 1
        }
    }

    # Method: DrawTick
    #
    # Draws an X-axis tick mark at the specified _x_ coordinate.
    #
    # Syntax:
    #   DrawTick _x_
    #  
    #   x - An X-coordinate in data units.

    method DrawTick {x} {
        let px [$self x2px $x]

        let py {$layout(cymax) + $parms(xaxis.ticklen)}

        $hull create line $px $layout(cymax) $px $py \
            -fill  black                             \
            -width 1

        let py {$py + $parms(xaxis.pad)}

        if {$x == $layout(xmax)} {
            set anchor ne
        } else {
            set anchor n
        }

        $hull create text $px $py                  \
            -anchor $anchor                        \
            -fill   black                          \
            -font   $parms(xaxis.font)             \
            -text   [format $options(-xformat) $x]
    }

    # Method: x2px
    #
    # Converts an x coordinate in data units to an x pixel coordinate.
    #
    # Syntax:
    #   x2px _x_
    #
    #   x - An X-coordinate in data units
    
    method x2px {x} {
        expr {($x - $layout(xmin))*$layout(ppu) + $layout(pxmin)}
    }

    # Method: RenderBars
    #
    # Draws the data series.  There are three cases.
    #
    # - If 0.0 is shown, then the bars are based at 0.0.
    # - If xmin > 0.0, then the bars are based at xmin.
    # - If xmax < 0.0, then the bars are based at xmax.

    method RenderBars {} {
        # FIRST, determine the base of each bar.
        if {$layout(xmin) > 0.0} {
            set bx $layout(pxmin)
        } elseif {$layout(xmax) < 0.0} {
            set bx $layout(pxmax)
        } else {
            set bx [$self x2px 0.0]
        }

        # NEXT, draw each bar for each label.
        set ns [llength $series(names)]

        set i 0
        foreach entity $options(-ylabels) {

            set s 0
            foreach name $series(names) {
                # FIRST, if there's no value, don't plot it.
                set x [lindex $series(data-$name) $i]

                if {$x eq ""} {
                    incr s
                    continue
                }

                # NEXT, compute the y coordinates of the
                # top and bottom of the bar.
                let py0 {
                    $layout(pybar-$entity) + $s*$parms(data.barheight)
                }

                let py1 {
                    $py0 + $parms(data.barheight)
                }

                # NEXT, compute the px.  If it's out of range, clamp it.
                let px [$self x2px $x]

                if {$px > $layout(pxmax)} {
                    set px $layout(pxmax)
                } elseif {$px < $layout(pxmin)} {
                    set px $layout(pxmin)
                }

                # NEXT, draw the bar to the left or right of bx.
                if {$px > $bx} {
                    set coords [list $bx $py0 $px $py1]
                } else {
                    set coords [list $px $py0 $bx $py1]
                }

                set id [$plot create rectangle $coords    \
                            -tags    bar                  \
                            -outline black                \
                            -fill    $parms(data.color$s) \
                            -width   1]

                # NEXT, save info about this bar
                set series(bar-$id) [list $entity $name $x]

                incr s
            }

            incr i
        }

        # NEXT, Allow hovering over bars on the plot canvas
        DynamicHelp::add $plot            \
            -item    bar                  \
            -command [mymethod HoverText]
    }

    # Method: HoverText
    #
    # Returns the appropriate text for hovering over a bar.

    method HoverText {} {
        set id [$plot find withtag current]

        lassign $series(bar-$id) ylabel name value
        
        set slabel $series(label-$name)
        set value  [format $options(-xformat) $value]

        return "$ylabel\n$slabel\n$value"
    }

    # Method: LegendIsVisible
    #
    # If the legend is not shown, then it is parked at (-10,0).
    
    method LegendIsVisible {} {
        expr {[lindex [$hull coords $info(legend)] 0] != -10.0}
    }


    # Method: PopupLegend 
    #
    # Pops up the legend, if it isn't already visible.
    
    method PopupLegend {} {
        # FIRST, is it already visible?
        if {[$self LegendIsVisible]} {
            return
        }
        
        # NEXT, pop it up.
        let cx {[winfo width $win] - $parms(chart.right)}
        set cy $layout(cymin)

        $hull coords $info(legend) $cx $cy
    }

    # Method: RenderLegend
    #
    # Renders the legend for the bars into the legend canvas.  We'll
    # add the legend canvas to the main canvas when we need it.

    method RenderLegend {} {
        # FIRST, clear the legend.
        $legend delete all

        # NEXT, if there are no series we're done.
        if {[llength $series(names)] == 0} {
            return
        }

        # NEXT, determine the height of each group and the y offset 
        # for the bar top and the text centerline.
        set barHeight $parms(data.barheight)
        set labHeight [font metrics $parms(legend.font) -linespace]

        let grpHeight {max($barHeight,$labHeight)}

        let labOffset {$grpHeight/2.0}
        let barOffset {max(0.0, ($grpHeight - $barHeight)/2.0)}

        # NEXT, render the data starting at 0,0; we'll move it once
        # we've got bounding box for it all.
        let tx {$barHeight + $parms(legend.gap)}

        set cy 8

        set s 0
        foreach name $series(names) {
            let by0 {$cy  + $barOffset}
            let by1 {$by0 + $barHeight}

            $legend create rectangle 0.0 $by0 $barHeight $by1 \
                -outline black                                \
                -fill    $parms(data.color$s)                 \
                -width   1

            let ty {$cy + $labOffset}

            $legend create text $tx $ty      \
                -anchor w                    \
                -fill   black                \
                -font   $parms(legend.font)  \
                -text   $series(label-$name)
            
            let cy {$cy + $barHeight + $parms(legend.gap)}
            incr s
        }

        # NEXT, move it all by the margin
        $legend move all $parms(legend.margin) $parms(legend.margin)

        # NEXT, get the window size.
        lassign [$legend bbox all] dummy dummy right bottom
        let wid {$right + $parms(legend.margin)}
        let ht  {$bottom + $parms(legend.margin)}

        # NEXT, add the close X
        $legend create image [expr {$wid - 1}] 3 \
            -tag    closer                       \
            -anchor ne                           \
            -image  ${type}::icon::close

        $legend configure \
            -width  $wid  \
            -height $ht

    }

    # Method: PopdownLegend 
    #
    # Pops down the legend, if it's visible.
    
    method PopdownLegend {} {
        if {[$self LegendIsVisible]} {
            $hull coords $info(legend) -10 0
            set info(drag) 0
            
            return
        }
    }

    # Method: LegendMark
    #
    # Method that begins the click/drag/drop sequence for dragging the
    # legend window around the main canvas; called on the initial
    # <ButtonPress-1> event.
    #
    # Syntax:
    #   LegendMark _wx wy_
    #
    #   wx, wy - Coordinates of the click location in the legend window
    #            in window coordinates.

    method LegendMark {wx wy} {
        # FIRST, start dragging
        set trans(dragging) 1
        set trans(id)       $info(legend)

        # NEXT, convert the legend window coordinates to main canvas 
        # coordinates.
        let trans(x) {[winfo x $legend] + $wx}
        let trans(y) {[winfo y $legend] + $wy}
    }

    # Method: LegendDrag
    #
    # Method that continues the click/drag/drop sequence for the
    # Legend window.  Called for each <B1-Motion> event.  Moves the 
    # Legend window to a new location in the main window.
    #
    # Syntax:
    #   LegendDraw _wx wy_
    #
    #   wx, wy - Coordinates of the mouse location in the legend window
    #            in window coordinates.

    method LegendDrag {wx wy} {
        # FIRST, don't drag if we're not dragging
        if {![info exists trans(dragging)]} {
            return
        }

        # NEXT, convert the legend window coordinates to main
        # canvas coordinates.
        let x {[winfo x $legend] + $wx}
        let y {[winfo y $legend] + $wy}

        # NEXT, if the coordinates are not in range, do nothing.
        if {$x <= 0 || $x >= [winfo width $win] ||
            $y <= 0 || $y >= [winfo height $win]
        } {
            return
        }

        # NEXT, compute the delta from the previous position,
        let dx {$x - $trans(x)}
        let dy {$y - $trans(y)}

        $hull move $trans(id) $dx $dy

        set trans(x) $x
        set trans(y) $y
    }

    # Method: LegendDrop
    #
    # Method that terminates the click/drag/drop sequence for the
    # Legend window.  Called for each <ButtonRelease-1> event.
    # The window is already in its new position; this method simply
    # clears the transient data related to the interaction.

    method LegendDrop {} {
        if {![info exists trans(dragging)]} {
            return
        }

        # NEXT, clear the trans array
        array unset trans
    }

    # Method: ContextClick
    #
    # Produces a <<Context>> event on $win corresponding to a 
    # right-click or control-click.  If the click is on a 
    # data bar, the %d contains the data bar info.
    #
    # Syntax:
    #   ContextClick _w wx wy rx ry_
    #
    #   w     - The window receiving the right-click
    #   wx,wy - The window coordinates of the click (%x,%y)
    #   rx,ry - The root window coordinates of the lick (%X,%Y)

    method ContextClick {w wx wy rx ry} {
        # FIRST, if this is the plot widget we need to translate
        # the window coordinates, and we need to look for a data
        # bar.
        set data "none"

        if {$w eq $plot} {
            # FIRST, translate the window coordinates.
            let wx {$wx + [winfo x $plot]}
            let wy {$wy + [winfo y $plot]}

            # NEXT, get the data bar, if any.
            set id [$plot find withtag current]

            if {[info exists series(bar-$id)]} {
                set data [linsert $series(bar-$id) 0 bar]
            }
        } elseif {$w eq $legend} {
            # No context on legend window
            return
        }

        # NEXT, generate the event
        event generate $win <<Context>> \
            -data  $data                \
            -x     $wx                  \
            -y     $wy                  \
            -rootx $rx                  \
            -rooty $ry

        return -code break
    }


    #-------------------------------------------------------------------
    # Group: Public Methods
    #
    # For the moment, all canvas methods are available.

    delegate method * to hull

    delegate method yview to plot

    # Method: plot
    #
    # Plots or updates a data series called _name_, given the options.
    # For new series, -data is required.  A render is scheduled.
    #
    # Syntax:
    #   plot _name option value ?option value...?__
    #
    #   name - The series name
    #   
    # Options:
    #   -label - The human-readable label; defaults to the _name_.
    #   -data  - A list of X-values, one for each of the -ylabels.
    #   -rmin  - Lower bound for the plotted data type, or "" if none.
    #            Defaults to "".
    #   -rmax  - Upper bound for the plotted data type, or "" if none.
    #            Defaults to "".

    method plot {name args} {
        # FIRST, get the options
        array set opts {
            -label ""
            -data  ""
        }

        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -label {
                    set opts($opt) [lshift args]
                }

                -data {
                    set opts($opt) [lshift args]
                }

                -rmin -
                -rmax {
                    set opts($opt) [lshift args]

                    if {$opts($opt) ne ""} {
                        snit::double validate $opts($opt)
                    }
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, If this is a new series, set it up.
        if {$name ni $series(names)} {
            require {[llength $series(names)] < $parms(chart.maxseries)} \
                "Too many data series: limit $parms(chart.maxseries)"

            lappend series(names) $name
            set series(label-$name) $name
            set series(data-$name) {}
            set series(rmin-$name) {}
            set series(rmax-$name) {}
            set series(dmin-$name) {}
            set series(dmax-$name) {}
        }

        # NEXT, apply the options.
        if {$opts(-label) ne ""} {
            set series(label-$name) $opts(-label)
        }

        if {[info exists opts(-rmin)]} {
            set series(rmin-$name) $opts(-rmin)
        }

        if {[info exists opts(-rmax)]} {
            set series(rmax-$name) $opts(-rmax)
        }

        if {$opts(-data) ne ""} {
            require {
                [llength $opts(-data)] == [llength $options(-ylabels)]
            } \
            "Number of values to plot doesn't match the number of -ylabels"

            # FIRST, save the series
            set series(data-$name) $opts(-data)

            # NEXT, get the dmin and dmax values if need be.
            if {$series(rmin-$name) eq ""} {
                set series(dmin-$name) [tcl::mathfunc::min {*}$opts(-data)]
            }

            if {$series(rmax-$name) eq ""} {
                set series(dmax-$name) [tcl::mathfunc::max {*}$opts(-data)]
            }
        }

        # NEXT, schedule the next rendering
        $lu update
    }
}