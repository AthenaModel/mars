#-----------------------------------------------------------------------
# TITLE:
#   gtclient.tcl
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
#   marsutil(n) Game Truth Client
#
#   This object allows the application to receive game truth published
#   via gtserver(n)/commserver(n) via a commclient(n).  As such, it 
#   implements the client side of the "gt" portion of the 
#   Simulation/Console Interface.
#
#   Note that gtclient(n) objects do not need to know the name of the
#   commclient(n) (indeed, there doesn't even need to be one).  Instead,
#   the name of the gtclient(n) object is aliased into the commclient(n):
#
#      commclient proxy ...options...
#      gtclient gt ...options...
#      proxy alias gt gt
#    
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export gtclient
}

#-----------------------------------------------------------------------
# gtclient

snit::type gtclient {
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

    # -refreshstartcmd
    #
    # Called on "gt refresh", before the refresh begins.

    option -refreshstartcmd {}

    # -refreshendcmd
    #
    # Called on "gt refresh", after the refresh is complete and
    # before any watchers are called.

    option -refreshendcmd {}

    # -completecmd
    #
    # Called on "gt complete".

    option -completecmd {}

    # -db
    #
    # Passes in an sqldatabase(n) component
  
    option -db -readonly 1

    #-------------------------------------------------------------------
    # Components

    component log            ;# logger(n) object
    component db             ;# sqlite database

    #-------------------------------------------------------------------
    # Instance variables

    variable gt                  ;# This contains the game truth.
    variable watchers            ;# Array of watch commands.
    variable receivingRefresh 0  ;# 0 normally, 1 while receiving refresh
                                  # before calling watchers.
    # classinfo -- class information array
    # 
    # classes       the list of classes registered with the server
    # $class-table  the name of the database table 
    # $class-idcol  the key column in the table
    # $class-prefix the command callback 
    #
    variable classinfo -array {
        classes {}
    }

   #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure args
        $self configurelist $args

        # NEXT, set the database object
        set db $options(-db)
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Log severity message
    #
    # severity         A logger(n) severity level
    # message          The message text.

    method Log {severity message} {
        $options(-logger) $severity $options(-logcomponent) $message
    }

    #-------------------------------------------------------------------
    # Public methods

    # startrefresh
    #
    # Begins a complete monitor data refresh.  During a refresh,
    # watchers are suspended.

    method startrefresh {} {
        # FIRST, log that a refresh is starting
        $self Log normal "startrefresh"

        # NEXT, allow app to prepare.
        if {$options(-refreshstartcmd) ne ""} {
            uplevel \#0 $options(-refreshstartcmd)
        }

        # NEXT, set the refresh flag
        set receivingRefresh 1
    }

    # endrefresh
    #
    # Ends a monitor data refresh.  Calls the refreshCommand, and
    # then all watchers.

    method endrefresh {} {
        $self Log normal "endrefresh"

        # FIRST, the refresh is over.
        set receivingRefresh 0

        # NEXT, do allow app to respond to changes.
        if {$options(-refreshendcmd) ne ""} {
            uplevel \#0 $options(-refreshendcmd)
        }

        # NEXT, call individual watchers; note, the order is
        # arbitrary.
        foreach name [array names gt] {
            if {[info exists watchers($name)]} {
                set cmd $watchers($name)
                lappend cmd $gt($name)
                
                uplevel \#0 $cmd
            }
        }
    }

    # set name value ?name value...?
    #
    # name       A game truth variable name
    # value      Its value.
    #
    # Saves the values.

    method set {args} {
        array set gt $args
        if {!$receivingRefresh} {
            foreach {name value} $args {
                if {[info exists watchers($name)]} {
                    set cmd $watchers($name)
                    lappend cmd $value
                    
                    uplevel \#0 $cmd
                }
            }
        }
        return
    }

    # get name
    #
    # name       A game truth variable name
    #
    # Retrieves the value of the variable, if any; set with "gt set"
    # before use.

    method get {name} {
        return $gt($name)
    }

    # var name
    #
    # name      A game truth variable name
    #
    # Retrieves the Tcl variable name of the game truth variable, 
    # for use with -textvariable options.

    method var {name} {
        return [myvar gt($name)]
    }

    # unset ?name...?
    #
    # Unsets deleted game truth variables.

    method unset {args} {
        foreach key $args {
            unset gt($key)
        }
        
        return
    }

    # clear
    #
    # Unsets all game truth variables and deletes all tables.

    method clear {} {
        # FIRST unset all game truth variables
        array unset gt

        # NEXT, clear out the database
        if {[info exists db]} {
            $db clear
        }
    }

    # complete
    #
    # Calls the -completecmd, if any.  This is used to indicate that
    # the current game truth update is complete, and that the game
    # truth data is in a consistent state.

    method complete {} {
        if {$options(-completecmd) ne ""} {
            uplevel \#0 $options(-completecmd)
        }
    }


    # watch name command
    #
    # name      A game truth variable name
    # command   A command to be called when the variable's value changes.
    #           It will be passed one argument, the new value.

    method watch {name command} {
        if {$name ne ""} {
            set watchers($name) $command
        } else {
            unset watchers($name)
        }
    }

    # class class table idcolumn
    #
    # class    The class of game truth object 
    # table    The name of the table in the database
    # idcolumn The column in the database row that is the key column
    #
    # Registers information about this type of game truth object for
    # use in create, update and delete of objects
    #

    method class {class table idcolumn} {
        # FIRST, make sure there is a database defined
        require {[info commands $db] ne ""} "-db is not defined."

        # NEXT, set table, id column and default command prefix
        set classinfo($class-table)  $table
        set classinfo($class-idcol)  $idcolumn
        set classinfo($class-prefix) ""

        # NEXT, add this class in the classes list if not already there
        if {[lsearch -exact $classinfo(classes) $class] == -1} {
            lappend classinfo(classes) $class
        }
    }

    # onupdate class prefix
    #
    # class    The class of game truth object
    # prefix   The command to append update type, id and object dictionary
    #

    method onupdate {class prefix} {
        # FIRST, check to see if the class has been registered
        if {[lsearch -exact $classinfo(classes) $class] == -1} {
            $self Log normal "Unknown game truth object class: $class"
            return
        }

        set classinfo($class-prefix) $prefix
    }

    # update class id dict
    #
    # class    The class of game truth object 
    # id       The id of the object to be updated
    # dict     The data to be changed in this object
    #
    # Update an instance of a game truth object in the database

    method update {class id dict} {
        # FIRST, check to see if the class has been registered
        if {[lsearch -exact $classinfo(classes) $class] == -1} {
            $self Log warning "Unknown game truth object class: $class"
            return
        }

        # NEXT, if this record doesn't exists we want to create it in the
        # database.
        set table $classinfo($class-table)
        set idcol $classinfo($class-idcol)
        $db eval "
            INSERT OR IGNORE INTO ${table}($idcol)
            VALUES(\$id)
        "

        # NEXT, update the record
        foreach {col val} $dict {
            $db eval "
                UPDATE $classinfo($class-table)
                SET $col = \$val
                WHERE $classinfo($class-idcol) == \$id
            " 
        }

        # NEXT, call the command registered for this class of object, but
        # only if there is no refresh going on        
        if (!$receivingRefresh) {
            callwith $classinfo($class-prefix) update $id
        }
    }

    # delete class id
    #
    # class    The class of game truth object 
    # id       The id of the object to delete
    #
    # Delete an instance of game truth object from the database
    #

    method delete {class id} {
        # FIRST, check to see if the class has been registered
        if {[lsearch -exact $classinfo(classes) $class] == -1} {
            $self Log normal "Unknown game truth object class: $class"
            return
        }

        # NEXT, query the database for this objects dict
        # TBD: I think this query can be deleted.
        set query {
            SELECT * from $classinfo($class-table)
            WHERE $classinfo($class-idcol) == $id
        }

        $db eval [subst $query] row {}
        unset row(*)
        set dict [array get row]

        # NEXT, call the command registered for this class of object, but
        # only if there is no refresh going on        
        if (!$receivingRefresh) {
            callwith $classinfo($class-prefix) delete $id 
        }

        # NEXT, remove the entry from the database
        $db eval "
            DELETE FROM $classinfo($class-table) 
            WHERE ($classinfo($class-idcol) = $id)
        "
    }       
}




