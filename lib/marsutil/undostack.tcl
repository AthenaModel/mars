#-----------------------------------------------------------------------
# TITLE:
#   undostack.tcl
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
#   Undo stack manager
#
#   Instances of the undostack object type do the following.
#
#   * Manage an undo stack similar to that provided by the 
#     Tk text widget.
#   * Allow multiple undo stacks in one program and RDB.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export undostack
}

#-----------------------------------------------------------------------
# undostack

snit::type ::marsutil::undostack {

    #-------------------------------------------------------------------
    # sqlsection(i) implementation
    #
    # The following routines implement the module's 
    # sqlsection(i) interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section.

    typemethod {sqlsection title} {} {
        return "undostack(n)"
    }

    # Type method: sqlsection schema
    #
    # Returns the section's persistent schema definitions, which are
    # read from undostack.sql.

    typemethod {sqlsection schema} {} {
        return [readfile [file join $::marsutil::library undostack.sql]]
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, which are
    # read from undostack.sql.

    typemethod {sqlsection tempschema} {} {
        return {}
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes.

    typemethod {sqlsection functions} {} {
        return []
    }

    #-------------------------------------------------------------------
    # Type Variables

    # rdbTracker
    #
    # Array mapping $rdb,$tag to undostack(n) instance.  Allows us to be 
    # sure that we have only one instance per RDB and tag name.
    
    typevariable rdbTracker -array { }

    #-------------------------------------------------------------------
    # Options

    # -automark
    #
    # A boolean flag, defaulting to "on".  If on, undo marks
    # are inserted before every [add] operation on the stack, and
    # "edit mark" need never be called.  If off, then
    # "edit mark" may be used to add marks explicitly.

    option -automark \
        -type     snit::boolean \
        -default  on

    # -rdb
    #
    # The name of the sqldocument(n) instance in which
    # undostack(n) will store its working data.  After creation, the
    # value will be stored in the rdb component.

    option -rdb \
        -readonly 1

    # -undo
    #
    # A boolean flag, defaulting to "on".  If on, undo information
    # is saved and the "edit undo" command is available.  If
    # off, no undo information is saved.

    option -undo \
        -type            snit::boolean \
        -default         on            \
        -configuremethod ConfigUndo

    method ConfigUndo {opt val} {
        # FIRST, save the option value
        set options($opt) $val

        # NEXT, if -undo is off, clear the undo stack.
        if {!$val} {
            $self edit reset
        }
    }

    # -tag
    #
    # A tag identifying this stack in the RDB.  Allows application to
    # ensure that the object can access undostacks across restarts.

    option -tag \
        -type     ::marsutil::identifier \
        -readonly 1


    #-------------------------------------------------------------------
    # Components
    #
    # Each instance of undostack(n) uses the following components.
    
    component rdb  ;# The RDB, passed in as -rdb.

    #-------------------------------------------------------------------
    # Instance Variables

    variable tag ;# The -tag, put here for use in SQL scripts.


    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor
    #
    # Creates a new instance of undostack(n), given the creation options.
    
    constructor {args} {
        # FIRST, get the creation arguments.
        $self configurelist $args

        # NEXT, save -rdb and -tag, verifying that no other instance
        # of undostack(n) is using them.
        set rdb $options(-rdb)
        assert {[info commands $rdb] ne ""}

        require {$type in [$rdb sections]} \
            "undostack(n) is not registered with database $rdb"

        set tag $options(-tag)

        # NEXT, ensure that this RDB/tag combination is unique.
        if {[info exists rdbTracker($rdb,$tag)]} {
            return -code error \
  "Tag \"$tag\" already in use in RDB $rdb by undostack $rdbTracker($rdb,$tag)"
        }

        set rdbTracker($rdb,$tag) $self
    }
    
    # destructor
    #
    # Deletes the object's tag, and moves the content from the RDB.

    destructor {
        catch {
            unset -nocomplain rdbTracker($rdb,$tag)
            $self edit reset
        }
    }

   
    #-------------------------------------------------------------------
    # Public Methods

    # add script
    #
    # script  - The client's undo script.
    #
    # Saves an undo script in the undostack_stack table, provided that 
    # undo is enabled.  If -automark, the script's mark is set.
    #
    # If undo is disabled, this is a no-op.

    method add {script} {
        if {!$options(-undo)} {
            return
        }

        set mark [expr {$options(-automark) ? 1 : 0}]

        $rdb eval {
            INSERT INTO undostack_stack(tag,mark,script) 
            VALUES($tag,$mark,$script)
        }
    }
   

    #-------------------------------------------------------------------
    # edit
    #
    # This family of subcommands is patterned after the mam(n) object's
    # "edit" command, but adds "edit mark".  It is expected that clients
    # will delegate their own "edit" subcommand here.

    # edit reset
    #
    # Clears the undo stack.

    method {edit reset} {} {
        # This can be called from the constructor, before $rdb is set
        if {$rdb ne ""} {
            $rdb eval {DELETE FROM undostack_stack WHERE tag=$tag}
        }

        return
    }

    # edit mark
    #
    # Adds a mark to the undo stack.  [edit undo] undoes commands
    # back to the mark.  If -automark is on, this is a no-op.

    method {edit mark} {} {
        if {!$options(-undo) || $options(-automark)} {
            return
        }

        $rdb eval {
            INSERT INTO undostack_stack(tag,mark) 
            VALUES($tag,1)
        }

        return
    }


    # edit canundo
    #
    # Returns 1 if there's anything on the undo stack, and 0 otherwise.
    # If undo is disabled, returns 0.

    method {edit canundo} {} {
        if {!$options(-undo)} {
            return 0
        }

        return [$rdb exists { 
            SELECT * FROM undostack_stack 
            WHERE tag=$tag
        }]
    }

    # edit undo
    #
    # Undoes operations back to the last mark.
    # It's an error if there's nothing to undo.

    method {edit undo} {} {
        require {[$self edit canundo]} "nothing to undo"

        # FIRST, get the ID of the most recent mark.
        set mid ""

        $rdb eval {
            SELECT MAX(id) AS mid
            FROM undostack_stack
            WHERE tag=$tag AND mark=1
        } {}

        # NEXT, if there is no mark, get the minimum ID;
        # everything will be undone.

        if {$mid eq ""} {
            # We know there's at least one entry, so there's a 
            # minimum entry.
            $rdb eval {
                SELECT MIN(id) AS mid
                FROM undostack_stack
                WHERE tag=$tag
            } {}
        }

        # NEXT, get the undo scripts.
        set scripts [$rdb eval {
            SELECT script
            FROM undostack_stack 
            WHERE tag=$tag
            AND id >= $mid
            AND script IS NOT NULL
            ORDER BY id DESC
        }]
        
        # NEXT, delete the operations from the undo stack
        $rdb eval {
            DELETE FROM undostack_stack 
            WHERE tag=$tag AND id >= $mid
        }

        # NEXT, execute the scripts
        if {[llength $scripts] > 0} {
            namespace eval :: [join $scripts \n]
        }

        return
    }
}
