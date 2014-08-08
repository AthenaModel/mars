#-----------------------------------------------------------------------
# TITLE:
#   filter.tcl
# 
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsgui(n) package: Filter widget.
# 
#   This widget provides a text filter control for doing exact, wildcard,
#   regular expression filtering, both inclusive and exclusive, of
#   arbitrary text.  Filtering is triggered when <Return> is pressed in
#   the entry field, when the filter's contents is cleared, and an item
#   is selected on the Sieve Icon menu.
# 
#   filter type:    exact        exact string filter
#                   wildcard     wildcard filter (? and *)
#                   regexp       full regexp filter
# 
#   inclusive:      yes, no
# 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsgui:: {
    namespace export filter
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ::marsgui::filter {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        snit::enum filterType -values {
            exact
            incremental
            wildcard
            regexp
        }

        snit::enum ignorecaseType -values {
            no
            yes
        }
    }


    #-------------------------------------------------------------------
    # Options

    # -msgcmd cmd
    # 
    # Specifies a log command for reporting messages.    
    option -msgcmd -default ""
    
    # -filtercmd  cmd
    # 
    # A command to be executed when filtration is triggered.
    option -filtercmd -default ""

    # -ignorecase flag
    option -ignorecase                                     \
        -default         no                                \
        -type            ::marsgui::filter::ignorecaseType \
        -configuremethod ConfigThenFilter

    # -filtertype value
    option -filtertype                                 \
        -default         exact                         \
        -type            ::marsgui::filter::filterType \
        -configuremethod ConfigThenFilter

    method ConfigThenFilter {opt val} {
        set options($opt) $val
        $self FilterNow
    }

    # Delegate all other options to the hull
    delegate option * to hull
    
    #-------------------------------------------------------------------
    # Variables

    variable inclusive    yes        ;# Include or exclude matches
    variable targetRegexp ""         ;# Used by "check".

    #-------------------------------------------------------------------
    # Constructor & Destructor
    
    constructor {args} {
        # FIRST, create the commandentry
        installhull using commandentry          \
            -clearbtn    1                      \
            -changecmd   [mymethod EntryChange] \
            -returncmd   [mymethod EntryReturn]
        
        # NEXT, get the commandentry's frame, so we can put stuff in it.
        set f [$hull frame]
            
        # NEXT, Create the -type menu.
        set menu $f.type.menu
        ttk::menubutton $f.type                \
            -style   Entrybutton.Toolbutton    \
            -image   ::marsgui::icon::filter   \
            -menu    $menu
        
        pack $f.type \
            -before [lindex [pack slaves $f] 0] \
            -side   left
        
        DynamicHelp::add $f.type \
            -text "Filter Options Menu"
                
        menu $menu
        
        $menu add radio                            \
            -label    "Exact"                      \
            -variable [myvar options(-filtertype)] \
            -value    "exact"                      \
            -command  [mymethod FilterNow]

        $menu add radio                            \
            -label    "Incremental"                \
            -variable [myvar options(-filtertype)] \
            -value    "incremental"                \
            -command  [mymethod FilterNow]
            
        $menu add radio                            \
            -label    "Wildcard"                   \
            -variable [myvar options(-filtertype)] \
            -value    "wildcard"                   \
            -command  [mymethod FilterNow]


        $menu add radio                            \
            -label    "Regexp"                     \
            -variable [myvar options(-filtertype)] \
            -value    "regexp"                     \
            -command  [mymethod FilterNow]
            
        $menu add separator

        $menu add check                            \
            -label    "Ignore Case"                \
            -variable [myvar options(-ignorecase)] \
            -onvalue  yes                          \
            -offvalue no                           \
            -command  [mymethod FilterNow]
            
        $menu add separator

        $menu add radio                    \
            -label    "Include Matches"    \
            -variable [myvar inclusive]    \
            -value    yes                  \
            -command  [mymethod FilterNow]
            
        $menu add radio                    \
            -label    "Exclude Matches"    \
            -variable [myvar inclusive]    \
            -value    no                   \
            -command  [mymethod FilterNow]
            
        # Save the constructor options.
        $self configurelist $args
    }
    
    # Destructor - default destructor is adequate


    #-------------------------------------------------------------------
    # Private Methods

    # EntryChange string
    #
    # Triggers filtration if the field is now empty or if the
    # filter type is incremental

    method EntryChange {string} {
        if {$string eq "" || $options(-filtertype) eq "incremental"} {
            $self FilterNow
        }
    }
    

    # EntryReturn string
    #
    # Triggers filtration
    method EntryReturn {string} {
        $self FilterNow
    }

    # FilterNow
    #
    # Set up to check strings against the filter conditions, and 
    # execute the -filtercmd
    method FilterNow {} {
        set target [string trim [$hull get]]
        
        if {$target eq ""} {
            set targetRegexp ""
        } else {
            # Process the new target according to the type.
            switch -exact -- $options(-filtertype) {
                "exact" -
                "incremental" {
                    set targetRegexp  "***=$target"
                }        
                "wildcard" {
                    set targetRegexp [::marsutil::wildToRegexp $target]
                } 
                "regexp" {
                    set targetRegexp $target
                }

                default {
                    error "Unknown -filtertype: \"$options(-filtertype)\""
                }
            }

            # Check the regexp for errors.  On error, write a message
            # using the -msgcmd.
            if {[catch {regexp -- $targetRegexp dummy} result]} {
                $self Message "invalid $options(-filtertype): \"[$hull get]\""
                bell
                return
            }
        }
    
        # Call the -filtercmd.
        if {$options(-filtercmd) ne ""} {
            uplevel \#0 $options(-filtercmd)
        }
    }

    # Message msg
    #
    # msg   A message string
    #
    # Logs a message using the -msgcmd.
    method Message {msg} {
        if {$options(-msgcmd) ne ""} {
            set cmd $options(-msgcmd)
            lappend cmd $msg
            uplevel \#0  $cmd
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # check string
    #
    # string    A string to filter
    #
    # Checks the string against the filter settings.  Returns 1 if the
    # string is included, and 0 otherwise.
    method check {string} {
        # If there's no target, all strings are included.
        if {$targetRegexp eq ""} {
            return 1
        }

        if {$options(-ignorecase)} {
            set flag [regexp -nocase -- $targetRegexp $string]
        } else {
            set flag [regexp -- $targetRegexp $string]
        }

        if {!$inclusive} {
            set flag [expr {!$flag}]
        }
        
        return $flag
        # return 1
    }
}




