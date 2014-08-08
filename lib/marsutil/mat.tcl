#-----------------------------------------------------------------------
# TITLE:
#   mat.tcl
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
#   Mars: marsutil(n) Tcl Utilities
#
#	Matrix commands.  
#
#   Matrix elements are retrieved and set using the lindex and lset 
#   commands.  An m*n matrix is indexed 0..m-1, and 0..n-1.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export mat
}

#-----------------------------------------------------------------------
# Matrix Ensemble

snit::type ::marsutil::mat {
    # Make it an ensemble
    pragma -hastypeinfo 0 -hastypedestroy 0 -hasinstances 0

    typeconstructor {
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Ensemble subcommands

    # new m n ?initval?
    #
    # Creates a new matrix of m rows by n columns; each cell is filled
    # with initval, which defaults to the empty string.  Note that each
    # row is a vector.
    typemethod new {m n {initval {}}} {
        assert {$m >= 1 && $n >= 1}

        set mat {}

        for {set i 0} {$i < $m} {incr i} {
            set row {}
            for {set j 0} {$j < $n} {incr j} {
                lappend row $initval
            }
            lappend mat $row
        }
        
        return $mat
    }

    # rows matrix
    #
    # Returns the number of rows in the matrix.
    typemethod rows {matrix} {
        llength $matrix
    }

    # cols matrix
    #
    # Returns the number of columns in the matrix.
    typemethod cols {matrix} {
        llength [lindex $matrix 0]
    }

    # rowvec matrix i
    #
    # Returns row i as a vector
    typemethod rowvec {matrix i} {
        assert {0 <= $i && $i < [mat rows $matrix]}
        lindex $matrix $i
    }
    
    # colvec matrix j
    #
    # Returns column j as a vector
    typemethod colvec {matrix j} {
        assert {0 <= $j && $j < [mat cols $matrix]}

        set m [mat rows $matrix]

        set result {}

        for {set i 0} {$i < $m} {incr i} {
            lappend result [lindex $matrix $i $j]
        }

        return $result
    }

    # equal mat1 mat2
    #
    # mat1      A matrix
    # mat2      Another matrix
    #
    # Returns 1 if the matrices have the same dimensions and the
    # elements are numerically equal, and 0 otherwise.

    typemethod equal {mat1 mat2} {
        set m [mat rows $mat1]
        set n [mat cols $mat1]

        if {[mat rows $mat2] != $m ||
            [mat cols $mat2] != $n} {
            return 0
        }

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                if {[lindex $mat1 $i $j] != [lindex $mat2 $i $j]} {
                    return 0
                }
            }
        }

        return 1
    }

    # add mat1 mat2
    #
    # Returns the sum of the two matrices.
    typemethod add {mat1 mat2} {
        set m1 [mat rows $mat1]
        set n1 [mat cols $mat1]

        set m2 [mat rows $mat2]
        set n2 [mat cols $mat2]

        assert {$m1 == $m2 && $n1 == $n2}

        set result [mat new $m1 $n1]

        for {set i 0} {$i < $m1} {incr i} {
            for {set j 0} {$j < $n1} {incr j} {
                set v1 [lindex $mat1 $i $j]
                set v2 [lindex $mat2 $i $j]
                lset result $i $j [expr {$v1 + $v2}]
            }
        }

        return $result
    }

    # sub mat1 mat2
    #
    # Returns the difference of the two matrices.
    typemethod sub {mat1 mat2} {
        set m1 [mat rows $mat1]
        set n1 [mat cols $mat1]

        set m2 [mat rows $mat2]
        set n2 [mat cols $mat2]

        assert {$m1 == $m2 && $n1 == $n2}

        set result [mat new $m1 $n1]

        for {set i 0} {$i < $m1} {incr i} {
            for {set j 0} {$j < $n1} {incr j} {
                set v1 [lindex $mat1 $i $j]
                set v2 [lindex $mat2 $i $j]
                lset result $i $j [expr {$v1 - $v2}]
            }
        }

        return $result
    }

    # scalarmul matrix constant
    #
    # Returns the product of a matrix and a scalar.
    typemethod scalarmul {matrix constant} {
        set m [mat rows $matrix]
        set n [mat cols $matrix]

        set result [mat new $m $n]

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                lset result $i $j \
                    [expr {$constant*[lindex $matrix $i $j]}]
            }
        }
        
        return $result
    }

    # format matrix fmtstring
    #
    # matrix      A matrix
    # fmtstring   A format string with one conversion
    
    typemethod format {matrix fmtstring} {
        set result {}

        foreach row $matrix {
            set rowresult {}

            foreach value $row {
                lappend rowresult [format $fmtstring $value]
            }

            lappend result $rowresult
        }

        return $result
    }

    # pprint matrix ?rlabels? ?clabels?
    #
    # matrix      A matrix.
    # rlabels     Row label vector
    # clabels     Column label vector
    #
    # Returns the pretty-printed contents of a matrix given the 
    # row and column labels.  The row and column labels default to
    # "Row $i" and "Col $j".

    typemethod pprint {matrix {rlabels ""} {clabels ""}} {
        # FIRST, get the dimensions of the matrix
        set m [mat rows $matrix]
        set n [mat cols $matrix]

        # NEXT, get the row labels
        if {[llength $rlabels] > 0} {
            assert {[vec size $rlabels] == [mat rows $matrix]}
        } else {
            set rlabels [GetLabels "Row" $m]
        }

        # NEXT, get the column labels
        if {[llength $clabels] > 0} {
            assert {[vec size $clabels] == [mat cols $matrix]}
        } else {
            set clabels [GetLabels "Col" $n]
        }

        # FIRST, get the width of the row labels.
        set hdrwidth [lmaxlen $rlabels]

        # NEXT, get the widths of the data in each columns
        for {set j 0} {$j < $n} {incr j} {
            set labwidth [string length [lindex $clabels $j]]
            
            set colwidth($j) [lmaxlen [mat colvec $matrix $j]]
            
            if {$colwidth($j) < $labwidth} {
                set colwidth($j) $labwidth
            }
        }

        # NEXT, pretty print the header line
        set out [format "%-*s" $hdrwidth " "]
        for {set j 0} {$j < $n} {incr j} {
            append out [format " %*s" $colwidth($j) [lindex $clabels $j]]
        }
        append out "\n"

        # NEXT, pretty print the rows.
        for {set i 0} {$i < $m} {incr i} {
            append out [format "%-*s" $hdrwidth [lindex $rlabels $i]]

            for {set j 0} {$j < $n} {incr j} {
                append out \
                    [format " %*s" $colwidth($j) [lindex $matrix $i $j]]
            }
            append out "\n"
        }

        return $out
    }

    
    # pprintf matrix format ?rlabels? ?clabels?
    #
    # matrix      A matrix.
    # format      A format(n) format string
    # rlabels     Row labels
    # clabels     Column labels
    #
    # Pretty-prints the contents of a matrix.  The entries are formatted
    # using $format; the row and column labels default as for [mat pprint].
    #
    # This command just formats the matrix entries; the rest of the work
    # is done by pprint
    typemethod pprintf {matrix format {rlabels ""} {clabels ""}} {
        set m [mat rows $matrix]
        set n [mat cols $matrix]

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                set item [lindex $matrix $i $j]
                if {[string trim $item] eq ""} {
                    lset matrix $i $j ""
                } else {
                    lset matrix $i $j [format $format [lindex $matrix $i $j]]
                }
            }
        }

        # NEXT, Pretty-print the matrix.
        mat pprint $matrix $rlabels $clabels
    }

    # pprintq matrix quality ?rlabels? ?clabels? 
    #
    # matrix      A matrix.
    # quality     A ::marsutil::quality object
    # rlabels     Row labels
    # clabels     Column labels
    #
    # Pretty-prints the contents of a "quality" matrix.  The entries 
    # are formatted as "quality=value".  Note that empty cells are
    # ignored.
    #
    # This command just formats the matrix entries; the rest of the work
    # is done by pprint.  The row and column labels default as for pprint.
    typemethod pprintq {matrix quality {rlabels ""} {clabels ""}} {
        # FIRST, get the max width of the quality shortnames
        set qualwidth [lmaxlen [$quality shortnames]]

        # NEXT, format the elements
        set m [mat rows $matrix]
        set n [mat cols $matrix]

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                set text [lindex $matrix $i $j]

                if {$text eq ""} {
                    continue
                }

                set value [$quality format $text]
                set name [$quality shortname $value]
                lset matrix $i $j \
                    [format "%*s=%s" $qualwidth $name $value]
            }
        }

        # NEXT, dump the matrix.
        mat pprint $matrix $rlabels $clabels
    }

    # numerize matrix quality
    #
    # Converts a matrix of symbols to a matrix of numbers using the
    # specified quality and returns the converted matrix.  If a value
    # is already numeric, it is unchanged.  If any symbol can't be
    # converted, an error is thrown.
    typemethod numerize {matrix quality} {
        set m [mat rows $matrix]
        set n [mat cols $matrix]

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                set symbol [lindex $matrix $i $j]

                if {[string is double -strict $symbol]} {
                    continue
                }

                if {$symbol eq ""} {
                    error "matrix $i $j is {}"
                }

                set value [$quality value $symbol]
                lset matrix $i $j $value
            }
        }

        return $matrix
    }

    # filter matrix command
    #
    # Runs the elements through the filter command, and returns the
    # result.
    typemethod filter {matrix command} {
        set m [mat rows $matrix]
        set n [mat cols $matrix]

        for {set i 0} {$i < $m} {incr i} {
            for {set j 0} {$j < $n} {incr j} {
                set cmd $command
                lappend cmd [lindex $matrix $i $j]

                if {[catch {uplevel \#0 $cmd} result]} {
                    error "element $i $j: $result" $::errorInfo 
                }
                lset matrix $i $j $result
            }
        }

        return $matrix
    }

    # GetLabels label m
    #
    # label     "Row" or "Col"
    # m         Number of labels
    #
    # Return a list of row or column labels of the form "$label $i",
    # where i runs from 0 to m-1.

    proc GetLabels {label m} {
        set labels {}

        set width [string length $m]

        for {set i 0} {$i < $m} {incr i} {
            set ilabel [format "%*d" $width $i]
            lappend labels "$label $ilabel"
        }

        return $labels
    }
}





