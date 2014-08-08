#-----------------------------------------------------------------------
# TITLE:
#   gtserver.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   marsutil(n) Game Truth Server
#
#   This object allows the application to publish game truth to clients
#   via a commserver(n) object.  Game truth comes in two forms: scalars, 
#   which are transported in name/value pairs and objects. An object can
#   be thought of as an entire row of a database entry.
#   Conceptually, scalar variables are stored  in a Tcl array and have 
#   standard Tcl values.  Objects are stored in a Tcl list as a dict and
#   have a key column and object class associated with them.
#
#   This is the server side of the "gt" portion of the Simulation/Console 
#   Interface.
#
#   Game truth clients should use gtclient(n) in tandem with a commclient(n).
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export gtserver
}

#-----------------------------------------------------------------------
# gtserver

snit::type ::marsutil::gtserver {
    #-------------------------------------------------------------------
    # Creation Options

    # -logger
    #
    # Passes in logger(n) component.
    
    option -logger -readonly 1

    # -logcomponent
    #
    # String used for "component" argument to the logger.
    
    option -logcomponent -default "gt"

    # -commserver
    #
    # Passes in the name of the commserver(n) object.

    option -commserver -readonly 1

    # -db
    #
    # Passes in the runtime database object.
    
    option -db -readonly 1

    #-------------------------------------------------------------------
    # Components

    component log            ;# logger(n) object
    component cs             ;# commserver(n) object
    component db             ;# sqlite database 

    #-------------------------------------------------------------------
    # Instance Variables

    variable data           ;# Array; keys are game truth variable names,
                            ;# values are game truth variable values.

    # classinfo -- class information array
    # 
    # classes      the list of classes registered with the server
    # $class-table the name of the database table 
    # $class-idcol the key column in the table
    #
    variable classinfo -array {
        classes {}
    }

    #-------------------------------------------------------------------
    # Constructor and Destructor
    
    constructor {args} {
        # FIRST, get options.
        $self configurelist $args

        # NEXT, check requirements
        set log $options(-logger)
        set cs  $options(-commserver)
        set db  $options(-db)

        set classinfo(classes) [list]

        require {[info commands $log] ne ""} "-log is not defined."
        require {[info commands $cs]  ne ""} "-commserver is not defined."

        $self Log normal "Initialized"
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Log severity message
    #
    # severity         A logger(n) severity level
    # message          The message text.

    method Log {severity message} {
        $log $severity $options(-logcomponent) $message
    }


    #-------------------------------------------------------------------
    # Public methods

    # set name value ?name value ...?
    #
    # name    A game truth variable name
    # value   A game truth variable value
    #
    # Sets the variable's value, and broadcasts it.

    method set {args} {
        # FIRST, save the data
        array set data $args

        # NEXT, publish the variables
        set cmd [linsert $args 0 gt set]
        $cs broadcast $cmd
    }

    # unset name ?name....?
    #
    # name     A game truth variable name
    #
    # Unsets all of the named variables, and publishes deletions

    method unset {args} {
        # FIRST, unset the saved data.
        foreach name $args {
            unset -nocomplain -- data($name)
        }

        # NEXT, unpublish the variables.
        set cmd [linsert $args 0 gt unset]
        $cs broadcast $cmd
    }

    # clear
    #
    # Clears all monitor data values

    method clear {} {
        # FIRST, unset the saved data.
        array unset data

        # NEXT, unpublish all items
        $cs broadcast [list gt clear]
    }

    # refresh ?id?
    #
    # id      A client comm(n) ID
    #
    # Broadcasts all data to all clients, or
    # if id is given refreshes just that client.
    #
    # Either way, first delete all game truth variables, then 
    # update all current game truth variables.
    #
    # TBD: commserver should be udpated to handle whether the message
    # is a broadcast message or single client message. The presence or
    # absence of the id would indicate which type it is. Once this
    # is done, then the if - else block can go away.

    method refresh {{id ""}} {
        if {$id eq ""} {
            # FIRST, broadcast start refresh
            $cs broadcast [list gt startrefresh]

            # NEXT, broadcast a clear
            $cs broadcast [list gt clear]

            # NEXT, broadcast all names and values
            $cs broadcast [linsert [array get data] 0 gt set]

            # NEXT, broadcast all game truth objects
            foreach class $classinfo(classes) {
                # FIRST, if this class does not get refreshed, don't
                if {$classinfo($class-norefresh)} {continue}

                # NEXT, build the query
                set query  { 
                    SELECT * from $classinfo($class-table) 
                }

                # NEXT, clear the row array
                array unset row

                # NEXT, make the request and broadcast
                $db eval [subst $query] row {
                    unset -nocomplain row(*)
                    set dict [array get row]
                    set id   $row($classinfo($class-idcol))
                    $cs broadcast [list gt update $class $id $dict]
                }
            }

            # NEXT, broadcast end of refresh
            $cs broadcast [list gt endrefresh]
        } else {
            # FIRST, send start refresh to requesting client
            $cs send $id [list gt startrefresh]

            # NEXT, send clear to client
            $cs send $id [list gt clear]

            # NEXT, send names and values to client
            $cs send $id [linsert [array get data] 0 gt set]

            # NEXT, send game truth objects to client
            foreach class $classinfo(classes) {
                # FIRST, if this class does not get refreshed, don't
                
                if {$classinfo($class-norefresh)} {continue}
                # NEXT, build the query
                set query  { 
                    SELECT * from $classinfo($class-table) 
                }

                # NEXT, clear the row array
                array unset row

                # NEXT, make the request and send
                $db eval [subst $query] row {
                    unset -nocomplain row(*)
                    set dict [array get row]
                    set cid   $row($classinfo($class-idcol))
                    $cs send $id [list gt update $class $cid $dict]
                }
            }

            # NEXT, send end of refresh to client
            $cs send $id [list gt endrefresh]
        }
    }

    # complete
    #
    # Sends a "gt complete" message, telling the client that the 
    # current state is consistent.

    method complete {} {
        $cs broadcast [list gt complete]
    }
 
    # class class table idcolumn
    #
    # class    The class of game truth object 
    # table    The name of the table in the database
    # idcolumn The column in the database row that is the key column
    #
    # Recognized options:
    #   -norefresh    Means that upon a refresh request these objects
    #                 do net get refreshed
    #
    # Registers information about this type of game truth object for
    # use in create, update and delete of objects
    #

    method class {class table idcolumn {args ""}} {

        # FIRST, assume all gt classes are refreshed
        set norefresh 0

        # NEXT, parse options.
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -norefresh {
                    set norefresh 1
                }

                default {
                    error "Unknown option \"$opt\""
                }
            }
        }

        set classinfo($class-norefresh) $norefresh
        set classinfo($class-table)     $table
        set classinfo($class-idcol)     $idcolumn 

        # NEXT, add this class in the classes list if not already there
        if {[lsearch -exact $classinfo(classes) $class] == -1} {
            lappend classinfo(classes) $class
        }
    }

    # update class id ?dict?
    #
    # class    The class of game truth object 
    # id       The id of the object to be updated
    # dict     The data to be changed in this object
    #
    # Update an instance of a game truth object in the database or
    # broadcast it if no dictionary is supplied. 

    method update {class id {dict ""}} {
        # FIRST, make sure the database is specified
        require {[info commands $db] ne ""} "-db is not defined."

        # FIRST, if there is no dict, get it from the database
        if {$dict eq ""} {
            # FIRST, get the dict from the database
            set query  { 
                SELECT * from $classinfo($class-table) 
                WHERE $classinfo($class-idcol) == $id
            }

            $db eval [subst $query] row {}
            unset row(*)
            set dict [array get row]
        }

        # NEXT, send update to clients
        $cs broadcast [list gt update $class $id $dict]

    }

    # delete class id
    #
    # class    The class of game truth object
    # id       The id of the object to delete
    #
    # Delete an instance of game truth object
    #

    method delete {class id} {
        # FIRST, send delete to clients
        $cs broadcast [list gt delete $class $id]
    }
    
}




