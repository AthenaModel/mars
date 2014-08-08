#-----------------------------------------------------------------------
# TITLE:
#   enum.tcl
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
#   Mars: marsutil(n) module: enum objects
#
#	A enum is an object that defines an enumerated type.  Each
#   value in the enum has two names, a longname and a shortname.
#   The enum object can determine whether values belong to the
#   type, and convert long names to short names and vice versa.
#
#   Note that a enum object does not store individual values;
#   rather, it defines the set of values for the enum.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export Public Commands

namespace eval ::marsutil:: {
    namespace export enum
}

#-----------------------------------------------------------------------
# enum ADT

snit::type ::marsutil::enum {
    typeconstructor {
        namespace import ::marsutil::* 
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Instance variables:

    # The elements in these lists correspond.
    variable shortnames {}  ;# List of short names
    variable longnames  {}  ;# List of long names
    variable opts -array {
        noindex 0
    }

    #-------------------------------------------------------------------
    # Constructor
    
    # The "deflist" is a list of pairs: shortname longname.  If 
    # opt is -noindex, don't do lookups by index.

    constructor {deflist {opt ""}} {
        $self add $deflist

        if {$opt ne ""} {
            if {$opt eq "-noindex"} {
                set opts(noindex) 1
            } else {
                error "invalid option: \"$opt\""
            }
        } 
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Deprecated method names
    delegate method shortname  using {%s name}
    delegate method shortnames using {%s names}

    # validate input
    #
    # Validates that the input is valid enum value.  If it is, the short
    # name is returned; otherwise an error is thrown.
    
    method validate {input} {
        set ndx  [$self Input2index $input]

        if {$ndx == -1} {
            set list [join $shortnames ", "]
            return -code error -errorcode INVALID \
                "invalid value \"$input\", should be one of: $list"
        } else {
            return [lindex $shortnames $ndx]
        }
    }

    # name input
    #
    # Retrieve the short name corresponding to the long name, value, or
    # index.
    method name {input} {
        set ndx  [$self Input2index $input]

        if {$ndx == -1} {
            return ""
        } else {
            return [lindex $shortnames $ndx]
        }
    }
    
    # longname value
    #
    # Retrieve the long name corresponding to the short name, value, or
    # index.
    method longname {input} {
        set ndx  [$self Input2index $input]

        if {$ndx == -1} {
            return ""
        } else {
            return [lindex $longnames $ndx]
        }
    }

    # index input
    #
    # Retrieve the index corresponding to the long name or short name.
    # Returns -1 if the input is not recognized.
    method index {input} {
        $self Input2index $input
    }

    # names
    #
    # Returns a list of the short names.
    method names {} {
        return $shortnames
    }

    # longnames
    #
    # Returns a list of the long names.
    method longnames {} {
        return $longnames
    }

    # add deflist
    #
    # Add new values to the enumeration.
    method add {deflist} {
        assert {[llength $deflist] % 2 == 0}
        foreach {short long} $deflist {
            lappend shortnames $short
            lappend longnames $long
        }
    }

    # size
    #
    # Returns the number of symbols in the enumeration.
    method size {} {
        llength $shortnames
    }

    # deflist
    #
    # Returns the enum's definition list

    method deflist {} {
        set result {}

        foreach short $shortnames long $longnames {
            lappend result $short $long
        }

        return $result
    }

    # eq a b
    #
    # a    A name or index
    # b    A name or index
    #
    # Returns 1 if index(a) == index(b), and 0 otherwise.

    method eq {a b} {
        expr {[$self index $a] == [$self index $b]}
    }

    # lt a b
    #
    # a    A name or index
    # b    A name or index
    #
    # Returns 1 if index(a) < index(b), and 0 otherwise.

    method lt {a b} {
        expr {[$self index $a] < [$self index $b]}
    }

    # gt a b
    #
    # a    A name or index
    # b    A name or index
    #
    # Returns 1 if index(a) > index(b), and 0 otherwise.

    method gt {a b} {
        expr {[$self index $a] > [$self index $b]}
    }

    # le a b
    #
    # a    A name or index
    # b    A name or index
    #
    # Returns 1 if index(a) <= index(b), and 0 otherwise.

    method le {a b} {
        expr {[$self index $a] <= [$self index $b]}
    }

    # ge a b
    #
    # a    A name or index
    # b    A name or index
    #
    # Returns 1 if index(a) >= index(b), and 0 otherwise.

    method ge {a b} {
        expr {[$self index $a] >= [$self index $b]}
    }

    #-------------------------------------------------------------------
    # Private Methods and Procs

    # html
    #
    # Returns a snippet of HTML suitable for inclusion in a man page.

    method html {} {
        append out "<table>\n"

        append out "<tr>\n"
        append out "<th align=\"right\">Index</th>\n"
        append out "<th align=\"left\">Name</th>\n"
        append out "<th align=\"left\">Long Name</th>\n"
        append out "</tr>\n"

        set len [llength $shortnames]

        for {set i 0} {$i < $len} {incr i} {
            append out "<tr>\n"
            append out "<td valign=\"baseline\" align=\"center\">$i</td>\n"
            append out \
                "<td valign=\"baseline\" align=\"left\"><tt>[lindex $shortnames $i]</tt></td>\n"
            append out "<td valign=\"baseline\" align=\"left\">[lindex $longnames $i]</td>\n"
            append out "</tr>\n"
        }

        append out "</table>\n"

        return $out
    } 

    # Input2Index input
    #
    # Given a name or index, returns the related index if possible.  
    # Otherwise, returns -1.  If -noindex was given on creation, the
    # input must be a name.
    method Input2index {input} {
        # FIRST, is it an index?
        if {!$opts(noindex)} {
            if {[string is integer -strict $input] &&
                $input >= 0 &&
                $input < [llength $shortnames]} {
                return $input
            }
        }

        # NEXT, is it a short name?
        set ndx [lsearch -nocase $shortnames $input]

        if {$ndx != -1} {
            return $ndx
        }

        # NEXT, is it a long name?
        set ndx [lsearch -nocase $longnames $input]

        if {$ndx != -1} {
            return $ndx
        }

        # NEXT, it's an error
        return -1
    }
}



