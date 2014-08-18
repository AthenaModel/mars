#-----------------------------------------------------------------------
# TITLE:
#   simtypes.tcl
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
#   Simulatin Type Definitions
#
# 	This module defines basic data types used by simlib(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::simlib:: {
    namespace export   \
        egrouptype     \
        eproximity     \
        ipopulation    \
        qaffinity      \
        qcooperation   \
        qduration      \
        qemphasis      \
        qmag           \
        qposition      \
        qrel           \
        qsaliency      \
        qsat           \
        qtrend         \
        rfraction      \
        rfracpair      \
        rmagnitude
}

#-----------------------------------------------------------------------
# Qualities
#
# Qualities relate English-language ratings, like "Very Good" to numeric
# values.  All quality names begin with "q".

# Affinity
::marsutil::quality ::simlib::qaffinity {
    SUPPORT  "Supports"               0.7  0.8  1.0  
    LIKE     "Likes"                  0.2  0.4  0.7
    INDIFF   "Is Indifferent To"     -0.2  0.0  0.2
    DISLIKE  "Dislikes"              -0.7 -0.4 -0.2
    OPPOSE   "Opposes"               -1.0 -0.8 -0.7
} -min -1.0 -max 1.0 -format {%4.1f} -bounds yes

# Cooperation
::marsutil::quality ::simlib::qcooperation {
    AC "Always Cooperative"      99.9 100.0 100.0
    VC "Very Cooperative"        80.0  90.0  99.9
    C  "Cooperative"             60.0  70.0  80.0
    MC "Marginally Cooperative"  40.0  50.0  60.0
    U  "Uncooperative"           20.0  30.0  40.0
    VU "Very Uncooperative"       1.0  10.0  20.0
    NC "Never Cooperative"        0.0   0.0   1.0
} -min 0.0 -max 100.0 -format {%5.1f} -bounds yes

# Reaction Time, in days, for GRAM level events
# 
# TBD: We'll be replacing this with just a time in decimal days.
::marsutil::quality ::simlib::qduration {
    XL "X_LONG"  5.0
    L  "LONG"    2.5
    M  "MEDIUM"  1.0
    S  "SHORT"   0.1
    XS "X_SHORT" 0.042
} -format {%3.1f} -min 0.0

# Magnitude: satisfaction and cooperation inputs
::marsutil::quality ::simlib::qmag {
    XXXXL+ "XXXXL+"   30.0
    XXXL+  "XXXL+"    20.0
    XXL+   "XXL+"     15.0
    XL+    "XL+"      10.0
    L+     "L+"        7.5
    M+     "M+"        5.0
    S+     "S+"        3.0
    XS+    "XS+"       2.0
    XXS+   "XXS+"      1.5
    XXXS+  "XXXS+"     1.0
    ZERO   "ZERO"      0.0
    XXXS-  "XXXS-"    -1.0
    XXS-   "XXS-"     -1.5
    XS-    "XS-"      -2.0
    S-     "S-"       -3.0
    M-     "M-"       -5.0
    L-     "L-"       -7.5
    XL-    "XL-"     -10.0
    XXL-   "XXL-"    -15.0
    XXXL-  "XXXL-"   -20.0
    XXXXL- "XXXXL-"  -30.0
} -format {%5.2f} -min -100.0 -max 100.0

# Position: a mam(n) entity's position on a topic.
::marsutil::quality ::simlib::qposition {
    P+ "Passionately For"      0.8   0.9  1.0
    S+ "Strongly For"          0.45  0.6  0.8
    W+ "Weakly For"            0.05  0.3  0.45
    A  "Ambivalent"           -0.05  0.0  0.05
    W- "Weakly Against"       -0.45 -0.3 -0.05
    S- "Strongly Against"     -0.8  -0.6 -0.45
    P- "Passionately Against" -1.0  -0.9 -0.8
} -bounds yes -format {%5.2f} -min -1.0 -max 1.0

# Relationship between two groups
::marsutil::quality ::simlib::qrel {
    FRIEND  "Friend"      0.3   0.5   1.0
    NEUTRAL "Neutral"    -0.1   0.1   0.3
    ENEMY   "Enemy"      -1.0  -0.5  -0.1
} -bounds yes -format {%+4.1f}

# Saliency (Of a concern)
::marsutil::quality ::simlib::qsaliency {
    CR "Crucial"         1.000
    VI "Very Important"  0.850
    I  "Important"       0.700
    LI "Less Important"  0.550
    UN "Unimportant"     0.400
    NG "Negligible"      0.000
} -min 0.0 -max 1.0 -format {%5.3f}

# Satisfaction
::marsutil::quality ::simlib::qsat {
    VS "Very Satisfied"     80.0
    S  "Satisfied"          40.0
    A  "Ambivalent"          0.0
    D  "Dissatisfied"      -40.0
    VD "Very Dissatisfied" -80.0
} -min -100.0 -max 100.0 -format {%7.2f}

# Emphasis: a mam(n) entity's emphasis on agreement or disagreement
# with respect to a topic.
::marsutil::quality ::simlib::qemphasis {
    ASTRONG  "Agreement--Strong"     0.9
    AWEAK    "Agreement"             0.7
    NEITHER  "Neither"               0.5
    DWEAK    "Disagreement"          0.35
    DSTRONG  "Disagreement--Strong"  0.25
    DEXTREME "Disagreement--Extreme" 0.15
} -format {%4.2f} -min 0.0 -max 1.0

# Satisfaction: Long-Term Trend
::marsutil::quality ::simlib::qtrend {
    VH "Very High"  8.0
    H  "High"       4.0
    N  "Neutral"   -1.0
    L  "Low"       -4.0
    VL "Very Low"  -8.0
} -format {%4.1f}

    
#-------------------------------------------------------------------
# Enumerations
#
# By convention, enumeration names begin with the letter "e".


# Group Types

::marsutil::enum ::simlib::egrouptype {
    CIV "CIVILIAN"
    ORG "ORGANIZATION"
    FRC "FORCE"
}


# Neighborhood Proximity
#
# 0=here, 1=near, 2=far, 3=remote
::marsutil::enum ::simlib::eproximity {
    HERE   "Here"
    NEAR   "Near"
    FAR    "Far"
    REMOTE "Remote"
}

#-------------------------------------------------------------------
# Range and Integer Types

# Fraction
::marsutil::range ::simlib::rfraction \
    -min 0.0 -max 1.0 -format "%4.2f"

# Non-negative decimal numbers
::marsutil::range ::simlib::rmagnitude \
    -min 0.0 -format "%.2f"

# Population values
snit::integer ::simlib::ipopulation \
    -min 0


# Pair of rfractions, total <= 1.0
snit::type ::simlib::rfracpair {
    typemethod validate {pair} {
        # FIRST, is it a list
        if {![string is list $pair] ||
            [llength $pair] != 2
        } {
            return -code error -errorcode INVALID \
 "expected a list of exactly two numbers between 0.0 and 1.0, got \"$pair\""
        }

        # NEXT, are they fractions?
        lassign $pair a b

        ::simlib::rfraction validate $a
        ::simlib::rfraction validate $b

        # NEXT, do they sum to more than 1.0?
        if {$a + $b > 1.0} {
            return -code error -errorcode INVALID \
"expected a pair of fractions whose sum is less than or equal to 1.0, got \"$pair\""
        }

        return $pair
    }
}


