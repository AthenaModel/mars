#-----------------------------------------------------------------------
# TITLE:
#   tabletext.tcl
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
#    tabletext(n) object: generic SQLite table/text file processor.  
#    Parses text files into SQLite tables, and validates the contents, 
#    given schema information provided by the caller.  Eventually, it
#    will probably also produce loadable text files from SQLite tables.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export tabletext
}

#-----------------------------------------------------------------------
# tabletext

snit::type ::marsutil::tabletext {
    #-------------------------------------------------------------------
    # Instance Variables

    # interp -- array of interpreters
    #
    # table     Interpreter for "table" command
    # record    Interpreter for "record" command
    # field     Interpreter for "field" command

    variable interp

    # schema  --  array of schema information
    #
    # tables                   List of tables name
    # dependson-$table         List of names of tables which must be
    #                          processed prior to this table.
    # tv-$table                Table validator command.
    # rv-$table                Record validator command.
    # fields-$table            List of field names
    # keys-$table              List of key field names
    # writeable-$table         -writeable table flag
    # fv-$table-$field         Field validator command.
    # unique-$table-$field     -unique field flag
    # required-$table-$field   -required field flag
    # default-$table-$field    -default field value
    # format-$table-$field     -formatcmd field value
    
    variable schema -array {
        tables {}
    }

    # info -- Array of information used while parsing.
    #         It is cleared after each parse.
    #
    # db           The SQLite3 db into which the data is being parsed.
    # table        The name of the table currently being parsed.
    # rooterr      Prefix for error messages.
    # row          The ROWID of the new record.
    # seen-$table  1 if we've parsed $table, and 0 otherwise.

    variable info

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        # FIRST, create the table interpreter.
        set interp(table) [interp create -safe]
        
        eval $interp(table) alias _table [mymethod ParseTable]

        $interp(table) eval {
            proc table {table records} {
                _table $table $records
            }
        }
        
        # NEXT, create the record interpreter.
        # TBD: Use a smartinterp
        set interp(record) [interp create -safe]
        
        eval $interp(record) alias _record [mymethod ParseRecord]

        $interp(record) eval {
            proc record {args} {
                _record $args
            }
        }

        # NEXT, create the field interpreter.
        set interp(field) [interp create -safe]
        
        eval $interp(field) alias _field [mymethod ParseField]

        $interp(field) eval {
            proc field {fieldName value} {
                _field $fieldName $value
            }
        }
    }

    #-------------------------------------------------------------------
    # Schema Definition Methods

    # table name options...
    #
    # name       The table's name in SQLite database, and in the input
    #            text
    #
    # -tablevalidator cmd
    #     Called when the table is defined, to validate cross-record
    #     constraints.  Called with SQLite db name and table name.
    #
    # -recordvalidator cmd
    #     Called when the record is defined, to validate cross-field
    #     constraints.  Called with db name, table name, and rowid.
    #
    # -dependson list
    #     The listed tables must be processed before this table.  If
    #     they haven't been, that's an error.

    method table {table args} {
        # FIRST, we can't already have a table with this name.
        require {[lsearch -exact $schema(tables) $table] == -1} \
            "Duplicate table name: \"$table\""

        lappend schema(tables) $table

        # NEXT, initialize the schema
        set schema(keys-$table)      {}
        set schema(fields-$table)    {}
        set schema(writeable-$table) 1
        set schema(tv-$table)        ""
        set schema(rv-$table)        ""
        set schema(dependson-$table) {}

        # NEXT, process the options.
        foreach {opt val} $args {
            switch -exact -- $opt {
                -tablevalidator {
                    set schema(tv-$table) $val
                }
                
                -recordvalidator {
                    set schema(rv-$table) $val
                }

                -dependson {
                    # FIRST, validate the names
                    foreach t $val {
                        require {[lsearch -exact $schema(tables) $t] != -1} \
                            "unknown table in -dependson: \"$t\""
                    }
                    
                    # NEXT, save the list
                    set schema(dependson-$table) $val
                }

                -writeable {
                    set schema(writeable-$table) $val
                }

                default {
                    error "unknown table option: \"$opt\""
                }
            }
        }
    }

    # field table field options...
    #
    # table     Name of table
    # field     Name of key field
    # 
    # -key
    #    Field is a component of the primary key.
    #
    # -unique
    #    Field's value must be unique.
    #
    # -required
    #    Field's value must be required.
    #
    # -validator cmd
    #    Command used to validate the field's value.  Called 
    #    with db name, table name, and value.
    #
    # -default value
    #    The default value for the field.
    #
    # -formatcmd cmd
    #    Command used to output the field's value. 
    #
    # Defines a field

    method field {table field args} {
        require {[lsearch -exact $schema(tables) $table] != -1} \
            "Invalid table name: \"$table\""

        require {[lsearch -exact $schema(fields-$table) $field] == -1} \
            "Duplicate field name in $table: \"$field\""

        # NEXT, initialize the schema
        lappend schema(fields-$table) $field
        
        set schema(unique-$table-$field) 0
        set schema(required-$table-$field) 0
        set schema(fv-$table-$field) ""
        set schema(format-$table-$field) ""

        # NEXT, process the options.
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -key {
                    lappend schema(keys-$table) $field
                }
                -unique {
                    set schema(unique-$table-$field) 1
                }
                -required {
                    set schema(required-$table-$field) 1
                }
                -validator {
                    set schema(fv-$table-$field) [lshift args]
                }
                -formatcmd {
                    set schema(format-$table-$field) [lshift args]
                }
                -default {
                    set schema(default-$table-$field) [lshift args]
                }

                default {
                    error "unknown field option: \"$opt\""
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Database Update methods

    # clear db
    #
    # db    An sqlite3 database object
    #
    # Deletes all tables of the defined kinds from the database.

    method clear {db} {
        foreach table $schema(tables) {
            $db eval "DELETE FROM $table"
        }
    }

    # loadfile db filename ?preamble?
    #
    # db        An sqlite3 database object
    # filename  A simdb(5) file
    # preamble  Additional text to parse prior to the file's content.
    #
    # Loads the text from the file, and parses it.

    method loadfile {db filename {preamble ""}} {
        # FIRST, clear the database tables
        $self clear $db

        # NEXT, get the file's content.
        set f [open $filename r]
        
        set text [read $f]
        
        close $f

        # NEXT, parse it
        $self ParseInput $db "$preamble\n$text" $filename

    }

    # load db text ?preamble?
    #
    # db      An sqlite3 database object
    # text    Table data text to parse
  
    method load {db text {preamble ""}} {
        $self clear $db

        $self ParseInput $db "$preamble\n$text"
    }

    #------------------------------------------------------------------
    # Database writing methods

    # writefile db outfile infile
    #
    # db         An sqlite3 database object
    # outfile    The file to write the simdb(5) file to
    # infile     The simdb(5) file that was previously read in
    #
    # This method writes the tabletext(n) data out to
    # the simdb(5) file format. Any comments from the
    # originally read simdb are not retained.

    method writefile {db outfile infile} {
        # FIRST, open the file for writing
        set f [open $outfile w]

        # NEXT, write the header
        puts $f [writeFileHeader $outfile $infile]

        # NEXT, go through the tables in order writing
        # each one as we go
        foreach table $schema(tables) {
            # NEXT, if the table is not writeable, skip it
            if {!$schema(writeable-$table)} {continue}

            # NEXT, initialize table output
            set tableout ""
            $db eval "
                SELECT * FROM $table 
            " row {
                # NEXT, records which are the key fields, if any
                set recname "\n    record"
                foreach key $schema(keys-$table) {
                    append recname " $key $row($key)"
                }

                set fields ""
                # NEXT, write the fields associated with the record
                foreach field $schema(fields-$table) {
                    # NEXT, No need to write the keys as a field
                    if {$field in $schema(keys-$table)} {
                        continue
                    }

                    # NEXT, No need to write empty fields
                    if {$row($field) eq ""} {continue}

                    # NEXT, format the field for writing
                    set ffield $row($field)
                    if {[string first " " $row($field)] > -1} {
                        set ffield \
                            [$self FormatField $table $field $row($field)]
                    }

                    append fields "\n        field $field [list $ffield]"
                }
                # NEXT, make indentation look nice at the end of a record
                append fields "\n    "

                # NEXT, add the record to the table
                append tableout "$recname [list $fields]\n"
            }
            # NEXT, dump the table to the file
            puts $f "table $table [list $tableout]\n"
        }
        close $f
    }

    # FormatField table field value
    #
    # table     the name of the table the field is from
    # field     the name of the field
    # value     the value to be formatted
    #
    # This method formats a field value for output. If a -formatcmd was 
    # specified for a field it is called. If not, the default format
    # is used.
    #

    method FormatField {table field value} {
        # FIRST, if a -formatcmd option was specified call that with the
        # value
        if {$schema(format-$table-$field) ne ""} {
            if {[catch {
                    callwith $schema(format-$table-$field) $value
                } result]} {
                    error "could not format field $field: $value\n$result"
                }

           set value $result

        } else {
            # Default behavior
            # FIRST, split along carriage returns
            set lines [split $value "\n"]

            # NEXT, if there is one line, assume a single token and
            # return it.
            if {[llength $lines] == 1} {
                return $value
            }

            # NEXT, build up a single token that consists of properly indented
            # text so it looks nice on output.
            set value "\n            [lindex $lines 0]\n"
            set lines [lrange $lines 1 end]
            foreach line $lines {
                append value "            $line\n"
            }
            append value "        "
        }

        return $value
    }

    # writeFileHeader filename infile
    #
    # filename     the name of the file being written
    # infile       the name of the db file that was previously read
    #
    # This helper proc outputs a simple file header indicating when the
    # file was written, what the source file was and the name of the output
    # file

    proc writeFileHeader {filename infile} {
        set timeformat {%Y-%m-%d %H:%M:%S}
        set header "
        #-------------------------------------------------------------------
        # TITLE:
        #     automatically generated simdb: [file tail $filename]
        #     this file was generated from db: [file tail $infile]
        #     generated on [clock format [clock seconds] -format $timeformat]
        #"
        return [outdent "$header\n"]
    }

    #-------------------------------------------------------------------
    # Parsing Methods

    # ParseInput db text ?filename?
    #
    # db        An sqlite3 database object
    # text      Table data text to parse
    # filename  Name of file containing text

    method ParseInput {db text {filename ""}} {
        # FIRST, initialize the parse info
        array unset info
        set info(db) $db

        foreach table $schema(tables) {
            set info(seen-$table) 0
        }

        if {$filename eq ""} {
            set info(rooterr) "Error in "
        } else {
            set info(rooterr) "Error in $filename, "
        }

        # NEXT, Evaluate the input text in the "table" interpreter.
        $interp(table) eval $text

        # NEXT, call the validators for all unseen tables
        foreach table $schema(tables) {
            if {!$info(seen-$table)} {
                $self ValidateTable $table
            }
        }
    }

    # ParseTable table records
    #
    # table     The table name
    # records   The record definition script for this table
    #
    # Called by the "table" command in the input.

    method ParseTable {table records} {
        # FIRST, set the error root
        set oldRoot $info(rooterr)
        append info(rooterr) "table $table"

        # NEXT, is the table valid?
        require {[lsearch -exact $schema(tables) $table] != -1} \
            "$info(rooterr), invalid table name: \"$table\""

        # NEXT, have we seen the tables this table depends on?
        foreach t $schema(dependson-$table) {
            require {$info(seen-$t)} \
                "$info(rooterr), table $t must be defined first but wasn't"

        }

        # NEXT, set up the info array for this table.
        set info(table) $table
        set info(row) 0

        # NEXT, parse the records
        $interp(record) eval $records

        # NEXT, validate the table as a whole.
        $self ValidateTable $table

        # NEXT, restore the old error root
        set info(rooterr) $oldRoot

        # NEXT, mark the table parsed.
        set info(seen-$table) 1
    }

    # ValidateTable table
    #
    # table    Table name
    #
    # Calls the table validator for the table

    method ValidateTable {table} {
        # FIRST, set the error root
        set oldRoot $info(rooterr)
        set info(rooterr) "table $table"

        # NEXT, validate the table as a whole.
        if {[catch {callwith $schema(tv-$table) $info(db) $table} result]} {
            error "$info(rooterr), $result"
        }

        # NEXT, restore the old error root
        set info(rooterr) $oldRoot
    }

    # ParseRecord key value ?key value...? fields
    #
    # key      Name of a key field for info(table)
    # value    Key value
    # fields   Field definition script for this record.

    method ParseRecord {arglist} {
        # FIRST, get the keys and field definition
        set keylist  [lrange $arglist 0 end-1]
        set fields   [lindex $arglist end]

        # NEXT, set the error root
        set oldRoot $info(rooterr)
        set info(rooterr) "$oldRoot, record $keylist"

        require {[llength $keylist] % 2 == 0} \
            "missing key name or value in \"$keylist\""

        # NEXT, process the keys
        set keyCount 0
        set keyCond ""
        foreach {key value} $keylist {
            require {[lsearch -exact $schema(keys-$info(table)) $key] != -1} \
                "$info(rooterr), unknown key field: \"$key\""

            set keys($key) [$self ValidateField $key $value]

            if {$keyCount == 0} {
                set keyCond "WHERE $key='$value'"
                set keyNames $key
                set keyValues "'$value'"
            } else {
                append keyCond " AND $key='$value'"
                append keyNames ",$key"
                append keyValues ",'$value'"
            }

            incr keyCount
        }

        # NEXT, do we have all of them?
        require {$keyCount == [llength $schema(keys-$info(table))]} \
            "incomplete key list"

        # NEXT, if there's already a record with this set of keys that's
        # an error--assuming that this table has any keys at all.
        if {$keyCount > 0} {
            $info(db) eval "SELECT ROWID FROM $info(table) $keyCond" {
                error "$info(rooterr), keys duplicate previous record"
            }
        }

        # NEXT, create the record in the database
        if {$keyCount > 0} {
            $info(db) eval \
                "INSERT INTO $info(table)($keyNames) VALUES($keyValues)"
        } else {
            # Insert a blank row
            set field [lindex $schema(fields-$info(table)) 0]
            $info(db) eval \
                "INSERT INTO $info(table)($field) VALUES ('')"
        }

        set info(row) [$info(db) last_insert_rowid]

        # NEXT, process default values
        foreach field $schema(fields-$info(table)) {
            if {[info exists schema(default-$info(table)-$field)]} {
                $info(db) eval "
                    UPDATE $info(table)
                    SET $field=\$schema(default-$info(table)-$field)
                    WHERE ROWID=\$info(row)
                "
            }
        }

        # NEXT, process the fields
        if {[catch {
            $interp(field) eval $fields
        } result]} {
            if {[string match {Error in*} $result]} {
                error $result
            } else {
                error "$info(rooterr), $result"
            }
        }

        # NEXT, verify that all required fields are present.
        foreach field $schema(fields-$info(table)) {
            if {!$schema(required-$info(table)-$field)} {
                continue
            }

            set value [$info(db) onecolumn \
                    "SELECT $field FROM $info(table) WHERE ROWID=\$info(row)"]

            if {$value eq ""} {
                error "$info(rooterr), missing field: $field"
            }
        }

        # NEXT, validate the record
        if {$schema(rv-$info(table)) ne ""} {
            if {[catch {
                callwith $schema(rv-$info(table)) $info(db) $info(table) $info(row)
            } result]} {
                error "$info(rooterr), $result"
            }
        }

        # Restore the caller's error root.
        set info(rooterr) $oldRoot
    }

    # ParseField field value
    #
    # field    The field name
    # value    The value
    #
    # Validates the value; if valid, inserts it into the database.

    method ParseField {field value} {
        # FIRST, set the error root
        set oldRoot $info(rooterr)
        set info(rooterr) "$oldRoot, field $field"

        # NEXT, call the validator on the value
        set value [$self ValidateField $field $value]

        # NEXT, is it suppose to be unique?
        if {$schema(unique-$info(table)-$field)} {
            set count [$info(db) onecolumn \
                    "SELECT count(ROWID) FROM $info(table) WHERE $field=\$value"]

            require {$count == 0} \
                "$info(rooterr), $field value is not unique: \"$value\""
        }

        # NEXT, insert the value into the database.
        $info(db) eval "
            UPDATE $info(table) SET $field=\$value
            WHERE ROWID=\$info(row)
        "

        # NEXT, restore the old error root
        set info(rooterr) $oldRoot
    }

    # ValidateField field value
    # 
    # field      A field name in info(table)
    # value      A possible value
    #
    # Validates and canonicalizes the field, or throws an error
    
    method ValidateField {field value} {
        if {![info exists schema(fv-$info(table)-$field)]} {
            error "$info(rooterr), invalid field name"
        }

        set validator $schema(fv-$info(table)-$field)

        if {$validator ne ""} {
            if {[catch {
                callwith $validator $info(db) $info(table) $value
            } result]} {
                error "$info(rooterr), $result"
            } else {
                # The validator canonicalized the value
                set value $result
            }
        }

        return $value
    }
    
    #-------------------------------------------------------------------
    # Generic Field Validators
    #
    # All validators take at least three arguments:
    #
    # db         The SQLite3 or sqldocument(n) object
    # table      The current table name
    # value      The value to validate
    #
    # Some take additional arguments at the beginning of the argument
    # list, to parameterize the validator.
    

    # validate vtype db table value
    #
    # vtype       An validation type object
    #
    # Value must be a valid value for the validation type.
    # It is presumed that the type's validation command
    # returns the value in canonical form.

    method {validate vtype} {vtype db table value} {
        return [$vtype validate $value]
    }

    # validate foreign otherTable field db table value
    #
    # otherTable  Name of another table
    # field       Field name in that table
    #
    # Value must appear in the specified field of the specified
    # table.  If found, the value is returned.

    method {validate foreign} {otherTable field db table value} {
        $db eval "SELECT rowid FROM $otherTable WHERE $field=\$value" {
            return $value
        }

        return -code error -errorcode INVALID \
            "unknown $otherTable $field: \"$value\""
    }

    #-------------------------------------------------------------------
    # Accessor Methods

    # get default table field
    #
    # table     Name of table
    # field     Name of field
    #
    # Returns default value for the requested field.  Returns the empty
    # string if no default exists.  The table and field name must be valid.

    method {get default} {table field} {
        require {$table in $schema(tables)} \
            "Invalid table name: \"$table\""

        require {$field in $schema(fields-$table)} \
            "Invalid field name: \"$field\""
       
        if {[info exists schema(default-$table-$field)]} {
            return $schema(default-$table-$field)
        }
  
        return ""
    }
}



