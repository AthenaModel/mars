#-----------------------------------------------------------------------
# FILE: stripchart.tcl
#   
#   Strip Chart Widget
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
    namespace export stripchart
}

#-------------------------------------------------------------------
# Widget: stripchart
#
# The stripchart(n) widget plots one or more series of data values as
# line plots against an X-data series, using time.
#
# TBD:
#
# - Fix <<Context>>
# - Move the close icon to the marsgui(n) icons library.
# - Consider abstracting the legend window code.
# - Put layout parameters in a parmset(n).
#
#-----------------------------------------------------------------------

snit::widgetadaptor ::marsgui::stripchart {
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
    # canvas(n) on which the actual data is drawn.  The only reason to
    # have a separate plot widget is to support clipping of data
    # outside the specified range.

    component plot

    # Component: legend
    # 
    # canvas(n) on which the legend is drawn.
    component legend

    #-------------------------------------------------------------------
    # Group: Options


    delegate option -width          to hull
    delegate option -height         to hull
    delegate option -closeenough    to hull

    # Option: -smooth
    #
    # If true, the line plots are smoothed.
    
    option -smooth \
        -default         false           \
        -configuremethod ConfigAndRender

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

    # Option: -xformatcmd
    #
    # Command for formatting X-values for output
    option -xformatcmd                   \
        -default         {format %g}     \
        -configuremethod ConfigAndRender

    # Option: -xmin
    #
    # Minimum X domain value.  Defaults to min X data value.
    
    option -xmin                         \
        -configuremethod ConfigAndRender

    # Option: -xmax
    #
    # Minimum X domain value.  Defaults to max X data value.
    
    option -xmax                         \
        -configuremethod ConfigAndRender

    # Option: -ytext
    #
    # This is the overall label for the Y-axis.

    option -ytext                        \
        -default         {}              \
        -configuremethod ConfigAndRender

    # Option: -yformatcmd
    #
    # Command for formatting Y-values for output
    option -yformatcmd                   \
        -default         {format %g}     \
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


    #-------------------------------------------------------------------
    # Group: Instance Variables

    # Variable: parms
    #
    # This array contains the parameters used to layout the chart.
    # It might eventually be replaced by a parmset(n).
    #
    # chart.maxseries  - Maximum number of data series
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
    #                    the related tick-marks, in pixels.
    # xaxis.ticklen    - Vertical length of the X-axis tick marks, in pixels.
    # xaxis.font       - Font used for the X-axis labels.
    #
    # yaxis.pad        - Horizontal pad between the y-axis labels and the
    #                    related tick marks, in pixels.
    # yaxis.ticklen    - Horizontal length of the X-axis tick marks, in pixels.
    # yaxis.font       - Font used for y-axis labels
    #
    # data.plotwid     - Width of plotted lin, in pixels
    # data.color<n>    - Fill color for each plotted line,
    #                    0...chart.maxseries.
    #
    # legend.linkfont  - Font for the "Click for Legend" link at the
    #                    top of the chart.
    # legend.linkcolor - Color for the "Click for Legend" link.
    # legend.font      - Font for the label text in the legend window
    #                    itself.
    # legend.gap       - Gap, in pixels, between successive entries in
    #                    the legend window, and between the plot
    #                    line and its label text.
    # legend.plotlen   - Length of the plot line
    # legend.plotwid   - Width of the plot line
    # legend.margin    - Margin, in pixels, between the edge of the
    #                    legend window and its content.

    variable parms -array {
        chart.maxseries  10
        chart.left       5
        chart.right      5
        chart.top        5
        chart.bottom     5
        chart.xfudge     200
        chart.yfudge     150

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
        yaxis.ticklen    3
        yaxis.pad        2

        data.plotwid     2

        data.color0      \#33FFFF
        data.color1      \#006666
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
        legend.plotlen   10
        legend.plotwid   4
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
    #
    #    pymin         - The y coordinate of the top of the data area.
    #    pymax         - The y coordinate of the bottom of the data area
    #                    (i.e., the X-axis line)
    #    pxmin         - The x coordinate of the left of the data area
    #                    (i.e., the Y-axis line)
    #    pxmax         - The x coordinate of the right of the data area
    #
    #    xmax          - Maximum x data coordinate
    #    xmin          - Minimum x data coordinate
    #    xppu          - The number of pixels per X data unit.
    #
    #    ymax          - Maximum y data coordinate
    #    ymin          - Minimum y data coordinate
    #    yppu          - The number of pixels per Y data unit.
    variable layout -array { }

    # Variable: series
    #
    # This array contains the data for the plotted series.  The keys
    # are as follows.
    #
    #   names       - List of series names, in order of definition.
    #   label-$name - Human readable label for the named series
    #   data-$name  - List of data values for the named series.
    #   plot-$name  - Canvas ID of the plotted line for this series
    #   name-$id    - Series name by canvas ID of the plotted line.
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
    # Creates a new instance of stripchart(n), given the creation 
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
        # scroll region.  Use the "win" tag, so that we don't delete it
        # later.
        install legend using canvas $win.legend \
            -background         white           \
            -highlightthickness 0               \
            -borderwidth        1               \
            -relief             solid

        set info(legend) [$hull create window -10 0 \
                              -tags   win           \
                              -anchor ne            \
                              -window $legend]

        # NEXT, let the embedded canvases canvas respond to
        # events on the main widget.
        bindtags $plot   [linsert [bindtags $plot]   0 $win]
        # TBD: Do I want this?
        bindtags $legend [linsert [bindtags $legend] 0 $win]

        # NEXT, do event bindings.
        bind $win <Configure> [list $lu update]

        $hull   bind legendlink <1> [mymethod PopupLegend]
        $legend bind closer     <1> [mymethod PopdownLegend]

        # Allow legend to be dragged
        bind $legend <ButtonPress-1>   [mymethod LegendMark %x %y]
        bind $legend <B1-Motion>       [mymethod LegendDrag %x %y]
        bind $legend <ButtonRelease-1> [mymethod LegendDrop]

        # Generate <<Context>>
        bind $win  <3>         [mymethod ContextClick %W %x %y %X %Y]
        bind $win  <Control-1> [mymethod ContextClick %W %x %y %X %Y]
        bind $plot <3>         [mymethod ContextClick %W %x %y %X %Y]
        bind $plot <Control-1> [mymethod ContextClick %W %x %y %X %Y]

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

        # NEXT, render the titles
        $self RenderTitles

        # NEXT, compute the Y axis bounds.
        $self ComputeYMinMax

        # NEXT, render the Y axis
        $self RenderYAxis

        # NEXT, compute the X axis bounds.
        $self ComputeXMinMax

        # NEXT, render the X axis
        $self RenderXAxis

        # NEXT, position the plot
        $self PositionPlot

        # NEXT, render the data series
        $self RenderSeries

        # NEXT, render the legend
        $self RenderLegend

        # NEXT, If we had a legend showing, display it again.
        if {[$self LegendIsVisible]} {
            let x {$fx * $layout(chartWidth)}
            let y {$fy * $layout(chartHeight)}

            $hull coords $info(legend) $x $y
        }
    }

    # Method: RenderTitles
    #
    # This method renders the title, ytext, xtext, legend hyperlink,
    # and X-axis line into the main canvas.  It saves the following
    # layout data.
    #
    #  - chartWidth
    #  - chartHeight
    #  - pxmax
    #  - pymin
    #  - pymax

    method RenderTitles {} {
        # FIRST, compute the width and height of the chart.  Normally
        # this is the window size, but there are minimums.

        let layout(chartWidth) {
            max([winfo width $win], $parms(chart.xfudge))
        }

        let layout(chartHeight) {
            max([winfo height $win], $parms(chart.yfudge))
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

        # NEXT, save the limits of the data area.
        set layout(pxmax) $cx1
        set layout(pymin) $cy0
        set layout(pymax) $cy1
    }

    # Method: ComputeYMinMax
    #
    # This method computes the minimum and maximum bounds for the
    # Y-axis from the bounds for each plotted series, rounding the
    # extremes up as needed.    It saves the following layout data.
    #
    # - ymin
    # - ymax

    method ComputeYMinMax {} {
        # FIRST, if there are no series, just use defaults.
        if {[llength $series(names)] == 0} {
            set layout(ymin) -1.0
            set layout(ymax)  1.0
            return
        }

        # NEXT, we don't know the bounds.
        set ymin +Inf
        set ymax -Inf

        # NEXT, loop for the series, and determine the overall
        # bounds--and whether they are _a priori_ range bounds,
        # or are derived from the data.

        set dminFlag 0
        set dmaxFlag 0

        foreach name $series(names) {
            if {$series(rmin-$name) ne ""} {
                if {$series(rmin-$name) < $ymin} {
                    set ymin $series(rmin-$name)
                    set dminFlag 0
                }
            } else {
                if {$series(dmin-$name) eq ""} {
                    set ylist [dict values $series(data-$name)]
                    
                    if {[llength $ylist] > 0} {
                        set series(dmin-$name) [tcl::mathfunc::min {*}$ylist]
                    } else {
                        set series(dmin-$name) +Inf
                    }
                }

                if {$series(dmin-$name) < $ymin} {
                    set ymin $series(dmin-$name)
                    set dminFlag 1
                }
            }

            if {$series(rmax-$name) ne ""} {
                if {$series(rmax-$name) > $ymax} {
                    set ymax $series(rmax-$name)
                    set dmaxFlag 0
                }
            } else {
                if {$series(dmax-$name) eq ""} {
                    set ylist [dict values $series(data-$name)]
                    
                    if {[llength $ylist] > 0} {
                        set series(dmax-$name) [tcl::mathfunc::max {*}$ylist]
                    } else {
                        set series(dmax-$name) -Inf
                    }
                }

                if {$series(dmax-$name) > $ymax} {
                    set ymax $series(dmax-$name)
                    set dmaxFlag 1
                }
            }
        }

        # NEXT, if either extreme is still infinite then we need to
        # compute the extremes, but don't have enough data.  Use the default
        # extremes.
        if {$ymin > $ymax} {
            set layout(ymin) 0.0
            set layout(ymax) 1.0
            return
        }

        # NEXT, if either extreme is based on data, compute and
        # apply the rounded extreme(s).
        if {$dminFlag || $dmaxFlag} {
            lassign [roundrange $ymin $ymax] rymin rymax

            if {$dminFlag} {
                set ymin $rymin
            }

            if {$dmaxFlag} {
                set ymax $rymax
            }
        }

        # FINALLY, save the computed extremes.
        set layout(ymin) $ymin
        set layout(ymax) $ymax
    }

    # Method: RenderYAxis
    #
    # This method renders the Y-axis labels and ticks; as part of this,
    # it computes the scaling from the data range to the pixel range, 
    # pymin to pymax, as well as the position of the Y-axis line,
    # pxmin.
    #
    # It saves the following layout data.
    #
    # - yppu
    # - pxmin

    method RenderYAxis {} {
        # FIRST, Compute pixels Per Unit
        let layout(yppu) {
            ($layout(pymax) - $layout(pymin)) /
            (double($layout(ymax)) - double($layout(ymin)))
        }

        # NEXT, draw ticks at pymin, pymax, and y=0.  We'll draw the
        # text right-justified at x=0, with the ticks to the right,
        # then shift it all over.

        $self DrawYTick $layout(ymin)
        $self DrawYTick $layout(ymax)

        if {$layout(ymin) < 0.0 &&
            $layout(ymax) > 0.0
        } {
            $self DrawYTick 0.0
        }

        # NEXT, compute pxmin and shift the ticks.
        lassign [$hull bbox yticks] px0 dummy dummy dummy

        let layout(pxmin) {-$px0 + $parms(chart.left)}

        $hull move yticks $layout(pxmin) 0.0

        # NEXT, draw a gray line at y = 0
        if {$layout(ymin) < 0.0 &&
            $layout(ymax) > 0.0
        } {
            set py0 [$self y2py 0.0]

            $hull create line $layout(pxmin) $py0 $layout(pxmax) $py0 \
                -fill  gray                                           \
                -width 1
        }

        # NEXT, draw the Y-axis.
        $hull create line \
            $layout(pxmin) $layout(pymin) $layout(pxmin) $layout(pymax) \
            -fill black \
            -width 1
    }

    # Method: DrawYTick
    #
    # Draws an Y-axis tick mark at the specified _y_ coordinate.
    #
    # Syntax:
    #   DrawYTick _y_
    #  
    #   y - A Y-coordinate in data units.

    method DrawYTick {y} {
        let py [$self y2py $y]

        let px {- ($parms(yaxis.pad) + $parms(yaxis.ticklen))}

        $hull create line -$parms(yaxis.ticklen) $py 0.0 $py \
            -tags  yticks                                    \
            -fill  black                                     \
            -width 1

        if {$y == $layout(ymax)} {
            set anchor ne
        } else {
            set anchor e
        }

        $hull create text $px $py                  \
            -tags   yticks                         \
            -anchor $anchor                        \
            -fill   black                          \
            -font   $parms(yaxis.font)             \
            -text   [{*}$options(-yformatcmd) $y]
    }

    # Method: ComputeXMinMax
    #
    # This method computes the minimum and maximum bounds for the
    # X-axis from the -xmin, -xmax, and -xvalues options, and
    # computes the pixels-per-data-unit for the X-axis.
    # It saves the following layout data.
    #
    # - xmin
    # - xmax
    # - xppu

    method ComputeXMinMax {} {
        # FIRST, Set defaults.
        set layout(xmin) 0.0
        set layout(xmax) 10.0

        # NEXT, if there are series, see if we can do better.
        if {[llength $series(names)] >= 0} {
            # FIRST, apply the -xmin, -xmax
            if {$options(-xmin) ne ""} {
                set xmin $options(-xmin)
            } else {
                set xmin +Inf
                foreach name $series(names) {
                    if {$series(xmin-$name) ne ""} {
                        let xmin {min($xmin, $series(xmin-$name))}
                    }
                }
            }

            if {$options(-xmax) ne ""} {
                set xmax $options(-xmax)
            } else {
                set xmax -Inf
                
                foreach name $series(names) {
                    if {$series(xmax-$name) ne ""} {
                        let xmax {max($xmax, $series(xmax-$name))}
                    }
                }
            }

            # NEXT, loop for the series, and determine the overall
            # bounds.
            
            foreach name $series(names) {
                if {[llength $series(data-$name)] > 0} {
                    let xmin {min($xmin, $series(xmin-$name))}
                    let xmax {max($xmax, $series(xmax-$name))}
                }
            }

            # NEXT, save the computed extremes.
            if {$xmin ne "+Inf"} {
                set layout(xmin) $xmin
            }

            if {$xmax ne "-Inf"} {
                set layout(xmax) $xmax
            }
        }

        # If there is only one point plotted, xmin will equal xmax.
        # We need some distance between them.
        if {$layout(xmin) == $layout(xmax)} {
            let layout(xmax) {$layout(xmin) + 1.0}
        }

        # NEXT, Compute pixels Per Unit
        let layout(xppu) {
            ($layout(pxmax) - $layout(pxmin)) /
            (double($layout(xmax)) - double($layout(xmin)))
        }
    }


    # Method: RenderXAxis
    #
    # This method renders the X-axis line, labels, and ticks.

    method RenderXAxis {} {
        # FIRST, draw the x-axis line.  Make it two pixels wide;
        # the plot widget will overlap it.
        $hull create line \
            $layout(pxmin) $layout(pymax) $layout(pxmax) $layout(pymax) \
            -width 1    \
            -fill black

        # NEXT, draw ticks at pxmin and pxmax
        $self DrawXTick $layout(xmin)
        $self DrawXTick $layout(xmax)
    }

    # Method: DrawXTick
    #
    # Draws an X-axis tick mark at the specified _x_ coordinate.
    #
    # Syntax:
    #   DrawXTick _x_
    #  
    #   x - An X-coordinate in data units.

    method DrawXTick {x} {
        let px [$self x2px $x]

        let py {$layout(pymax) + $parms(xaxis.ticklen)}

        $hull create line $px $layout(pymax) $px $py \
            -fill  black                             \
            -width 1

        let py {$py + $parms(xaxis.pad)}

        set text [{*}$options(-xformatcmd) $x]

        if {$x == $layout(xmax)} {
            set anchor ne
        } elseif {$x == $layout(xmin) && [string length $text] > 4} {
            set anchor nw
        } else {
            set anchor n
        }

        $hull create text $px $py                  \
            -anchor $anchor                        \
            -fill   black                          \
            -font   $parms(xaxis.font)             \
            -text   $text
    }

    # Method: PositionPlot
    #
    # This method positions the plot canvas on the main canvas.  The
    # plot canvas is the part on which the actual data is plotted.
    # It fits exactly in the space available, and has its scrollregion
    # set so that canvas coordinates on the plot widget are identical to 
    # canvas coordinates on the main widget.


    method PositionPlot {} {
        # FIRST, compute the width and the height of the plot widget.
        let px  {$layout(pxmin) + 1}
        let py  {$layout(pymin)}
        let wid {$layout(pxmax) - $layout(pxmin) - 1}
        let ht  {$layout(pymax) - $layout(pymin)}

        # NEXT, position the plot canvas.
        $hull coords $info(plot) $px $py
        $hull itemconfigure $info(plot) \
            -width  $wid                \
            -height $ht

        # NEXT, configure the plot widget's scroll region so that the
        # coordinates match.

        $plot configure -scrollregion \
            [list $px $py $layout(pxmax) $layout(pymax)]
    }

    # Method: RenderSeries
    #
    # Renders the plots for the data series.

    method RenderSeries {} {
        # FIRST, add a blank rectangle that we can hover over.
        # Lower it to the bottom.
        $plot create rectangle \
            $layout(pxmin) $layout(pymin) \
            $layout(pxmax) $layout(pymax) \
            -tags    bg                   \
            -fill    ""                   \
            -outline ""

        $plot lower bg

        

        # NEXT, plot the data series
        set i -1

        foreach name $series(names) {
            # FIRST, get the series number
            incr i

            # NEXT, skip missing data
            if {[llength $series(data-$name)] == 0} {
                return
            }

            # NEXT, create the list of coordinates
            set coords [list]

            foreach {x y} $series(data-$name) {
                lappend coords [$self x2px $x] [$self y2py $y]
            }

            # NEXT, if there's only one point, double it to make a valid line.
            if {[llength $coords] == 2} {
                set coords [concat $coords $coords]
            }

            # NEXT, plot the line
            set id [$plot create line $coords        \
                        -tags   plot                 \
                        -width  $parms(data.plotwid) \
                        -smooth $options(-smooth)    \
                        -fill   $parms(data.color$i)]

            # NEXT, save the ID
            set series(name-$id)   $name
            set series(plot-$name) $id
        }

        # NEXT, Allow hovering over plots on the canvas
        DynamicHelp::add $plot            \
            -item    bg                   \
            -command [mymethod HoverText]

        DynamicHelp::add $plot            \
            -item    plot                 \
            -command [mymethod HoverText]

    }

    # Method: HoverText
    #
    # Returns the appropriate text for hovering over a plot

    method HoverText {} {
        # FIRST, get the id of the plot, the data series name,
        # and the label.
        set id    [$plot find withtag current]
        if {[info exists series(name-$id)]} {
            set name  $series(name-$id)
            set text "$series(label-$name)\n"
        } else {
            # Hovering over the background
            set text ""
        }

        # NEXT, determine where the mouse pointer is. in data
        # coordinates.
        lassign [winfo pointerxy $win] rx ry

        let px {$rx - [winfo rootx $win]}
        let py {$ry - [winfo rooty $win]}

        set xtext [{*}$options(-xformatcmd) [$self px2x $px]]
        set ytext [{*}$options(-yformatcmd) [$self py2y $py]]

        append text "($xtext, $ytext)"

        # NEXT, return the hover text
        return $text
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
        set cy $layout(pymin)

        $hull coords $info(legend) $cx $cy
    }

    # Method: RenderLegend
    #
    # Renders the legend for the series into the legend canvas.  We'll
    # add the legend canvas to the main canvas when we need it.

    method RenderLegend {} {
        # FIRST, clear the legend.
        $legend delete all

        # NEXT, determine the X coordinates
        set px0 0.0
        set px1 $parms(legend.plotlen)
        let px2 {$px1 + $parms(legend.gap)}

        # NEXT, determine the distance between entries.
        set yskip [font metrics $parms(legend.font) -linespace]

        # NEXT, render the data starting at 0,0; we'll move it once
        # we've got bounding box for it all.

        set py 0.0
        set i -1
        
        if {[llength $series(names)] != 0} {
            # FIRST, render an entry for each series.
            foreach name $series(names) {
                # FIRST, increment the series number
                incr i

                # NEXT, draw the line
                $legend create line $px0 $py $px1 $py \
                    -fill  $parms(data.color$i)       \
                    -width $parms(legend.plotwid)

                # NEXT, draw the label
                $legend create text $px2 $py     \
                    -anchor w                    \
                    -fill   black                \
                    -font   $parms(legend.font)  \
                    -text   $series(label-$name)
                
                let py {$py + $yskip}
            }
        } else {
            # FIRST, there's no data series, so say so
            $legend create text $px0 $py \
                -anchor w                   \
                -fill   black               \
                -font   $parms(legend.font) \
                -text   "no data"
        }


        # NEXT, move it so that the upper left is within the margin
        lassign [$legend bbox all] dummy top dummy dummy

        $legend move all \
            $parms(legend.margin) \
            [expr {-$top + $parms(legend.margin) + 10}]

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
    # data plot, the %d contains the data plot info.
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
        if {$w eq $plot} {
            # FIRST, translate the window coordinates.
            let wx {$wx + [winfo x $plot]}
            let wy {$wy + [winfo y $plot]}

            # NEXT, get the data bar, if any.
            set id [$plot find withtag current]

            if {[info exists series(name-$id)]} {
                set name $series(name-$id)
                
                set data [list line [$self px2x $wx] [$self py2y $wy] $name]
            } else {
                set data [list plot [$self px2x $wx] [$self py2y $wy]]
            }
        } elseif {$w eq $legend} {
            # No context on legend window
            return
        } else {
            set data [list none]
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

    # Method: x2px
    #
    # Converts an x coordinate in data units to an x pixel coordinate.
    #
    # Syntax:
    #   x2px _x_
    #
    #   x - An X-coordinate in data units
    
    method x2px {x} {
        expr {$layout(pxmin) + ($x - $layout(xmin))*$layout(xppu)}
    }


    # Method: px2x
    #
    # Converts an x pixel coordinate to an x data coordinate.
    #
    # Syntax:
    #   px2x _px_
    #
    #   px - An X-coordinate in pixels
    
    method px2x {px} {
        expr {$layout(xmin) + ($px - $layout(pxmin))/$layout(xppu)}
    }


    # Method: y2py
    #
    # Converts a y coordinate in data units to a y pixel coordinate.
    #
    # Syntax:
    #   y2py _y_
    #
    #   y - A Y-coordinate in data units
    
    method y2py {y} {
        expr {$layout(pymax) - ($y - $layout(ymin))*$layout(yppu)}
    }

    # Method: py2y
    #
    # Converts a y pixel coordinate to a y data coordinate.
    #
    # Syntax:
    #   py2y _py_
    #
    #   py - A Y-coordinate in pixels
    
    method py2y {py} {
        expr {$layout(ymin) + ($layout(pymax) - $py)/$layout(yppu)}
    }



    #-------------------------------------------------------------------
    # Group: Public Methods
    #
    # For the moment, all canvas methods are available.

    delegate method * to hull

    # Method: clear
    #
    # Clears the saved plot data, and, schedules a render timeout.

    method clear {} {
        array unset series
        set series(names) [list]

        $lu update
    }

    # Method: plot
    #
    # Plots or updates a data series called _name_, given the options.
    # A render is scheduled.
    #
    # Syntax:
    #   plot _name option value ?option value...?__
    #
    #   name - The series name
    #   
    # Options:
    #   -label - The human-readable label; defaults to the _name_.
    #   -data  - A flat list of X/Y pairs.
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
            set series(plot-$name) {}
            set series(data-$name) {}
            set series(rmin-$name) {}
            set series(rmax-$name) {}
            set series(dmin-$name) {}
            set series(dmax-$name) {}
            set series(xmin-$name) {}
            set series(xmax-$name) {}
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
            # FIRST, save the series
            set series(data-$name) $opts(-data)

            # NEXT, clear the min and max stats, as we'll compute
            # them as needed.
            set series(dmin-$name) ""
            set series(dmax-$name) ""
            set series(xmin-$name) ""
            set series(xmax-$name) ""
            
            # NEXT, get the xmin and xmax values for this series.
            set xlist [dict keys $opts(-data)]

            set series(xmin-$name) [lindex $xlist 0]
            set series(xmax-$name) [lindex $xlist end]
        }

        # NEXT, schedule the next rendering
        $lu update
    }
}
