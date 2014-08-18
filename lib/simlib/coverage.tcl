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
#   Coverage Functions
#
#   The "coverage" command validates and evaluates personnel coverage
#   functions, yielding coverage fractions for a population, e.g.,
#   what percentage of a neighborhood's population are affected 
#   by the PRESENCE of BLUE forces.
#
#   A coverage function is specified as a pair of parameters, c and d,
#   e.g., {25 1000}.  This specification says that it requires a
#   troop density of 25 personnel per 1000 people in the population
#   to achieve 2/3 coverage of the population.  In other words,
#   if the population is 100,000, it will take 2500 personnel to
#   achieve a coverage of 2/3.
#
#   Given c and d, the function is defined as follows:
#
#                                         -lambda*TD
#        CF(personnel,population) = (1 - e          )
#
#   where
#
#        lambda = ln(3)/c, 
#
#   and
#
#        TD = personnel*d/population
#
#   TD is the "troop density".  
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export coverage
}

#-----------------------------------------------------------------------
# coverage type

snit::type ::simlib::coverage {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate func
    #
    # func    A personnel coverage function specified, {c d}
    #
    # Validates and returns the function spec, or throws
    # INVALID on error.

    typemethod validate {func} {
        if {[llength $func] != 2} {
            return -code error -errorcode INVALID \
     "invalid coverage function \"$func\", expected \"c d\""
        }
        
        foreach {c d} $func {}

        if {![string is double -strict $c] || $c < 0.0} {
            return -code error -errorcode INVALID \
                "invalid c \"$c\", should be non-negative number"
        }

        if {![string is double -strict $d] || $d <= 0.0} {
            return -code error -errorcode INVALID \
             "invalid d \"$d\", should be positive number"
        }

        return $func
    }

    # eval func personnel population
    #
    # func        A personnel coverage function spec, {c d}
    # personnel   Number of personnel present in area
    # population  Civilian population of area
    #
    # Computes the personnel coverage given the inputs.

    typemethod eval {func personnel population} {
        # FIRST, handle the degenerate case when the population
        # is 0.0.
        if {$population == 0} {
            return 0.0
        }

        # NEXT, handle the normal case.
        lassign $func c d

        let td {double($personnel)*$d/$population}

        let exponent {-($td)*log(3)/($c)}

        let cf {1 - exp($exponent)}

        return $cf
    }
}













