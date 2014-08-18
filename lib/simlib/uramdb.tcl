#-----------------------------------------------------------------------
# TITLE:
#   uramdb.tcl
#
# PACKAGE:
#   simlib(n) -- Simulation Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Parser for the uramdb(5) database format.
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export uramdb
}

#-----------------------------------------------------------------------
# Module: uramdb
#
# This parser is based on tabletext(n) which provides a generic
# mechanism for loading data from text files into SQLite3 tables.

snit::type ::simlib::uramdb {
    # Make it a singleton
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Import needed commands
        namespace import ::marsutil::* 
    }

    #-------------------------------------------------------------------
    # sqlsection(i) implementation
    #
    # The following variables and routines implement the module's 
    # sqlsection(i) interface.

    # List of the table names.
    typevariable tableNames {
        uramdb_c
        uramdb_a
        uramdb_n
        uramdb_civ_g
        uramdb_frc_g
        uramdb_org_g
        uramdb_g
        uramdb_mn
        uramdb_hrel
        uramdb_vrel
        uramdb_sat
        uramdb_coop
    }

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "uramdb(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions.

    typemethod {sqlsection schema} {} {
        return [readfile [file join $::simlib::library uramdb.sql]]
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, if any.

    typemethod {sqlsection tempschema} {} {
        return ""
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes

    typemethod {sqlsection functions} {} {
        return [list]
    }

    #-------------------------------------------------------------------
    # Type Components

    typecomponent tt               ;# tabletext(n) object

    #-------------------------------------------------------------------
    # Lookup Tables

    # Concern Definitions
    typevariable concernDefinitions {
        table uramdb_c {
            record c AUT { }
            record c QOL { }
            record c CUL { } 
            record c SFT { } 
        }
    }

    #-------------------------------------------------------------------
    # Type Variables

    typevariable initialized 0     ;# 1 if initialized, 0 otherwise.
                                    # uramdb is initialized on first use.

    #-------------------------------------------------------------------
    # Initialization

    typemethod Initialize {} {
        # FIRST, skip if we're already initialized
        if {$initialized} {
            return
        }

        set initialized 1

        # NEXT, define the parser.
        set tt [tabletext ${type}::tt]

        #---------------------------------------------------------------
        # Table -- uramdb_c

        $tt table uramdb_c
        
        $tt field uramdb_c c -key                           \
            -validator [mytypemethod ValidateSymbolicName]

        #---------------------------------------------------------------
        # Table -- uramdb_a

        $tt table  uramdb_a                                 \
            -tablevalidator  [mytypemethod ValidateNonEmptyTable]

        $tt field uramdb_a a -key                           \
            -validator [mytypemethod ValidateSymbolicName]

        #---------------------------------------------------------------
        # Table -- uramdb_n

        $tt table  uramdb_n                                 \
            -tablevalidator  [mytypemethod ValidateNonEmptyTable]

        $tt field uramdb_n n -key                           \
            -validator [mytypemethod ValidateSymbolicName]

        #---------------------------------------------------------------
        # Table -- uramdb_civ_g

        $tt table uramdb_civ_g                                       \
            -tablevalidator  [mytypemethod ValidateNonEmptyTable]    \
            -recordvalidator [mytypemethod ValidateGroupRecord]
 
        $tt field uramdb_civ_g g -key                               \
            -validator [mytypemethod ValidateSymbolicName]

        $tt field uramdb_civ_g n -required                          \
            -validator [list $tt validate foreign uramdb_n n]

        $tt field uramdb_civ_g pop -required                        \
            -validator [mytypemethod ValidateIntMagnitude]

        #---------------------------------------------------------------
        # Table -- uramdb_frc_g

        $tt table uramdb_frc_g                                    \
            -tablevalidator  [mytypemethod ValidateNonEmptyTable] \
            -recordvalidator [mytypemethod ValidateGroupRecord]
 
        $tt field uramdb_frc_g g -key                            \
            -validator [mytypemethod ValidateSymbolicName]

        #---------------------------------------------------------------
        # Table -- uramdb_org_g

        $tt table uramdb_org_g \
            -recordvalidator [mytypemethod ValidateGroupRecord]

         $tt field uramdb_org_g g -key                            \
            -validator [mytypemethod ValidateSymbolicName]

        #---------------------------------------------------------------
        # Table -- uramdb_mn

        $tt table uramdb_mn -dependson uramdb_n                  \
            -tablevalidator  [mytypemethod Val_uramdb_mn]

        $tt field uramdb_mn m -key                               \
            -validator [list $tt validate foreign uramdb_n n]
        $tt field uramdb_mn n -key                               \
            -validator [list $tt validate foreign uramdb_n n]
        $tt field uramdb_mn proximity                            \
            -validator [list $tt validate vtype eproximity]

        #---------------------------------------------------------------
        # Table -- uramdb_hrel
        
        $tt table uramdb_hrel \
            -dependson      {uramdb_civ_g uramdb_frc_g uramdb_org_g} \
            -tablevalidator [mytypemethod Val_uramdb_hrel]

        $tt field uramdb_hrel f -key \
            -validator [list $tt validate foreign uramdb_g g]
        $tt field uramdb_hrel g -key \
            -validator [list $tt validate foreign uramdb_g g]

        $tt field uramdb_hrel hrel \
            -validator [list $tt validate vtype ::simlib::qaffinity]

        #---------------------------------------------------------------
        # Table -- uramdb_vrel
        
        $tt table uramdb_vrel \
            -dependson      {uramdb_a uramdb_civ_g uramdb_frc_g uramdb_org_g} \
            -tablevalidator [mytypemethod Val_uramdb_vrel]

        $tt field uramdb_vrel g -key \
            -validator [list $tt validate foreign uramdb_g g]
        $tt field uramdb_vrel a -key \
            -validator [list $tt validate foreign uramdb_a a]

        $tt field uramdb_vrel vrel \
            -validator [list $tt validate vtype ::simlib::qaffinity]

        #---------------------------------------------------------------
        # Table -- uramdb_sat
        
        $tt table uramdb_sat -dependson uramdb_civ_g \
            -tablevalidator [mytypemethod Val_uramdb_sat]

        $tt field uramdb_sat g -key \
            -validator [list $tt validate foreign uramdb_civ_g g]
        $tt field uramdb_sat c -key \
            -validator [list $tt validate foreign uramdb_c c]

        $tt field uramdb_sat sat \
            -validator [mytypemethod ValidateQuality qsat]
        $tt field uramdb_sat saliency \
            -validator [mytypemethod ValidateQuality qsaliency]
        

        #---------------------------------------------------------------
        # Table -- uramdb_coop
        
        $tt table uramdb_coop -dependson {uramdb_civ_g uramdb_frc_g} \
            -tablevalidator [mytypemethod Val_uramdb_coop]

        $tt field uramdb_coop f -key \
            -validator [list $tt validate foreign uramdb_civ_g g]
        $tt field uramdb_coop g -key \
            -validator [list $tt validate foreign uramdb_frc_g g]

        $tt field uramdb_coop coop \
            -validator [mytypemethod ValidateQuality qcooperation]
    }

    #-------------------------------------------------------------------
    # Generic Validators
    #
    # All validators take at least three arguments:
    #
    # db         The SQLite3 or sqldocument(n) object
    # table      The current table name
    # value      The value to validate
    #
    # Some take additional arguments at the beginning of the argument
    # list, to parameterize the validator.
    

    # ValidateSymbolicName db table value
    #
    # The value must be an "identifier" (see marsutil(n)); it
    # will be converted to uppercase.

    typemethod ValidateSymbolicName {db table value} {
        identifier validate $value
        return [string toupper $value]
    }


    # ValidateQuality qual db table value
    #
    # qual       An quality(n) object
    #
    # Value must be a valid value for the quality; the 
    # equivalent "value" is returned.

    typemethod ValidateQuality {qual db table value} {
        $qual validate $value

        return [$qual value $value]
    }


    # ValidateIntMagnitude db table value
    #
    # The value must be an integer value
    # greater than or equal to zero.

    typemethod ValidateIntMagnitude {db table value} {
        # TBD: Should use count, once count is updated.
        if {![string is integer -strict $value]} {
            invalid "non-integer input: \"$value\""
        }
            
        if {$value < 0} {
            invalid "value is negative: \"$value\""
        }

        return $value
    }

    # ValidateNonEmptyTable db table
    #
    # Verifies that the table contains at least one entry.

    typemethod ValidateNonEmptyTable {db table} {
        # Must have at least one entry
        if {[$db eval "SELECT count(rowid) FROM $table"] == 0} {
            invalid "Table $table is empty."
        }
    }

    # ValidateGroupRecord db table rowid
    #
    # Adds the group name to the uramdb_g table.

    typemethod ValidateGroupRecord {db table rowid} {
        $db eval "SELECT * FROM $table WHERE rowid=\$rowid" row {
            if {[$db exists "SELECT g FROM uramdb_g WHERE g=\$row(g)"]} {
                invalid "Duplicate group name \"$g\" in $table"
            }

            $db eval {
                INSERT INTO uramdb_g(g) VALUES($row(g));
            }
        }
    }



    #-------------------------------------------------------------------
    # Table -- uramdb_mn

    typemethod Val_uramdb_mn {db table} {
        # Fill out table with default values: HERE when m==n, FAR otherwise.

        set nbhoods [$db eval {SELECT n FROM uramdb_n}]

        foreach m $nbhoods {
            foreach n $nbhoods {
                let proximity {$m eq $n ? "HERE" : "REMOTE"}

                # Insert the record, if it doesn't exist
                $db eval {
                    INSERT OR IGNORE INTO uramdb_mn(m,n,proximity) 
                    VALUES($m,$n,$proximity)
                }
            }
        }
        
        $db eval {
            UPDATE uramdb_mn
            SET proximity = "HERE"
            WHERE m = n AND proximity IS NULL;
            
            UPDATE uramdb_mn
            SET proximity = "REMOTE"
            WHERE m != n AND proximity IS NULL;
        }
    }
    
    #-------------------------------------------------------------------
    # Table -- uramdb_hrel
    
    typemethod Val_uramdb_hrel {db table} {
        # Insert rows for all missing combinations of f and g
        
        $db eval {
            SELECT F.g AS f, G.g AS g
            FROM uramdb_g AS F JOIN uramdb_g AS G
        } {
            set hrel [expr {$f eq $g ? 1.0 : 0.0}]

            $db eval {
                INSERT OR IGNORE INTO uramdb_hrel(f,g,hrel) VALUES($f,$g,$hrel)
            }
        }
    }

    #-------------------------------------------------------------------
    # Table -- uramdb_vrel
    
    typemethod Val_uramdb_vrel {db table} {
        # Insert rows for all missing combinations of g and a
        
        $db eval {
            SELECT g, a
            FROM uramdb_g JOIN uramdb_a
        } {
            $db eval {
                INSERT OR IGNORE INTO uramdb_vrel(g,a) VALUES($g,$a)
            }
        }
    }

    #-------------------------------------------------------------------
    # Table -- uramdb_sat
    
    typemethod Val_uramdb_sat {db table} {
        # Insert rows for all missing combinations of g and c
        # with compatible types.  We'll get the defaults from the
        # schema.
        
        $db eval {
            SELECT g,c
            FROM uramdb_civ_g JOIN uramdb_c
        } {
            $db eval {
                INSERT OR IGNORE INTO uramdb_sat(g,c) VALUES($g,$c)
            }
        }
    }

    #-------------------------------------------------------------------
    # Table -- uramdb_coop

    typemethod Val_uramdb_coop {db table} {
        # Fill out table with default values.
        
        $db eval {
            SELECT F.g AS f,
                   G.g AS g
            FROM uramdb_civ_g AS F JOIN uramdb_frc_g AS G    
        } {
            $db eval {
                INSERT OR IGNORE INTO uramdb_coop(f,g) 
                VALUES($f,$g)
            }
        }
    }

    
    #-------------------------------------------------------------------
    # Public Type Methods: Loading data

    # loadfile dbfile ?db?
    #
    # dbfile     A uramdb(5) text file
    # db         An sqldocument(n) in which to load the data.  One is
    #            created if no database is specified.
    #
    # Parses the contents of the named file into the relevant tables
    # in the db, returning the name of the db.

    typemethod loadfile {dbfile {db ""}} {
        $type Initialize

        if {$db eq ""} {
            set db [$type CreateDatabase]
        } elseif {$type ni [$db sections]} {
            error "schema not defined"
        }

        $tt loadfile $db $dbfile $concernDefinitions

        return $db
    }

    # load text ?db?
    #
    # text       A uramdb(5) text string
    # db         An sqldocument(n) in which to load the data.  One is
    #            created if no database is specified.
    #
    # Parses the contents of the text string into the relevant tables
    # in the db, returning the name of the db.

    typemethod load {text {db ""}} {
        $type Initialize

        if {$db eq ""} {
            set db [$type CreateDatabase]
        } elseif {$type ni [$db sections]} {
            error "schema not defined"
        }

        $tt load $db $text $concernDefinitions

        return
    }

    # mkperfdb db options...
    #
    # db         An sqldocument(n) in which to load the data.
    #
    # Options:
    #
    #   -actors    num    Number of actors; defaults to 4
    #   -nbhoods   num    Number of neighborhoods; defaults to 10
    #   -civgroups num    Number of civilian groups per nbhood; defaults to 2
    #   -frcgroups num    Number of force groups; defaults to 4
    #   -orggroups num    Number of org groups; defaults to 4
    #
    # Populates a uramdb database for performance testing
    # given the option values.  The database will have these characteristics:
    #
    # * -actors actors
    # * -nbhoods neighborhoods.
    # * -civgroups civilian groups in each neighborhood.
    # * -frcgroups force groups
    # * -orggroups org groups
    # * All proximities are HERE or NEAR.
    # * All relationships are 1.0, -0.5, +0.5.
    # * All satisfaction levels are 0.0.
    # * All saliencies are 1.0.
    # * All cooperation levels are 50.0
    # * All populations are 1000

    typemethod mkperfdb {db args} {
        # FIRST, get the defaults
        array set opts {
            -actors    4
            -nbhoods   10
            -civgroups 2
            -frcgroups 4
            -orggroups 4
        }

        # NEXT, get the option values.
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -actors    -
                -nbhoods   -
                -civgroups -
                -frcgroups -
                -orggroups {
                    set opts($opt) [lshift args]
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, make sure the schema is defined.
        if {$type ni [$db sections]} {
            error "schema not defined"
        }

        # NEXT, clear just the uramdb tables.
        $db eval {
            SELECT name FROM sqlite_master
            WHERE type='table' AND name GLOB 'uramdb_*'
        } {
            $db eval "DELETE FROM $name"
        }

        # NEXT, uramdb_c
        $db eval {
            INSERT INTO uramdb_c(c) VALUES('AUT');
            INSERT INTO uramdb_c(c) VALUES('CUL');
            INSERT INTO uramdb_c(c) VALUES('QOL');
            INSERT INTO uramdb_c(c) VALUES('SFT');
        }

        # NEXT, uramdb_a
        for {set i 1} {$i <= $opts(-actors)} {incr i} {
            set a "A$i"

            $db eval {
                INSERT INTO uramdb_a(a) VALUES($a);
            }
        }

        # NEXT, uramdb_n
        for {set i 1} {$i <= $opts(-nbhoods)} {incr i} {
            set n "N$i"

            $db eval {
                INSERT INTO uramdb_n(n) VALUES($n);
            }
        }

        # NEXT, uramdb_civ_g
        set letters "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        $db eval {SELECT n FROM uramdb_n} {
            for {set i 0} {$i < $opts(-civgroups)} {incr i} {
                set g "C[string range $n 1 end][string index $letters $i]"

                $db eval {
                    INSERT INTO uramdb_g(g,gtype) VALUES($g,'CIV');
                    INSERT INTO uramdb_civ_g(g,n,pop)
                    VALUES($g,$n,1000);
                }
            }
        }

        # NEXT, uramdb_frc_g
        for {set i 1} {$i <= $opts(-frcgroups)} {incr i} {
            set g "F$i"

            $db eval {
                INSERT INTO uramdb_g(g,gtype) VALUES($g,'FRC');
                INSERT INTO uramdb_frc_g(g) VALUES($g);
            }
        }

        # NEXT, uramdb_org_g
        for {set i 1} {$i <= $opts(-orggroups)} {incr i} {
            set g "O$i"

            $db eval {
                INSERT INTO uramdb_g(g,gtype) VALUES($g,'ORG');
                INSERT INTO uramdb_org_g(g) VALUES($g);
            }
        }

        # NEXT, uramdb_mn
        $db eval {
            SELECT M.n AS m, N.n AS n
            FROM uramdb_n AS M JOIN uramdb_n AS N
        } {
            if {$m eq $n} {
                set proximity HERE
            } else {
                set proximity NEAR
            }

            $db eval {
                INSERT INTO uramdb_mn(m,n,proximity)
                VALUES($m,$n,$proximity);
            }
        }

        # NEXT, uramdb_hrel
        set rels {0.5 -0.5}

        set i 0

        $db eval {
            SELECT F.g     AS f, 
                   F.gtype AS ftype,
                   G.g     AS g,
                   G.gtype AS gtype
            FROM uramdb_g AS F 
            JOIN uramdb_g AS G
        } {
            # This logic matches that in gramdb(2), so that performance
            # can be compared.
            if {$f eq $g} {
                let hrel 1.0
            } elseif {$ftype eq $gtype &&
                      $ftype eq "CIV"  &&
                      [string index $f end] eq [string index $g end]} {
                let hrel 1.0
            } else {
                let ndx {$i % 2}
                set hrel [lindex $rels $ndx]
                incr i
            }

            $db eval {
                INSERT INTO uramdb_hrel(f,g,hrel)
                VALUES($f,$g,$hrel)
            }
        }

        # NEXT, uramdb_vrel
        set i 0

        $db eval {
            SELECT g, a
            FROM uramdb_g
            JOIN uramdb_a
        } {
            let ndx {$i % 2}
            set vrel [lindex $rels $ndx]
            incr i

            $db eval {
                INSERT INTO uramdb_vrel(g,a,vrel)
                VALUES($g,$a,$vrel)
            }
        }

        # NEXT, uramdb_sat
        $db eval {
            INSERT INTO uramdb_sat(g,c)
            SELECT g, c FROM uramdb_civ_g JOIN uramdb_c
        }

        # NEXT, uramdb_coop
        $db eval {
            SELECT F.g AS f, G.g AS g
            FROM uramdb_civ_g AS F JOIN uramdb_frc_g AS g
        } {
            $db eval {
                INSERT INTO uramdb_coop(f,g)
                VALUES($f,$g)
            }
        }
    }
  
    # loader db uram
    #
    # db     An sqldocument(n) with uramdb(5) data
    # uram   A uram(n)
    #
    # Loads the uramdb(5) data into the uram(n).  This command is
    # intended to be used as a uram(n) -loadcmd, like this:
    #
    #   -loadcmd [list ::simlib::uramdb loader $db]
    #
    # where $db is the name of the sqldocument(n) containing the
    # uramdb(5) data.
    
    typemethod loader {db uram} {
        set causes [list]
        for {set i 1} {$i <= 10} {incr i} {
            lappend causes "CAUSE[format %02d $i]"
        }
        $uram load causes {*}$causes

        $uram load actors {*}[$db eval {
            SELECT a FROM uramdb_a
            ORDER BY a
        }]

        $uram load nbhoods {*}[$db eval {
            SELECT n FROM uramdb_n
            ORDER BY n
        }]
        
        set data [list]
        $db eval {
            SELECT m, n, proximity FROM uramdb_mn
            ORDER BY m,n
        } {
            lappend data $m $n [eproximity index $proximity]
        }
        $uram load prox {*}$data

        $uram load civg {*}[$db eval {
            SELECT g,n,pop FROM uramdb_civ_g
            ORDER BY g
        }]

        $uram load otherg {*}[$db eval {
            SELECT g,'FRC' FROM uramdb_frc_g
            UNION
            SELECT g,'ORG' FROM uramdb_org_g
            ORDER BY g;
        }]

        $uram load hrel {*}[$db eval {
            SELECT f, g, hrel, hrel, hrel FROM uramdb_hrel
            ORDER BY f, g
        }]

        $uram load vrel {*}[$db eval {
            SELECT g, a, vrel, vrel, vrel FROM uramdb_vrel
            ORDER BY g, a
        }]

        $uram load sat {*}[$db eval {
            SELECT g, c, sat, sat, sat, saliency FROM uramdb_sat
            ORDER BY g, c
        }]

        $uram load coop {*}[$db eval {
            SELECT f, g, coop, coop, coop FROM uramdb_coop
            ORDER BY f, g
        }]
    }

    #-------------------------------------------------------------------
    # Other Private Routines

    # CreateDatabase
    #
    # Creates an in-memory run-time database if one is not specified.

    typemethod CreateDatabase {} {
        set db [sqldocument %AUTO%]
        $db register $type
        $db open :memory:
        $db clear

        return $db
    }
    
    # invalid message
    #
    # message    An error string
    #
    # Throws the error with -errorcode INVALID
    
    proc invalid {message} {
        return -code error -errorcode INVALID $message
    }
}



