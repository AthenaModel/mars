#-----------------------------------------------------------------------
# TITLE:
#   rmf.tcl
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
#   Relationship Multiplier Functions
#
#   The "rmf" command defines a number of "relationship multiplier
#   functions" or RMFs.  RMFs are used to allow effects to depend
#   on relationships in a variety of ways.  Each RMF, m = rmf(R), 
#   takes a relationship value,  11.0 <= R <= 1.0, and returns a 
#   multipler m, -1.0 <= m <= 1.0.
#
#   There are many RMFs, and they have names.  Consequently, the 
#   "rmf" command is also an enum(n) enumeration of the RMF names.
#
#-----------------------------------------------------------------------

namespace eval ::simlib:: {
    namespace export rmf
}

#-----------------------------------------------------------------------
# rmf type

snit::type ::simlib::rmf {
    # Make it a singleton
    pragma -hasinstances no -hastypeinfo no -hastypedestroy no

    #-------------------------------------------------------------------
    # Type Components

    # rmf(n)'s configuration parameter set
    typecomponent parm -public parm

    # The enum of function names
    typecomponent enum

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # FIRST, Import needed commands from other packages.
        namespace import ::marsutil::* 
        namespace import ::marsutil::*

        # NEXT, define the function names.
        enum rmfEnum {
            constant   "Constant"
            linear     "Linear"
            quad       "Quad"
            frquad     "Friends Quad"
            frmore     "Friends More"
            enquad     "Enemies Quad"
            enmore     "Enemies More"
        }

        set enum [myproc rmfEnum]

        # NEXT, define the module's configuration parameters
        set parm ${type}::parm
        parmset $parm

        $parm subset rmf {
            rmf(n) configuration parameters.
        }

        snit::double ${type}::nomrelType -min 0.1 -max 1.0

        $parm define rmf.nominalRelationship ${type}::nomrelType 0.6 {
            This value, a floating point number from 0.1 to 1.0, defines
            the strength of the nominal relationship value, that is, 
            the magnitude of relationships for which the RMFs should
            return a value of 1.0 or -1.0.
        }
    }


    #-------------------------------------------------------------------
    # Public Type Methods

    # Make all of the enum(n) methods available.
    delegate typemethod * to enum

    # constant R
    #
    # R    A relationship value
    #
    # Returns a constant 1.0.  The relationship does not affect the result.

    typemethod constant {R} {
        return 1.0
    }

    # linear R
    #
    # R    A relationship value
    #
    # The effects match the relationship exactly.

    typemethod linear {R} {
        set Rnom [$parm get rmf.nominalRelationship]

        expr {$R/$Rnom}
    }

    # quad R
    #
    # R   A relationship value
    #
    # The effects match the relationship, but are weaker than with the
    # "linear" function where R < Rnom and stronger where R > Rnom.

    typemethod quad {R} {
        set Rnom [$parm get rmf.nominalRelationship]

        set root [expr {$R/$Rnom}]

        # Compute sign
        if {$R > 0} {
            return [expr {$root*$root}]
        } elseif {$R < 0} {
            return [expr {-($root*$root)}]
        } else {
            return 0.0
        }
    }

    # frquad R
    #
    # R   A relationship value
    #
    # "Friends Quad".  Enemies are not affected.  Like "quad", but 0
    # if R <= 0.

    typemethod frquad {R} {
        if {$R > 0} {
            set Rnom [$parm get rmf.nominalRelationship]
            set root [expr {$R/$Rnom}]
            return [expr {$root*$root}]
        } else {
            return 0.0
        }
    }

    # frmore R
    #
    # R   A relationship value
    #
    # "Friends More".  Both friends and enemies are affected, but
    # friends are affected more than enemies.

    typemethod frmore {R} {
        set Rnom [$parm get rmf.nominalRelationship]

        set root [expr {(1 + $R)/(1 + $Rnom)}]

        return [expr {$root*$root}]
    }

    # enquad R
    #
    # R   A relationship value
    #
    # "Enemies Quad".  Friends are not affected.  Like "quad", but 0
    # if R >= 0, and always positive.

    typemethod enquad {R} {
        if {$R < 0} {
            set Rnom [$parm get rmf.nominalRelationship]
            set root [expr {$R/$Rnom}]
            return [expr {$root*$root}]
        } else {
            return 0.0
        }
    }

    # enmore R
    #
    # R   A relationship value
    #
    # "Enemies More".  Both friends and enemies are affected, but enemies
    # are effected more than friends.

    typemethod enmore {R} {
        set Rnom [$parm get Rmf.nominalRelationship]
        set root [expr {(1 - $R)/(1 + $Rnom)}]

        return [expr {$root*$root}]
    }
}













