#-----------------------------------------------------------------------
# TITLE:
#   parmset.tcl
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
#   Mars marsutil(n) Module: Parameter Set Framework
#
#   A parameter set is a vector of typed parameters which may be
#   loaded from a file, edited, and saved back to the file.  Parameter
#   values are validated on load and edit, and jnem_man(1)-style
#   documentation can be generated automatically for inclusion in a
#   jnem_man(1) man page.
#
#   Parameter names must begin with a letter, and may include
#   letters, numbers, underscores, hyphens, and periods.  Embedded periods
#   are used to indicate subset-membership, i.e., parameter "a.b.c"
#   belongs to subset "a.b", and subset "a.b" belongs in turn to
#   subset "a".  A subset must be defined before any members of
#   the subset.
#
#   The file format is simple:
#
#     parm <parm> <value>
#
#   It has Tcl syntax, so that complicated values containing newlines
#   can be entered using braces, as usual.  The file can contain Tcl 
#   comments, but there's not much point, as the file is often produced
#   by software.
#
#   This module defines the parmset type; to define a parameter set,
#   create an instance of parmset; then define the parameters using
#   the define method.
#
# MASTERS AND SLAVES
#   Parmsets can be linked in a master/slave relationship.  The slave's 
#   parameters are grafted into the master, unchanged; note that they
#   must not already exist there, and the slave must not already be
#   a slave.  Then, changes to either parmset are communicated to the
#   other transparently.  Neither clients of the slave nor clients
#   of the master need be aware of the relationship.
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export parmset
}

#-----------------------------------------------------------------------
# parmset

snit::type ::marsutil::parmset {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Options

    # -notifycmd cmd
    #
    # cmd is called when a parameter value changes.  It takes one
    # argument, the name of the changed parameter.  If multiple 
    # parameters may have changed, e.g., on load, the argument will
    # be the empty string.

    option -notifycmd -default ""

    #-------------------------------------------------------------------
    # Instance Variables

    # Array of parameter names and values by lowercase name.
    # This array remains separate from info() because it's convenient
    # to manipulate it separately.
    variable values

    # Array of parameter set data.  In what follows, "$id" is 
    # the lowercase form of the parameter or subset name.
    #
    # items            Item names, in order of definition
    # parms            Parameter id's, in order of definition
    # notify           Flag: if 1, call -notifycmd, otherwise don't.
    # master           The master parmset(n)'s name, or "" if none.
    # slaves           List of slave parmset(n)'s, or {} if none.
    # changed          saveable(i) changed flag
    #
    # children-$id     IDs of children of subset $id. info(children-) 
    #                  is the list of top-level item IDs.
    # canon-$id        Canonical form of the item name.
    # doc-$id          Item's doc string
    # itype-$id        Item type, parm|subset
    # vtype-$id        Parameter's value type
    # defvalue-$id     Parameter's default value
    # locked-$id       1 if the parameter is locked, and 0 otherwise.
    # slave-$id        The name of the slave parmset(n)'s name from which
    #                  the parm was grafted, or "" if none.

    variable info -array {
        items   {}
        parms   {}
        notify  1
        master  ""
        slaves  {}
        changed 0
    }

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # No constructor needed

    destructor {
        # FIRST, free all slaves
        foreach slave $info(slaves) {
            $self slave free $slave
        }

        # NEXT, free self from master, if any
        callwith $info(master) slave free $self
    }

    #-------------------------------------------------------------------
    # Parameter Set Definition Methods

    # subset name docstring
    #
    # name         The subset name
    # docstring    A brief description of the subset.
    # 
    # Defines a new subset.

    method subset {name docstring} {
        require {$info(master) eq ""} \
            "can't add subset, parmset is slave of \"$info(master)\""

        # FIRST, is the name valid?
        ::marsutil::parmname validate $name

        # NEXT, get the ID.
        set id [string tolower $name]

        # Not yet defined?
        require {![info exists info(canon-$id)]} \
            "item already defined: \"$name\""

        # Parent subset defined
        set parent [ParentSubset $name]
        set pid [string tolower $parent]

        if {$pid ne ""} {
            require {[info exists info(canon-$pid)]} \
                "parent subset \"$parent\" has not been defined: \"$name\""
            require {$info(itype-$pid) eq "subset"} \
                "parent \"$parent\" is a parameter, not a subset: \"$name\""
        }

        lappend info(children-$pid) $id
        set info(canon-$id) $name
        set info(doc-$id) [Normalize $docstring]
        set info(itype-$id) subset
        set info(slave-$id) ""
    }

    # define name vtype defvalue docstring
    #
    # name         The parameter name
    # vtype        The parameter type; a snit:: validation type (or the
    #              equivalent).
    # defvalue     The default value.  All parms should have a valid default,
    #              even if it's only the empty string.
    # docstring    A brief description; it need not contain information
    #              that can be inferred from the type.
    #
    # Defines a new parameter.  Verifies that the name is valid.  Verifies
    # that the default value is valid.  Normalizes the docstring.
    # (i.e., removes excess whitespace and newlines).

    method define {name vtype defvalue docstring} {
        require {$info(master) eq ""} \
            "can't define parm, parmset is slave of \"$info(master)\""

        # FIRST, make sure that its parent exists and is a subset.
        # The "subset" command will do this, and will coincidentally save
        # its docstring.
        $self subset $name $docstring

        # NEXT, get the ID
        set id [string tolower $name]

        # NEXT, save the type, etc.
        set info(itype-$id)   parm
        set info(vtype-$id)   $vtype
        set info(locked-$id)  0

        # NEXT, turn notifications off
        set info(notify) 0

        # NEXT, save and validate the default value
        set code [catch {$self setdefault $id $defvalue} result]

        # NEXT, turn notifications on
        set info(notify) 1

        # NEXT, if there was an error, throw it!
        if {$code} {
            return -code error $result
        }

        return
    }

    method Debug {} {
        parray info
    }

    # setdefault name value
    #
    # Sets the named parm's current and default values.

    method setdefault {name value} {
        $self SetParm setdefault $name $value
    }

    # getdefault name
    #
    # Gets the parameter's default value.

    method getdefault {name} {
        set id [$self ValidID $name]

        return $info(defvalue-$id)
    }

    #-------------------------------------------------------------------
    # Parameter Set Usage Methods

    # get name
    #
    # Gets the parm's value

    method get {name} {
        set id [$self ValidID $name]

        return $values($id)
    }

    # set name value
    #
    # Sets the parm's value, validating and normalizing the value
    
    method set {name value} {
        $self SetParm set $name $value
    }

    # SetParm op name value
    #
    # op     set | setdefault
    #
    # Implementation for set/setdefault
    
    method SetParm {op name value} {
        # FIRST, validate the value
        set id [$self ValidID $name]

        if {[catch {$info(vtype-$id) validate $value} result]} {
            error "Invalid $name value \"$value\": $result"
        }

        set value [Normalize $value]

        require {!$info(locked-$id) || $value eq $values($id)} \
            "Parameter is locked: \"$name\""

        # NEXT, save the value
        set values($id) $value

        if {$op eq "setdefault"} {
            set info(defvalue-$id)  $value
        }

        # NEXT, do notifications.
        if {$info(notify)} {
            # FIRST, if there's a slave notify it.
            callwith $info(slave-$id) NotifySlave $op $id $value
            
            # NEXT, if there's a master notify it.
            callwith $info(master) NotifyMaster $op $id $value

            # NEXT, notify client.
            callwith $options(-notifycmd) $name
        }

        # NEXT, set the change flag
        set info(changed) 1

        return $value
    }

    # NotifySlave op id value
    #
    # op       set | setdefault
    # id       A parameter ID
    # value    Its value
    #
    # Notify this parmset that this parameter's value was changed
    # in its master.

    method NotifySlave {op id value} {
        # FIRST, the value is guaranteed to be OK, since it was
        # validated by the master.
        set values($id) $value

        if {$op eq "setdefault"} {
            set info(defvalue-$id)  $value
        }

        # NEXT, notify this parmset's slave, if any.
        callwith $info(slave-$id) NotifySlave $op $id $value
            
        # NEXT, notify client.
        callwith $options(-notifycmd) $info(canon-$id)
    }

    # NotifyMaster op id value
    #
    # op       set | setdefault
    # id       A parameter ID
    # value    Its value
    #
    # Notify this parmset that this parameter's value was changed
    # by a slave.

    method NotifyMaster {op id value} {
        # FIRST, the value is guaranteed to be OK, since it was
        # validated by the slave.
        set values($id) $value

        if {$op eq "setdefault"} {
            set info(defvalue-$id)  $value
        }

        # NEXT, notify this parmset's master, if any.
        callwith $info(master) NotifyMaster $op $id $value
            
        # NEXT, notify client.
        callwith $options(-notifycmd) $info(canon-$id)
    }

    # lock pattern
    #
    # pattern    A glob pattern
    #
    # Locks all parameters whose names match pattern.
    
    method lock {pattern} {
        # The keys in values() are all lower case
        set lowpat [string tolower $pattern]

        set count 0

        foreach id [array names values $lowpat] {
            incr count

            set info(locked-$id) 1

            callwith $info(slave-$id) SlaveLocked  $id 1
            callwith $info(master)    MasterLocked $id 1
        }

        if {$count == 0} {
            error "Pattern matches no parameters: \"$pattern\""
        }
    }

    # unlock pattern
    #
    # pattern    A glob pattern
    #
    # Unlocks all parameters whose names match pattern.
    
    method unlock {pattern} {
        # The keys in values() are all lower case
        set lowpat [string tolower $pattern]

        set count 0

        foreach id [array names values $lowpat] {
            incr count

            set info(locked-$id) 0

            callwith $info(slave-$id) SlaveLocked  $id 0
            callwith $info(master)    MasterLocked $id 0
        }

        if {$count == 0} {
            error "Pattern matches no parameters: \"$pattern\""
        }
    }

    # SlaveLocked id state
    #
    # id     parameter id
    # state  1 if locked, 0 otherwise
    #
    # Locks/unlocks the parameter and propagates to slaves.

    method SlaveLocked {id state} {
        set info(locked-$id) $state

        callwith $info(slave-$id) SlaveLocked $id $state
    }

    # MasterLocked id state
    #
    # id     parameter id
    # state  1 if locked, 0 otherwise
    #
    # Locks/unlocks the parameter and propagates to masters.

    method MasterLocked {id state} {
        set info(locked-$id) $state

        callwith $info(master) MasterLocked $id $state
    }

    # islocked name
    #
    # Returns 1 if the parameter is locked, and 0 otherwise.

    method islocked {name} {
        set id [$self ValidID $name]

        return $info(locked-$id)
    }

    # ValidID name
    #
    # name     A parameter name, possibly with different casing.
    #          
    # Returns the parameter's ID, or throws an error.

    method ValidID {name} {
        set id [string tolower $name]

        # Make sure it exists, and it's a parameter.
        require {[info exists info(vtype-$id)]} \
            "unknown parameter: \"$name\""

        return $id
    }

    # type name
    #
    # Gets the parameter's type

    method type {name} {
        set id [$self ValidID $name]

        return $info(vtype-$id)
    }

    # docstring name
    #
    # Gets the item's doc string

    method docstring {name} {
        set id [string tolower $name]

        require {[info exists info(doc-$id)]} \
            "unknown item: \"$name\""

        return $info(doc-$id)
    }


    # names ?pattern?
    # 
    # pattern     A glob pattern.
    # 
    # Lists the names of parameters that match the pattern, in sorted
    # order.

    method names {{pattern "*"}} {
        set ids [$self GetIDs $pattern]

        set names {}
        foreach id $ids {
            if {$info(itype-$id) eq "parm"} {
                lappend names $info(canon-$id)
            }
        }

        return $names
    }

    # GetIDs pattern
    #
    # Returns a list of the IDs, in tree order, which match the pattern.
    
    method GetIDs {pattern} {
        set pattern [string tolower $pattern]
        
        set ids {}

        set items $info(children-)
        
        while {[llength $items] > 0} {
            set id [lshift items]

            if {$info(itype-$id) eq "subset"} {
                set items [concat $info(children-$id) $items]
            }

            if {[string match $pattern $id]} {
                lappend ids $id
            }
        }

        return $ids
    }

    # locked ?pattern?
    # 
    # pattern     A glob pattern.
    # 
    # Lists the names of locked parameters that match the pattern, in sorted
    # order.

    method locked {{pattern "*"}} {
        set ids [$self GetIDs $pattern]

        set names {}
        foreach id $ids {
            if {$info(itype-$id) eq "parm" &&
                $info(locked-$id)
            } {
                lappend names $info(canon-$id)
            }
        }

        return $names
    }

    # list ?pattern?
    #
    # pattern     A glob pattern.
    # 
    # Lists the parameters that match the pattern, in sorted
    # order, with their values.

    method list {{pattern "*"}} {
        set names [$self names $pattern]

        set wid [lmaxlen $names]

        set out ""

        foreach name $names {
            set id [string tolower $name]
            append out [format "%-*s %s\n" $wid $name [list $values($id)]]
        }

        return $out
    }

    # items
    #
    # Returns a list of the item names and types, sorted by item name.

    method items {} {
        set ids [$self GetIDs *]

        set items {}

        foreach id $ids {
            lappend items $info(canon-$id) $info(itype-$id)
        }

        return $items
    }

    #-------------------------------------------------------------------
    # File Handling

    # save filename
    #
    # Saves non-defaulted parameter data to a file   
    #
    # Note: does not affect saveable(i) status!

    method save {filename} {
        # FIRST, rename any old file
        if {[file exists $filename]} {
            file copy -force $filename $filename.bak
        }

        set f [open $filename w]

        puts $f "# File saved [clock format [clock seconds]]\n"

        set names [$self names]
        set wid [lmaxlen $names]

        foreach name [$self names] {
            set id [string tolower $name]
            if {$values($id) ne $info(defvalue-$id)} {
                puts $f "parm [format %-*s $wid $name] [list $values($id)]"
            }
        }

        puts $f "\n# End of file"
        
        close $f
    }

    # reset
    #
    # Resets all values to their defaults.
    
    method reset {} {
        # FIRST, reset the values
        foreach id [array names values] {
            # Only reset unlocked parameters.
            if {!$info(locked-$id)} {
                set values($id) $info(defvalue-$id)
            }
        }

        # NEXT, set changed flag
        set info(changed) 1

        # NEXT, do notifications
        if {$info(notify)} {
            # FIRST, notify the slaves, if any.
            foreach slave $info(slaves) {
                callwith $slave CopyFromMaster $self
            }

            # NEXT, notify the master, if any.
            callwith $info(master) CopyFromSlave $self
            
            # NEXT, notify the client
            callwith $options(-notifycmd) ""
        }
    }

    # load filename ?-safe?
    #
    # filename    File to load
    # -safe       If specified, load will not throw an error when encountering
    #             an invalid parameter or value.  All valid parameters will 
    #             be loaded and errors will be ignored.
    #
    # Loads the data from a file. If the file is invalid, the existing
    # values are untouched.

    method load {filename {opt ""}} {
        require {[file exists $filename]} \
            "Error, file not found: \"$filename\""

        # FIRST, check for the option
        if {$opt ne "" && $opt ne "-safe"} {
            error "Invalid option: \"$opt\""
        }

        # NEXT, save the old values
        set savedValues [array get values]

        # NEXT, disable notifications until we're done.
        set info(notify) 0

        # NEXT, reinitialize to default values.
        $self reset

        # NEXT, try to load the file
        set code [catch {$self LoadFile $filename $opt} result]

        # NEXT, re-enable notification
        set info(notify) 1

        # NEXT, on error, restore the saved values and return the error.
        if {$code} {
            # Restore the saved values
            array set values $savedValues

            return -code error "Error in $filename: $result"
        }

        # NEXT, notify the slaves, if any.
        foreach slave $info(slaves) {
            callwith $slave CopyFromMaster $self
        }

        # NEXT, notify the master, if any.
        callwith $info(master) CopyFromSlave $self


        # NEXT, notify the client.
        callwith $options(-notifycmd) ""

        # NEXT, set changed flag
        set info(changed) 1

        return
    }

    # LoadFile filename opt
    # 
    # filename    File to load
    # opt         When equal to "-safe", will silently ignore erroneous
    #             file content.
    #
    # Does the heavy lifting of loading a file.

    method LoadFile {filename opt} {
        # FIRST, create the slave interpreter, and define the "parm" command.
        set interp [interp create -safe]
        $interp alias _parm $self set
        if {$opt eq "-safe"} {
            $interp eval {
                proc parm {name value} { catch { _parm $name $value } }
            }
        } else {
            $interp eval {
                proc parm {name value} { _parm $name $value }
            }
        }

        # NEXT, Attempt to load the file
        set code [catch {$interp invokehidden -global source $filename} result]

        # NEXT, destroy the interpreter
        interp delete $interp

        # NEXT, rethrow any error.
        if {$code} {
            error $result
        }
        
        return
    }

    #-------------------------------------------------------------------
    # Parameter Set Documentation Methods

    # manpage
    #
    # Produces EHTML documentation as a deflist in jnem_man(1) format, 
    # for inclusion in a man page.

    method manpage {} {
        set out "<deflist parmset>\n\n"
        set stack {}

        foreach {item ntype} [$self items] {
            set id [string tolower $item]

            # FIRST, do we need to pop any elements off of the
            # stack?
            set parent [ParentSubset $item]


            while {[lindex $stack end] ne $parent} {
                set oldTop [lindex $stack end]
                set stack [lrange $stack 0 end-1]
                
                append out "</deflist $oldTop>\n\n"
            }

            if {$ntype eq "subset"} {
                # FIRST, output the docs for this subset
                append out "<defitem $item.* $item.*>\n"
                append out "$info(doc-$id)\n"
                append out "<p>\n\n"

                # NEXT, push the subset onto the stack.
                lappend stack $item

                append out "<deflist $item>\n\n"
            } else {
                # FIRST, output the docs for this parameter
                set vtype [namespace tail $info(vtype-$id)]

                append out "<defitem $item {$item <i>value</i>}>\n"
                append out "Defaults to \"<b><tt>$info(defvalue-$id)</tt></b>\".\n"
                append out "$info(doc-$id)\n"
                append out "<p>\n\n"
            }
        }

        while {[lindex $stack end] ne ""} {
            set oldTop [lindex $stack end]
            set stack [lrange $stack 0 end-1]
            
            append out "</deflist $oldTop>\n\n"
        }

        append out "</deflist parmset>\n"

        return $out
    }

    # manlinks
    #
    # Produces an indented list of parameters, set to use the "mktree"
    # dynamic scripting.

    method manlinks {} {
        set out "<mktree>\n\n"
        append out "<ul class=\"mktree\" id=\"$self\">\n"
        set stack {}

        foreach {item ntype} [$self items] {
            set id [string tolower $item]

            # FIRST, do we need to pop any elements off of the
            # stack?
            set parent [ParentSubset $item]


            while {[lindex $stack end] ne $parent} {
                set oldTop [lindex $stack end]
                set stack [lrange $stack 0 end-1]
                
                append out "</ul></li>\n\n"
            }

            if {$ntype eq "subset"} {
                # FIRST, output the items for this subset
                append out "<li><iref $item.*>\n"

                # NEXT, push the subset onto the stack.
                lappend stack $item

                append out "<ul>\n\n"
            } else {
                append out "<li><iref $item></li>\n"
            }
        }

        while {[lindex $stack end] ne ""} {
            set stack [lrange $stack 0 end-1]
            
            append out "</ul></li>\n\n"
        }

        append out "</ul>\n"

        return $out
    }

    #-------------------------------------------------------------------
    # Master/Slave

    # slave add slave
    #
    # slave    The name of another parmset(n)
    #
    # Places "slave" in a master/slave relationship with $self.  Note
    # a parmset can be master to arbitrarily many slaves, but may have
    # at most one master.

    method {slave add} {slave} {
        require {$info(master) eq ""} \
            "can't add slave, parmset is slave of \"$info(master)\""
        
        # FIRST, tell the slave that it is a slave.  This will
        # throw an error if the slave is *already* a slave.
        callwith $slave SetMaster $self

        # NEXT, remember that we have a slave
        lappend info(slaves) $slave

        # NEXT, graft each subset and parameter from slave into 
        # master, remembering that it's a slave.
        foreach {item itype} [callwith $slave items] {
            if {$itype eq "subset"} {
                $self subset $item [callwith $slave docstring $item]
            } else {
                # FIRST, define the parameter
                $self define $item            \
                    [callwith $slave type $item]       \
                    [callwith $slave getdefault $item] \
                    [callwith $slave docstring  $item]

                # NEXT, copy its current value, avoiding notifications.
                # Since we know that the types are the same, there should
                # be no chance of error.
                set info(notify) 0
                $self set $item [callwith $slave get $item]
                set info(notify) 1

                # NEXT, remember that it's a slave, and copy its locked
                # state.
                set id [string tolower $item]
                set info(slave-$id) $slave
                set info(locked-$id) [callwith $slave islocked $id]
            }
        }
    }

    # slave free slave
    #
    # slave    The name of another parmset(n)
    #
    # Tells slave that it no longer has a master.

    method {slave free} {slave} {
        require {[lsearch -exact $info(slaves) $slave] != -1} \
            "not a slave of $self: \"$slave\""

        # FIRST, forget that we have this slave
        ldelete info(slaves) $slave

        # NEXT, we'll keep the parms but unlink them.
        foreach name [callwith $slave names] {
            set id [string tolower $name]

            set info(slave-$id) ""
        }

        # NEXT, we'll tell the slave it has no master.
        callwith $slave SetMaster ""
    }


    # SetMaster master
    #
    # master   The name of another parmset(n).
    #
    # Tells $self that it is the slave of parmset(n) master.  It's
    # an error of $self is already a slave.

    method SetMaster {master} {
        # FIRST, are we already a slave?
        require {$master eq "" || $info(master) eq ""} \
            "parmset(n) $self already has a master: \"$info(master)\""

        set info(master) $master
    }

    # CopyFromMaster master
    #
    # master    The name of another parmset(n)
    #
    # Copies the master's parameter values for all known parameters.
    
    method CopyFromMaster {master} {
        assert {$master eq $info(master)}

        # FIRST, set notification off.
        set info(notify) 0

        # NEXT, copy all of the values. There should be no errors,
        # as the parameters were defined with the same types.
        foreach parm [$self names] {
            $self set $parm [callwith $master get $parm]
        }

        # NEXT, set notification on.
        set info(notify) 0

        # NEXT, notify any slaves
        foreach slave $info(slaves) {
            callwith $slave CopyFromMaster $self
        }

        # NEXT, notify the client.
        callwith $options(-notifycmd) ""
    }

    # CopyFromSlave slave
    #
    # slave    The name of another parmset(n)
    #
    # Copies the slave's parameter values for all known parameters.
    
    method CopyFromSlave {slave} {
        assert {[lsearch -exact $info(slaves) $slave] != -1}

        # FIRST, set notification off.
        set info(notify) 0

        # NEXT, copy all of the values. There should be no errors,
        # as the parameters were defined with the same types.
        foreach parm [callwith $slave names] {
            $self set $parm [callwith $slave get $parm]
        }

        # NEXT, set notification on.
        set info(notify) 1

        # NEXT, notify the master, if any
        callwith $info(master) CopyFromSlave $self

        # NEXT, notify the client.
        callwith $options(-notifycmd) ""
    }

    #-------------------------------------------------------------------
    # Saveable(i) Interface

    # changed
    #
    # Returns 1 if the saveable(i) data has changed, and 0 otherwise.

    method changed {} {
        return $info(changed)
    }

    # checkpoint ?-saved?
    #
    # Returns the parmset's checkpoint information as a string.
    # If -save is specified, clears the changed flag.

    method checkpoint {{opt ""}} {
        if {$opt eq "-saved"} {
            set info(changed) 0
        }

        # Do not include parms with default values
        set checkpoint [list]

        foreach name [$self names] {
            set id [string tolower $name]
            if {$values($id) ne $info(defvalue-$id)} {
                lappend checkpoint $id $values($id)
            }
        }

        return $checkpoint
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint      A checkpoint string returned by "checkpoint"
    #
    # Restores the parmset's state back to the checkpoint.  If
    # -saved, clears the changed flag; otherwise, sets it.

    method restore {checkpoint {opt ""}} {
        # FIRST, restore the checkpointed data.  The checkpoint
        # includes only the non-default values, so reset back to
        # defaults first; then save the checkpointed values,
        # if any.

        foreach id [array names values] {
            set values($id) $info(defvalue-$id)
        }

        array set values $checkpoint

        # NEXT, do notifications
        if {$info(notify)} {
            # FIRST, notify the slaves, if any.
            foreach slave $info(slaves) {
                callwith $slave CopyFromMaster $self
            }

            # NEXT, notify the master, if any.
            callwith $info(master) CopyFromSlave $self
            
            # NEXT, notify the client
            callwith $options(-notifycmd) ""
        }

        # NEXT, set or clear the changed flag
        if {$opt eq "-saved"} {
            set info(changed) 0
        } else {
            set info(changed) 1
        }
    }

    #-------------------------------------------------------------------
    # Helper Procs

    # ParentSubset name
    #
    # name     A parameter or subset name
    #
    # Returns the name's parent subset name, or "" if none.

    proc ParentSubset {name} {
        join [lrange [split $name "."] 0 end-1] "."
    }

    # Normalize text
    #
    # text      A block of text
    #
    # Trims leading and trailing whitespace and removes excess internal
    # whitespace, converting new-lines and tabs to single spaces.

    proc Normalize {text} {
        set text [string trim $text]
        regsub -all "\n" $text " " text
        regsub -all "\t" $text " " text
        regsub -all { +} $text " " text
        
        return $text
    }
}

#-----------------------------------------------------------------------
# Standard Types

# Parameter Names:
#
# * Begin with a letter
# * Letters, numbers, underscores, and hyphens.
# * "." as a separator.

snit::stringtype ::marsutil::parmname \
    -regexp {^[[:alpha:]][[:alnum:]_-]*(\.[[:alnum:]_-]+)*$}

# We should probably have a module for these.





