#-----------------------------------------------------------------------
# TITLE:
#   vec.tcl
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
#	Vector commands.  
#
#   Vector elements are retrieved and set using the lindex and lset 
#   commands.  An n-vector is indexed 0..n-1, following
#   normal mathematical conventions.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export vec
}


#-----------------------------------------------------------------------
# Vector Ensemble

snit::type ::marsutil::vec {
    # Make it an ensemble
    pragma -hastypeinfo 0 -hastypedestroy 0 -hasinstances 0

    typeconstructor {
        namespace import ::marsutil::*
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Ensemble subcommands

    # new n ?initval?
    #
    # Creates a new vector of size n >= 1.  The cells are initialized
    # with initVal, which defaults to {}.

    typemethod new {n {initval {}}} {
        assert {$n >= 1}

        # Otherwise, create the vector.
        set vec {}

        for {set i 0} {$i < $n} {incr i} {
            lappend vec $initval
        }
        
        return $vec
    }

    # size vector
    #
    # Returns the number of elements in the vector.
    typemethod size {vector} {
        llength $vector
    }

    # equal vec1 vec2
    #
    # Returns 1 if the two vectors are the same size and
    # corresponding elements are numerically equal, and 0 otherwise.
    
    typemethod equal {vec1 vec2} {
        set n [vec size $vec1]

        if {[vec size $vec2] != $n} {
            return 0
        }

        for {set i 0} {$i < $n} {incr i} {
            if {[lindex $vec1 $i] != [lindex $vec2 $i]} {
                return 0
            }
        }

        return 1
    }

    # add vec1 vec2
    #
    # Returns the sum of the two vectors.
    typemethod add {vec1 vec2} {
        set n1 [vec size $vec1]
        set n2 [vec size $vec2]

        assert {$n1 == $n2}

        set result {}

        for {set i 0} {$i < $n1} {incr i} {
            set v1 [lindex $vec1 $i]
            set v2 [lindex $vec2 $i]
            lappend result [expr {$v1 + $v2}]
        }

        return $result
    }

    # sub vec1 vec2
    #
    # Returns the difference of the two vectors.

    typemethod sub {vec1 vec2} {
        set n1 [vec size $vec1]
        set n2 [vec size $vec2]

        assert {$n1 == $n2}

        set result {}

        for {set i 0} {$i < $n1} {incr i} {
            set v1 [lindex $vec1 $i]
            set v2 [lindex $vec2 $i]
            lappend result [expr {$v1 - $v2}]
        }

        return $result
    }

    # scalarmul vec constant
    #
    # Returns the vector multiplied by a scalar constant.

    typemethod scalarmul {vec constant} {
        set n1 [vec size $vec]

        set result {}

        for {set i 0} {$i < $n1} {incr i} {
            set v [lindex $vec $i]

            lappend result [expr {$constant*$v}]
        }

        return $result
    }

    # normalize vector
    #
    # vec     A vector of numbers >= 0, sum(vec) > 0
    #
    # Normalizes the vector, returning a vector of numbers where
    # 0 <= num <= 1 and sum(vector) == 1.0.

    typemethod normalize {vec} {
        set sum [expr [join $vec +]]
        
        if {$sum <= 0} {
            error "Cannot normalize, sum <= 0"
        }
        
        return [vec scalarmul $vec [expr {1.0/$sum}]]
    }

    # numerize vector quality
    #
    # Converts a vector of symbols to a vector of numbers using the
    # specified quality and returns the converted vector.  If a value
    # is already numeric, it is unchanged.  If any symbol can't be
    # converted, an error is thrown.
    typemethod numerize {vector quality} {
        set n [vec size $vector]

        for {set i 0} {$i < $n} {incr i} {
            set symbol [lindex $vector $i]

            if {[string is double -strict $symbol]} {
                continue
            }

            if {$symbol eq ""} {
                error "vector $i is {}"
            }

            set value [$quality value $symbol]
            lset vector $i $value
        }

        return $vector
    }

    # format vector fmtstring
    #
    # vector      A vector
    # fmtstring   A format string with one conversion
    
    typemethod format {vector fmtstring} {
        set result {}

        foreach value $vector {
            lappend result [format $fmtstring $value]
        }

        return $result
    }

    # pprint vector labels
    #
    # vector      A vector.
    # labels      Element labels
    #
    # Pretty-prints the contents of a vector one per row, given the labels,
    # and returns the result.

    typemethod pprint {vector labels} {
        assert {[llength $labels] == [llength $vector]}

        set m [llength $vector]

        # FIRST, get the width of the labels.
        set hdrwidth [lmaxlen $labels]

        # NEXT, get the width of the data.
        set datawidth [lmaxlen $vector]

        # NEXT, pretty-print the rows.
        set out {}
        for {set i 0} {$i < $m} {incr i} {
            append out [format "%-*s %*s\n" \
                            $hdrwidth [lindex $labels $i] \
                            $datawidth [lindex $vector $i]]
        }

        return $out
    }

    # pprintf vector labels format
    #
    # vector      A vector.
    # labels      Labels
    # format      A format(n) format string
    #
    # Pretty-prints the contents of a vector.  The entries are formatted
    # using $format.
    #
    # This command just formats the vector's entries; the rest of the work
    # is done by pprint.
    typemethod pprintf {vector labels format} {
        set m [llength $vector]

        for {set i 0} {$i < $m} {incr i} {
            lset vector $i [format $format [lindex $vector $i]]
        }

        # NEXT, Pretty-print the vector.
        vec pprint $vector $labels
    }

    # pprintq vector labels quality
    #
    # vector      A vector.
    # labels      Labels
    # quality     A ::marsutil::quality object
    #
    # Pretty-prints the contents of a "quality" vector.  The entries 
    # are formatted as "quality=value".  
    #
    # This command just formats the vector's entries; the rest of the work
    # is done by pprint.
    typemethod pprintq {vector labels quality} {
        # FIRST, get the max width of the quality shortnames
        set qualwidth [lmaxlen [$quality shortnames]]

        # NEXT, format the elements
        set m [llength $vector]

        for {set i 0} {$i < $m} {incr i} {
            set value [$quality format [lindex $vector $i]]
            set name [$quality shortname $value]
            lset vector $i \
                [format "%*s=%s" $qualwidth $name $value]
        }

        # NEXT, pretty-print the vector.
        vec pprint $vector $labels
    }
}













