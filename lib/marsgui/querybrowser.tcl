#-----------------------------------------------------------------------
# TITLE:
#    querybrowser.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    marsgui(n): SQLite3 browser for arbitrary queries.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::marsgui:: {
    namespace export querybrowser
}


#-----------------------------------------------------------------------
# sqlbrowser

snit::widget ::marsgui::querybrowser {
    hulltype ttk::frame
    
    #-------------------------------------------------------------------
    # Type Constructor
    
    typeconstructor {
        namespace import ::marsutil::*
    }
    
    #-------------------------------------------------------------------
    # Components
    
    component browser   ;# sqlbrowser(n) for displaying the results.
    component editor    ;# texteditor(n) for editing the query.
    component db        ;# sqldocument(n) handle, or equivalent
    
    #-------------------------------------------------------------------
    # Options
    
    delegate option * to hull
    
    delegate option -db           to browser
    delegate option -selectmode   to browser
    delegate option -selectioncmd to browser
    
    # -reloadon events
    #
    # events is a list of notifier(n) subjects and events.  The
    # browser will reload its contents when the events are received.
    
    option -reloadon                       \
        -default         {}                \
        -configuremethod ConfigureReloadOn
    
    method ConfigureReloadOn {opt val} {
        # FIRST, remove any existing bindings
        foreach {subject event} $options(-reloadon) {
            notifier bind $subject $event $win ""
        }
        
        # NEXT, add the new bindings
        set options($opt) $val
        
        foreach {subject event} $val {
            notifier bind $subject $event $win [mymethod ReloadOnEvent]
        }
    }

    
    #-------------------------------------------------------------------
    # Instance Variables
    
    # info array
    #
    #   view     The name of this instance's view
    
    variable info -array {
        view {}
    }
    
    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, determine the view name to be used for queries.
        set info(view) [string map {. _} "temp_querybrowser$win"]
        
        # NEXT, get the -db from the args
        set db [from args -db ""]
        
        # NEXT, create the components to which options are delegated.
        
        # The paner
        ttk::panedwindow $win.paner \
            -orient vertical
            
        # browser
        install browser using sqlbrowser $win.paner.browser \
            -view   $info(view)                             \
            -db     $db
        
        $win.paner add $browser -weight 1
        
        # editor
        install editor using texteditor $win.paner.editor \
            -height      4                                \
            -borderwidth 1                                \
            -relief      sunken
        
        $win.paner add $editor
        
        # query button
        ttk::button $win.query \
            -text    "Execute Query"         \
            -command [mymethod ExecuteQuery]
        
        # NEXT, configure the options
        $self configurelist $args
        
        # NEXT, pack it all in
        grid $win.paner -row 0 -column 0 -sticky nsew
        grid $win.query -row 1 -column 0 -sticky ew
        
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 0 -weight 1
    }
    
    destructor {
        notifier forget $win
    }
    
    #-------------------------------------------------------------------
    # Behaviour
    
    # ExecuteQuery
    #
    # Attempts to execute the specified query and load the results into
    # the browser.
    
    method ExecuteQuery {} {
        # FIRST, drop the view.
        $db eval "DROP VIEW IF EXISTS $info(view)"
        
        # NEXT, get the query.
        set query [string trim [$editor get 1.0 end]]
        
        if {$query eq ""} {
            $browser layout
            return
        }

        # NEXT, try to redefine it.
        $db authorizer [myproc SqliteAuthorizer $info(view)]
        
        if {[catch {
            $db eval "CREATE TEMPORARY VIEW $info(view) AS $query"
        } result]} {
            messagebox popup                        \
                -icon    error                      \
                -parent  $win                       \
                -title   "Error in Query"           \
                -message [tsubst {
                    |<--
                    There was an error in your SQL Query:
                    
                    $result
                }]
        }
        
        $db authorizer ""
        
        $browser layout
    }
    
    # ReloadOnEvent
    #
    # Reloads the widget when a -reloadon event is received.
    # The "args" parameter is so that any event can be handled.
    
    method ReloadOnEvent {args} {
        $self ExecuteQuery
    }

    # SqliteAuthorizer 
    #
    # view      The name of the view being created.
    # op        The SQLite operation
    # args      Related arguments; ignored.
    #
    # Allows SELECTs and READs, which are needed to query the database,
    # and CREATE TEMP VIEW, which is needed to create the query view.
    # I suspect FUNCTION is needed to allow the user to call SQL
    # functions defined in Tcl.  
    # All other operations are denied.

    proc SqliteAuthorizer {view op name args} {
        if {$op eq "SQLITE_INSERT" && $name eq "sqlite_temp_master"} {
            return SQLITE_OK
        }
        
        if {$op eq "SQLITE_CREATE_TEMP_VIEW" && $name eq $view} {
            return SQLITE_OK
        }
        
        if {$op eq "SQLITE_UPDATE" && $name eq "sqlite_temp_master"} {
            return SQLITE_OK
        }

        if {$op eq "SQLITE_READ" && $name eq "sqlite_temp_master"} {
            return SQLITE_OK
        }
        
        return SQLITE_DENY
    }
    
    #-------------------------------------------------------------------
    # Public Methods
    
    delegate method curselection to browser
    delegate method selection    to browser
    delegate method get          to browser
    delegate method toolbar      to browser
    
    # reload
    #
    # Tells the widget to re-evaluate the query and present the results.
    
    method reload {} {
        $self ExecuteQuery
        return
    }
    
    # clear
    #
    # Clears all data from the browser
    
    method clear {} {
        $editor delete 1.0 end
        $self ExecuteQuery
        return
    }

    # query set sql
    #
    # sql       A query
    #
    # Sets the query and executes it.
    
    method {query set} {sql} {
        $editor delete 1.0 end
        $editor insert 1.0 $sql
        $editor yview moveto 0

        $self ExecuteQuery
        return
    }
    
    # query get
    #
    # Returns the text from the query editor
    
    method {query get} {} {
        $editor get 1.0 {end - 1 char}
    }
}