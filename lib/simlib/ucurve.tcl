#-----------------------------------------------------------------------
# TITLE:
#   coverage.tcl
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
#   URAM curve manager
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export ucurve
}

#-----------------------------------------------------------------------
# ucurve
#
# Curve manager for Unified Regional Attitude Model (URAM)
#
# Instances of the ucurve object type do the following.
#
#  * Define curve types (e.g., satisfaction, cooperation)
#  * Manage curves of the various types
#  * Manage effects applied to these curves
#  * Update curves given the current set of effects, taking
#    causes into account.
#  * Save contributions to each curve by driver and timestamp
#
# Instances of ucurve are primarily used by the uram(n) type.
#
# Handling of Untracked Curves
#
# By definition, untracked curves cannot be adjusted or affected.
# The A and B values are always equal to the C value.  Thus, it is
# an error for there to be entries in the adjustments or effects tables
# for untracked curves.  Therefore:
#
# * When a curve becomes untracked, any pending adjustments or effects
#   are deleted.
# * The [$ucurve apply] method will throw an error if there are any
#   pending adjustments or effects for untracked curves; a well-behaved
#   client shouldn't be providing adjustments or effects for curves
#   it knows to be untracked.
#
# Note that we do not throw an error when the invalid adjustments and
# effects are created, because doing so requires an additional database
# query.

snit::type ::simlib::ucurve {

    #-------------------------------------------------------------------
    # sqlsection(i) implementation
    #
    # The following routines implement the module's 
    # sqlsection(i) interface.

    # Type method: sqlsection title
    #
    # Returns a human-readable title for the section.

    typemethod {sqlsection title} {} {
        return "ucurve(n)"
    }

    # Type method: sqlsection schema
    #
    # Returns the section's persistent schema definitions, which are
    # read from ucurve.sql.

    typemethod {sqlsection schema} {} {
        return [readfile [file join $::simlib::library ucurve.sql]]
    }

    # Type method: sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, which are
    # read from ucurve.sql.

    typemethod {sqlsection tempschema} {} {
        return {}
    }

    # Type method: sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes.
    #
    #   clamp - Clamp a curve within its limits

    typemethod {sqlsection functions} {} {
        return [list \
                    ucurve_clamp [myproc ClampCurve]]
    }

    #-------------------------------------------------------------------
    # Type Variables

    # Type Variable: rdbTracker
    #
    # Array, ucurve(n) instance by RDB. This array tracks which RDBs 
    # are in use by ucurve instances; thus, if we create a new instance on 
    # an RDB that's already in use, we can throw an error.
    
    typevariable rdbTracker -array { }

    #-------------------------------------------------------------------
    # Options

    delegate option -automark to us
    delegate option -undo     to us

    # -rdb
    #
    # The name of the sqldocument(n) instance in which
    # ucurve(n) will store its working data.  After creation, the
    # value will be stored in the rdb component.

    option -rdb \
        -readonly 1

    # -savehistory
    #
    # If on, contributions by drivers will be saved; otherwise not.
    # Turning -savehistory off will clear any saved history.

    option -savehistory \
        -type            snit::boolean     \
        -default         on                \
        -configuremethod ConfigSaveHistory

    method ConfigSaveHistory {opt val} {
        set options($opt) $val

        if {!$val} {
            $rdb eval { DELETE FROM ucurve_contribs_t }
        }
    }

    # -undostack
    #
    # The name of an undostack(n) object.  If none is specified, the
    # instance will create its own with -tag ucurve.

    option -undostack \
        -readonly 1

    #-------------------------------------------------------------------
    # Components
    #
    # Each instance of ucurve(n) uses the following components.
    
    component rdb  ;# The RDB, passed in as -rdb.
    component us   ;# The undostack(n)

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor
    #
    # Creates a new instance of ucurve(n), given the creation options.
    
    constructor {args} {
        # FIRST, get the RDB and verify that there's only one ucurve(n)
        # on this RDB.
        set rdb [from args -rdb ""]
        assert {[info commands $rdb] ne ""}
        require {$type in [$rdb sections]} \
            "ucurve(n) is not registered with database $rdb"

        if {[info exists rdbTracker($rdb)]} {
            return -code error \
                "RDB $rdb already in use by ucurve(n) $rdbTracker($rdb)"
        }

        set options(-rdb) $rdb

        # NEXT, get the undostack.
        set us [from args -undostack ""]

        if {$us eq ""} {
            install us using undostack ${selfns}::us \
                -rdb      $rdb                       \
                -tag      ucurve                     \
                -undo     off                        \
                -automark on
        }

        set options(-undostack) $us

        # NEXT, get the creation arguments.
        $self configurelist $args

        
        set rdbTracker($rdb) $self
    }
    
    # destructor
    #
    # Removes the instance's rdb from the rdbTracker, and deletes
    # the instance's content from the relevant RDB tables.

    destructor {
        catch {
            unset -nocomplain rdbTracker($rdb)
            $self clear
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method edit to us

    # clear
    #
    # Removes all ucurve(n) data from the RDB. This command is
    # not undoable.

    method clear {} {
        # Note: Deleting the curve types will also delete all
        # curves, effects, and adjustments.
        $rdb eval {
            DELETE FROM ucurve_contribs_t;
            DELETE FROM ucurve_ctypes_t;
        }

        $self edit reset
    }

    # reset
    #
    # Resets all curves to their initial values and deletes all
    # effects.  This command is not undoable.
    method reset {} {
        $rdb eval {
            DELETE FROM ucurve_effects_t;
            DELETE FROM ucurve_adjustments_t;
            DELETE FROM ucurve_contribs_t;

            UPDATE ucurve_curves_t 
            SET a = a0,
                b = b0,
                c = c0;
        }

        $self edit reset
    }

    # ctype add name ?options...?
    #
    # name   - Curve type name
    #
    # Options:
    #
    #    -alpha  - Alpha parameter
    #    -gamma  - Gamma parameter
    #
    # Adds a new curve type with the given options.
    # Undoable.  Returns the ID of the new curve type.

    method {ctype add} {name min max args} {
        # FIRST, check the min/max values
        snit::double validate $min
        snit::double validate $max
        require {$min < $max} "min must be less than max"

        # NEXT, use a transaction, so that there will be no
        # change to the database in case of an error in an option value.

        $rdb transaction {
            # FIRST, add the record
            $rdb eval {
                INSERT INTO ucurve_ctypes_t(name, min, max)
                VALUES(nullif($name,''), $min, $max);
            }

            set id [$rdb last_insert_rowid]

            # NEXT, set the option values
            $self DbConfigure ucurve_ctypes_t [list $name] $args
        }

        # NEXT, save the undo information
        $us add [list $self UndoCtypeAdd $name]

        return $id
    }

    # UndoCtypeAdd name
    #
    # name - The curve type name
    #
    # Deletes a curve type, including dependent records.

    method UndoCtypeAdd {name} {
        $rdb eval {
            DELETE FROM ucurve_ctypes_t WHERE name=$name;
        }
    }

    # ctype names
    #
    # Returns the names of all curve types.

    method {ctype names} {} {
        $rdb eval {
            SELECT name FROM ucurve_ctypes_t ORDER BY ct_id
        }
    }

    # ctype id name
    # 
    # name - The name of a curve type
    #
    # Returns the ID, or "" if none found.

    method {ctype id} {name} {
        $rdb onecolumn {SELECT ct_id FROM ucurve_ctypes_t WHERE name=$name}
    }

    # ctype name id
    # 
    # id - The ID of a curve type
    #
    # Returns the name, or "" if none found.

    method {ctype name} {id} {
        $rdb onecolumn {SELECT name FROM ucurve_ctypes_t WHERE ct_id=$id}
    }

    # ctype cget name option
    #
    # name    - Curve Type Name
    # option  - The name of a ctype option.
    #
    # Retrieves the value of a ctype option: one of
    #
    #   -min
    #   -max
    #   -alpha
    #   -beta
    #   -gamma

    method {ctype cget} {name option} {
        $self DbCget ucurve_ctypes [list $name] $option
    }

    # ctype configure name ?options...?
    #
    # name     - Curve Type Name
    # options  - A list of option names and values.
    #
    #   -alpha value    - Sets the curve type's alpha
    #   -gamma value    - Sets the curve type's gamma
    #
    # Sets ctype option values.

    method {ctype configure} {name args} {
        # FIRST, get the undo script.  Don't save it yet, as there
        # might be an error in the arguments.
        set UndoData [$rdb grab ucurve_ctypes_t {name=$name}]
        set script [list $rdb ungrab $UndoData]

        # NEXT, make the change.
        $self DbConfigure ucurve_ctypes_t [list $name] $args

        # NEXT, save the undo script
        $us add $script

        return
    }

    # ctype delete name
    #
    # name - The curve type name.
    #
    # Deletes a curve type, along with any dependent records.

    method {ctype delete} {name} {
        # FIRST, delete the type, grabbing the undo data set.
        set data [$rdb delete -grab ucurve_ctypes_t {name=$name}]

        # NEXT, save the undo script.
        $us add [list $rdb ungrab $data]

        return
    }
    
    # curve add ctype ?a b c...?
    #
    # ctype    - A curve type ID or name
    # a,b,c    - The A, B, and C values for a new curve
    #
    # Defines zero or more curves in the order given, and returns a list
    # of the curve IDs.  The values are all presumed to be numeric in 
    # the correct range.

    method {curve add} {ctype args} {
        # FIRST, get the curve type ID
        if {[$rdb exists {
            SELECT * FROM ucurve_ctypes_t WHERE ct_id=$ctype
        }]} {
            set ct_id $ctype
        } else {
            set ct_id [$rdb eval {
                SELECT ct_id FROM ucurve_ctypes_t WHERE name=$ctype
            }]
        }

        require {$ct_id ne ""} "Unknown curve type, \"$ctype\""

        # NEXT, we need to remember the curve IDs
        set ids [list]

        # NEXT, use a transaction so that nothing changes on error.
        $rdb transaction {
            foreach {a b c} $args {
                $rdb eval {
                    INSERT INTO ucurve_curves_t(ct_id, a, b, c, a0, b0, c0)
                    VALUES($ct_id, $a, $b, $c, $a, $b, $c);
                }

                lappend ids [$rdb last_insert_rowid]
            }
        }

        # NEXT, save the undo information
        $us add [list $self UndoCurveAdd [lindex $ids 0]]

        return $ids
    }

    # UndoCurveAdd id
    #
    # id   - A curve ID
    #
    # Undoes the operation that added the curve ID.

    method UndoCurveAdd {id} {
        $rdb eval {DELETE FROM ucurve_curves_t WHERE curve_id >= $id}
    }

    # curve exists curve_id
    #
    # curve_id   - Possibly, a curve ID
    #
    # Returns 1 if the curve exists, and 0 otherwise.

    method {curve exists} {curve_id} {
        $rdb exists {SELECT * FROM ucurve_curves_t WHERE curve_id=$curve_id}
    }

    # curve configure id ?options...?
    #
    # id       - Curve ID
    # options  - A list of option names and values.
    #
    # Sets curve option values.

    method {curve configure} {id args} {
        # FIRST, get the undo script.  Don't save it yet, as there
        # might be an error in the arguments.
        set UndoData [$rdb grab ucurve_curves_t {curve_id=$id}]
        set script [list $rdb ungrab $UndoData]

        # NEXT, make the change.
        $self DbConfigure ucurve_curves_t [list $id] $args

        # NEXT, save the undo script
        $us add $script

        return
    }

    # curve cget id option
    #
    # id      - A curve ID
    # option  - The name of a ctype option.  See [ctype configure].
    #
    # Retrieves the value of a ctype option.

    method {curve cget} {id option} {
        $self DbCget ucurve_curves_t [list $id] $option
    }

    # curve track curve_ids
    #
    # curve_ids    - A list of curve IDs
    #
    # NOT UNDOABLE! Sets the tracked flag for each curve.
    # This is intended as a fast bulk operation, so error-checking is 
    # minimal.

    method {curve track} {curve_ids} {
        # FIRST, do this in a transaction, so that nothing changes on error.
        $rdb transaction {
            foreach curve_id $curve_ids {
                $rdb eval {
                    UPDATE ucurve_curves_t
                    SET tracked=1
                    WHERE curve_id=$curve_id;
                }
            }
        }

        # NEXT, this is not undoable.
        $self edit reset
    }

    # curve untrack curve_ids
    #
    # curve_ids    - A list of curve IDs
    #
    # NOT UNDOABLE! Clears the tracked flag for each curve.
    # This is intended as a fast bulk operation, so error-checking is 
    # minimal.

    method {curve untrack} {curve_ids} {
        # FIRST, do this in a transaction, so that nothing changes on error.
        $rdb transaction {
            foreach curve_id $curve_ids {
                $rdb eval {
                    UPDATE ucurve_curves_t
                    SET tracked=0
                    WHERE curve_id=$curve_id;

                    DELETE FROM ucurve_adjustments_t
                    WHERE curve_id=$curve_id;

                    DELETE FROM ucurve_effects_t
                    WHERE curve_id=$curve_id;
                }
            }
        }

        # NEXT, this is not undoable.
        $self edit reset
    }

    # istracked curve_id
    #
    # Returns if the curve is tracked, and 0 otherwise.

    method istracked {curve_id} {
        return [$rdb onecolumn {
            SELECT tracked FROM ucurve_curves_t
            WHERE curve_id = $curve_id
        }]
    }   

    # curve bset curve_id b ?curve_id b...?
    #
    # curve_id    - A curve ID
    # b           - A new B value
    #
    # NOT UNDOABLE! Sets the B value for each curve.  This is
    # intended as a fast bulk operation, so error-checking is 
    # minimal.

    method {curve bset} {args} {
        # FIRST, do this in a transaction, so that nothing changes on error.
        $rdb transaction {
            foreach {curve_id b} $args {
                $rdb eval {
                    UPDATE ucurve_curves_t
                    SET b=$b
                    WHERE curve_id=$curve_id;
                }
            }
        }

        # NEXT, this is not undoable.
        $self edit reset
    }

    # curve cset curve_id c ?curve_id c...?
    #
    # curve_id    - A curve ID
    # c           - A new C value
    #
    # NOT UNDOABLE! Sets the C value for each curve.  This is
    # intended as a fast bulk operation, so error-checking is 
    # minimal.

    method {curve cset} {args} {
        # FIRST, do this in a transaction, so that nothing changes on error.
        $rdb transaction {
            foreach {curve_id c} $args {
                $rdb eval {
                    UPDATE ucurve_curves_t
                    SET c=$c
                    WHERE curve_id=$curve_id;
                }
            }
        }

        # NEXT, this is not undoable.
        $self edit reset
    }

    # transient driver_id cause_id curve_id mag ?curve_id mag...?
    #
    # driver_id   - The unique integer ID of the driver causing this
    #               effect.
    # cause_id    - The unique integer ID of the "cause", e.g., sickness
    # curve_id    - The curve receiving this effect.
    # mag         - The magnitude of the effect.
    #
    # Undoable.  Adds one or more transient effects, all related to a 
    # single driver and cause.
    #
    # Note that effects on untracked curves will be accepted here, but
    # will cause an error on [apply]
    
    method transient {driver_id cause_id args} {
        $self AddEffect 0 $driver_id $cause_id {*}$args
    }

    # persistent driver_id cause_id curve_id mag ?curve_id mag...?
    #
    # driver_id   - The unique integer ID of the driver causing this
    #               effect.
    # cause_id    - The unique integer ID of the "cause", e.g., sickness
    # curve_id    - The curve receiving this effect.
    # mag         - The magnitude of the effect.
    #
    # Undoable.  Adds one or more persistent effects, all related to a 
    # single driver and cause.
    #
    # Note that effects on untracked curves will be accepted here, but
    # will cause an error on [apply]
    
    method persistent {driver_id cause_id args} {
        $self AddEffect 1 $driver_id $cause_id {*}$args
    }

    # AddEffect pflag driver_id cause_id curve_id mag ?curve_id mag...?
    #
    # pflag       - Persistence flag, 1 if persistent, 0 if transient
    # driver_id   - The unique integer ID of the driver causing this
    #               effect.
    # cause_id    - The unique integer ID of the "cause", e.g., sickness
    # curve_id    - The curve receiving this effect.
    # mag         - The magnitude of the effect.
    #
    # Undoable.  Adds one or more persistent effects, all related to a 
    # single driver and cause.
    
    method AddEffect {pflag driver_id cause_id args} {
        # FIRST, prepare to save the undo info
        set eid ""

        # NEXT, do this in a transaction, so there's no change on error.
        $rdb transaction {
            foreach {curve_id mag} $args {
                $rdb eval {
                    INSERT INTO ucurve_effects_t(
                        curve_id, 
                        driver_id,
                        cause_id, 
                        pflag,
                        mag)
                    VALUES(
                        $curve_id,
                        $driver_id,
                        $cause_id,
                        $pflag,
                        $mag
                    );
                }

                if {$eid eq ""} {
                    set eid [$rdb last_insert_rowid]
                }
            }
        }

        $us add [list $self UndoEffect $eid]
    }

    # UndoEffect eid
    #
    # eid   - An effect ID
    #
    # Undoes the operation that added the effect ID.

    method UndoEffect {eid} {
        $rdb eval {DELETE FROM ucurve_effects_t WHERE e_id >= $eid}
    }


    # adjust driver_id curve_id delta ?curve_id delta...?
    #
    # driver_id   - The unique integer ID of the driver causing this
    #               effect.
    # curve_id    - The curve whose baseline will be adjusted.
    # mag         - The delta to the baseline.
    #
    # Undoable.  Adds one or more adjustments, all related to a single driver.
    # The net adjustments take place immediately; the net adjustments
    # are accumulated in the ucurve_adjustments_t table, and saved as
    # contributions when time is advanced.
    
    method adjust {driver_id args} {
        # FIRST, prepare to save the undo info
        set aid ""

        # NEXT, do this in a transaction, so there's no change on error.
        $rdb transaction {
            foreach {curve_id delta} $args {
                # FIRST, get the old b value, the min, and the max.
                set b ""

                $rdb eval {
                    SELECT C.b       AS b,
                           T.min     AS min,
                           T.max     AS max
                    FROM ucurve_curves_t AS C
                    JOIN ucurve_ctypes   AS T USING (ct_id)
                    WHERE C.curve_id = $curve_id
                } {}

                require {$b ne ""} "invalid curve_id \"$curve_id\""

                # NEXT, compute and clamp bnew and compute
                # the true delta.
                set bnew [expr {$b + $delta}]
                    
                if {$bnew < $min} {
                    set bnew $min
                    set delta [expr {$min - $b}]
                } elseif {$bnew > $max} {
                    set bnew $max
                    set delta [expr {$max - $b}]
                }

                # NEXT, update the actual baseline.
                $rdb eval {
                    UPDATE ucurve_curves_t
                    SET b = $bnew
                    WHERE curve_id = $curve_id;
                }

                # NEXT, save the adjustment, so that it can 
                # be added to the contributions on apply.

                $rdb eval {
                    INSERT INTO ucurve_adjustments_t(
                        curve_id, 
                        driver_id,
                        delta)
                    VALUES(
                        $curve_id,
                        $driver_id,
                        $delta
                    );
                }

                if {![info exists oldBs($curve_id)]} {
                    set oldBs($curve_id) $b
                }

                if {$aid eq ""} {
                    set aid [$rdb last_insert_rowid]
                }
            }
        }

        $us add [list $self UndoAdjust [array get oldBs] $aid]
    }

    # UndoAdjust oldBs aid
    #
    # oldBs - Array of old B values.
    # aid   - An adjustment ID
    #
    # Undoes the adjustment operation.

    method UndoAdjust {oldBs aid} {
        # FIRST, reset the baselines.
        foreach {curve_id b} $oldBs {
            $rdb eval {
                UPDATE ucurve_curves_t
                SET b=$b
                WHERE curve_id=$curve_id;
            }
        }
        
        # NEXT, get rid of the adjustment records.
        $rdb eval {DELETE FROM ucurve_adjustments_t WHERE a_id >= $aid}
    }


    #-------------------------------------------------------------------
    # apply

    # apply t ?-start?
    #
    # t            - A timestamp
    # -start       - Start flag.
    #
    # Updates all curves for which we are tracking changes, applying
    # adjustments and effects.  Untracked curves have their actual and 
    # baseline levels set to their natural levels.
    #
    # If -start, then we are initializing the model at time t.  The baseline 
    # is NOT recomputed, and only transient effects are applied.  Finally,
    # the a, b, and c values for each curve will be saved as a0, b0, and c0.
    # (Any persistent effects will be thrown away unused...so don't 
    # make any.)

    method apply {t {opt ""}} {
        # FIRST, complain if there are effects or adjustments on untracked
        # curves.  There shouldn't be.

        if {[$rdb exists {
            SELECT e_id FROM ucurve_effects_t
            JOIN ucurve_curves_t USING (curve_id)
            WHERE tracked = 0
            UNION 
            SELECT a_id FROM ucurve_adjustments_t
            JOIN ucurve_curves_t USING (curve_id)
            WHERE tracked = 0
        }]} {
            error "Effects or adjustments exist on untracked curves."
        }

        # NEXT, handle all untracked curves; just set everything to the
        # natural level.
        $rdb eval {
            UPDATE ucurve_curves_t
            SET a = c,
                b = c
            WHERE tracked = 0;
        }

        # NEXT, handle pending adjustments.
        $self SaveAdjustmentContributions $t

        # NEXT, handle baseline effects if the flag is not given.
        if {$opt ne "-start"} {
            # NEXT, compute B.t = alpha*A.t-1 + beta*B.t-1 + gamma*C.t,
            # along with scaling factors for B.t.
            $self ComputeBaselineAndScalingFactors

            # NEXT, apply pending persistent effects
            if {[$self ComputeContributionsByCause -persistent]} {
                # Add the DeltaB's to the B.t's, and update the
                # scaling factors.
                $self UpdateBaselineAndScalingFactors
            }
        } else {
            # Transient effects only; but we still need to compute
            # the baseline scaling factors.  Clear the deltas.

            $rdb eval {UPDATE ucurve_curves_t SET delta = 0.0}
            $self UpdateBaselineAndScalingFactors
        }
        
        # NEXT, apply the pending transient effects.
        $self ComputeContributionsByCause -transient
        $self ComputeCurrentLevels

        # NEXT, save the contributions of each driver due to
        # both baseline and transient effects.
        $self SaveContributionsByDriver $t

        # NEXT, clean up for next time.
        $self PurgeEffectsAndAdjustments

        # NEXT, if t=0, save a0, b0, and c0 for all curves.
        if {$opt eq "-start"} {
            $rdb eval {
                UPDATE ucurve_curves_t
                SET a0 = a,
                    b0 = b,
                    c0 = c;
            }
        }

        # NEXT, This cannot be undone.
        $self edit reset
    }

    # SaveAdjustmentContributions t
    #
    # t - A timestamp
    #
    # Save the contributions for all of the baseline adjustments.
    # We should only save contributions for untracked curves...
    # but we ensured that there were no such in [apply].

    method SaveAdjustmentContributions {t} {
        $rdb eval {
            SELECT curve_id       AS curve_id,
                   driver_id      AS driver_id,
                   total(delta)   AS delta
            FROM ucurve_adjustments_t
            GROUP BY curve_id, driver_id
        } {
            $self SaveContrib $curve_id $driver_id $t $delta
        }
    }


    # ComputeBaselineAndScalingFactors
    #
    # Recomputes the baseline value B, and also the positive and
    # negative scaling factors for every curve, for *tracked*
    # curves only.

    method ComputeBaselineAndScalingFactors {} {
        foreach {curve_id bnew min max} [$rdb eval {
            SELECT C.curve_id                             AS curve_id,
                   T.alpha*C.a + T.beta*C.b + T.gamma*C.c AS bnew,
                   T.min                                  AS min,
                   T.max                                  AS max
            FROM ucurve_ctypes   AS T
            JOIN ucurve_curves_t AS C USING (ct_id)
            WHERE C.tracked = 1
        }] {
            # Note: This same UPDATE is used in 
            # UpdateBaselineAndScalingFactors; if it's updated here,
            # it should be updated there.
            $rdb eval {
                UPDATE ucurve_curves_t
                SET b = $bnew,
                    posfactor = ($max - $bnew)/100.0,
                    negfactor = ($bnew - $min)/100.0
                WHERE curve_id = $curve_id
            }
        }
    }


    # ComputeContributionsByCause mode
    #
    # mode - -persistent or -transient
    #
    # Given the current mode, determine the maximum positive and 
    # negative contributions for each curve and cause and apply them 
    # to the curve's delta.
    #
    # NOTE: This should operate only on tracked curves; but since
    # only tracked curves will have effects we don't need to do
    # anything special.
    #
    # Returns 1 if there were any contributions, and 0 otherwise.

    method ComputeContributionsByCause {mode} {
        # FIRST, get the pflag
        set pflag [expr {$mode eq "-persistent"}]

        # NEXT, clear the curve deltas
        $rdb eval {UPDATE ucurve_curves_t SET delta = 0.0}

        # NEXT, accumulate the actual contributions to the
        # curves.
        set updates [list]

        $rdb eval {
            SELECT curve_id   AS curve_id, 
                   cause_id   AS cause_id,
                   posfactor  AS posfactor,
                   negfactor  AS negfactor,
                   max(pos)   AS maxpos,
                   sum(pos)   AS sumpos,
                   min(neg)   AS minneg,
                   sum(neg)   AS sumneg
            FROM
            (SELECT E.curve_id      AS curve_id, 
                    C.posfactor     AS posfactor, 
                    C.negfactor     AS negfactor,
                    E.cause_id      AS cause_id, 
                    CASE WHEN E.mag > 0
                         THEN E.mag
                         ELSE 0 END AS pos,
                    CASE WHEN E.mag < 0
                         THEN E.mag
                         ELSE 0 END AS neg
             FROM ucurve_effects_t AS E
             JOIN ucurve_curves_t  AS C USING (curve_id)
             WHERE E.pflag=$pflag)
            GROUP BY curve_id, cause_id
        } {
            # FIRST, get the net contribution of this cause.
            set net [expr {$maxpos + $minneg}]

            if {$net >= 0} {
                set scale $posfactor
            } else {
                set scale $negfactor
            }

            set acontrib [expr {$scale*$net}]

            lappend updates $curve_id $acontrib

            # NEXT, get the scaled actual positive contribution as a fraction
            # of the total sum
            if {$maxpos > 0.0} {
                let posfrac($curve_id,$cause_id) {$scale*$maxpos/$sumpos}
            }
            
            # NEXT, get the scaled actual negative contribution as a fraction
            # of the total sum.
            if {$minneg < 0.0} {
                let negfrac($curve_id,$cause_id) {$scale*$minneg/$sumneg}
            }
        }

        # NEXT, if there were none, we can stop here.
        if {[llength $updates] == 0} {
            return 0
        }

        # NEXT, apply the net contributions to the curves.
        foreach {curve_id acontrib} $updates {
            $rdb eval {
                UPDATE ucurve_curves_t
                SET delta = delta + $acontrib
                WHERE curve_id=$curve_id
            }
        }

        # NEXT, give effects scaled credit for their contribution
        # in proportion to their magnitude.

        $rdb eval {
            SELECT E.e_id     AS e_id,
                   E.curve_id AS curve_id,
                   E.cause_id AS cause_id,
                   E.mag      AS mag
            FROM ucurve_effects_t AS E
            JOIN ucurve_curves_t AS C USING (curve_id)
            WHERE C.tracked = 1 AND E.pflag=$pflag AND E.mag != 0.0
        } {
            # FIRST, retrieve the multiplier based on the sign of the
            # magnitude
            if {$mag >= 0.0} {
                set mult $posfrac($curve_id,$cause_id)
            } else {
                set mult $negfrac($curve_id,$cause_id)
            } 

            # NEXT update the effects
            $rdb eval {
                UPDATE ucurve_effects_t
                SET actual = $mult*$mag
                WHERE e_id=$e_id
            }
        }

        return 1
    }

    # UpdateBaselineAndScalingFactors
    #
    # Adds the DeltaB resulting from persistent effects to the baseline,
    # clamping if need be, and updates the scale factors.
    #
    # Untracked curves are ignored.
    #
    # On [apply $t -transients], this is called with deltas all zero,
    # just to compute the scaling factors.

    method UpdateBaselineAndScalingFactors {} {
        foreach {curve_id bnew min max} [$rdb eval {
            SELECT C.curve_id    AS curve_id,
                   C.b + C.delta AS bnew,
                   T.min         AS min,
                   T.max         AS max
            FROM ucurve_curves_t AS C
            JOIN ucurve_ctypes_t AS T USING (ct_id)
            WHERE C.tracked = 1;
        }] {
            # FIRST, clamp the curve
            if {$bnew > $max} {
                set bnew $max
            } elseif {$bnew < $min} {
                set bnew $min
            }

            # Note: This same UPDATE is used in 
            # ComputeBaselineAndScalingFactors; if it's updated here,
            # it should be updated there.
            $rdb eval {
                UPDATE ucurve_curves_t
                SET b = $bnew,
                    posfactor = ($max - $bnew)/100.0,
                    negfactor = ($bnew - $min)/100.0
                WHERE curve_id = $curve_id
            }
        }
    }

    # ComputeCurrentLevels
    #
    # Computes the current level of each curve from the baseline
    # and delta, and clamps it within bounds.  Untracked curves
    # are ignored.

    method ComputeCurrentLevels {} {
        foreach {curve_id anew min max} [$rdb eval {
            SELECT C.curve_id    AS curve_id,
                   C.b + C.delta AS anew,
                   T.min         AS min,
                   T.max         AS max
            FROM ucurve_curves_t AS C
            JOIN ucurve_ctypes_t AS T USING (ct_id)
            WHERE C.tracked = 1;
        }] {
            # FIRST, clamp the curve
            if {$anew > $max} {
                set anew $max
            } elseif {$anew < $min} {
                set anew $min
            }

            $rdb eval {
                UPDATE ucurve_curves_t
                SET a = $anew
                WHERE curve_id = $curve_id
            }
        }
    }

    # SaveContributionsByDriver t
    #
    # t - The timestamp of this time advance.
    #
    # Saves the contribution of each effect to the relevant driver.

    method SaveContributionsByDriver {t} {
        if {!$options(-savehistory)} {
            return
        }

        $rdb eval {
            SELECT curve_id, driver_id, total(actual) as contrib
            FROM ucurve_effects_t
            GROUP BY curve_id, driver_id
        } {
            $self SaveContrib $curve_id $driver_id $t $contrib
        }
    }

    # PurgeEffectsAndAdjustments
    #
    # Purges the applied effects and adjustments; we don't need them anymore.
    
    method PurgeEffectsAndAdjustments {} {
        $rdb eval {
            DELETE FROM ucurve_effects_t;
            DELETE FROM ucurve_adjustments_t;
        }
    }

    # SaveContrib curve_id driver_id t contrib
    #
    # curve_id    - The curve that changed
    # driver_id   - The responsible driver
    # t           - The timestamp
    # contrib     - The new contribution

    method SaveContrib {curve_id driver_id t contrib} {
        if {!$options(-savehistory)} {
            return
        }

        $rdb eval {
            INSERT OR IGNORE INTO ucurve_contribs_t(curve_id,driver_id,t)
            VALUES($curve_id,$driver_id,$t);

            UPDATE ucurve_contribs_t
            SET contrib = contrib + $contrib
            WHERE curve_id=$curve_id AND driver_id=$driver_id AND t=$t;
        }
    }
   
    #-------------------------------------------------------------------
    # Generic DB Methods
    #
    # These routines implement a generic way to set and get table
    # column values using a configure/cget interface.  The specifics
    # of the table are defined in the tableInfo array, and then the
    # public interface calls the Db* interface.

    # Table Info Array
    #
    # This table contains data used by the generic routines.
    #
    # $table-keys      - List of names of primary key columns.
    # $table-options   - List of names of table options
    # $table-where     - Where clause

    typevariable tableInfo -array {
        ucurve_ctypes_t-keys      {name}
        ucurve_ctypes_t-configure {-alpha -gamma}
        ucurve_ctypes_t-where     {WHERE name=$key(name)}

        ucurve_ctypes-keys        {name}
        ucurve_ctypes-cget        {-min -max -alpha -beta -gamma}
        ucurve_ctypes-where       {WHERE name=$key(name)}

        ucurve_curves_t-keys      {curve_id}
        ucurve_curves_t-configure {-b -c}
        ucurve_curves_t-cget      {-tracked -b -c}
        ucurve_curves_t-where     {WHERE curve_id=$key(curve_id)}
    }

    # DbCget table keyVals option
    #
    # table    - The name of the table
    # keyVals  - A list of the values of the key fields
    # option   - The name of the option to retrieve.
    #
    # Retrieves the value of a table column

    method DbCget {table keyVals option} {
        # FIRST, get the key array
        foreach name $tableInfo($table-keys) val $keyVals {
            set key($name) $val
        }

        # NEXT, get the column name
        if {$option in $tableInfo($table-cget)} {
            set colname [string range $option 1 end]
        } else {
            error "Unknown $table option: \"$option\""
        }

        # NEXT, get the value
        $rdb eval "
            SELECT $colname FROM $table 
            $tableInfo($table-where)
        " row {
            return $row($colname)
        }

        # NEXT, there's no such key.
        error "Unknown $table key: \"$keyVals\""
    }


    # DbConfigure table keyVals optList
    #
    # table     - The name of a table in tableInfo
    # keyVals   - A list of the values of the key field(s)
    # optList   - A list of option names and values.
    #
    # Sets column values in the row specified by the
    # keyVals.  If there is an
    # error in one of the options or values, the database
    # will be rolled back (provided rollbacks are enabled,
    # and that this routine wasn't called from within a wider
    # transaction).

    method DbConfigure {table keyVals optList} {
        # FIRST, if there's nothing being updated, we are done
        if {[llength $optList] == 0} {
            return
        }

        # NEXT, store options in a local list, use the incoming
        # options list for error reporting, if necessary.
        set opts $optList

        # NEXT, get the key array
        foreach name $tableInfo($table-keys) val $keyVals {
            set key($name) $val
        }

        # NEXT, accumulate option value pairs into a single list of
        # updates in SQL syntax, we will update them at once.
        # Note the use of a counter for array variables to update 
        # column values -- this is to keep SQLite happy, it must have 
        # fixed indices for arrays.
        set ctr 0
        set updates [list]

        while {[llength $opts] > 0} {
            set opt [lshift opts]

            if {$opt in $tableInfo($table-configure)} {
                set colname     [string range $opt 1 end]
                set value($ctr) [lshift opts]

                lappend updates "$colname=\$value($ctr)"
                incr ctr

            } else {
                error "Unknown $table option: \"$opt\""
            }
        }


        # NEXT, join all updates and do the RDB transaction
        set allsets [join $updates ", "]

        $rdb transaction {
            if {[catch {
                $rdb eval "
                    UPDATE $table
                    SET $allsets
                    $tableInfo($table-where)
                " 
            } result]} {
                error "Invalid $table $optList: $result"
            }
            if {[$rdb changes] == 0} {
                error "Unknown $table key: \"$keyVals\""
            }
        }

        return
    }
}

