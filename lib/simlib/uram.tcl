#-----------------------------------------------------------------------
# TITLE:
#   uram.tcl
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
#   URAM: Unified Regional Analysis Module
#
# TODO:
#   Remove undo/redo, since we don't use it.
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export uram
}

#-----------------------------------------------------------------------
# Object Types

# A simpler replacement for qmag(n), since we do not in fact give
# symbolic values to uram(n).
snit::double ::simlib::umag -min -100.0 -max 100.0

#-----------------------------------------------------------------------
# uram Type
#
# URAM -- Unified Regional Analysis Model
#
# Instances of the uram object type do the following.
#
#  * Bookkeep URAM inputs.
#  * Recompute URAM outputs as simulation time is advanced.
#  * Allow the owner to enter URAM effects and adjustments
#  * Allow introspection of all inputs and outputs.
#
# Note that the instance of uram cannot "run" on its own; it expects to be
# embedded in a larger simulation which will control the advancement
# of simulation time and enter URAM effects and adjustments as needed.

snit::type ::simlib::uram {
    #-------------------------------------------------------------------
    # Type Components

    # parm
    #
    # uram(n) supports the parm(i) interface.  This component is
    # uram(n)'s configuration parmset.  Because it is -public,
    # it is automatically available as a type method.
    
    typecomponent parm -public parm


    #-------------------------------------------------------------------
    # Type Constructor
    #
    # The type constructor is responsible for creating the parm
    # component and adding the URAM configuration parameters.

    typeconstructor {
        # FIRST, Import needed commands from other packages.
        namespace import ::marsutil::*

        # NEXT, define the module's configuration parameters.
        set parm ${type}::parm
        parmset $parm \
            -notifycmd [myproc ParmsNotify]

        $parm subset uram {
            uram(n) configuration parameters.
        }

        $parm define uram.saveHistory ::snit::boolean yes {
            If yes, URAM saves a history, timestep-by-timestep,
            of the actual contribution to each effect's curve during 
            that timestep by each driver, as well as the current
            level of each curve.  If no, it doesn't.
        }

        $parm define uram.coopRelationshipLimit ::simlib::rfraction 1.0 {
            Controls the set of civilian groups that receive cooperation
            indirect effects.  When CIV group g gets a direct cooperation
            effect, all groups f whose relationships rel.fg are
            greater than or equal to this limit receive indirect effects.
        }

        $parm subset uram.factors {
            <i>alpha</i> and <i>gamma</i> parameters for the different 
            attitude curve types.  Changes made to these parameters
            will take effect at the next time advance.  The <i>beta</i>
            value will be 1.0 minus the sum of <i>alpha</i> and 
            <i>gamma</i>.
        }

        $parm define uram.factors.AUT ::simlib::rfracpair {0.05 0.0} {
            <i>alpha</i> and <i>gamma</i> parameters for the Autonomy
            (AUT) satisfaction curve type, specified as a 
            white-space-delimited pair of floating point numbers. 
            <i>alpha</i> plus <i>gamma</i> must be less than or equal 
            to 1.0.
        }

        $parm define uram.factors.COOP ::simlib::rfracpair {0.05 0.02} {
            <i>alpha</i> and <i>gamma</i> parameters for the 
            cooperation curve type, specified as a white-space-delimited
            pair of floating point numbers. <i>alpha</i> plus <i>gamma</i>
            must be less than or equal to 1.0.
        }

        $parm define uram.factors.CUL ::simlib::rfracpair {0.05 0.0} {
            <i>alpha</i> and <i>gamma</i> parameters for the Culture
            (CUL) satisfaction curve type, specified as a 
            white-space-delimited pair of floating point numbers. 
            <i>alpha</i> plus <i>gamma</i> must be less than or equal 
            to 1.0.
        }

        $parm define uram.factors.HREL ::simlib::rfracpair {0.05 0.02} {
            <i>alpha</i> and <i>gamma</i> parameters for the horizontal
            relationship curve type, specified as a white-space-delimited
            pair of floating point numbers. <i>alpha</i> plus <i>gamma</i>
            must be less than or equal to 1.0.
        }

        $parm define uram.factors.QOL ::simlib::rfracpair {0.05 0.0} {
            <i>alpha</i> and <i>gamma</i> parameters for the Quality of
            Life (QOL) satisfaction curve type, specified as a 
            white-space-delimited pair of floating point numbers. 
            <i>alpha</i> plus <i>gamma</i> must be less than or equal
            to 1.0.
        }

        $parm define uram.factors.SFT ::simlib::rfracpair {0.05 0.02} {
            <i>alpha</i> and <i>gamma</i> parameters for the Safety
            (SFT) satisfaction curve type, specified as a 
            white-space-delimited pair of floating point numbers. 
            <i>alpha</i> plus <i>gamma</i> must be less than or equal
            to 1.0.
        }

        $parm define uram.factors.VREL ::simlib::rfracpair {0.05 0.02} {
            <i>alpha</i> and <i>gamma</i> parameters for the vertical
            relationship curve type, specified as a 
            white-space-delimited pair of floating point numbers. 
            <i>alpha</i> plus <i>gamma</i> must be less than or equal
            to 1.0.
        }

        $parm subset uram.raf {
            The Relationship Attenuation Factors are used when computing
            indirect effects based on horizontal relationships.  The 
            relationship multiplier is attenuated (decreased) by 
            multiplying it with either the positive or negative RAF.  This
            is so that strongly negative relationships will no longer
            cause pathological indirect effects.  (The positive RAF
            is defined mostly for symmetry.)
        }

        $parm define uram.raf.positive ::simlib::rfraction 1.0 {
            The positive Relationship Attenuation Factor.
        }

        $parm define uram.raf.negative ::simlib::rfraction 0.5 {
            The negative Relationship Attenuation Factor.
        }
    }

    # ParmsNotify dummy
    #
    # Updates all instances with the latest parms.

    proc ParmsNotify {dummy} {
        foreach o [::simlib::uram info instances] {
            $o ParmsNotifyCmd
        }
    }

    #-------------------------------------------------------------------
    # sqlsection(i) implementation
    #
    # The following routines implement the module's 
    # sqlsection(i) interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section.

    typemethod {sqlsection title} {} {
        return "uram(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, which are
    # read from uram.sql.

    typemethod {sqlsection schema} {} {
        return [readfile [file join $::simlib::library uram.sql]]
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, which would
    # be read from uram_temp.sql if we had any.

    typemethod {sqlsection tempschema} {} {
        return [readfile [file join $::simlib::library uram_temp.sql]]
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes
    # if any.

    typemethod {sqlsection functions} {} {
        return {}
    }

    #-------------------------------------------------------------------
    # Type Variables

    # rdbTracker
    #
    # Array, uram(n) instance by RDB. This array tracks which RDBs are 
    # in use by uram instances; thus, if we create a new instance on an 
    # RDB that's already in use by a URAM instance, we can throw an error.
    
    typevariable rdbTracker -array { }

    #-------------------------------------------------------------------
    # Options

    delegate option -undo to us

    # -driverbase number
    #
    # Base driver ID.  Defaults to 1000.

    option -driverbase \
        -type     {snit::integer -min 1} \
        -default  1000                   \
        -readonly 1

    # -loadcmd cmd
    #
    # The name of a command that will populate the URAM tables in the
    # RDB.  It must take one additional argument, $self.
    # See uram(n) for more details.

    option -loadcmd \
        -readonly 1

    # -logger cmd
    #
    # The name of application's logger(n) object.

    option -logger

    # -logcomponent name
    #
    # This object's "log component" name, to be used in log messages.

    option -logcomponent \
        -default  uram \
        -readonly 1

    # -rdb cmd
    #
    # The name of the sqldocument(n) instance in which
    # uram(n) will store its working data.  After creation, the
    # value will be stored in the rdb component.

    option -rdb \
        -readonly 1

    #-------------------------------------------------------------------
    # Components
    #
    # Each instance of uram(n) uses the following components.
    
    # rdb
    #
    # The run-time database (RDB), an instance of sqldocument(n) in which
    # uram(n) stores its data.  The RDB is passed in at creation time via
    # the -rdb option.

    component rdb

    # us
    #
    # The undostack(n) component, which is shared with ucurve(n).

    component us

    # cm
    #
    # The ucurve(n) component, the curve manager for this instance of
    # URAM.
    
    component cm
    
    #-------------------------------------------------------------------
    # Checkpointed Variables
    #
    # Most model data is stored in the rdb; however, there are a few
    # values that are stored in variables.
    
    # db
    #
    # Array of model scalars; the elements are as listed below.
    #
    #   initialized - 0 if -loadcmd has never been called, and 1 if 
    #                 it has.
    #   started     - 0 if the simulation has been initialized but not
    #                 "advanced" to its initial time.
    #   time        - Simulation Time: integer ticks, starting at -1
    #   nextDriver  - The next driver ID to assign; set from -driverbase.
    #   ssCache     - Satisfaction spread cache: a dictionary
    #                 {$g,$s,$p,$q -> spread}, where spread is a dict
    #                 {$g_id -> $factor}.
    #   scid        - Sat curve_id dict: g_id -> c_id -> curve_id
    #   causeIDs    - Dictionary: cause -> cause_id
    #   groupIDs    - Dictionary: g -> g_id
    #   concernIDs  - Dictionary: c -> c_id
    #   hrelIDs     - Dictionary: f -> g -> curve_id
    #   vrelIDs     - Dictionary: g -> a -> curve_id
    #   satIDs      - Dictionary: g -> c -> curve_id
    #   coopIDs     - Dictionary: f -> g -> curve_id
    #
    #-----------------------------------------------------------------------
    
    variable db -array { }

    #-------------------------------------------------------------------
    # Non-checkpointed Variables

    # clearedDB
    #
    # Array, values to use when clearing DB <db>.

    variable clearedDB {
        initialized      0
        started          0
        time             ""
        nextDriver       ""
        ssCache          {}
        scid             {}
        causeIDs         {}
        groupIDs         {}
        concernIDs       {}
        hrelIDs          {}
        vrelIDs          {}
        satIDs           {}
        coopIDs          {}
    }

    # info
    #
    # Array, non-checkpointed scalar data.  The keys are as follows.
    #
    #   changed     - 1 if the contents of db has changed, and 0 otherwise.
    
    variable info -array {
        changed   0
    }

    # trans
    #
    # Transient data, used during loading.
    #
    # loadstate   - indicates the progress of the -loadcmd.
    # fgids       - Dict, f_id,g_id -> fg_id, from uram_hrel_t,
    #               used to provide consistent fg_ids across tables.

    variable trans -array {
        loadstate ""
        fgids     ""
    }


    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor
    #
    # Creates a new instance of uram(n), given the creation options.
    
    constructor {args} {
        # FIRST, retrieve the -undo setting; we'll give to the undostack
        # explicitly once it has been created.
        set options(-undo) [from args -undo off]

        # NEXT, get the creation arguments.
        $self configurelist $args

        # NEXT, verify that we have a load command
        assert {$options(-loadcmd) ne ""}

        # NEXT, save the RDB component, verifying that no other instance
        # of URAM is using it.
        set rdb $options(-rdb)
        assert {[info commands $rdb] ne ""}

        require {$type in [$rdb sections]} \
            "uram(n) is not registered with database $rdb"
        
        if {[info exists rdbTracker($rdb)]} {
            return -code error \
                "RDB $rdb already in use by URAM $rdbTracker($rdb)"
        }
        
        set rdbTracker($rdb) $self

        # NEXT, create the undostack.
        install us using undostack ${selfns}::us       \
            -rdb         $rdb                          \
            -tag         uram                          \
            -undo        $options(-undo)               \
            -automark    off

        # NEXT, create the ucurve(n) curve manager.
        install cm using ucurve ${selfns}::cm        \
            -rdb         $rdb                        \
            -undostack   $us                         \
            -savehistory [$parm get uram.saveHistory]


        # NEXT, initialize db
        array set db $clearedDB
    }
    
    # destructor
    #
    # Removes the instance's rdb from the <rdbTracker>, and deletes
    # the instance's content from the relevant rdb tables.

    destructor {
        catch {
            unset -nocomplain rdbTracker($rdb)

            $self ClearTables
        }
    }
    #-------------------------------------------------------------------
    # Scenario Management

    # init ?-reload?
    #
    # -reload   - If present, calls the -loadcmd to reload the 
    #             initial data into the rdb.
    #
    # Initializes the simulation to time -1, reloads initial data on
    # demand.  [advance 0] must be called (after any transient inputs
    # due to starting conditions have been entered) to compute the
    # current levels at t=0 and thus complete the initialization.

    method init {{opt ""}} {
        # FIRST, get inputs from the RDB
        if {!$db(initialized) || $opt eq "-reload"} {
            $self LoadData
            set db(initialized) 1
        } elseif {$opt ne ""} {
            error "invalid option: \"$opt\""
        }

        # NEXT, set the time to -1.
        set db(time) -1
        set db(started) 0

        # NEXT, reset the driver ID
        set db(nextDriver) $options(-driverbase)

        # NEXT, Reset the curves in the curve manager.
        $cm reset

        # NEXT, Compute all roll-ups
        $self ComputeSatRollups
        $self ComputeCoopRollups

        # NEXT, save initial values
        $rdb eval {
            UPDATE uram_n        SET nbmood0 = nbmood;
            UPDATE uram_civ_g    SET mood0   = mood;
            UPDATE uram_nbcoop_t SET nbcoop0 = nbcoop;
        }

        return
    }

    # clear
    #
    # Uninitializes uram, returning it to its initial state on 
    # creation and deleting all of the instance's data from the rdb.
    # A new [init] is required to start moving again.

    method clear {} {
        # FIRST, reset the in-memory data
        array unset db
        array set db $clearedDB

        # NEXT, Clear the RDB
        $self ClearTables
    }
    
    # ClearTables
    #
    # Deletes all data from the uram.sql tables for this instance

    method ClearTables {} {
        # FIRST, clear all URAM tables.
        $rdb eval {
            SELECT name FROM sqlite_master
            WHERE type='table' AND name GLOB 'uram_*'
        } {
            $rdb eval "DELETE FROM $name"
        }

        # NEXT, clear the curve manager tables
        $cm clear
    }

    # initialized
    #
    # Returns 1 if the -loadcmd has ever been successfully called, and 0
    # otherwise.

    method initialized {} {
        return $db(initialized)
    }
    

    #-------------------------------------------------------------------
    # Load API
    #
    # URAM is usually initialized from the rdb, but different
    # applications have different database schemas; thus, URAM cannot
    # assume that the data will be in the form that it wants.
    # Consequently, this API is used by the load command to load new
    # data into URAM. The commands must be used in a strict order, as
    # indicated by trans(loadstate).  The order of states is:
    #
    #  * causes
    #  * actors
    #  * nbhoods
    #  * prox
    #  * civg
    #  * otherg
    #  * hrel
    #  * vrel
    #  * sat
    #  * coop
    #
    # The state indicates that the relevant "load *" method has
    # successfully been called, e.g., trans(loadstate) is "nbhoods"
    # after [load nbhoods] has been called.

    # LoadData
    #
    # This is called by <init> when it's necessary to reload input
    # data from the client.  It clears the current data, initializes
    # the trans(loadstate) state machine, calls the -loadcmd, verifies
    # that the state machine has terminated, and does a <SanityCheck>.

    method LoadData {} {
        # FIRST, clear all of the tables, so that they can be
        # refilled.
        $self ClearTables

        # NEXT, create the curve types in ucurve(n)
        # TBD: Get alphas and gammas from parms.
        $cm ctype add AUT  -100.0 100.0
        $cm ctype add CUL  -100.0 100.0 
        $cm ctype add QOL  -100.0 100.0 
        $cm ctype add SFT  -100.0 100.0 
        $cm ctype add HREL   -1.0   1.0 
        $cm ctype add VREL   -1.0   1.0 
        $cm ctype add COOP    0.0 100.0 

        $self ParmsNotifyCmd

        # NEXT, add the four concerns to uram_c.
        $rdb eval {
            INSERT INTO uram_c(c) VALUES('AUT');
            INSERT INTO uram_c(c) VALUES('CUL');
            INSERT INTO uram_c(c) VALUES('QOL');
            INSERT INTO uram_c(c) VALUES('SFT');
        }

        set db(concernIDs) [$rdb eval {
            SELECT c, c_id FROM uram_c
        }]

        # NEXT, the client's -loadcmd must call the "load *" methods
        # in a precise sequence.  Set up the state machine to handle
        # it.
        set trans(loadstate) begin
        set trans(fgids)     [dict create]

        # NEXT, call the -loadcmd.  The client will specify the
        # entities and input data, and URAM will populate tables.
        {*}$options(-loadcmd) $self

        # NEXT, make sure that all "load *" methods were called,
        assert {$trans(loadstate) eq "coop"}

        # NEXT, final steps.  Do a sanity check of the input data.
        $self SanityCheck

        # NEXT, populate output tables as needed.
        $self ComputeCivRelTable
        $self ComputeFrcRelTable
        $self PopulateNbhoodCoopTable
        $self PopulateScid

        # NEXT, untrack curves for empty groups.
        set empty [$rdb eval {
            SELECT g_id FROM uram_civ_g WHERE pop == 0 
        }]
        if {[llength $empty] > 0} {
            $self SetTracking 0 $empty
        }

        # NEXT, clear the transient data
        array unset trans
    }

    # ParmsNotifyCmd
    #
    # Updates the instance given changes to the model parameters.

    method ParmsNotifyCmd {} {
        $cm configure \
            -savehistory [$parm get uram.saveHistory]

        foreach ctype [$cm ctype names] {
            lassign [$parm get uram.factors.$ctype] alpha gamma

            $cm ctype configure $ctype \
                -alpha $alpha \
                -gamma $gamma
        }
    }

    # load causes name ?name ...?
    #
    # name - A cause name.
    #
    # Loads the cause names into uram_cause. The names
    # should be pre-sorted as desired.

    method {load causes} {args} {
        assert {$trans(loadstate) eq "begin"}
        
        # FIRST, load the cause names.
        foreach cause $args {
            $rdb eval {
                INSERT INTO uram_cause(cause)
                VALUES($cause);
            }
        }

        # NEXT, save them in a dictionary for quick access.
        set db(causeIDs) [$rdb eval {
            SELECT cause, cause_id FROM uram_cause ORDER BY cause_id
        }]

        set trans(loadstate) "causes"
    }

    # load actors name ?name ...?
    #
    # name - An actor name.
    #
    # Loads the actor names into uram_a. Typically, the names
    # should be pre-sorted.

    method {load actors} {args} {
        assert {$trans(loadstate) eq "causes"}
        
        # FIRST, load the actor names.
        foreach a $args {
            $rdb eval {
                INSERT INTO uram_a(a)
                VALUES($a);
            }
        }

        set trans(loadstate) "actors"
    }



    # load nbhoods name ?name ...?
    #
    # name - A neighborhood name.
    #
    # Loads the neighborhood names into uram_n. Typically, the names
    # should be pre-sorted.

    method {load nbhoods} {args} {
        assert {$trans(loadstate) eq "actors"}
        
        # FIRST, load the nbhood names.
        foreach n $args {
            $rdb eval {
                INSERT INTO uram_n(n)
                VALUES($n);
            }
        }

        set trans(loadstate) "nbhoods"
    }

    # load prox m n proximity ?m n proximity...?
    #
    # m             - Neighborhood name
    # n             - Neighborhood name
    # proximity     - {0...3}, corresponding to eproximity(n) here,
    #                 near, far, remote.
    #
    # Loads non-default neighborhood relationships into uram_mn.

    method {load prox} {args} {
        assert {$trans(loadstate) eq "nbhoods"}

        # FIRST, get IDs
        array set nids [$rdb eval {SELECT n, n_id FROM uram_n}]

        foreach {m n proximity} $args {
            set m_id $nids($m)
            set n_id $nids($n)

            $rdb eval {
                INSERT INTO uram_mn(m_id, n_id, proximity)
                VALUES($m_id, $n_id, $proximity)
            }
        }

        set trans(loadstate) "prox"
    }

    # load civg g n pop ?g n pop...?
    #
    # g       - Group name
    # n       - Nbhood of residence
    # pop     - Population, in numbers of people
    #
    # Loads the CIV group names and populations into uram_g and uram_civ_g.
    # Typically, the groups are ordered by name.

    method {load civg} {args} {
        assert {$trans(loadstate) eq "prox"}

        # FIRST, get IDs
        array set nids [$rdb eval {SELECT n, n_id FROM uram_n}]

        # NEXT, load the civ group definitions.
        foreach {g n pop} $args {
            set n_id $nids($n)

            $rdb eval {
                INSERT INTO uram_g(g, gtype) 
                VALUES($g, 'CIV');

                INSERT INTO uram_civ_g(g_id, n_id, pop)
                VALUES(last_insert_rowid(), $n_id, $pop);
            }
        }

        set trans(loadstate) "civg"
    }

    # load otherg g gtype ?g gtype...?
    #
    # g              - Group name
    # gtype          - Group type
    #
    # Loads the FRC and ORG group names into uram_g. Typically, 
    # the groups are ordered by name.

    method {load otherg} {args} {
        assert {$trans(loadstate) eq "civg"}

        # FIRST, load the other group definitions.
        foreach {g gtype} $args {
            $rdb eval {
                INSERT INTO uram_g(g,gtype) VALUES($g,$gtype);
            }
        }

        # NEXT, cache all of the group IDs.
        set db(groupIDs) [$rdb eval {
            SELECT g, g_id FROM uram_g
        }]

        set trans(loadstate) "otherg"
    }


    # load hrel f g current base nat ?f g current base nat...?
    #
    # f       - Group name
    # g       - Group name
    # current - Initial current baseline relationship
    # base    - Initial baseline relationship
    # nat     - Initial natural relationship
    #
    # Loads horizontal relationships into uram_hrel_t.

    method {load hrel} {args} {
        assert {$trans(loadstate) eq "otherg"}

        array set gids [$rdb eval {SELECT g, g_id FROM uram_g}]

        set db(vrelIDs) [dict create]

        foreach {f g current base nat} $args {
            set f_id $gids($f)
            set g_id $gids($g)

            # A=B
            set curve_id [$cm curve add HREL $current $base $nat]

            $rdb eval {
                INSERT INTO uram_hrel_t(f_id, g_id, curve_id)
                VALUES($f_id, $g_id, $curve_id)
            }

            dict set db(hrelIDs) $f $g $curve_id
        }

        # Get the fg_id mapping
        set trans(fgids) [$rdb eval {
            SELECT f_id || ',' || g_id, fg_id FROM uram_hrel_t
        }]


        set trans(loadstate) "hrel"
    }

    # load vrel g a current base nat ?g a current base nat...?
    #
    # g        - Group name
    # a        - Actor name
    # current  - Initial current relationship
    # base     - Initial baseline relationship
    # nat      - Initial natural relationship
    #
    # Loads vertical relationships into uram_ga.

    method {load vrel} {args} {
        assert {$trans(loadstate) eq "hrel"}

        # FIRST, load the data
        array set gids [$rdb eval {SELECT g, g_id FROM uram_g}]
        array set aids [$rdb eval {SELECT a, a_id FROM uram_a}]

        set db(vrelIDs) [dict create]

        foreach {g a current base nat} $args {
            set g_id $gids($g)
            set a_id $aids($a)

            # A=B
            set curve_id [$cm curve add VREL $current $base $nat]

            $rdb eval {
                INSERT INTO uram_vrel_t(g_id, a_id, curve_id)
                VALUES($g_id, $a_id, $curve_id)
            }

            dict set db(vrelIDs) $g $a $curve_id
        }

        set trans(loadstate) "vrel"
    }


    # load sat g c current base nat saliency ?g c current base nat saliency ...?
    #
    # g        - Group name
    # c        - Concern name
    # current  - Initial current level
    # base     - Initial baseline level
    # nat      - Initial natural level
    # saliency - Saliency
    #
    # Loads the satisfaction curve data into ucurve(n) and
    # uram_sat_t.

    method {load sat} {args} {
        assert {$trans(loadstate) eq "vrel"}

        array set gids [$rdb eval {SELECT g, g_id FROM uram_g}]
        array set cids [$rdb eval {SELECT c, c_id FROM uram_c}]

        set db(satIDs) [dict create]

        foreach {g c current base nat saliency} $args {
            set g_id $gids($g)
            set c_id $cids($c)

            # A=B; C will be set explicitly later.
            set curve_id [$cm curve add $c $current $base $nat]

            $rdb eval {
                INSERT INTO uram_sat_t(g_id, c_id, curve_id, saliency)
                VALUES($g_id, $c_id, $curve_id, $saliency);
            }

            dict set db(satIDs) $g $c $curve_id
        }

        set trans(loadstate) "sat"
    }

    # load coop f g current base nat ?f g current base nat...?
    #
    # f       - Force group name
    # g       - Civ group name
    # current - Initial current level
    # base    - Initial baseline level
    # nat     - Initial natural level
    #
    # Loads cooperation curve data into ucurve(n) and uram_coop_t.  

    method {load coop} {args} {
        assert {$trans(loadstate) eq "sat"}

        # FIRST, get the group IDs
        array set gids [$rdb eval {SELECT g, g_id FROM uram_g}]

        set db(coopIDs) [dict create]

        foreach {f g current base nat} $args {
            set f_id $gids($f)
            set g_id $gids($g)
            set fg_id [dict get $trans(fgids) $f_id,$g_id]
            
            # A=B
            set curve_id [$cm curve add COOP $current $base $nat]

            # Make sure we get the same fg_id's as in uram_hrel_t.
            $rdb eval {
                INSERT INTO uram_coop_t(fg_id, f_id, g_id, curve_id)
                VALUES($fg_id, $f_id, $g_id, $curve_id)
            }

            dict set db(coopIDs) $f $g $curve_id
        }

        set trans(loadstate) "coop"
    }


    
    # SanityCheck
    #
    # Verifies that LoadData has loaded everything we need to run.
    #
    # This routine simply checks that we've got the right number of
    # entries in the multi-key tables.  To verify that the key
    # fields are valid, enable foreign keys when creating the
    # database handle.

    method SanityCheck {} {
        set Na    [$rdb eval {SELECT count(a) FROM uram_a}]
        set Nn    [$rdb eval {SELECT count(n) FROM uram_n}]
        set Ng    [$rdb eval {SELECT count(g) FROM uram_g}]
        set Ncivg [$rdb eval {SELECT count(g) FROM uram_g WHERE gtype='CIV'}]
        set Nfrcg [$rdb eval {SELECT count(g) FROM uram_g WHERE gtype='FRC'}]
        set Nc    [$rdb eval {SELECT count(c) FROM uram_c}]
        set Nmn   [$rdb eval {SELECT count(mn_id) FROM uram_mn}]
        set Nhrel [$rdb eval {SELECT count(fg_id) FROM uram_hrel_t}]
        set Nvrel [$rdb eval {SELECT count(ga_id) FROM uram_vrel_t}]
        set Nsat  [$rdb eval {SELECT count(gc_id) FROM uram_sat_t}]
        set Ncoop [$rdb eval {SELECT count(fg_id) FROM uram_coop_t}]

        require {$Na > 0}                 "no actors defined"
        require {$Nn > 0}                 "no neighborhoods defined"
        require {$Ng > 0}                 "no groups defined"
        require {$Ncivg > 0}              "no civilian groups defined"
        require {$Nfrcg > 0}              "no force groups defined"
        require {$Nmn == $Nn*$Nn}         "too few entries in uram_mn"
        require {$Nhrel == $Ng*$Ng}       "too few HREL curves"
        require {$Nvrel == $Ng*$Na}       "too few VREL curves"
        require {$Nsat == $Ncivg*$Nc}     "too few SAT curves"
        require {$Ncoop == $Ncivg*$Nfrcg} "too few COOP curves"
    }

    # ComputeCivRelTable
    #
    # Computes the proximity between all pairs
    # of civilian groups, and links them to the HREL curve.

    method ComputeCivRelTable {} {
        $rdb eval {
            SELECT F.g_id                        AS f_id,
                   G.g_id                        AS g_id,
                   HREL.fg_id                    AS fg_id,
                   HREL.curve_id                 AS hrel_id,
                   CASE WHEN F.g_id = G.g_id
                        THEN -1
                        ELSE MN.proximity END    AS proximity
            FROM uram_mn     AS MN
            JOIN uram_civ_g  AS F    ON (F.n_id = MN.m_id)
            JOIN uram_civ_g  AS G    ON (G.n_id = MN.n_id)
            JOIN uram_hrel_t AS HREL 
                 ON (HREL.f_id = F.g_id AND HREL.g_id = G.g_id);
        } {
            $rdb eval {
                INSERT INTO 
                uram_civrel_t(fg_id, f_id, g_id, hrel_id, proximity)
                VALUES($fg_id, $f_id, $g_id, $hrel_id, $proximity);
            }
        }
    }

    # ComputeFrcRelTable
    #
    # Caches the HREL curve_id for pairs of force groups,
    # for use when computing COOP spread.

    method ComputeFrcRelTable {} {
        $rdb eval {
            SELECT R.fg_id      AS fg_id,
                   R.curve_id   AS hrel_id,
                   F.g_id       AS f_id,
                   G.g_id       AS g_id
            FROM uram_hrel_t AS R
            JOIN uram_g      AS F ON (F.g_id = R.f_id)
            JOIN uram_g      AS G ON (G.g_id = R.g_id)
            WHERE F.gtype = 'FRC' AND G.gtype = 'FRC'
        } {
            $rdb eval {
                INSERT INTO 
                uram_frcrel_t(fg_id, f_id, g_id, hrel_id)
                VALUES($fg_id, $f_id, $g_id, $hrel_id);
            }
        }
    }

    # PopulateNbhoodCoopTable
    #
    # Populates the neighborhood cooperation table with records.

    method PopulateNbhoodCoopTable {} {
        # NEXT, populate uram_nbcoop_t.
        $rdb eval {
            INSERT INTO uram_nbcoop_t(n_id, g_id)
            SELECT n_id, g_id
            FROM uram_n JOIN uram_g
            WHERE gtype='FRC'
            ORDER BY n_id, g_id
        }
    }

    # PopulateScid
    #
    # Populates the db(scid) dict for quick satisfaction curve lookups
    
    method PopulateScid {} {
        set db(scid) [dict create]

        $rdb eval {
            SELECT g_id,c_id,curve_id FROM uram_sat_t
        } {
            dict set db(scid) $g_id $c_id $curve_id
        }
    }

    #-------------------------------------------------------------------
    # Update API
    #
    # This API is used to update scenario data after the initial load.
    # Not everything can be modified.  (In fact, very little can
    # be modified.)

    # update pop g pop ?g pop...?
    #
    # g     - A civilian group name
    # pop   - Population of g (integer number of people)
    #
    # Updates uram_civ_g.pop for the specified groups.
    # The change takes effect on the next time [advance]
    #
    # At the same time, make note of groups that have become empty
    # or are no longer empty, and set the tracking for their curves.
    #
    # NOTE: This routine updates uram_civ_g; do not call it in the body
    # of a query on uram_civ_g.

    method {update pop} {args} {
        set nowTracked [list]
        set nowUntracked [list]

        foreach {g pop} $args {
            set g_id [dict get $db(groupIDs) $g]

            set oldPop [$rdb eval {
                SELECT pop FROM uram_civ_g WHERE g_id=$g_id
            }]

            if {$oldPop == 0 && $pop > 0} {
                lappend nowTracked $g_id
            } elseif {$oldPop > 0 && $pop == 0} {
                lappend nowUntracked $g_id
            }

            $rdb eval {
                UPDATE uram_civ_g
                SET pop = $pop
                WHERE g_id=$g_id
            }
        }

        if {[llength $nowTracked] > 0} {
            $self SetTracking 1 $nowTracked
        }

        if {[llength $nowUntracked] > 0} {
            $self SetTracking 0 $nowUntracked
        }
    }

    # SetTracking flag glist
    #
    # flag    - 1 or 0
    # glist   - A list of civilian g_id's
    #
    # Tracks or untracks the curves related to the listed civilian
    # groups.

    method SetTracking {flag glist} {
        # FIRST, get the list of curve IDs.  For HRELs, it's asymmetric;
        # when untracking, all of a group's HREL curves are untracked,
        # but when tracking they only get tracked if the other group is
        # non-empty.
        set gs "([join $glist ,])"

        set curve_ids [$rdb eval "
            SELECT curve_id FROM uram_hrel_t WHERE f_id IN $gs OR g_id IN $gs
            UNION
            SELECT curve_id FROM uram_vrel_t WHERE g_id IN $gs
            UNION
            SELECT curve_id FROM uram_sat_t WHERE g_id IN $gs
            UNION
            SELECT curve_id FROM uram_coop_t WHERE f_id IN $gs
        "]

        if {$flag} {
            $cm curve track $curve_ids 
        } else {
            $cm curve untrack $curve_ids
        }

        # NEXT, if we were tracking, look for HREL curves that shouldn't be
        # tracked. (Fixed for Bug 4044)
        if {$flag} {
            set curve_ids [$rdb eval {
                SELECT curve_id
                FROM uram_civ_g AS G
                JOIN uram_hrel_t AS H ON (H.f_id = G.g_id OR H.g_id = G.g_id)
                JOIN ucurve_curves_t AS C USING (curve_id)
                WHERE G.pop = 0 AND C.tracked
            }]

            if {[llength $curve_ids] > 0} {
                $cm curve untrack $curve_ids
            }
        }
    }

    #-------------------------------------------------------------------
    # Time Advance

    # advance t
    #
    # t        - The current simulation time.
    #
    # Advances simulation time to t, applying all current effects to
    # the attitude curves and computing mood and other outputs.
    #
    # Initializing URAM is expected to involve two calls: [init]
    # and [advance $t], where $t is the starting time for the simulation
    # run.  On the first advance only transient effects 
    # will be applied, leaving the initial baseline levels as set by the 
    # caller.

    method advance {t} {
        # FIRST, update the time.
        require {$t > $db(time)} \
            "time did not advance, new time $t, old time $db(time)"
        set db(time) $t

        # NEXT, clear the spread caches.
        set db(ssCache) [dict create]

        # NEXT, Apply current effects to the attitude curves.
        if {$db(started)} {
            $cm apply $t
        } else {
            $cm apply $t -start 
            set db(started) 1
        }
        
        # NEXT, Compute all roll-ups
        $self ComputeSatRollups
        $self ComputeCoopRollups

        # NEXT, save historical data.
        if {[$parm get uram.saveHistory]} {
            $self SaveHistory $t
        }

        set info(changed) 1

        return
    }

    # time
    #
    # Current uram(n) simulation time, in ticks.
    method time {} { 
        return $db(time) 
    }

    #-------------------------------------------------------------------
    # Satisfaction Roll-ups
    #
    # All satisfaction roll-ups -- sat.n, sat.g, etc. -- all have the 
    # same nature.  The computation is a weighted average over a set of 
    # satisfaction levels; all that changes is the definition
    # of the set.  The equation for a roll-up over set A is as follows:
    #
    #           Sum(g,c in A, w.g * L.gc * S.gc)
    #   S.A  =  --------------------------------
    #           Sum(g,c in A, w.g * L.gc)
    #
    # where w.g is the weight, usually the population of group g.

    # ComputeSatRollups
    #
    # Computes all satisfaction roll-ups.

    method ComputeSatRollups {} {
        $self ComputeSatN
        $self ComputeSatG
    }


    # ComputeSatN
    #
    # Computes the overall civilian mood for each nbhood.
    # The mood is 0.0 if the population of the neighborhood is 0.
    
    method ComputeSatN {} {
        $rdb eval {
            SELECT n_id                     AS n_id, 
                   total(sat*saliency*pop)  AS num,
                   total(saliency*pop)      AS denom
            FROM uram_sat
            GROUP BY n_id
        } {
            if {$denom == 0.0} {
                let nbmood 0.0
            } else {
                let nbmood {$num/$denom}
            }

            $rdb eval {
                UPDATE uram_n
                SET nbmood       = $nbmood,
                    nbmood_denom = $denom
                WHERE n_id=$n_id
            }
        }

        # Compute neighborhood population.
        # TBD: This should be probably be done on load, and on "update pop".
        # In practice though, this happens once a tick, and "update
        # pop" happens once a tick, so it doesn't really matter.
        $rdb eval {
            SELECT n_id        AS n_id, 
                   total(pop)  AS pop
            FROM uram_civ_g
            GROUP BY n_id
        } {
            $rdb eval {
                UPDATE uram_n
                SET pop = $pop
                WHERE n_id=$n_id
            }
        }
    }
    
    # ComputeSatG
    #
    # Computes the mood for each group.
    
    method ComputeSatG {} {
        $rdb eval {
            SELECT g_id                AS g_id,
                   total(sat*saliency) AS num,
                   total(saliency)     AS denom
            FROM uram_sat
            GROUP BY g_id
        } {
            if {$denom == 0.0} {
                let mood 0.0
            } else {
                let mood {$num/$denom}
            }

            $rdb eval {
                UPDATE uram_civ_g
                SET mood       = $mood,
                    mood_denom = $denom
                WHERE g_id=$g_id
            }
        }
    }

    #-------------------------------------------------------------------
    # Cooperation Roll-ups
    #
    # We only compute one cooperation roll-up, coop.ng: the cooperation
    # of a neighborhood as a whole with a force group.  This is based
    # on the population of the neighborhood groups, rather than
    # saliency; cooperation is the likelihood that
    # random member of the population will share information if asked.
    #
    # The equation is as follows:
    #
    #              Sum(f in n, pop.f * coop.fg)
    #   coop.ng  = ----------------------------
    #              Sum(f in n, pop.f)

    # ComputeCoopRollups
    #
    # Computes coop.ng; if neighborhood n has zero population, 
    # the result is 0.0.

    method ComputeCoopRollups {} {
        # FIRST, compute coop.ng
        $rdb eval {
            SELECT n_id               AS n_id, 
                   g_id               AS g_id,
                   total(coop * pop)  AS num,
                   total(pop)         AS denom
            FROM uram_coop
            GROUP BY n_id, g_id
        } {
            if {$denom == 0} {
                let nbcoop 0.0
            } else {
                let nbcoop {$num/$denom}
            }

            $rdb eval {
                UPDATE uram_nbcoop_t
                SET nbcoop = $nbcoop
                WHERE n_id=$n_id AND g_id=$g_id
            }
        }
    }

    #-------------------------------------------------------------------
    # History

    # SaveHistory t
    #
    # t   - The time stamp, in ticks.
    #
    # Saves historical data needed to compute contribs.

    method SaveHistory {t} {
        # FIRST, save the population of each civilian group.
        $rdb eval {
            INSERT INTO uram_civhist_t(t, g_id, n_id, pop)
            SELECT $t, g_id, n_id, pop
            FROM uram_civ_g;
        }

        # NEXT, save the nbmood denominator for each neighborhood.
        $rdb eval {
            INSERT INTO uram_nbhist_t(t, n_id, pop, nbmood_denom)
            SELECT $t, n_id, pop, nbmood_denom
            FROM uram_n;
        }
    }

    #-------------------------------------------------------------------
    # HREL attitude methods

    # hrel persistent driver cause f g mag
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # f        - A group
    # g        - Another group
    # mag      - A umag(n) value
    #
    # UNDOABLE. Creates a persistent HREL attitude input with given 
    # driver and cause, affecting the horizontal relationship between 
    # f and g with magnitude mag.
    #
    # At present, there is no spread algorithm for HREL inputs; the
    # only effect is the direct effect.
    #
    # Inputs for civilian groups with zero population are ignored.

    method {hrel persistent} {driver cause f g mag} {
        require {$db(time) >= 0} "Persistent inputs not allowed when t=-1"

        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(hrelIDs) $f $g]
        set mag      [umag validate $mag]

        if {![$cm istracked $curve_id]} {
            return
        }

        $cm persistent $driver $cause_id $curve_id $mag
    }

    # hrel transient driver cause f g mag
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # f        - A group
    # g        - Another group
    # mag      - A umag(n) value
    #
    # UNDOABLE. Creates a transient HREL attitude input with given 
    # driver and cause, affecting the horizontal relationship between 
    # f and g with magnitude mag.
    #
    # At present, there is no spread algorithm for HREL inputs; the
    # only effect is the direct effect.

    method {hrel transient} {driver cause f g mag} {
        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(hrelIDs) $f $g]
        set mag      [umag validate $mag]

        if {![$cm istracked $curve_id]} {
            return
        }

        $cm transient $driver $cause_id $curve_id $mag
    }

    # hrel badjust driver f g delta
    #
    # driver   - An integer driver ID
    # f        - A group
    # g        - Another group
    # delta    - An hrel delta
    #
    # UNDOABLE.  Adjusts the baseline of the horizontal relationship 
    # between f and g by the specified delta.  The change takes 
    # place immediately, and is ascribed to the driver at the next 
    # [advance].

    method {hrel badjust} {driver f g delta} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        set curve_id [dict get $db(hrelIDs) $f $g]

        if {![$cm istracked $curve_id]} {
            return
        }

        snit::double validate $delta

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # hrel bset driver f g value
    #
    # driver   - An integer driver ID
    # f        - A group
    # g        - Another group
    # value    - An hrel value
    #
    # UNDOABLE.  Sets the baseline of the horizontal relationship 
    # between f and g to the specified value.  The change takes 
    # place immediately, and the delta is ascribed to the driver
    # at the next [advance].

    method {hrel bset} {driver f g value} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        # FIRST, validate inputs.
        set curve_id [dict get $db(hrelIDs) $f $g]

        if {![$cm istracked $curve_id]} {
            return
        }

        qaffinity validate $value

        # NEXT, get the current value and compute the delta
        set oldb [$cm curve cget $curve_id -b] 
        set delta [expr {$value - $oldb}]        

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # hrel cset ?f g value...?
    #
    # f        - A group
    # g        - Another group
    # value    - An HREL value
    #
    # NOT UNDOABLE.  Sets the natural levels of the specified attitude
    # curves to the specified values.  
    #
    # TBD: at this point, each value is validated as a qaffinity(n)
    # input; this may slow things down considerably.  Looking up the 
    # curve_id's may also be a bottle neck; we might want to assume that
    # the caller looked up the curve_id at the same time as the value,
    # and pass this through to ucurve(n).

    method {hrel cset} {args} {
        set cmlist [list]

        foreach {f g value} $args {
            lappend cmlist \
                [dict get $db(hrelIDs) $f $g] [qaffinity validate $value]
        }

        # ucurve adds the necessary records to the undo stack
        $cm curve cset {*}$cmlist
    }

    #-------------------------------------------------------------------
    # VREL attitude methods

    # vrel persistent driver cause g a mag
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # g        - A group
    # a        - An actor
    # mag      - A umag(n) value
    #
    # UNDOABLE. Creates a persistent VREL attitude input with given 
    # driver and cause, affecting the vertical relationship between 
    # g and a with magnitude mag.
    #
    # At present, there is no spread algorithm for VREL inputs; the
    # only effect is the direct effect.

    method {vrel persistent} {driver cause g a mag} {
        require {$db(time) >= 0} "Persistent inputs not allowed when t=-1"

        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(vrelIDs) $g $a] 
        set mag      [umag validate $mag]

        if {![$cm istracked $curve_id]} {
            return
        }

        $cm persistent $driver $cause_id $curve_id $mag
    }

    # vrel transient driver cause g a mag
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # g        - A group
    # a        - An actor
    # mag      - A umag(n) value
    #
    # UNDOABLE. Creates a transient VREL attitude input with given 
    # driver and cause, affecting the vertical relationship between 
    # g and a with magnitude mag.
    #
    # At present, there is no spread algorithm for VREL inputs; the
    # only effect is the direct effect.

    method {vrel transient} {driver cause g a mag} {
        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(vrelIDs) $g $a] 
        set mag      [umag validate $mag]

        if {![$cm istracked $curve_id]} {
            return
        }

        $cm transient $driver $cause_id $curve_id $mag
    }

    # vrel badjust driver g a delta
    #
    # driver   - An integer driver ID
    # g        - A group
    # a        - An actor
    # delta    - A vrel delta
    #
    # UNDOABLE.  Adjusts the baseline of the vertical relationship 
    # between g and a by the specified delta.  The change takes 
    # place immediately, and is ascribed to the driver at the next 
    # [advance].

    method {vrel badjust} {driver g a delta} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        set curve_id [dict get $db(vrelIDs) $g $a] 
        if {![$cm istracked $curve_id]} {
            return
        }

        snit::double validate $delta

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # vrel bset driver g a value
    #
    # driver   - An integer driver ID
    # g        - A group
    # a        - An actor
    # value    - A vrel value
    #
    # UNDOABLE.  Sets the baseline of the vertical relationship 
    # between g and a to the specified value.  The change takes 
    # place immediately, and the delta is ascribed to the driver
    # at the next [advance].

    method {vrel bset} {driver g a value} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        # FIRST, validate inputs.
        set curve_id [dict get $db(vrelIDs) $g $a] 
        if {![$cm istracked $curve_id]} {
            return
        }

        qaffinity validate $value

        # NEXT, get the current value and compute the delta
        set oldb [$cm curve cget $curve_id -b] 
        set delta [expr {$value - $oldb}]        

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # vrel cset ?g a value...?
    #
    # g        - A group
    # a        - An actor
    # value    - A VREL value
    #
    # NOT UNDOABLE.  Sets the natural levels of the specified attitude
    # curves to the specified values.  
    #
    # TBD: at this point, each value is validated as a qaffinity(n)
    # input; this may slow things down considerably.  Looking up the 
    # curve_id's may also be a bottle neck; we might want to assume that
    # the caller looked up the curve_id at the same time as the value,
    # and pass this through to ucurve(n).

    method {vrel cset} {args} {
        set cmlist [list]

        foreach {g a value} $args {
            lappend cmlist \
                [dict get $db(vrelIDs) $g $a] \
                [qaffinity validate $value]
        }

        # ucurve adds the necessary records to the undo stack
        $cm curve cset {*}$cmlist
    }

    #-------------------------------------------------------------------
    # SAT attitude methods

    # sat persistent driver cause g c mag ?options...?
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # g        - A civilian group
    # c        - A concern
    # mag      - A umag(n) value
    #
    # Options:
    #
    #   -s factor    - "here" indirect effects multiplier, defaults to 1.0
    #   -p factor    - "near" indirect effects multiplier, defaults to 0
    #   -q factor    - "far" indirect effects multiplier, defaults to 0
    #
    # UNDOABLE. Creates a persistent SAT attitude input with given 
    # driver and cause, affecting the satisfaction of g with c
    # with magnitude mag.  The input causes a direct effect and
    # possibly also indirect effects depending on the values of -s,
    # -p, and -q.
    #
    # There will no indirect effects on empty groups, and if g itself
    # is empty there will be no effects at all.

    method {sat persistent} {driver cause g c mag args} {
        require {$db(time) >= 0} "Persistent inputs not allowed when t=-1"

        # FIRST, validate the normal inputs and retrieve IDs.
        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(satIDs) $g $c]
        set g_id     [dict get $db(groupIDs) $g]
        set c_id     [dict get $db(concernIDs) $c]
        set mag      [umag validate $mag]

        # NEXT, if the mag is 0.0, ignore it.
        if {$mag == 0.0} {
            return
        }

        # NEXT, parse the options
        $self ParseInputOptions opts $args

        # NEXT, schedule the inputs
        $cm persistent $driver $cause_id \
            {*}[$self SatSpreadEffects $g_id $c_id $mag \
                    $opts(-s) $opts(-p) $opts(-q)]

        return
    }

    # sat transient driver cause g c mag ?options...?
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # g        - A civilian group
    # c        - A concern
    # mag      - A umag(n) value
    #
    # Options:
    #
    #   -s factor    - "here" indirect effects multiplier, defaults to 1.0
    #   -p factor    - "near" indirect effects multiplier, defaults to 0
    #   -q factor    - "far" indirect effects multiplier, defaults to 0
    #
    # UNDOABLE. Creates a transient SAT attitude input with given 
    # driver and cause, affecting the satisfaction of g with c
    # with magnitude mag.  The input causes a direct effect and
    # possibly also indirect effects depending on the values of -s,
    # -p, and -q.
    #
    # There will no indirect effects on empty groups, and if g itself
    # is empty there will be no effects at all.

    method {sat transient} {driver cause g c mag args} {
        # FIRST, validate the normal inputs and retrieve IDs.
        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(satIDs) $g $c]
        set g_id     [dict get $db(groupIDs) $g]
        set c_id     [dict get $db(concernIDs) $c]
        set mag      [umag validate $mag]

        # NEXT, if the mag is 0.0, ignore it.
        if {$mag == 0.0} {
            return
        }

        # NEXT, parse the options
        $self ParseInputOptions opts $args

        # NEXT, schedule the inputs
        $cm transient $driver $cause_id \
            {*}[$self SatSpreadEffects $g_id $c_id $mag \
                    $opts(-s) $opts(-p) $opts(-q)]

        return
    }

    # SatSpreadEffects g_id c_id mag s p q
    #
    # g_id   - The directly affected group
    # c_id   - The concern
    # mag    - The input magnitude
    # s      - The -s "here factor"
    # p      - The -p "near factor"
    # q      - The -q "far factor".
    #
    # Computes the satisfaction spread for the input, and from that
    # computes a list of curve_id's and magnitudes, suitable to be
    # given to ucurve(n).

    method SatSpreadEffects {g_id c_id mag s p q} {
        set cmlist [list]

        foreach {ig_id factor} [$self SatSpread $g_id $s $p $q] {
            lappend cmlist \
                [dict get $db(scid) $ig_id $c_id] \
                [expr {$factor*$mag}]
        }

        return $cmlist
    }
    

    # SatSpread g_id s p q
    #
    # g_id   - The directly affected group
    # s      - The -s "here factor"
    # p      - The -p "near factor"
    # q      - The -q "far factor".
    #
    # Computes and returns a satisfaction spread, a dictionary
    # {g_id -> factor}.  The spread is cached for later use during
    # the same timestep.
    #
    # Groups with zero population are excluded from the spread.
    
    method SatSpread {g_id s p q} {
        # FIRST, if this spread is cached, return the cached value.
        set tag "$g_id,$s,$p,$q"

        if {[dict exists $db(ssCache) $tag]} {
            return [dict get $db(ssCache) $tag]
        }

        # NEXT, get the proximity limit and RAFs
        set plimit [$self GetProxLimit $s $p $q]
        set praf   [$parm get uram.raf.positive]
        set nraf   [$parm get uram.raf.negative]
        
        # NEXT, create the empty dictionary
        set spread [dict create]

        # Ignore f's where either f or g has zero population.  We get this
        # by looking at the tracked flag on the hrel, because the hrel
        # will be untracked if either group has zero population.
        $rdb eval {
            SELECT f_id      AS f_id,
                   hrel      AS hrel,
                   proximity AS proximity
            FROM uram_civrel 
            WHERE g_id = $g_id AND tracked
            AND   proximity < $plimit
        } {
            # FIRST, Apply the RAFs.
            set hrel [expr {$hrel > 0.0 ? $hrel * $praf : $hrel * $nraf}]

            # NEXT, apply the here, near, and far factors.
            # TBD: Put s,p,q in a list, 0, 1, 2 and extract using lindex!
            if {$proximity == 2} {
                # Far
                set factor [expr {$q * $hrel}]
            } elseif {$proximity == 1} {
                # Near
                set factor [expr {$p * $hrel}]
            } elseif {$proximity == 0} {
                # Here
                set factor [expr {$s * $hrel}]
            } else {
                set factor $hrel
            }

            # NEXT, save the data for this group.
            if {$factor != 0.0} {
                dict set spread $f_id $factor
            }
        }

        # NEXT, cache this spread
        dict set db(ssCache) $tag $spread

        # NEXT, return the spread
        return $spread
    }


    # sat badjust driver g c delta
    #
    # driver   - An integer driver ID
    # g        - A civilian group
    # c        - A concern
    # delta    - A satisfaction delta
    #
    # UNDOABLE.  Adjusts the baseline of the satisfaction 
    # of g with c by the specified delta.  The change takes 
    # between f and g by the specified delta.  The change takes 
    # place immediately, and is ascribed to the driver at the next 
    # [advance].

    method {sat badjust} {driver g c delta} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        set curve_id [dict get $db(satIDs) $g $c]
        if {![$cm istracked $curve_id]} {
            return
        }

        snit::double validate $delta

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # sat bset driver g c value
    #
    # driver   - An integer driver ID
    # g        - A civilian group
    # c        - A concern
    # value    - A satisfaction value
    #
    # UNDOABLE.  Sets the baseline of the satisfaction 
    # between g and c to the specified value.  The change takes 
    # place immediately, and the delta is ascribed to the driver
    # at the next [advance].

    method {sat bset} {driver g c value} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        # FIRST, validate inputs.
        set curve_id [dict get $db(satIDs) $g $c]
        if {![$cm istracked $curve_id]} {
            return
        }

        qsat validate $value

        # NEXT, get the current value and compute the delta
        set oldb [$cm curve cget $curve_id -b] 
        set delta [expr {$value - $oldb}]        

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }


    # sat cset ?g c value...?
    #
    # g        - A civilian group
    # c        - A concern
    # value    - A SAT value
    #
    # NOT UNDOABLE.  Sets the natural levels of the specified attitude
    # curves to the specified values.  
    #
    # TBD: at this point, each value is validated as a qsat(n)
    # input; this may slow things down considerably.  Looking up the 
    # curve_id's may also be a bottle neck; we might want to assume that
    # the caller looked up the curve_id at the same time as the value,
    # and pass this through to ucurve(n).

    method {sat cset} {args} {
        set cmlist [list]

        foreach {g c value} $args {
            lappend cmlist \
                [dict get $db(satIDs) $g $c] [qsat validate $value]
        }

        # ucurve adds the necessary records to the undo stack
        $cm curve cset {*}$cmlist
    }

    #-------------------------------------------------------------------
    # COOP attitude methods

    # coop persistent driver cause f g mag ?options...?
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # f        - A civilian group
    # g        - A force group
    # mag      - A umag(n) value
    #
    # Options:
    #
    #   -s factor    - "here" indirect effects multiplier, defaults to 1.0
    #   -p factor    - "near" indirect effects multiplier, defaults to 0
    #   -q factor    - "far" indirect effects multiplier, defaults to 0
    #
    # UNDOABLE. Creates a persistent COOP attitude input with given 
    # driver and cause, affecting the cooperation of f with g
    # with magnitude mag.  The input causes a direct effect and
    # possibly also indirect effects depending on the values of -s,
    # -p, and -q.

    method {coop persistent} {driver cause f g mag args} {
        require {$db(time) >= 0} "Persistent inputs not allowed when t=-1"

        # FIRST, validate the normal inputs and retrieve IDs.
        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(coopIDs) $f $g]
        set mag      [umag validate $mag]
        set f_id     [dict get $db(groupIDs) $f]
        set g_id     [dict get $db(groupIDs) $g]

        # NEXT, if the mag is 0.0, ignore it.
        if {$mag == 0.0} {
            return
        }

        # NEXT, parse the options
        $self ParseInputOptions opts $args

        # NEXT, schedule the effects in every influenced neighborhood
        $cm persistent $driver $cause_id \
            {*}[$self CoopSpreadEffects $f_id $g_id $mag \
                    $opts(-s) $opts(-p) $opts(-q)]
        
        return
    }


    # coop transient driver cause f g mag ?options...?
    #
    # driver   - An integer driver ID
    # cause    - A cause name, or ""
    # f        - A civilian group
    # g        - A force group
    # mag      - A umag(n) value
    #
    # Options:
    #
    #   -s factor    - "here" indirect effects multiplier, defaults to 1.0
    #   -p factor    - "near" indirect effects multiplier, defaults to 0
    #   -q factor    - "far" indirect effects multiplier, defaults to 0
    #
    # UNDOABLE. Creates a transient COOP attitude input with given 
    # driver and cause, affecting the cooperation of f with g
    # with magnitude mag.  The input causes a direct effect and
    # possibly also indirect effects depending on the values of -s,
    # -p, and -q.

    method {coop transient} {driver cause f g mag args} {
        # FIRST, validate the normal inputs and retrieve IDs.
        set cause_id [$self GetCauseID $cause $driver]
        set curve_id [dict get $db(coopIDs) $f $g]
        set mag      [umag validate $mag]
        set f_id     [dict get $db(groupIDs) $f]
        set g_id     [dict get $db(groupIDs) $g]

        # NEXT, if the mag is 0.0, ignore it.
        if {$mag == 0.0} {
            return
        }

        # NEXT, parse the options
        $self ParseInputOptions opts $args

        # NEXT, schedule the effects in every influenced neighborhood
        $cm transient $driver $cause_id \
            {*}[$self CoopSpreadEffects $f_id $g_id $mag \
                    $opts(-s) $opts(-p) $opts(-q)]
        
        return
    }


    # CoopSpreadEffects f_id g_id mag s p q
    #
    # f_id   - The directly affected civilian group
    # g_id   - The directly affected force group
    # mag    - The input magnitude
    # s      - The -s "here factor"
    # p      - The -p "near factor"
    # q      - The -q "far factor".
    #
    # Computes the cooperation spread as a curve_id/magnitude list, 
    # suitable to be given to ucurve(n), for persistent and transient 
    # cooperation effects.

    method CoopSpreadEffects {f_id g_id mag s p q} {
        # FIRST, schedule the effects in every influenced neighborhood
        # within the proximity limit.
        set plimit [$self GetProxLimit $s $p $q]

        set CRL  [$parm get uram.coopRelationshipLimit]
        set praf [$parm get uram.raf.positive]
        set nraf [$parm get uram.raf.negative]

        # Schedule the effects
        set cmlist [list]

        # There are no effects on empty civilian groups.  We check
        # this using the tracked flag on the relevant hrel curve,
        # which will always be false if either civilian group is empty.
        $rdb eval {
            SELECT curve_id, factor, proximity 
            FROM uram_coop_spread
            WHERE df_id     =  $f_id
            AND   dg_id     =  $g_id
            AND   proximity <  $plimit
            AND   civrel    >= $CRL
            AND   tracked
        } {
            # FIRST, The factor is the HREL between two force groups,
            # and as such is subject to the RAFs.
            set factor [expr {
                $factor > 0.0 ? $factor * $praf : $factor * $nraf
            }]
            
            # NET, apply the here, near, and far factors.
            if {$proximity == 2} {
                set imag [expr {$q * $factor * $mag}]
            } elseif {$proximity == 1} {
                set imag [expr {$p * $factor * $mag}]
            } elseif {$proximity == 0} {
                set imag [expr {$s * $factor * $mag}]
            } else {
                # The group with itself
                set imag [expr {$factor * $mag}]
            }

            if {$imag != 0} {
                lappend cmlist $curve_id $imag
            }
        }

        return $cmlist
    }

    # coop badjust driver f g delta
    #
    # driver   - An integer driver ID
    # f        - A civilian group
    # g        - A force group
    # delta    - A coop delta
    #
    # UNDOABLE.  Adjusts the baseline of the cooperation 
    # between f and g by the specified delta.  The change takes 
    # place immediately, and is ascribed to the driver at the next 
    # [advance].

    method {coop badjust} {driver f g delta} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        set curve_id [dict get $db(coopIDs) $f $g]
        if {![$cm istracked $curve_id]} {
            return
        }

        snit::double validate $delta

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # coop bset driver f g value
    #
    # driver   - An integer driver ID
    # f        - A civilian group
    # g        - A force group
    # value    - A cooperation value
    #
    # UNDOABLE.  Sets the baseline of the cooperation of 
    # f with g to the specified value.  The change takes 
    # place immediately, and the delta is ascribed to the driver
    # at the next [advance].

    method {coop bset} {driver f g value} {
        require {$db(time) >= 0} "baseline adjustments not allowed when t=-1"

        # FIRST, validate inputs.
        set curve_id [dict get $db(coopIDs) $f $g]
        if {![$cm istracked $curve_id]} {
            return
        }

        qcooperation validate $value

        # NEXT, get the current value and compute the delta
        set oldb [$cm curve cget $curve_id -b] 
        set delta [expr {$value - $oldb}]        

        # ucurve adds the necessary record to the undo stack
        $cm adjust $driver $curve_id $delta
    }

    # coop cset ?f g value...?
    #
    # f        - A civilian group
    # g        - A force group
    # value    - An COOP value
    #
    # NOT UNDOABLE.  Sets the natural levels of the specified attitude
    # curves to the specified values.  
    #
    # TBD: at this point, each value is validated as a qcooperation(n)
    # input; this may slow things down considerably.  Looking up the 
    # curve_id's may also be a bottle neck; we might want to assume that
    # the caller looked up the curve_id at the same time as the value,
    # and pass this through to ucurve(n).

    method {coop cset} {args} {
        set cmlist [list]

        foreach {f g value} $args {
            lappend cmlist \
                [dict get $db(coopIDs) $f $g] [qcooperation validate $value]
        }

        # ucurve adds the necessary records to the undo stack
        $cm curve cset {*}$cmlist
    }

    #-------------------------------------------------------------------
    # Input Helpers

    # GetCauseID cause driver
    #
    # cause    - A cause name or ""
    # driver   - An integer driver ID
    #
    # Returns the integer cause ID, if cause is a known cause name,
    # or the driver ID if cause is "".  It's an error if cause is
    # neither known nor "".

    method GetCauseID {cause driver} {
        if {$cause eq ""} {
            set cause_id $driver
        } else {
            set cause_id [dict get $db(causeIDs) $cause]
        }

        return $cause_id
    }

    # ParseInputOptions optsArray optsList
    #
    # optsArray - An array to receive the options
    # optsList  - List of options and their values
    #
    # Option parser for [sat transient] and company.
    # Sets defaults, processes the _optsList_, validating each
    # entry, and puts the parsed values in the _optsVar_.  If
    # any values are invalid, an error is thrown.

    method ParseInputOptions {optsArray optsList} {
        upvar $optsArray opts

        # FIRST, set up the defaults.
        array set opts { 
            -s   1.0
            -p   0.0
            -q   0.0
        }
        
        # NEXT, get the values.
        while {[llength $optsList] > 0} {
            set opt [lshift optsList]

            switch -exact -- $opt {
                -s -
                -p -
                -q {
                    set val [lshift optsList]
                    rfraction validate $val
                        
                    set opts($opt) $val
                }

                default {
                    error "invalid option: \"$opt\""
                }
            }
        }
    }

    # GetProxLimit s p q
    #
    # s - Here effects multiplier
    # p - Near effects multiplier
    # q - Far effects multiplier
    #
    # An input to a curve cannot have any indirect effect beyond the
    # de factor proximity limit, given the here, near, and far
    # multipliers.  This routine computes this limit for an input.
    #
    # Returns 0, 1, 2, or 3, where:
    #
    # 0 - No indirect effects
    # 1 - Indirect effects here
    # 2 - Indirect effects here and near
    # 3 - Indirect effects here, near, and far
    #
    # It is assumed that s >= p >= q, i.e., if s is 0 then 
    # p and q are both zero.

    method GetProxLimit {s p q} {
        if {$s == 0.0} {
            set plimit 0
        } elseif {$p == 0.0} {
            set plimit 1
        } elseif {$q == 0.0} {
            set plimit 2
        } else {
            set plimit 3
        }
        
        return $plimit
    }

    #-------------------------------------------------------------------
    # Computation of Contributions
    #
    # Each of the routines in this section computes the contribution
    # to a given curve or set of curves by driver over a given span
    # of time.

    # contribs hrel f g ?options...?
    #
    # f     - A group
    # g     - A group
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.

    method {contribs hrel} {f g args} {
        $self GetCurveContribs [dict get $db(hrelIDs) $f $g] {*}$args
    }

    # contribs vrel g a ?options...?
    #
    # g     - A group
    # a     - An actor
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.

    method {contribs vrel} {g a args} {
        $self GetCurveContribs [dict get $db(vrelIDs) $g $a] {*}$args
    }

    # contribs sat g c ?options...?
    #
    # g     - A civilian group
    # c     - A concern
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.

    method {contribs sat} {g c args} {
        $self GetCurveContribs [dict get $db(satIDs) $g $c] {*}$args
    }

    # contribs coop f g ?options...?
    #
    # f     - A group
    # g     - A group
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.

    method {contribs coop} {f g args} {
        $self GetCurveContribs [dict get $db(coopIDs) $f $g] {*}$args
    }

    # contribs mood g ?options...?
    #
    # g    - A civilian group
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.
    #
    # Computes the contributions by driver to group g's mood.  Contributions
    # to each of the four concerns are weighted by saliency.

    method {contribs mood} {g args} {
        # FIRST, get the group
        set g_id [$self GetCivGroupID $g]

        # NEXT, get the options
        $self ParseContribsOptions opts $args

        # NEXT, clear the output table
        $rdb eval {DELETE FROM uram_contribs}

        # NEXT, aggregate the ucurve contribs data
        set ts $opts(-start)
        set te $opts(-end)

        $rdb eval {
            INSERT INTO uram_contribs(driver,contrib)
            SELECT C.driver_id,
                   total(S.saliency*C.contrib)/G.mood_denom
            FROM uram_sat_t AS S
            JOIN ucurve_contribs_t AS C USING (curve_id)
            JOIN uram_civ_g AS G ON (G.g_id = S.g_id)
            WHERE S.g_id = $g_id
            AND t >= $ts AND t <= $te
            GROUP BY C.driver_id
        }
    }

    # contribs nbmood n ?options...?
    #
    # n    - A neighborhood
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.
    #
    # Computes the contributions by driver to nbhood n's mood.  
    # Contributions to each of the four concerns are weighted by 
    # population and saliency.

    method {contribs nbmood} {n args} {
        # FIRST, get the group
        set n_id [$self GetNbhoodID $n]

        # NEXT, get the options
        $self ParseContribsOptions opts $args

        # NEXT, clear the output table
        $rdb eval {DELETE FROM uram_contribs}

        # NEXT, aggregate the ucurve contribs data
        set ts $opts(-start)
        set te $opts(-end)

        $rdb eval {
            INSERT INTO uram_contribs(driver,contrib)
            SELECT driver_id, total(contrib_at_t)
            FROM (
                SELECT C.t             AS t,
                       C.driver_id     AS driver_id,
                       total(G.pop*S.saliency*C.contrib)/N.nbmood_denom
                       AS contrib_at_t
                FROM ucurve_contribs_t AS C
                JOIN uram_sat_t        AS S USING (curve_id)
                JOIN uram_civhist_t    AS G USING (t, g_id)
                JOIN uram_nbhist_t     AS N USING (t, n_id)
                WHERE N.n_id = $n_id 
                AND N.nbmood_denom > 0.0
                AND C.t >= $ts AND C.t <= $te
                GROUP BY C.driver_id, C.t
            ) GROUP BY driver_id
        }
    }

    # contribs nbcoop n g ?options...?
    #
    # n    - A neighborhood
    # g    - A force group
    #
    # Options:
    #    -start    - Start tick; default is 0
    #    -end      - End tick; default is now.
    #
    # Computes the contributions by driver to nbhood n's cooperation
    # with force group g.  Contributions are weighted by civilian
    # group population.

    method {contribs nbcoop} {n g args} {
        # FIRST, get the neighborhood and group
        set n_id [$self GetNbhoodID $n]
        set g_id [$self GetFrcGroupID $g]

        # NEXT, get the options
        $self ParseContribsOptions opts $args

        # NEXT, clear the output table
        $rdb eval {DELETE FROM uram_contribs}

        # NEXT, aggregate the ucurve contribs data
        set ts $opts(-start)
        set te $opts(-end)

        $rdb eval {
            INSERT INTO uram_contribs(driver,contrib)
            SELECT driver_id, total(contrib_at_t)
            FROM (
                SELECT C.t                          AS t,
                       C.driver_id                  AS driver_id,
                       total(F.pop*C.contrib)/N.pop AS contrib_at_t
                FROM ucurve_contribs_t AS C
                JOIN uram_coop_t       AS COOP USING (curve_id)
                JOIN uram_civhist_t    AS F 
                     ON (F.t = C.t AND F.g_id = COOP.f_id)
                JOIN uram_nbhist_t     AS N 
                     ON (N.t = C.t AND N.n_id = F.n_id)
                WHERE N.n_id = $n_id AND COOP.g_id = $g_id
                AND N.pop > 0.0
                AND C.t >= $ts AND C.t <= $te
                GROUP BY C.driver_id, C.t
            ) GROUP BY driver_id
        }
    }

    # GetCurveContribs curve_id ?options...?
    #
    # curve_id - The curve for which contributes are to be aggregated
    # options  - -start, -end
    #
    # Aggregates contributions for the time-interval.

    method GetCurveContribs {curve_id args} {
        # FIRST, get the options
        $self ParseContribsOptions opts $args

        # NEXT, clear the output table
        $rdb eval {DELETE FROM uram_contribs}

        # NEXT, aggregate the ucurve contribs data
        set ts $opts(-start)
        set te $opts(-end)

        $rdb eval {
            INSERT INTO uram_contribs(driver,contrib)
            SELECT driver_id,total(contrib)
            FROM ucurve_contribs_t
            WHERE curve_id = $curve_id
            AND t >= $ts AND t <= $te
            GROUP BY driver_id;
        }
    }

    

    # ParseContribsOptions optsArray optsList
    #
    # optsArray - An array to receive the options
    # optsList  - List of options and their values
    #
    # Option parser for [contribs *] subcommands.
    # Sets defaults, processes the _optsList_, validating each
    # entry, and puts the parsed values in the _optsVar_.  If
    # any values are invalid, an error is thrown.

    method ParseContribsOptions {optsArray optsList} {
        upvar $optsArray opts

        # FIRST, set up the defaults.
        set opts(-start) 0
        set opts(-end)   $db(time)
        
        # NEXT, get the values.
        while {[llength $optsList] > 0} {
            set opt [lshift optsList]

            switch -exact -- $opt {
                -start -
                -end {
                    set val [lshift optsList]

                    count validate $val
                        
                    set opts($opt) $val
                }

                default {
                    error "invalid option: \"$opt\""
                }
            }
        }
    }
  

    # GetNbhoodID n
    #
    # n - A neighborhood name
    #
    # Returns the n_id of nbhood n, or throws an error if no nbhood 
    # is found.

    method GetNbhoodID {n} {
        set n_id [$rdb onecolumn {
            SELECT n_id FROM uram_n WHERE n=$n
        }]
        
        require {$n_id ne ""} \
            "No such nbhood \"$n\""

        return $n_id
    }

    # GetCivGroupID g
    #
    # g   - A civilian group
    #
    # Returns the g_id of civilian group g, or throws an error if no group 
    # is found.

    method GetCivGroupID {g} {
        set g_id [$rdb onecolumn {
            SELECT g_id FROM uram_g WHERE g=$g AND gtype='CIV'
        }]
        
        require {$g_id ne ""} \
            "No civilian group \"$g\""

        return $g_id
    }

    # GetFrcGroupID g
    #
    # g   - A civilian group
    #
    # Returns the g_id of force group g, or throws an error if no group 
    # is found.

    method GetFrcGroupID {g} {
        set g_id [$rdb onecolumn {
            SELECT g_id FROM uram_g WHERE g=$g AND gtype='FRC'
        }]
        
        require {$g_id ne ""} \
            "No force group \"$g\""

        return $g_id
    }




    #-------------------------------------------------------------------
    # Other Public Methods

    delegate method edit to us

    # driver
    #
    # UNDOABLE!  Returns a new driver ID.

    method driver {} {
        set driver $db(nextDriver)
        incr db(nextDriver)

        $us add [mymethod UndoDriver]

        return $driver
    }

    # UndoDriver
    #
    # Undoes [driver].

    method UndoDriver {} {
        incr db(nextDriver) -1
    }

   
    #-------------------------------------------------------------------
    # saveable(i) Interface: Checkpoint/Restore

    # saveable checkpoint ?-saved?
    #
    # Returns a copy of the object's state for later restoration.
    # This includes only the data stored in the db array; data stored
    # in the RDB is checkpointed with the RDB.  If the -saved flag
    # is included, the object is marked as unchanged.
    
    method {saveable checkpoint} {{option ""}} {
        if {$option eq "-saved"} {
            set info(changed) 0
        }

        return [array get db]
    }


    # saveable restore state ?-saved?
    #
    # state - Checkpointed state returned by the checkpoint method.
    #
    # Restores the checkpointed state; this is just the reverse of
    # checkpoint. If the -saved flag is included, the object is marked as
    # unchanged.

    method {saveable restore} {state {option ""}} {
        # FIRST, restore the state.
        array unset db
        array set db $state

        # NEXT, set the changed flag
        if {$option eq "-saved"} {
            set info(changed) 0
        } else {
            set info(changed) 1
        }

        # NEXT, clear the undo stack
        $us edit reset
    }


    # saveable changed
    #
    # Returns the changed flag, 1 if the state has changed and 0 otherwise.
    # The changed flag is set on change, and is cleared by checkpoint and
    # restore when called with the -saved flag.

    method {saveable changed} {} {
        return $info(changed)
    }

    #-------------------------------------------------------------------
    # Utility Methods

    # profile
    #
    # Executes the _command_ using Tcl's "time" command, and logs the
    # run time.
    #
    # Syntax:
    #   profile _command...._
    #
    #   command - A command to execute

    method profile {args} {
        set profile [time $args 1]
        $self Log detail "profile: $args $profile"
    }

    # Log
    #
    # Logs the message to the -logger.
    #
    # Syntax:
    #   Log _severity message_
    #
    #   severity - A logger(n) severity level
    #   message  - The message text.

    method Log {severity message} {
        if {$options(-logger) ne ""} {
            $options(-logger) $severity $options(-logcomponent) $message
        }
    }
}
