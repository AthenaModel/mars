#-----------------------------------------------------------------------
# TITLE:
#   sqlib.tcl
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
#	SQLite utilities
#
#   SQLite is a small SQL database manager for Tcl and other
#   languages.  This module defines a number of tools for use
#   with SQLite database objects.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export sqlib
}

#-----------------------------------------------------------------------
# sqlib Ensemble

snit::type ::marsutil::sqlib {
    # Make it an ensemble
    pragma -hastypeinfo 0 -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # Transient variables for storing query data as a formatted query 
    # is produced.

    # The query options
    typevariable qopts -array {}

    # The row array
    typevariable qrow -array {}

    # For MC mode, the column widths
    typevariable qwidths -array {}

    # Other transient data, as needed by the mode
    #
    #    names   - Column names, i.e., qrow(*)
    #    out     - The output
    #    labels  - The label strings
    #    rows    - In MC mode, the actual rows of data as dicts
    typevariable qtrans -array {}



    #-------------------------------------------------------------------
    # Ensemble subcommands

    # clear db
    #
    # db     The fully-qualified SQLite database command.
    #
    # Deletes all persistent and temporary schema elements from the 
    # database.  Attached databases are ignored.

    typemethod clear {db} {
        set sql [list]

        $db eval {
            SELECT type AS dbtype, name FROM sqlite_master
            WHERE type IN ('table', 'view')
            UNION ALL
            SELECT type AS dbtype, name FROM sqlite_temp_master 
            WHERE type IN ('table', 'view')
        } {
            switch -exact -- $dbtype {
                table {
                    if {![string match "sqlite*" $name]} {
                        lappend sql "DROP TABLE $name;"
                    } else {
                        lappend sql "DELETE FROM $name;"
                    }
                }

                view {
                    lappend sql "DROP VIEW $name;"
                }
                default {
                    # Do nothing
                }
            }
        }

        $db eval [join $sql "\n"]
    }

    # saveas db filename
    #
    # db          The fully-qualified SQLite database command.
    # filename    A file name
    #
    # Saves a copy of the persistent contents of db as a new 
    # database file called filename.  It's an error if filename
    # already exists.

    typemethod saveas {db filename} {
        require {![file exists $filename]} \
            "File already exists: \"$filename\""

        # FIRST, create the saveas database.  This might throw
        # an error if the database cannot be opened.
        sqlite3 sadb $filename

        # NEXT, copy the schema and the user_version
        sadb transaction {
            set ver [$db eval {PRAGMA user_version}]

            sadb eval "PRAGMA user_version=$ver"

            $db eval {
                SELECT sql FROM sqlite_master 
                WHERE sql NOT NULL
                AND name NOT GLOB 'sqlite*'
            } {
                sadb eval $sql
            }
        }

        # NEXT, close the saveas database, and attach it to
        # db temporarily so we can copy tables.  If db is
        # in a transaction, we need to commit it. (Sigh!)

        sadb close

        $db eval "ATTACH DATABASE '$filename' AS saveas"

        # NEXT, copy the tables
        set tableList [$db eval {
            SELECT name FROM sqlite_master 
            WHERE type='table'
            AND name NOT GLOB 'sqlite*'
        }]

        $db transaction {
            foreach table $tableList {
                $db eval "INSERT INTO saveas.$table SELECT * FROM main.$table"
            }
        }

        # NEXT, detach the saveas database.
        $db eval {DETACH DATABASE saveas}
    }

    # compare db1 db2
    #
    # db1     A fully-qualified SQLite database command.
    # db2     Another fully-qualified SQLite database command.
    #
    # Compares the two databases, ignoring attached databases and
    # temporary entities.  Returns a string describing the first
    # difference found, or "" if no differences are found.  This is
    # not a particularly fast operation for large databases.
    #
    # First the schema is compared, and then the content of the
    # individual tables.

    typemethod compare {db1 db2} {
        set rows [list]

        # FIRST, get the rows from db1's master table
        $db1 eval {
            SELECT * FROM sqlite_master
            WHERE name NOT GLOB "sqlite*"
            ORDER BY name
        } row1 {
            lappend rows [array get row1]
        }

        # NEXT, compare them against the rows from db2's master table
        $db2 eval {
            SELECT * FROM sqlite_master
            WHERE name NOT GLOB "sqlite*"
            ORDER BY name
        } row2 {
            if {[llength $rows] == 0} {
                return \
                    "In $db2, found $row2(type) $row2(name), missing in $db1"
            }

            array set row1 [lshift rows]

            if {$row1(name) ne $row2(name)} {
                return \
    "In $db2, found $row2(type) $row2(name), expected $row1(type) $row1(name)"
            }

            foreach column {type tbl_name sql} {
                if {$row1($column) ne $row2($column)} {
                    return \
                        "Mismatch on \"$column\" for $row1(type) $row1(name)"
                }
            }
        }

        if {[llength $rows] > 0} {
            array set row1 [lshift rows]

            return "In $db1, found $row1(type) $row1(name), missing in $db2"
        }

        # NEXT, compare the individual tables.
        set tableList [$db1 eval {
            SELECT name FROM sqlite_master
            WHERE name NOT GLOB 'sqlite*'
            AND type == 'table'
            ORDER BY name
        }]

        foreach table $tableList {
            # FIRST, get all of the rows in db1's table
            set rows [list]
            array unset row1
            array unset row2

            $db1 eval "
                SELECT * FROM $table
            " row1 {
                unset -nocomplain row1(*)
                lappend rows [array get row1]
            }

            # NEXT, compare against each row in db2's table
            $db2 eval "
                SELECT * FROM $table
            " row2 {
                unset -nocomplain row2(*)

                if {[llength $rows] == 0} {
                    return \
                        "Table $table contains more rows in $db2 than in $db1"
                }

                array unset row1
                array set row1 [lshift rows]

                foreach column [array names row1] {
                    if {$row1($column) ne $row2($column)} {
                        return \
      "Mismatch on \"$column\" for table $table:\n$db1: [array get row1]\n$db2: [array get row2]"
                    }
                }
            }

            if {[llength $rows] > 0} {
                return "Table $table contains more rows in $db1 than in $db2"
            }
        }

        return ""
    }


    # tables db
    #
    # db     The fully-qualified SQLite database command.
    #
    # Returns a list of the names of the tables defined in the database.
    # Includes attached databases.

    typemethod tables {db} {
        set cmd {
            SELECT name FROM sqlite_master WHERE type='table'
            UNION ALL
            SELECT name FROM sqlite_temp_master WHERE type='table'
        }

        $db eval {PRAGMA database_list} {
            if {$name != "temp" && $name != "main"} {
                append cmd \
                    "UNION ALL SELECT '$name.' || name FROM $name.sqlite_master
                     WHERE type='table'"
            }
        }

        append cmd { ORDER BY 1 }

        return [$db eval $cmd]
    }

    # schema db ?table?
    #
    # db      The fully-qualified SQLite database command.
    # table   A table name or glob-pattern.
    #
    # Returns the SQL statements that define the schema.  If table
    # is given, returns only those tables/views/indices whose names
    # match the pattern.  Skips attached tables.

    typemethod schema {db {table "*"}} {
        set cmd {
            SELECT sql FROM sqlite_master 
            WHERE name GLOB $table
            AND sql NOT NULL 
            UNION ALL 
            SELECT sql FROM sqlite_temp_master
            WHERE name GLOB $table
            AND sql NOT NULL
        }

        return [join [$db eval $cmd] ";\n\n"]
    }

    # columns db table
    #
    # db          - The fully-qualified SQLite database command
    # table       - A table name in the db
    #
    # Returns a list of the table's column names, in order of
    # definitions, as returned by PRAGMA table_list().

    typemethod columns {db table} {
        set names [list]

        $db eval "PRAGMA table_info($table)" row {
            lappend names $row(name)
        }

        return $names
    }

    # query db sql ?options...?
    #
    # db            The fully-qualified SQLite database command.
    # sql           An SQL query.
    # options       Formatting options
    #
    #   -mode mc|list|csv    Display mode: mc (multicolumn), record list,
    #                        or CSV.
    #   -maxcolwidth num     Maximum displayed column width, in 
    #                        characters.
    #   -labels list         List of column labels.
    #   -headercols n        Number of header columns (default 0)
    #
    # Executes the query and accumulates the results into a nice
    # formatted output.
    #
    # If -mode is "list", each record is output in two-column
    # format: name  value, etc., with a blank line between records.
    #
    # If -mode is "mc" (the default) then multicolumn output is used.
    # In this mode, long values are truncated to -maxcolwidth.
    #
    # In either case, newlines are escaped.  If -labels is specified,
    # it is a list of column labels which are displayed instead of the 
    # column names used in the query.
    #
    # If -mode is "mc" and -headercols is greater than 0, then 
    # duplicate entries in the leading columns are omitted.
    #
    # If -mode is "csv", each record is output in CSV format.  
    # Non-numeric values are double-quoted, and individual " characters
    # in data are quoted as "".  No other translations are done.

    typemethod query {db sql args} {
        # FIRST, get options.
        array unset qopts
        array set qopts {
            -mode         mc
            -maxcolwidth  30
            -labels       {}
            -headercols   0
        }
        array set qopts $args

        # NEXT, prepare for the query.  Every mode uses names and out;
        # other array elements can be used as desired.
        array set qtrans {
            names ""
            out   ""
            rows  {}
        }

        array unset qwidths

        switch -exact -- $qopts(-mode) {
            mc    { set rowproc ${type}::QueryMC   }
            list  { set rowproc ${type}::QueryList }
            csv   { set rowproc ${type}::QueryCSV  }
            default { 
                error "Unknown -mode: \"$qopts(-mode)\"" 
            }
        }

        # NEXT, do the query:
        uplevel 1 [list $db eval $sql ::marsutil::sqlib::qrow $rowproc]

        # NEXT, if the mode is not "mc" we're done.
        if {$qopts(-mode) eq "mc"} {
            set out [FormatQueryMC]
        } else {
            set out $qtrans(out)
        }

        array unset qtrans
        array unset qrow
        array unset qopts
        array unset qwidths

        return $out
    }

    # QueryMC
    #
    # Save individual rows for MC mode

    proc QueryMC {} {
        # FIRST, The first time get the column names
        if {[llength $qtrans(names)] == 0} {
            # FIRST, get the column names
            set qtrans(names) $qrow(*)
            unset qrow(*)

            # NEXT, get the labels
            if {[llength $qopts(-labels)] > 0} {
                set qtrans(labels) $qopts(-labels)
            } else {
                set qtrans(labels) $qtrans(names)
            }

            # NEXT, initialize the column width array with the label widths
            foreach name $qtrans(names) label $qtrans(labels) {
                set qwidths($name) [string length $label]
            }
        }

        # NEXT, do translation on the data, and get the column widths.
        foreach name $qtrans(names) {
            set qrow($name) [string map [list \n \\n] $qrow($name)]

            set len [string length $qrow($name)]

            if {$qopts(-maxcolwidth) > 0} {
                if {$len > $qopts(-maxcolwidth)} {
                    # At least three characters
                    set len [::marsutil::max $qopts(-maxcolwidth) 3]
                    set end [expr {$len - 4}]
                    set qrow($name) \
                        "[string range $qrow($name) 0 $end]..."
                }
            }

            if {$len > $qwidths($name)} {
                set qwidths($name) $len
            }
        }

        # NEXT, save the row
        lappend qtrans(rows) [array get qrow]
    }

    # FormatQueryMC
    #
    # Formats the current query rows.

    proc FormatQueryMC {} {
        # FIRST, were there any rows?
        if {[llength $qtrans(rows)] == 0} {
            return ""
        }

        # NEXT, format the header lines.
        set out ""

        foreach label $qtrans(labels) name $qtrans(names) {
            append out [format "%-*s " $qwidths($name) $label]
        }
        append out "\n"

        foreach name $qtrans(names) {
            append out [string repeat "-" $qwidths($name)]
            append out " "

            # Initialize the lastrow array
            set lastrow($name) ""
        }
        append out "\n"
        
        # NEXT, format the rows
        foreach entry $qtrans(rows) {
            array set row $entry

            set i 0
            foreach name $qtrans(names) {
                # Append either the column value or a blank, with the
                # required width
                if {$i < $qopts(-headercols) && 
                    $row($name) eq $lastrow($name)} {
                    append out [format "%-*s " $qwidths($name) "\""]
                } else {
                    append out [format "%-*s " $qwidths($name) $row($name)]
                }
                incr i
            }
            append out "\n"

            array set lastrow $entry
        }

        return $out
    }

    # QueryList
    #
    # Handle individual rows for list mode

    proc QueryList {} {
        # FIRST, The first time figure out what the labels are.
        if {[llength $qtrans(names)] == 0} {
            # FIRST, get the column names
            set qtrans(names) $qrow(*)
            unset qrow(*)

            # NEXT, if they specified labels use them
            if {[llength $qopts(-labels)] > 0} {
                set qtrans(labels) $qopts(-labels)
            } else {
                set qtrans(labels) $qtrans(names)                
            }

            # NEXT, What's the maximum label width?
            set qtrans(labelWidth) [lmaxlen $qtrans(labels)]

            # NEXT, initialize the count.
            set qtrans(count) 0
        }

        # NEXT, output the record
        incr qtrans(count)

        if {$qtrans(count) > 1} {
            append qtrans(out) "\n"
        }

        foreach label $qtrans(labels) name $qtrans(names) {
            set leader [string repeat " " $qtrans(labelWidth)]

            regsub -all {\n} [string trimright $qrow($name)] \
                "\n$leader  " value

            append qtrans(out) \
                [format "%-*s  %s\n" $qtrans(labelWidth) $label $value]
        }

    }

    # QueryCSV 
    #
    # Handle individual rows for CSV mode

    proc QueryCSV {} {
        # FIRST, The first time figure out what the labels are.
        if {[llength $qtrans(names)] == 0} {
            # FIRST, get the column names
            set qtrans(names) $qrow(*)
            unset qrow(*)

            # NEXT, if they specified labels use those instead
            if {[llength $qopts(-labels)] > 0} {
                append qtrans(out) [CsvRecord $qopts(-labels)]
            } else {
                append qtrans(out) [CsvRecord $qtrans(names)]
            }

        }

        # NEXT, output the record
        set record [list]

        foreach col $qtrans(names) {
            lappend record $qrow($col)
        }

        append qtrans(out) [CsvRecord $record]

    }

    # CsvRecord record
    #
    # record   - A list of values
    #
    # Quotes the list entries as a record in a CSV file.

    proc CsvRecord {record} {
        # FIRST, convert the list to CSV column entries
        set cols [list]

        foreach value $record {
            # Quote double quotes
            set value [string map [list \" \"\"] $value]

            # If non-numeric, add double quotes
            if {![string is double -strict $value]} {
                set value "\"$value\""
            }

            lappend cols $value
        }

        return "[join $cols {,}]\n"
    }


    proc dummy {} {

        # NEXT, get the data; accumulate column widths as we go.
        set rows {}
        set names {}
        $db eval $sql row {
            if {[llength $names] eq 0} {
                set names $row(*)
                unset row(*)

                foreach name $names {
                    set colwidth($name) 0
                }
            }

            foreach name $names {
                set row($name) [string map [list \n \\n] $row($name)]

                set len [string length $row($name)]

                if {$qopts(-maxcolwidth) > 0} {
                    if {$len > $qopts(-maxcolwidth)} {
                        # At least three characters
                        set len [::marsutil::max $qopts(-maxcolwidth) 3]
                        set end [expr {$len - 4}]
                        set row($name) \
                            "[string range $row($name) 0 $end]..."
                    }
                }

                if {$len > $colwidth($name)} {
                    set colwidth($name) $len
                }
            }

            lappend rows [array get row]
        }

        if {[llength $names] == 0} {
            return ""
        }

        # NEXT, include the label widths.
        if {[llength $qopts(-labels)] > 0} {
            set labels $qopts(-labels)
        } else {
            set labels $names
        }

        foreach label $labels name $names {
            set len [string length $label]

            if {$len > $colwidth($name)} {
                set colwidth($name) $len
            }
        }

        # NEXT, format the header lines.
        set out ""

        foreach label $labels name $names {
            append out [format "%-*s " $colwidth($name) $label]
        }
        append out "\n"

        foreach name $names {
            append out [string repeat "-" $colwidth($name)]
            append out " "

            # Initialize the lastrow array
            set lastrow($name) ""
        }
        append out "\n"
        
        # NEXT, format the rows
        foreach entry $rows {
            array set row $entry

            set i 0
            foreach name $names {
                # Append either the column value or a blank, with the
                # required width
                if {$i < $qopts(-headercols) && 
                    $row($name) eq $lastrow($name)} {
                    append out [format "%-*s " $colwidth($name) "\""]
                } else {
                    append out [format "%-*s " $colwidth($name) $row($name)]
                }
                incr i
            }
            append out "\n"

            array set lastrow $entry
        }

        return $out
    }

    # mat db table iname jname ename ?options?
    #
    # db      An sqlite3 database object.
    # table   A table in the database.
    # iname   The name of the "i" or "row" column.
    # jname   The name of the "j" or "column" column.
    # ename   The name of the "element" column.
    # 
    # Options:
    #    -ikeys       A list of the "i" column keys, in the desired order
    #    -jkeys       A list of the "j" column keys, in the desired order
    #    -returnkeys  0|1.  If 1, the key lists are returned.
    #    -defvalue    Value for empty cells.
    #
    # Queries the named table, producing a matrix whose elements are
    # drawn from the element column, with the iname column defining
    # the rows and the jname column defining the columns.  If -ikeys
    # or -jkeys are specified, iname or jname values not included in
    # the lists will be excluded from the output, and the matrix rows
    # and columns will be in the order specified.  Otherwise, there
    # will be a row for each unique value in the iname column and a
    # column for each unique value in the jname column.
    #
    # Normally, the command returns the matrix.  If -returnkeys is 1,
    # the command returns a list {matrix ikeys jkeys}.

    typemethod mat {db table iname jname ename args} {
        # FIRST, get the options
        array set opts {
            -ikeys      ""
            -jkeys      ""
            -returnkeys 0
            -defvalue   ""
        }
        array set opts $args

        # NEXT, if no keys are specified, get the full list.
        if {[llength $opts(-ikeys)] == 0} {
            set opts(-ikeys) [rdb query "
                SELECT $iname FROM $table GROUP BY $iname
            "]
        }

        if {[llength $opts(-jkeys)] == 0} {
            set opts(-jkeys) [rdb query "
                SELECT $jname FROM $table GROUP BY $jname
            "]
        }

        # NEXT, get the matrix.
        set mat [mat new \
                     [llength $opts(-ikeys)] \
                     [llength $opts(-jkeys)] \
                     $opts(-defvalue)]

        rdb eval "
            SELECT $iname AS iname, 
                   $jname AS jname, 
                   $ename AS element
            FROM   $table
            WHERE  $iname IN ('[join $opts(-ikeys) ',']')
            AND    $jname IN ('[join $opts(-jkeys) ',']')
        " {
            set i [lsearch -exact $opts(-ikeys) $iname]
            set j [lsearch -exact $opts(-jkeys) $jname]

            lset mat $i $j $element
        }

        # NEXT, return the result.
        if {$opts(-returnkeys)} {
            return [list $mat $opts(-ikeys) $opts(-jkeys)]
        } else {
            return $mat
        }
    }

    # insert db table dict
    #
    # db      A database handle
    # table   Name of a table in db
    # dict    A dictionary whose keys are column names in the table
    #
    # Inserts the contents of dict into table.  This will be less
    # efficient than an explicit "INSERT INTO" with hardcoded column
    # names, but where performance isn't an issue it wins on 
    # maintainability.
    #
    # WARNING: None of the dict columns can be named "sqlib_table".

    typemethod insert {db table dict} {
        set sqlib_table $table
        set keys [dict keys $dict]

        dict with dict {
            $db eval [tsubst {
                INSERT INTO ${sqlib_table}([join $keys ,])
                VALUES(\$[join $keys ,\$])
            }]
        }
    }

    # replace db table dict
    #
    # db      A database handle
    # table   Name of a table in db
    # dict    A dictionary whose keys are column names in the table
    #
    # Inserts or replaces the contents of dict into table.  This will 
    # be less efficient than an explicit "INSERT OR REPLACE INTO" with 
    # hardcoded column names, but where performance isn't an issue it 
    # wins on  maintainability.
    #
    # WARNING: None of the dict columns can be named "sqlib_table".

    typemethod replace {db table dict} {
        set sqlib_table $table
        set keys [dict keys $dict]

        dict with dict {
            $db eval [tsubst {
                INSERT OR REPLACE INTO ${sqlib_table}([join $keys ,])
                VALUES(\$[join $keys ,\$])
            }]
        }
    }

    # grab db ?-insert? table condition ?table condition...?
    #
    # db        - A database handle
    # table     - Name of a table in db
    # condition - A WHERE expression describing rows in the table.
    #
    # Grabs a collection of rows from one or more tables in the 
    # database, and returns them to the user as one value, a 
    # flat list with structure
    #
    #    <table> <values> ...
    #
    # where <table> is the table name and <values> is a flat list 
    # of column values for the columns in table. NULLs are reported
    # using the SQLite3 "nullvalue"; [ungrab] converts them back to NULLs.
    #
    # If the -insert option is included, the table name will be the list
    # {tableName INSERT}, and [ungrab] will INSERT the rows instead of
    # UPDATE-ing them.

    typemethod grab {db args} {
        # FIRST, get the insert flag.
        if {[lindex $args 0] eq "-insert"} {
            set insertFlag 1
            lshift args
        } else {
            set insertFlag 0
        }

        # NEXT, prepare to stash the grabbed data
        set result [list]

        # NEXT, grab rows for each table.
        foreach {table condition} $args {
            set columns [sqlib columns $db $table]

            # TBD: Use "*"?
            set query "SELECT [join $columns ,] FROM $table"

            if {$condition ne ""} {
                append query " WHERE $condition"
            }
            
            set rows [uplevel 1 [list $db eval $query]]

            if {$insertFlag} {
                set tableSpec [list $table INSERT]
            } else {
                set tableSpec $table
            }

            if {[llength $rows] > 0} {
                lappend result $tableSpec $rows
            }
        }

        return $result
    }

    # ungrab db data
    #
    # db       - A database handle
    # data     - A list {table values ?table values...?} as returned
    #            by grab.  Note that the <table> is a list
    #            {tableName ?INSERT?}.
    #
    # Puts row data into each table using UPDATE, or INSERT if the
    # table spec includes the INSERT tag.  The same table may appear
    # multiple times.  Each "values" entry must be a list of column
    # values in Tcl format; values matching the SQLite3 "nullvalue"
    # will be put into the database as NULLs.  The length of the "values" 
    # entry must be a multiple of the number of columns in the table.

    typemethod ungrab {db data} {
        foreach {table values} $data {
            if {[llength $values] == 0} {
                continue
            }

            # FIRST, parse the table spec.
            lassign $table tableName tag
            
            # NEXT, get the number of columns in this table.
            set ncols [llength [sqlib columns $db $tableName]]

            require {$ncols > 0} "Unknown table: \"$tableName\""

            # NEXT, get the SQL statements for this table
            # and set of values.
            if {$tag eq "INSERT"} {
                InsertGrabValues $db $tableName $ncols $values
            } else {
                UpdateGrabValues $db $tableName $values
            }
        }
        return
    }

    # InsertGrabValues db table ncols values
    #
    # db     - The database
    # table  - A table name
    # ncols  - Number of columns in table
    # values - A list of column values comprising 1 to N distinct rows.
    #
    # Inserts the grab values into the table.

    proc InsertGrabValues {db table ncols values} {
        # FIRST, create the query string.
        set vars [list]
        set nul [$db nullvalue]
        for {set i 0} {$i < $ncols} {incr i} {
            lappend vars "nullif(\$b($i),\$nul)"
        }

        set sql "INSERT INTO $table VALUES([join $vars ,]);"

        # NEXT, insert the rows
        set i 0

        foreach val $values {
            set b($i) $val
            incr i

            if {$i == $ncols} {
                set i 0
                $db eval $sql
            }
        }
    }

    # UpdateGrabValues db table values
    #
    # db     - The database
    # table  - A table name
    # values - A list of column values comprising 1 to N distinct rows.
    #
    # Returns SQL code to update the matching rows in the table.

    proc UpdateGrabValues {db table values} {
        # FIRST, get the key names and column names.
        set columns [list]

        $db eval "PRAGMA table_info($table)" data {
            lappend columns $data(name)
            set key($data(name)) $data(pk)
        }
        
        set ncols [llength $columns]

        # NEXT, build the update statement
        set ands [list]
        set sets [list]
        set nul [$db nullvalue]

        for {set i 0} {$i < $ncols} {incr i} {
            set col [lindex $columns $i]

            if {$key($col)} {
                lappend ands "$col=\$b($i)"
            } else {
                lappend sets "$col=nullif(\$b($i),\$nul)"
            }
        }

        set sql "UPDATE $table SET [join $sets ,] WHERE [join $ands { AND }]"

        # NEXT, update the rows
        set i 0

        foreach val $values {
            set b($i) $val
            incr i

            if {$i == $ncols} {
                $db eval $sql
                set i 0
            }
        }
    }

    # fklist db table ?-indirect?
    #
    # db      - A database handle
    # table   - A table in the database
    #
    # Retrieves a list of the tables that have foreign keys that
    # references the given table.  If the -indirect option is given,
    # tables that depend on those are included.

    typemethod fklist {db table {opt ""}} {
        if {$opt ni {"" -indirect}} {
            error "invalid option: \"$opt\""
        }

        # FIRST, get the basic dependency data
        set tables [sqlib tables $db]

        if {$table ni $tables} {
            error "unknown table: \"$table\""
        }

        foreach tab $tables {
            $db eval "PRAGMA foreign_key_list($tab)" row {
                ladd dep($row(table)) $tab
            }
        }

        # NEXT, if there are no dependencies on this table, return
        # the empty list.
        if {![info exists dep($table)]} {
            return [list]
        }

        # NEXT, if they just want the direct dependencies, return them.
        if {$opt eq ""} {
            # The user knows the table depends on itself; if there's
            # a foreign key, ignore it.
            ldelete dep($table) $table
            return $dep($table)
        }

        # NEXT, if they want the indirect dependencies, compute and return
        # them.
        
        lappend depList $table
        set result [list]

        while {[llength $depList] > 0} {
            set next [lshift depList]
            if {$next ni $result} {
                lappend result $next

                if {[info exists dep($next)]} {
                    lappend depList {*}$dep($next)
                }
            }
        }

        # Skip the original table
        return [lrange $result 1 end]
    }
}





