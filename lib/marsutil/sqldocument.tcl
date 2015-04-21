#-----------------------------------------------------------------------
# TITLE:
#   sqldocument.tcl
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
#   Extensible SQL Database Object
#
#   This module defines the sqldocument(n) type.  Each instance 
#   of the type can wrap a single SQLite3 database handle, providing
#   access to all of the database handle's subcommands as well as
#   addition subcommands of its own.
#
#   Access to the database is document-centric: open/create the 
#   database, read and write until an appropriate save point is 
#   reached, then commit all changes.  In other words, it's expected
#   that any given database file has but one writer at a time, and
#   arbitrarily many writes are batched into a single transaction.
#   (Otherwise, each write would be a single transaction, and the necessary
#   locking and unlocking would cause a performance hit.)
#
#   sqldocument(n) can be used to open and query any kind of SQL 
#   database file.  It addition, it can also create databases with
#   the necessary schema definitions to support other modules,
#   called sqlsections.  Each such module must adhere to the 
#   sqlsection(i) interface.  All definitions for all loaded sqlsection(i)
#   modules will be included in the created databases.
#
#   An sqlsection(i) module can define the following things:
#
#   * Persistent schema definitions
#   * Temporary schema definitions
#   * Temporary data definitions
#   * SQL functions
#
#   sqlsection(i) modules register themselves with sqldocument(n) on
#   load; sqldocument(n) queries the sqlsection(i) modules for their
#   definitions on database open and clear.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export sqldocument
}

#-----------------------------------------------------------------------
# sqldocument

snit::type ::marsutil::sqldocument {
    #-------------------------------------------------------------------
    # sqlsection(i)
    #
    # The following routines implement the module's sqlsection(i)
    # interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "sqldocument(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, if any.

    typemethod {sqlsection schema} {} {
        return ""
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, if any.

    typemethod {sqlsection tempschema} {} {
        return ""
    }

    # sqlsection tempdata
    #
    # Returns the section's temporary data definitions, if any.

    typemethod {sqlsection tempdata} {} {
        return ""
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes

    typemethod {sqlsection functions} {} {
        set functions [list]

        lappend functions dictget             [myproc dictget]
        lappend functions error               [list ::error]
        lappend functions format              [list ::format]
        lappend functions joinlist            [list ::join]
        lappend functions nonempty            [myproc NonEmpty]
        lappend functions percent             [list ::marsutil::percent]
        lappend functions wallclock           [list ::clock seconds]
        lappend functions sqldocument_grab    [myproc GrabFunc]
        lappend functions sqldocument_monitor [myproc RowMonitorFunc]

        return $functions
   }


    #-------------------------------------------------------------------
    # Components

    component db   ;# The SQLite3 database command, or NullDatabase if none

    #-------------------------------------------------------------------
    # Options

    # -subject
    #
    # Sets the subject name for notifier(n) events sent by this
    # option.  Defaults to $self.

    option -subject

    # -rollback
    #
    # If on, sqldocument(n) supports rollbacks.  Default is off.

    option -rollback        \
        -default off        \
        -readonly yes       \
        -type snit::boolean

    # -autotrans
    #
    # If on, a transaction is always open; data isn't saved until the
    # application calls "commit".  If off, the user is responsible for
    # transactions, and "commit" is a no-op.

    option -autotrans       \
        -default on         \
        -readonly yes       \
        -type snit::boolean

    # -foreignkeys
    #
    # If on (the default), any foreign key constraints and actions
    # defined in the schema will take effect.  If off (the default)
    # they will not.

    option -foreignkeys \
        -default  on             \
        -readonly yes            \
        -type     snit::boolean

    # -clock
    #
    # Specifies a simclock(i).  If it exists, simclock-related functions
    # are defined.

    option -clock     \
        -default  ""  \
        -readonly yes


    # -commitcmd
    #
    # Specifies an optional callback command to be executed after the
    # database has been committed but before a new transaction is 
    # started.
    
    option -commitcmd \
        -default "" 

    # -explaincmd cmd
    #
    # Specifies a command prefix to be called with two additional
    # arguments when the [explain] method is used.  The first is the
    # query, and the second is the result of EXPLAIN QUERY PLAN.

    option -explaincmd

    # -readonly flag
    #
    # If true, the sqlite3 handle is opened in readonly mode.

    option -readonly \
        -default  no \
        -readonly yes \
        -type     snit::boolean


    #-------------------------------------------------------------------
    # Instance variables

    # Array of data variables:
    #
    # dbIsOpen      - Flag: 1 if there is an open database, and 0
    #                 otherwise.
    # dbFile        - Name of the current database file, or ""
    # registry      - List of registered sqlsection module names,
    #                 in order of registration.
    # monitorLevel  - Number of nested "monitor *" calls

    variable info -array {
        dbIsOpen       0
        dbFile         {}
        registry       ::marsutil::sqldocument
        monitorLevel   0

    }

    # monitors array: monitored tables
    #
    # List of keynames by table name.

    variable monitors -array { }


    # updates list
    #
    # This is a flat list {<table> <operation> <keyval>...} 
    # produced during a monitor_transaction.
    #
    # NOTE: This variable is used transiently during the 
    # monitor_transaction call..  It's a typevariable
    # so that it can be accessed by the RowMonitorFunc proc.

    typevariable updates {}

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, we have no database; set the db component accordingly.
        set db [myproc NullDatabase]

        # NEXT, process options
        $self configurelist $args
    }


    #-------------------------------------------------------------------
    # Public Methods: sqlsection(i) registration

    # register section
    #
    # section     Fully qualified name of an sqlsection(i) module
    #
    # Registers the section for later use

    method register {section} {
        if {$section ni $info(registry)} {
            lappend info(registry) $section
        }
    }

    # sections
    #
    # Returns a list of the names of the registered sections

    method sections {} {
        return $info(registry)
    }


    #-------------------------------------------------------------------
    # Public Methods: Database Management

    # open ?filename?
    #
    # filename         database file name
    #
    # Opens the database file, creating it if necessary.  Does not
    # change the database in any way; use "clear" to initialize it.
    # If filename is not specified, will reopen the previous file, if any.
    #
    # The DICT collation sequence is defined automatically.
    
    method open {{filename ""}} {
        # FIRST, the database must not already be open!
        require {!$info(dbIsOpen)} "database is already open"

        # NEXT, get the file name.
        if {$filename eq ""} {
            require {$info(dbFile) ne ""} "database file name not specified"

            set filename $info(dbFile)
        }

        # NEXT, attempt to open the database and define the db component.
        # 
        # NOTE: since the db command is defined in the instance
        # namespace, it will be destroyed automatically when the
        # instance is destroyed.  Note that uncommitted updates will
        # *not* be saved.
        set db ${selfns}::db

        sqlite3 $db $filename -readonly $options(-readonly)

        # NEXT, define the DICT collating sequence.
        $db collate DICT [myproc DictCompare]

        # NEXT, set up various pragmas, IF we are not read-only.
        # If we are read-only we can't change these things, and anyway
        # they should already be set in the DB we're reading.

        if {!$options(-readonly)} {
            # FIRST, set the hardware security requirement
            $db eval {
                -- We don't need to safeguard the database from 
                -- hardware errors.
                PRAGMA synchronous=OFF;

                -- Keep temporary data in memory
                PRAGMA temp_store=MEMORY;
            }

            # NEXT, if -rollback is off, turn off journaling.
            if {!$options(-rollback)} {
                $db eval {
                    PRAGMA journal_mode=OFF;
                }
            }

            # NEXT, if -foreignkeys is on, turn on foreign keys,
            # else turn it off.  (Foreign keys are liable to be
            # on by default in a future version of SQLite3; 
            # setting the pragma explicitly in both cases means
            # we don't need to think about it.)

            if {$options(-foreignkeys)} {
                $db eval {
                    PRAGMA foreign_keys=ON
                }
            } else {
                $db eval {
                    PRAGMA foreign_keys=OFF
                }
            }
        }

        # NEXT, define the temporary tables
        $self DefineTempSchema
        $self DefineTempData

        # NEXT, define standard functions.
        $self DefineFunctions

        # NEXT, save the file name; we are in business
        set info(dbFile)   $filename
        set info(dbIsOpen) 1

        # NEXT, if -autotrans then open the initial transaction.
        if {!$options(-readonly) && $options(-autotrans)} {
            $db eval {BEGIN IMMEDIATE TRANSACTION;}
        }
    }

    # clear
    #
    # Initializes the database, clearing old content and redefining
    # the schema according to the registered list of sqlsections.

    method clear {} {
        # FIRST, are the requirements for clearing the database met?
        require {$info(dbIsOpen)}         "database is not open"
        require {!$options(-readonly)} "database is -readonly yes"

        # NEXT, Clear the current contents, if any, and set up the 
        # schema.  If the database is being written to by another
        # application, we will get a "database is locked" error.

        if {[catch {$self DefineSchema} result]} {
            if {$result eq "database is locked"} {
                error $result
            } else {
                error "could not initialize database: $result"
            }
        }
    }

    # DefineSchema
    #
    # Deletes old data from the database, and defines the proper schema.

    method DefineSchema {} {
        # FIRST, commit any open transaction.  If the commit fails, that's
        # no big deal.
        catch {$db eval {COMMIT TRANSACTION;}}

        # NEXT, Turn off foreign keys if they are on, as it can
        # screw up the process of dropping the old tables.
        $db eval {PRAGMA foreign_keys=0;}

        # NEXT, open an exclusive transaction; if there's another
        # application attached to this database file, 
        # we'll get a "database is locked" error.

        $db eval {BEGIN EXCLUSIVE TRANSACTION}

        # NEXT, clear any old content
        sqlib clear $db

        # NEXT, define persistent schema entities
        foreach section $info(registry) {
            set schema [$section sqlsection schema]

            if {$schema ne ""} {
                $db eval $schema
            }
        }

        # NEXT, define temporary schema entities
        $self DefineTempSchema
        $self DefineTempData

        # NEXT, commit the schema changes
        $db eval {COMMIT TRANSACTION;}

        # NEXT, turn foreign keys back on, if they are supposed to be.
        if {$options(-foreignkeys)} {
            $db eval {PRAGMA foreign_keys=1}
        }

        # NEXT, if -autotrans then begin an immediate transaction; we want 
        # there to be a transaction open at all times.  We'll commit the 
        # data to disk from time to time.

        if {$options(-autotrans)} {
            $db eval {BEGIN IMMEDIATE TRANSACTION;}
        }
    }

    # DefineTempSchema
    #
    # Define the temporary tables for the sqlsections included in
    # the registry.  This should be called on both "open"
    # and "clear", so that the temporary tables are always defined.

    method DefineTempSchema {} {
        foreach section $info(registry) {
            set schema [$section sqlsection tempschema]

            if {$schema ne ""} {
                $db eval $schema
            }
        }
    }

    # DefineTempData
    #
    # Define the temporary data for the sqlsections included in
    # the registry.  This should be called on both "open"
    # and "clear", so that the temporary tables are always populated
    # as required.

    method DefineTempData {} {
        foreach section $info(registry) {
            # FIRST, if the section does not define the tempdata 
            # subcommand, skip it.
            #
            # TBD: Once all existing sections are updated, this
            # check should be omitted, as it unduly constrains
            # the clients.
            if {[catch {
                if {"sqlsection tempdata" ni [$section info typemethods]} {
                    continue
                }
            }]} {
                continue
            }

            set content [$section sqlsection tempdata]

            foreach {table rows} $content {
                $db eval "DELETE FROM $table"

                foreach row $rows {
                    $self insert $table $row
                }
            }
        }
    }

    # DefineFunctions
    #
    # Define SQL functions.

    method DefineFunctions {} {
        # FIRST, define the -clock functions.  Note that "tozulu" is
        # deprecated.
        if {$options(-clock) ne ""} {
            $db function timestr [list $options(-clock) toString]
            $db function tozulu  [list $options(-clock) toString]
            $db function now     [list $options(-clock) now]
        }

        # NEXT, define functions defined in sqlsections.
        foreach section $info(registry) {
            foreach {name definition} [$section sqlsection functions] {
                $db function $name $definition
            }
        }
    }

    # lock tables
    #
    # tables      A list of table names
    #
    # Creates triggers which effectively make the listed tables read-only.
    # It's OK if the tables are already locked.  Note that locking
    # a table doesn't prevent the database from being "clear"ed.
    #
    # NOTE: Doesn't support attached databases.

    method lock {tables} {
        require {$info(dbIsOpen)} "database is not open"
        require {!$options(-readonly)} "database is -readonly yes"


        foreach table $tables {
            foreach event {DELETE INSERT UPDATE} {
                $db eval [outdent "
                    CREATE TRIGGER IF NOT EXISTS
                    sqldocument_lock_${event}_${table} BEFORE $event ON $table
                    BEGIN SELECT error('Table \"$table\" is read-only'); END;
                "]
            }
        }
    }

    # unlock tables
    #
    # tables      A list of table names
    #
    # Deletes any lock triggers. It's OK if the tables are already unlocked.
    #
    # NOTE: Doesn't support attached databases.

    method unlock {tables} {
        require {$info(dbIsOpen)} "database is not open"
        require {!$options(-readonly)} "database is -readonly yes"

        foreach table $tables {
            foreach event {DELETE INSERT UPDATE} {
                $db eval [outdent "
                    DROP TRIGGER IF EXISTS sqldocument_lock_${event}_${table}
                "]
            }
        }
    }

    # islocked table
    # 
    # table      The name of a table
    #
    # Returns 1 if the table is locked, and 0 otherwise.
    #
    # Note: if a table is a temporary table, the lock triggers will
    # *automatically* be temporary triggers; otherwise they will be
    # persistent triggers.  Thus, we need to look into both the
    # sqlite_master and the sqlite_temp_master for matching triggers.
    #
    # NOTE: Doesn't support attached databases.
   
    method islocked {table} {
        # Just query whether the UPDATE trigger exists
        set trigger "sqldocument_lock_UPDATE_$table"

        $db exists {
            SELECT name FROM sqlite_master
            WHERE name=$trigger
            UNION
            SELECT name FROM sqlite_temp_master
            WHERE name=$trigger
        }
    }

    # commit
    #
    # Commits all database changes to the db, and opens a new 
    # transaction.  If -autotrans is off, this is a no-op.

    method commit {} {
        require {$info(dbIsOpen)} "database is not open"
        require {!$options(-readonly)} "database is -readonly yes"

        if {$options(-autotrans)} {
            # Break this up into two SQL statements. If one fails, its
            # easier to trace the problem.
            try {
                $db eval {
                    COMMIT TRANSACTION;
                }

                # If there is a commit command to be executed, do it.
                if {$options(-commitcmd) ne ""} {
                    if {[catch {uplevel \#0 $options(-commitcmd)} result]} {
                        bgerror "-commitcmd: $result"
                    }
                }
            } finally {
                $db eval {
                    BEGIN IMMEDIATE TRANSACTION;
                }
            }
        }
    }

    # close
    #
    # Commits all changes and closes the wsdb.  Once this is done,
    # the database must be opened before it can be used.

    method close {} {
        require {$info(dbIsOpen)} "database is not open"

        # Try to commit any changes; but if it's not possible, it's
        # not possible.
        catch {$db eval {COMMIT TRANSACTION;}}
        $db close

        set info(dbIsOpen) 0
        set db [myproc NullDatabase]
    }

    #-------------------------------------------------------------------
    # Public Methods: General database queries

    # Delegated methods
    delegate method columns         to db using {::marsutil::sqlib %m %c}
    delegate method fklist          to db using {::marsutil::sqlib %m %c}
    delegate method grab            to db using {::marsutil::sqlib %m %c}
    delegate method insert          to db using {::marsutil::sqlib %m %c}
    delegate method mat             to db using {::marsutil::sqlib %m %c} 
    delegate method query           to db using {::marsutil::sqlib %m %c} 
    delegate method replace         to db using {::marsutil::sqlib %m %c}
    delegate method schema          to db using {::marsutil::sqlib %m %c} 
    delegate method tables          to db using {::marsutil::sqlib %m %c} 
    delegate method ungrab          to db using {::marsutil::sqlib %m %c}
    delegate method *               to db

    # dbfile
    #
    # Returns the file name, if any

    method dbfile {} {
        return $info(dbFile)
    }

    # isopen
    #
    # Returns 1 if the database is open, and 0 otherwise.
    
    method isopen {} {
        return $info(dbIsOpen)
    }

    # saveas filename
    #
    # filename   A file name
    #
    # Saves a copy of the db to the specified file name.

    method saveas {filename} {
        # FIRST, if we have locked tables they need to be unlocked.
        set lockedTables [list]

        foreach table [$self tables] {
            if {[$self islocked $table]} {
                lappend lockedTables $table
                $self unlock $table
            }
        }

        # NEXT, there can't be any open transaction, so commit.
        catch {
            $db eval {COMMIT TRANSACTION;}
        }

        # NEXT, try to save the data.
        try {
            sqlib saveas $db $filename
        } finally {
            # And now, make sure we lock the tables and open
            # transaction (if need be)
            $self lock $lockedTables
            
            if {$options(-autotrans)} {
                $db eval {BEGIN IMMEDIATE TRANSACTION;}
            }
        }

        return
    }

    #-------------------------------------------------------------------
    # delete
    #
    # The following variables and routines are all related to the
    # "delete" mechanism.

    # grab_data: A transient dictionary of grabbed rows.  The keys
    # are lists {<tableName> INSERT}, so that ungrab will insert
    # them into the database.

    typevariable grab_data

    # nullvalue: The current [$db nullvalue]

    typevariable nullvalue

    # delete ?-grab? table condition ?table condition...?
    #
    # db         - An sqldocument handle
    # table      - A table in the db
    # condition  - A where condition specifying the rows to delete.
    #
    # Deletes the records; if -grab is given, a grab of the data 
    # that was deleted, including cascading deletes.

    method delete {args} {
        # FIRST, get the option, if it's there.
        if {[lindex $args 0] eq "-grab"} {
            set grabbing 1
            lshift args
        } else {
            set grabbing 0
        }

        # NEXT, clear the grab_data
        set nullvalue [$db nullvalue]
        set grab_data [dict create]

        # NEXT, delete the data
        foreach {table condition} $args {
            if {$grabbing} {
                # FIRST, define delete triggers on all tables
                set tables [$self tables]
                $self SetDeleteTraces $tables
            }

            uplevel 1 [list $db eval "DELETE FROM $table WHERE $condition"]

            if {$grabbing} {
                $self DropDeleteTraces $tables
            }
        }

        # NEXT, return the grabbed data, while clearing the cache.
        if {$grabbing} {
            set result $grab_data
            set grab_data [dict create]

            return $result
        } else {
            # Just return
            return
        }
    }

    
    # GrabFunc table values...
    #
    # table   - A table name
    # values  - A list of column values for a row.
    #
    # Stashes the grabbed data in the grab_data dict.
    # TBD: Null values come across as "", regardless of
    # the "nullvalue" setting.

    proc GrabFunc {table args} {
        foreach value $args {
            if {$value ne ""} {
                dict lappend grab_data [list $table INSERT] $value
            } else {
                dict lappend grab_data [list $table INSERT] $nullvalue
            }
        }
        return
    }

    # SetDeleteTraces tables
    #
    # tables   - A list of tables in the db
    #
    # Adds a delete trace trigger on the tables, to grab the
    # data to be deleted.

    method SetDeleteTraces {tables} {
        foreach table $tables {
            # Skip built-in tables
            if {[string match "sqlite*" $table]} {
                continue
            }

            set names [$self columns $table]

            $db eval "
                DROP TRIGGER IF EXISTS sqldocument_trace_${table};

                CREATE TEMP TRIGGER sqldocument_trace_${table}
                BEFORE DELETE ON $table BEGIN
                SELECT sqldocument_grab('$table',old.[join $names ,old.]);
                END;
            "
        }
    }

    # DropDeleteTraces tables
    #
    # tables   - A list of tables in the db
    #
    # Drops the delete trace triggers from the tables.

    method DropDeleteTraces {tables} {
        foreach table $tables {
            $db eval "
                DROP TRIGGER IF EXISTS sqldocument_trace_${table};
            "
        }
    }

    #-------------------------------------------------------------------
    # explain

    # explain 
    #
    # Like "eval", but also does "EXPLAIN QUERY PLAN"

    method explain {args} {
        # FIRST, get the query.
        set query [lshift args]

        # NEXT, explain it and give the result to the -explaincmd.
        set query2 "EXPLAIN QUERY PLAN $query"
        
        set explanation [$self query $query2 -mode list]
        callwith $options(-explaincmd) $query $explanation


        # NEXT, Evaluate the query 
        set command [list $db eval $query {*}$args]

        return [uplevel 1 $command]
    }

    #-------------------------------------------------------------------
    # safeeval/safequery

    # safeeval args...
    #
    # Like "eval", but authorized only to query, not to change

    method safeeval {args} {
        # Allow SELECTs only.
        $db authorizer [myproc RdbAuthorizer]

        set command [list $db eval {*}$args]

        set code [catch {
            uplevel 1 $command
        } result]
        
        # Open it up again.
        $db authorizer ""

        if {$code} {
            error "query error: $result"
        } else {
            return $result
        }
    }


    # safequery args
    #
    # Like "query", but authorized only to query, not to change

    method safequery {args} {
        # Allow SELECTs only.
        $db authorizer [myproc RdbAuthorizer]

        set command [list $self query {*}$args]

        set code [catch {
            uplevel 1 $command
        } result]
        
        # Open it up again.
        $db authorizer ""

        if {$code} {
            error "query error: $result"
        } else {
            return $result
        }
    }

    # RdbAuthorizer op args
    #
    # op        The SQLite operation
    # args      Related arguments; ignored.
    #
    # Allows SELECTs and READs, which are needed to query the database;
    # all other operations are denied.

    proc RdbAuthorizer {op args} {
        if {$op eq "SQLITE_SELECT" || $op eq "SQLITE_READ"} {
            return SQLITE_OK
        } elseif {$op eq "SQLITE_FUNCTION"} {
            return SQLITE_OK
        } else {
            return SQLITE_DENY
        }
    }

    #-------------------------------------------------------------------
    # Table Monitoring

    # monitor add table keynames
    #
    # table    - A table name
    # keynames - A list of the column names used to uniquely identify
    #            the row.
    #
    # Enables monitoring of the specified table.  Updates, inserts or 
    # deletes performed on the table during a monitor_transaction
    # will result in a notifier event:
    #
    #    notifer send $self <$table> $operation $keyval
    #
    # $operation will be either "update" or "delete".

    method {monitor add} {table keynames} {
        # FIRST, note that monitoring is desired.
        set monitors($table) $keynames
    }

    # monitor remove table
    #
    # table   - A table name
    #
    # Disables monitoring of the specified table.

    method {monitor remove} {table} {
        # FIRST, note that monitoring is no longer desired.
        unset -nocomplain monitors($table)
    }

    # monitor transaction body
    #
    # body    - A Tcl script to be implemented as a transaction
    #
    # Enables monitoring, evaluates the body, and sends 
    # relevant notifications.

    method {monitor transaction} {body} {
        $self MonitorPrepare

        try {
            uplevel 1 [list $db transaction $body]
        } finally {
            $self MonitorNotify
        }
    }

    # monitor script body
    #
    # body    - A Tcl script
    #
    # Enables monitoring, evaluates the body, and sends 
    # relevant notifications.

    method {monitor script} {body} {
        $self MonitorPrepare

        try {
            uplevel 1 $body
        } finally {
            $self MonitorNotify
        }
    }

    # MonitorPrepare
    #
    # Enables monitoring; updates to monitored tables
    # will be accumulated.

    method MonitorPrepare {} {
        if {$info(monitorLevel) == 0} {
            # FIRST, install the monitor traces.
            foreach table [array names monitors] {
                $self AddMonitorTrigger $table INSERT
                $self AddMonitorTrigger $table UPDATE
                $self AddMonitorTrigger $table DELETE
            }
            
            # NEXT, make sure the updates array is empty
            set updates [list]
        }

        incr info(monitorLevel)
    }

    # MonitorNotify
    #
    # Sends notifications for the accumulated updates, and
    # disables monitoring.

    method MonitorNotify {} {
        incr info(monitorLevel) -1

        if {$info(monitorLevel) == 0} {
            # FIRST, get the subject name
            if {$options(-subject) eq ""} {
                set subject $self
            } else {
                set subject $options(-subject)
            }

            # NEXT, send the notifications
            foreach {table operation keyval} $updates {
                notifier send $subject <$table> $operation $keyval
            }

            if {[llength $updates] > 0} {
                notifier send $subject <Monitor>
            }
            

            # NEXT, clear the updates array
            set updates [list]

            # NEXT, remove the monitor traces
            $self DeleteMonitorTriggers
        }
    }


    # AddMonitorTrigger table operation
    #
    # table       - The table name
    # operation   - INSERT, UPDATE, or DELETE
    #
    #
    # Adds a monitor trigger to the specified table for the 
    # specified operation, and returns a DELETE statement for
    # the trigger.

    method AddMonitorTrigger {table operation} {
        if {$operation eq "DELETE"} {
            set optype delete
            set keyExpr old.[join $monitors($table) " || ' ' || old."]
        } else {
            set optype update
            set keyExpr new.[join $monitors($table) " || ' ' || new."]
        }

        set trigger sqldocument_monitor_${table}_$operation

        $db eval "
            DROP TRIGGER IF EXISTS $trigger;
            CREATE TEMP TRIGGER $trigger
            AFTER $operation ON $table BEGIN 
                SELECT sqldocument_monitor('$table','$optype',$keyExpr);
            END;
        "
    }

    # DeleteMonitorTriggers
    #
    # Deletes all monitor triggers.

    method DeleteMonitorTriggers {} {
        foreach table [array names monitors] {
            $db eval "
                DROP TRIGGER IF EXISTS sqldocument_monitor_${table}_INSERT;
                DROP TRIGGER IF EXISTS sqldocument_monitor_${table}_UPDATE;
                DROP TRIGGER IF EXISTS sqldocument_monitor_${table}_DELETE;
            "
        }
    }

    # RowMonitorFunc table operation keyval
    #
    # table     - A table name.
    # operation - create|update|delete
    # keyval    - Key value or values that identifies the modified row.
    #
    # Notes that the row has been updated.

    proc RowMonitorFunc {table operation keyval} {
        lappend updates $table $operation $keyval
    }


    #-------------------------------------------------------------------
    # SQL Functions

    # NonEmpty args...
    #
    # args...    A list of one or more arguments
    #
    # Returns the first argument that isn't "".  Like COALESCE(),
    # but treats "" like NULL.

    proc NonEmpty {args} {
        foreach arg $args {
            if {$arg ne ""} {
                return $arg
            }
        }

        return ""
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # dictget dict key
    #
    # Returns a value from a dictionary, or "" if the key isn't found.

    proc dictget {dict key} {
        if {[dict exists $dict $key]} {
            return [dict get $dict $key]
        } else {
            return ""
        }
    }

    # DictCompare a b
    #
    # a - A string
    # b - Another string
    #
    # Compares the two strings in dictionary order, returning 1 if a > b
    # and -1 otherwise.  This proc is used to implement DICT collating order.
    # Normally a comparison function like this would return 0 if a == b,
    # but this is not needed in this case.

    proc DictCompare {a b} { 
        expr {[string equal $a \
               [lindex [lsort -dictionary [list $a $b]] 0]] ? -1 : 1} 
    }


    # NullDatabase args
    #
    # args       Arguments to the db component.  Ignored.
    #
    # Used as the db component when no database is open.  Causes all 
    # methods delegated to the db to be rejected with a good error
    # message

    proc NullDatabase {args} {
        return -code error "database is not open"
    }
}
