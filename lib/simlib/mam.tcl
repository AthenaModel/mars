#-----------------------------------------------------------------------
# TITLE:
#   mam.tcl
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
#   Mars Affinity Model
#
#   This module is a pure-Tcl replacement for the original 
#   mam(n), which made heavy use of SQLite.  It is a 
#   saveable(i) module.
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export mam
}

#-------------------------------------------------------------------
# mam

snit::type ::simlib::mam {
    # Make it a singleton
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Lookup Tables

    # Default topic attributes.  The "name" attribute is set 
    # programmatically.

    typevariable defaultTopic {
        affinity  1
        relevance 1.0
    }

    # Default system attributes.  The "name" attribute is set
    # programmatically.

    typevariable defaultSystem {
        commonality 1.0
    }

    # Default belief attributes.

    typevariable defaultBelief {
        position 0.0
        emphasis 0.5
    }
    

    #-------------------------------------------------------------------
    # Type Variables

    # db: Array variable for most of the module's saved data.  Many
    #     of the entries are dictionaries. 
    #
    #   changed => Changed flag, for saveable(i)
    #
    #   playbox => Dictionary of playbox-wide settings
    #           -> commonality => playbox commonality fraction (gamma)
    #
    #   sids => List of belief system IDs
    #   system-$sid => Dictionary for belief system $sid
    #               -> name => belief system name
    #               -> commonality => commonality fraction
    #   beliefs-$sid => Dictionary of beliefs by topic.  If a tid is missing,
    #                   the belief is presumed to be {0.0, 0.0}.
    #                -> $tid => Belief dictionary
    #                        -> position => position on topic
    #                        -> emphasis => emphasis on topic 
    #
    #   tids => List of topic IDs
    #   topic-$tid => Dictionary for topic $tid
    #              -> name => Topic name
    #              -> affinity => Affinity flag
    #              -> relevance => Topic relevance fraction
    #     

    typevariable db -array {
        changed    0
        playbox    {gamma 1.0}
        sids       {}
        tids       {}
    }

    # cache: Computed results dictionary.  The cache is cleared whenever
    # any input data changes.  The keys are as follows:
    #
    #  affinity => dictionary of computed affinity values by sid1,sid2
    #           -> $sid1 => dictionary of affinities of $sid1 with others
    #                    -> $sid2 => computed affinity.
    #  atids    => List of topic IDs of affinity topics
    #  etaPlaybox => etaPlaybox commonality value
    #  P => dictionary of relevant positions by sid
    #    -> $sid => List of positions P for each atid
    #  tau => dictionary of relevant emphases by sid
    #      -> $sid => List of emphases tau for each atid.
    #
    # The cache is cleared when any data is changed.

    typevariable cache {}

    #-------------------------------------------------------------------
    # General Typemethods

    # clear
    #
    # Deletes all content, returning the module to its initial state.

    typemethod clear {} {
        array unset db
        array set db {
            changed    1
            playbox    {gamma 1.0}
            sids       {}
            tids       {}
        }

        set cache [dict create]
    }

    #-------------------------------------------------------------------
    # Playbox typemethods
    
    # playbox set attr value ?attr value...?
    # playbox set attrdict
    #
    # attr     - An attribute name
    # value    - An attribute value
    # attrdict - A dictionary of attribute names and values.
    #
    # Set playbox attributes.

    typemethod {playbox set} {args} {
        SaveAttributes playbox playbox {} [args2dict $args] 
    }

    # playbox get ?attr?
    #
    # attr   - An attribute name
    #
    # Returns the value of the named attribute, or the whole dictionary
    # if $attr is omitted.

    typemethod {playbox get} {{attr ""}} {
        return [GetAttributes $db(playbox) $attr]
    }

    # playbox cget opt
    #
    # opt - An option name.
    #
    # Returns an attribute using option notation.

    typemethod {playbox cget} {opt} {
        return [$type playbox get [string range $opt 1 end]]
    }

    # playbox configure opt val ?opt val...?
    #
    # opt - An option name.
    # val - An option value.
    #
    # Configures a playbox using option notation.

    typemethod {playbox configure} {args} {
        return [$type playbox set [optlist2dict $args]]
    }

    # playbox view
    #
    # Returns a formatted [playbox get] dictionary.

    typemethod {playbox view} {} {
        set view [$type playbox get]

        dict with view {
            set gamma [format "%.2f" $gamma]
        }

        return $view
    }
    

    #-------------------------------------------------------------------
    # System typemethods

    # system ids
    #
    # Returns a list of system IDs (sids)

    typemethod {system ids} {} {
        return $db(sids)
    }

    # system namedict
    #
    # Returns a dictionary $sid => $name for all belief systems.

    typemethod {system namedict} {} {
        set ndict [dict create]
        foreach sid $db(sids) {
            dict set ndict $sid [dict get $db(system-$sid) name]
        }

        return $ndict
    }

    # system add sid
    #
    # sid - a system ID (a unique token).
    #
    # Adds a new system with the given ID; returns the ID.

    typemethod {system add} {sid} {
        assert {![$type system exists $sid]}

        lappend db(sids) $sid

        set db(system-$sid) \
            [dict create name "System $sid" {*}$defaultSystem]
        set db(beliefs-$sid) [dict create]

        # Mark data changed
        MarkChanged

        return $sid
    }

    # system set sid attr value ?attr value...?
    # system set sid attrdict
    #
    # sid      - A system ID
    # attr     - An attribute name
    # value    - An attribute value
    # attrdict - A dictionary of attribute names and values.
    #
    # Set system attributes.

    typemethod {system set} {sid args} {
        SaveAttributes system system-$sid {} [args2dict $args] 
    }

    # system get sid ?attr?
    #
    # sid    - A system ID
    # attr   - An attribute name
    #
    # Returns the value of the named attribute, or the whole dictionary
    # if $attr is omitted.

    typemethod {system get} {sid {attr ""}} {
        return [GetAttributes $db(system-$sid) $attr]
    }

    # system delete sid
    #
    # sid - A system ID
    #
    # Deletes the system ID. Returns the undo data for [system undelete].

    typemethod {system delete} {sid} {
        # FIRST, save the undo data.
        set undoData \
            [list $sid $db(sids) $db(system-$sid) $db(beliefs-$sid)]

        # NEXT, remove the system and its beliefs
        ldelete db(sids) $sid
        unset -nocomplain db(system-$sid)
        unset -nocomplain db(beliefs-$sid)

        # Mark data changed
        MarkChanged

        # NEXT, return the undo data.
        return $undoData
    }

    # system undelete undoData
    #
    # undoData - An undo data string returned by [system delete].
    # 
    # Undeletes the deleted system, restoring system attributes and
    # all beliefs, under normal undo conditions, and returns the
    # system ID.

    typemethod {system undelete} {undoData} {
        # FIRST, get the system ID.
        set sid [lindex $undoData 0]

        # NEXT, restore the system's data.
        set db(sids)         [lindex $undoData 1]
        set db(system-$sid)  [lindex $undoData 2]
        set db(beliefs-$sid) [lindex $undoData 3]

        # Mark data changed
        MarkChanged

        # NEXT, return the system ID.
        return $sid
    }


    # system exists sid
    #
    # sid - A system ID
    #
    # Returns 1 if there's a system with the given ID, and 0 otherwise.

    typemethod {system exists} {sid} {
        return [info exists db(system-$sid)]
    }

    # system cget sid opt
    #
    # sid - A system ID
    # opt - An option name.
    #
    # Returns an attribute using option notation.

    typemethod {system cget} {sid opt} {
        return [$type system get $sid [string range $opt 1 end]]
    }

    # system configure sid opt val ?opt val...?
    #
    # sid - A system ID
    # opt - An option name.
    # val - An option value.
    #
    # Configures a system using option notation.

    typemethod {system configure} {sid args} {
        return [$type system set $sid [optlist2dict $args]]
    }

    # system id name
    #
    # name - A system name
    #
    # Returns the system's id given its name, or "" if no such system is
    # found.

    typemethod {system id} {name} {
        foreach sid $db(sids) {
            if {[dict get $db(system-$sid) name] eq $name} {
                return $sid
            }
        }

        return ""
    }

    # system view sid
    #
    # sid - A system ID
    #
    # Returns a formatted [system get] dictionary with the following
    # additions:
    #
    #    sid - The system ID

    typemethod {system view} {sid} {
        set view [$type system get $sid]

        dict set view sid $sid

        dict with view {
            set commonality [format "%.2f" $commonality]
        }

        return $view
    }


    
    #-------------------------------------------------------------------
    # Topic typemethods

    # topic ids
    #
    # Returns a list of topic IDs (tids)

    typemethod {topic ids} {} {
        return $db(tids)
    }

    # topic namedict
    #
    # Returns a dictionary $tid => $name for all belief topics.

    typemethod {topic namedict} {} {
        set ndict [dict create]
        foreach tid $db(tids) {
            dict set ndict $tid [dict get $db(topic-$tid) name]
        }

        return $ndict
    }

    # topic add tid
    #
    # tid  - a topic ID (a unique token)
    #
    # Adds a new topic, returning the ID.

    typemethod {topic add} {tid} {
        assert {![$type topic exists $tid]}

        lappend db(tids) $tid

        set db(topic-$tid) \
            [dict create name "Topic $tid" {*}$defaultTopic]

        # Mark data changed
        MarkChanged

        return $tid
    }

    # topic set tid attr value ?attr value...?
    # topic set tid attrdict
    #
    # tid      - A topic ID
    # attr     - An attribute name
    # value    - An attribute value
    # attrdict - A dictionary of attribute names and values.
    #
    # Set topic attributes.

    typemethod {topic set} {tid args} {
        SaveAttributes topic topic-$tid {} [args2dict $args] 
    }

    # topic get tid ?attr?
    #
    # tid    - A topic ID
    # attr   - An attribute name
    #
    # Returns the value of the named attribute, or the whole dictionary
    # if $attr is omitted.

    typemethod {topic get} {tid {attr ""}} {
        return [GetAttributes $db(topic-$tid) $attr]
    }

    # topic delete tid
    #
    # tid - A topic ID
    #
    # Deletes the topic ID.  If it was the most recently created entity,
    # decrements the ID counter.  That way, [topic delete] can be used
    # to undo [topic add].  Returns the undo data for [topic undelete].

    typemethod {topic delete} {tid} {
        # FIRST, begin to accumulate the undo data.
        set undoData [list $tid $db(tids) $db(topic-$tid)]

        # NEXT, remove the topic itself
        ldelete db(tids) $tid
        unset -nocomplain db(topic-$tid)

        # NEXT, remove any beliefs for this topic
        foreach sid $db(sids) {
            if {[dict exists $db(beliefs-$sid) $tid]} {
                lappend undoData $sid [dict get $db(beliefs-$sid) $tid]
                dict unset db(beliefs-$sid) $tid
            }
        }

        # Mark data changed
        MarkChanged

        return $undoData
    }

    # topic undelete undoData
    #
    # undoData - An undo data string returned by [topic delete].
    # 
    # Undeletes the deleted topic, restoring topic attributes and
    # all beliefs, under normal undo conditions, and returns the
    # topic ID.

    typemethod {topic undelete} {undoData} {
        # FIRST, get the topic ID.
        set tid [lindex $undoData 0]

        # NEXT, restore the topic's ID to the list.
        set db(tids) [lindex $undoData 1]

        # NEXT, restore the topic's data
        set db(topic-$tid) [lindex $undoData 2]

        # NEXT, restore the topic's beliefs
        foreach {sid bdata} [lrange $undoData 3 end] {
            dict set db(beliefs-$sid) $tid $bdata
        }

        # NEXT, mark changed
        MarkChanged

        # NEXT, return the topic ID.
        return $tid
    }

    # topic exists tid
    #
    # tid - A topic ID
    #
    # Returns 1 if there's a topic with the given ID, and 0 otherwise.

    typemethod {topic exists} {tid} {
        return [info exists db(topic-$tid)]
    }

    # topic cget tid opt
    #
    # tid - A topic ID
    # opt - An option name.
    #
    # Returns an attribute using option notation.

    typemethod {topic cget} {tid opt} {
        return [$type topic get $tid [string range $opt 1 end]]
    }

    # topic configure tid opt val ?opt val...?
    #
    # tid - A topic ID
    # opt - An option name.
    # val - An option value.
    #
    # Configures a topic using option notation.

    typemethod {topic configure} {tid args} {
        return [$type topic set $tid [optlist2dict $args]]
    }

    # topic id name
    #
    # name - A topic name
    #
    # Returns the topic's id given its name, or "" if no such topic is
    # found.

    typemethod {topic id} {name} {
        foreach tid $db(tids) {
            if {[dict get $db(topic-$tid) name] eq $name} {
                return $tid
            }
        }

        return ""
    }

    # topic view tid
    #
    # tid - A topic ID
    #
    # Returns a formatted [topic get] dictionary with the following
    # additions:
    #
    #    tid   - The topic ID
    #    aflag - The affinity flag as a human-readable string

    typemethod {topic view} {tid} {
        set view [$type topic get $tid]

        dict with view {}

        dict set view tid       $tid
        dict set view aflag     [expr {$affinity ? "Yes" : "No"}]
        dict set view relevance [format "%.2f" $relevance]

        return $view
    }

    #-------------------------------------------------------------------
    # Belief typemethods

    # belief set sid tid attr value ?attr value...?
    # belief set sid tid attrdict
    #
    # sid      - A system ID
    # tid      - A topic ID
    # attr     - An attribute name
    # value    - An attribute value
    # attrdict - A dictionary of attribute names and values.
    #
    # Set belief attributes.

    typemethod {belief set} {sid tid args} {
        # FIRST, ensure sid and tid exist.
        if {![info exists db(system-$sid)]} {
            error "Invalid system"
        }

        if {![info exists db(topic-$tid)]} {
            error "Invalid topic"
        }

        # NEXT, if there's no belief created yet for this sid and tid, 
        # put in the default.
        if {![dict exists $db(beliefs-$sid) $tid]} {
            dict set db(beliefs-$sid) $tid $defaultBelief
        }

        # NEXT, save the new attributes.
        SaveAttributes belief beliefs-$sid $tid [args2dict $args] 
    }

    # belief get sid tid ?attr?
    #
    # sid    - A system ID
    # tid    - A topic ID
    # attr   - An attribute name
    #
    # Returns the value of the named attribute, or the whole dictionary
    # if $attr is omitted.

    typemethod {belief get} {sid tid {attr ""}} {
        if {[dict exists $db(beliefs-$sid) $tid]} {
            set bdict [dict get $db(beliefs-$sid) $tid]
        } else {
            set bdict [dict create {*}$defaultBelief]
        }

        return [GetAttributes $bdict $attr]
    }

    # belief cget sid tid opt
    #
    # sid - A system ID
    # tid - A topic ID
    # opt - An option name.
    #
    # Returns an attribute using option notation.

    typemethod {belief cget} {sid tid opt} {
        return [$type belief get $sid $tid [string range $opt 1 end]]
    }

    # belief configure sid tid opt val ?opt val...?
    #
    # sid - A system ID
    # tid - A topic ID
    # opt - An option name.
    # val - An option value.
    #
    # Configures a belief using option notation.

    typemethod {belief configure} {sid tid args} {
        return [$type belief set $sid $tid [optlist2dict $args]]
    }

    # belief view sid tid
    #
    # sid - A system ID
    # tid - A topic ID
    #
    # Returns a formatted [belief get] dictionary with the following
    # additions:
    #
    #    sid - The system ID
    #    tid - The belief ID

    typemethod {belief view} {sid tid} {
        set view [$type belief get $sid $tid]

        set p [dict get $view position]
        set e [dict get $view emphasis]

        dict set view sid      $sid
        dict set view tid      $tid
        dict set view position [::simlib::qposition name $p]
        dict set view emphasis [::simlib::qemphasis name $e]
        dict set view textpos  [::simlib::qposition longname $p]
        dict set view textemph [::simlib::qemphasis longname $e]
        dict set view numpos   $p
        dict set view numemph  $e

        return $view
    }


    #-------------------------------------------------------------------
    # Affinity Computation

    # affinity sid1 sid2
    #
    # sid1 - A system ID
    # sid2 - A system ID
    #
    # Returns the affinity of sid1 for sid2, computing it if need be.

    typemethod affinity {sid1 sid2} {
        if {![dict exists $cache affinity $sid1 $sid2]} {
            $type ComputeAffinity $sid1 $sid2
        }

        return [dict get $cache affinity $sid1 $sid2]
    }

    # compute
    #
    # Computes the affinity of every system for every other system,
    # based on the topics for which the affinity flag is set.
    # Clears the cache before proceeding.

    typemethod compute {} {
        set cache [dict create]
        $type ComputeAffinity $db(sids) $db(sids)
    }

    # ComputeAffinity asids bsids
    #
    # asids  - "a" system IDs
    # bsids  - "b" system IDs
    #
    # Computes affinity.ab for all systems A and all systems B.

    typemethod ComputeAffinity {asids bsids} {
        # FIRST, get the affinity topics and compute eta.playbox.
        set atids      [$type Cache_atids]
        set etaPlaybox [$type Cache_etaPlaybox]

        # NEXT, if we have no affinity tactics we're done.  All affinities
        # are 1.0.
        if {[llength $atids] == 0} {
            foreach s1 $asids {
                foreach s2 $bsids {
                    dict set cache affinity $s1 $s2 [expr {0.0}]
                }
            }

            return
        }

        # NEXT, compute the affinity for each pair of entities.  If there 
        # are no affinity topics, then all affinities are zero.

        foreach s1 $asids {
            foreach s2 $bsids {
                set theta1 [dict get $db(system-$s1) commonality]
                set theta2 [dict get $db(system-$s2) commonality]

                let eta {$etaPlaybox * min($theta1,$theta2)}

                $type Cache_PTau $s1 $atids
                $type Cache_PTau $s2 $atids

                set P1  [dict get $cache P $s1]
                set tau [dict get $cache tau $s1]
                set P2  [dict get $cache P $s2]

                dict set cache affinity $s1 $s2 \
                   [Affinity $eta $P1 $tau $P2]
            }
        }
    }

    # Cache_atids
    #
    # Returns the list of affinity topics, using the cache.

    typemethod Cache_atids {} {
        if {![dict exists $cache atids]} {
            set atids [list]
            foreach tid $db(tids) {
                if {[dict get $db(topic-$tid) affinity]} {
                    lappend atids $tid
                }
            }
            dict set cache atids $atids
        }

        return [dict get $cache atids]
    }

    # Cache_etaPlaybox
    #
    # Returns etaPlaybox for the affinity topics.

    typemethod Cache_etaPlaybox {} {
        if {![dict exists $cache etaPlaybox]} {
            dict set cache etaPlaybox [etaPlaybox [$type Cache_atids]]
        }

        return [dict get $cache etaPlaybox]
    }

    # Cache_PTau sid atids
    #
    # sid   - A system ID
    # atids - The affinity topic IDs
    #
    # Caches the list of P and tau values for the system, given the
    # affinity topics.  Does nothing if the data is already cached.

    typemethod Cache_PTau {sid atids} {
        if {[dict exists $cache P $sid]} {
            return
        }

        set pList [list]
        set tauList [list]

        foreach tid $atids {
            set rel [dict get $db(topic-$tid) relevance]
            lassign [getBelief $sid $tid] pos emph

            lappend pList   [expr {$pos*$rel}]
            lappend tauList $emph
        }

        dict set cache P $sid $pList
        dict set cache tau $sid $tauList
    }

    # congruence sid theta hook
    #
    # sid     - A system ID.
    # theta   - The hook's system commonality, 0.0 to 1.0
    # hook    - A dictionary {tid -> position}
    #
    # Computes the congruence of the hook with the system,
    # given the hook's system commonality.  Essentially, 
    # the congruence of the hook with a belief system is simply the 
    # affinity of the system with the hook considering only the
    # explicit topics included in the hook, along with the 
    # implicit topics implied by the playbox commonality setting
    # and the system's and hook's system commonality.

    typemethod congruence {sid theta hook} {
        # FIRST, if there are no topics in the hook, return 0.0.
        if {[dict size $hook] == 0} {
            return 0.0
        }

        # NEXT, compute eta.playbox for the topics in the topic set.
        set etaPlaybox [etaPlaybox [dict keys $hook]]

        # NEXT, get sid's entity commonality, and compute eta.

        set sid_theta [dict get $db(system-$sid) commonality]
       
        let eta {$etaPlaybox * min($sid_theta, $theta)}

        # NEXT, Get the entity's signs, strengths, and emphases.
        # The entity's position is attenuated by the relevance of the
        # topic.

        foreach tid [dict keys $hook] {
            set rel [dict get $db(topic-$tid) relevance]
            lassign [getBelief $sid $tid] pos emph

            lappend ePos [expr {$rel * $pos}]
            lappend hPos [expr {$rel * [dict get $hook $tid]}]
            lappend tau $emph

        }

        return [Affinity $eta $ePos $tau $hPos]
    }



    # getBelief sid tid
    #
    # sid  - A system ID
    # tid  - A topic ID
    #
    # Returns a list of the position and emphasis for the belief, 
    # providing the default values if nothing's been set.

    proc getBelief {sid tid} {
        if {[dict exists $db(beliefs-$sid) $tid]} {
            set bdict [dict get $db(beliefs-$sid) $tid]
        } else {
            set bdict [dict create {*}$defaultBelief]
        }

        list \
            [dict get $bdict position] \
            [dict get $bdict emphasis]
    }

    # etaPlaybox tlist
    #
    # tlist   - A list of topics
    #
    # Computes the playbox commonality for the topics in the tlist.

    proc etaPlaybox {tlist} {
        # FIRST, retrieve gamma and compute eta.playbox.
        set gamma [dict get $db(playbox) gamma]

        set totalRelevance 0.0

        foreach tid $tlist {
            set totalRelevance [expr {
                $totalRelevance + [dict get $db(topic-$tid) relevance]
            }]
        }

        return [expr {$gamma*$totalRelevance}]
    }

    
    # Affinity $eta pfList eList pgList
    #
    # eta     - A measure of the commonality between the entities
    # pfList  - A list of positions for entity f
    # eList   - A list of emphases for entity f
    # pgList  - A list of positions for entity g
    #
    # Computes the affinity of entity f for entity g given their
    # positions on the same topics and f's emphasis on agreement/disagreement,
    # per the Mars Analyst's Guide.
    #
    # NOTE: The eta and positions have already been modified by topic
    # relevance.

    proc Affinity {eta pfList eList pgList} {
        # FIRST, set epsilon.  This could be a parmset parameter, but
        # there seems little need to adjust it.  Note that all of the 
        # numbers we're comparing have absolute values less than or 
        # equal to 1.0.
        set epsilon 0.001

        # NEXT, Prepare to accumulate data
        set J [list]   ;# Topics i s.t. E.fi = 0
        set K [list]   ;# Topics in J s.t. P.fi != P.gi
        set L [list]   ;# Topics i s.t. E.fi > 0

        set sum_L_M     0.0
        set sum_J_ZG    0.0
        set sum_L_Num   0.0
        set sum_L_Denom 0.0

        # NEXT, loop over the topics and accumulate the data needed to
        # assess the special cases.
        for {set i 0} {$i < [llength $pfList]} {incr i} {
            set Efi [lindex $eList $i]
            set Pfi [lindex $pfList $i]
            set Pgi [lindex $pgList $i]

            set Bfi    [sign $Pfi]
            let Bgi    [sign $Pgi]
            let Zfi    {abs($Pfi)}
            let Zgi    {abs($Pgi)}

            # Agreement
            if {$Bfi == $Bgi} {
                let G {sqrt($Pfi * $Pgi)}
            } else {
                let G 0.0
            }

            # Disagreement
            let D {abs($Pfi - $Pgi)/2.0}
            
            # Importance
            let M {max($Zfi,$D)}

            if {abs($Efi) < $epsilon} {
                lappend J $i
                let sum_J_ZG {$sum_J_ZG + $Zfi*$G}

                let val {abs($Pfi-$Pgi)}

                if {abs($Pfi - $Pgi) >= $epsilon} {
                    lappend K $i
                }
            } else {
                lappend L $i

                let beta {(1 - $Efi)/$Efi}

                let sum_L_M {$sum_L_M + $M}

                let sum_L_Num   {$sum_L_Num   + $M*($G - $beta*$D)}
                let sum_L_Denom {$sum_L_Denom + $M*(1  + $beta*$D)}
            }
        }

        # CASE A

        if {[llength $J] == 0 && 
            $eta + $sum_L_M < $epsilon
        } {
            return 0.0
        }

        # CASE B
        if {[llength $J] > 0 &&
            [llength $K] == 0 &&
            $eta + $sum_J_ZG + $sum_L_M < $epsilon
        } {
            return 0.0
        }

        # CASE C
        
        if {[llength $J] > 0 &&
            [llength $K] > 0
        } {
            return -1.0
        }

        # CASE D/E
        #
        # These cases differ only in the $sum_J_ZG term, which is
        # zero in Case E.

        let Num   {$eta + $sum_J_ZG + $sum_L_Num}
        let Denom {$eta + $sum_J_ZG + $sum_L_Denom}

        return [expr {$Num/$Denom}]
    }

    # sign x
    # 
    # x - A number
    #
    # Returns the sign of x as -1, 0, or 1.

    proc sign {x} {
        if {$x < 0.0} {
            return -1.0
        } elseif {$x > 0.0} {
            return 1.0
        } else {
            return 0.0
        }
    }

    #-------------------------------------------------------------------
    # Debugging aids

    # dump
    #
    # Debugging dump

    typemethod dump {} {
        set out ""
        append out "playbox:     $db(playbox)\n"
        append out "sids:        $db(sids)\n"
        append out "tids:        $db(tids)\n"

        append out "\n"
        foreach tid $db(tids) {
            append out "topic-$tid:  $db(topic-$tid)\n"
        }

        foreach sid $db(sids) {
            append out "\n"
            append out "system-$sid: $db(system-$sid)\n"
            foreach tid $db(tids) {
                append out "belief $tid: [getBelief $sid $tid]]\n"
            }
        }

        if {[dict size $cache] == 0} {
            return $out
        }

        append out "\n"
        dict for {s1 sdict} [dict get $cache affinity] {
            dict for {s2 affinity} $sdict {
                append out \
                "affinity $s1,$s2 = $affinity\n"

            }
        }

        return $out
    }

    

    #-------------------------------------------------------------------
    # Utility Procedures

    # SaveAttributes etype dictname keylist adict
    #
    # etype     - The entity type, used in error message
    # dictname  - The dictionary name in db()
    # keylist   - Any nested keys, or "" for none
    # adict     - The attribute dictionary
    #
    # Saves the attributes in the db() dictionary.  Verifies
    # attribute names.

    proc SaveAttributes {etype dictname keylist adict} {
        # FIRST, verify that the dictname exists
        if {![info exists db($dictname)]} {
            error "Invalid $etype"
        }

        # NEXT, save the data
        dict for {attr value} $adict {
            if {[dict exists $db($dictname) {*}$keylist $attr]} {
                dict set db($dictname) {*}$keylist $attr $value 
            } else {
                error "Invalid $etype attribute: $attr"
            }
        }

        # NEXT, clear the cache; any computation might be invalid.
        MarkChanged
    }

    # GetAttributes adict attr
    #
    # adict - An attribute dictionary.
    # attr  - The attribute name, or ""
    #
    # Retrieves the named attribute, or the whole dictionary if "".

    proc GetAttributes {adict attr} {
        if {$attr eq ""} {
            return $adict
        } else {
            return [dict get $adict $attr]
        }
    }

    # args2adict argv
    #
    # argv   - An argument list
    #
    # If argv is one item, extract its first entry; otherwise return it.
    # This is used in commands that can take a dictionary as individual
    # arguments or as a single value.

    proc args2dict {argv} {
        if {[llength $argv] == 1} {
            return [lindex $argv 0]
        } else {
            return $argv
        }
    }

    # optlist2dict optlist
    #
    # optlist - A list of option names and values
    #
    # Returns the optlist as a dictionary, with the hyphens removed.

    proc optlist2dict {optlist} {
        foreach {opt val} $optlist {
            dict set result [string range $opt 1 end] $val
        }

        return $result
    }

    # dict2optlist optlist
    #
    # dict - An attribute dictionary
    #
    # Returns the dictionary as an option list, adding hyphens to the
    # key names.

    proc dict2optlist {dict} {
        dict for {attr val} $dict {
            lappend result -$attr $value
        }

        return $result
    }
   
    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.  If 
    # -saved is specified, the data is marked unchanged.

    typemethod checkpoint {{option ""}} {
        if {$option eq "-saved"} {
            set db(changed) 0
        }

        return [array get db]
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint - A string returned by the checkpoint typemethod
    #
    # Restores the non-RDB state of the module to that contained
    # in the checkpoint.  If -saved is specified, the data is marked
    # unchanged.
    
    typemethod restore {checkpoint {option ""}} {
        # FIRST, restore the checkpoint data
        $type clear
        array set db $checkpoint

        if {$option eq "-saved"} {
            set db(changed) 0
        }
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.
    #
    # Syntax:
    #   changed

    typemethod changed {} {
        return $db(changed)
    }

    # MarkChanged
    #
    # Sets the changed flag, and clears the cache.

    proc MarkChanged {} {
        set db(changed) 1
        set cache [dict create]
    }


}

