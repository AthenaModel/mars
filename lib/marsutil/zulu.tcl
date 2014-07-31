#-----------------------------------------------------------------------
# TITLE:
#	zulu.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Mars: marsutil(n) Tcl Utilities
#
#	Zulu-Time Translation
#
#       A Zulu-time string is a UTC time in this format:
#
#         ddhhmmZmmmyy
#
#       where
#
#         dd    Day of month, 01 to 31
#         hh    Hours, 00 to 23
#         mm    Minutes, 00 to 59
#         Z     Literal "Z"
#         mmm   Three letter month abbreviation, capitalized.
#         yy    Two-digit year, 1969 to 2068
#
#       This module has conversions from Zulu-time to Unix seconds
#       and vice-versa.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::marsutil:: {
    namespace export zulu
}


#-----------------------------------------------------------------------
# Zulu Ensemble

snit::type ::marsutil::zulu {
    # Make it an ensemble
    pragma -hastypeinfo 0 -hastypedestroy 0 -hasinstances 0

    typeconstructor {
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Ensemble subcommands

    # fromsec seconds
    #
    # seconds        Clock seconds since the epoch
    #
    # Convert clock seconds into a Zulu-time string.

    typemethod fromsec {seconds} {
        string toupper [clock format $seconds \
                            -format {%d%H%MZ%b%y} \
                            -gmt 1]
    }

    # tosec zulutime
    #
    # zulutime     A Zulu time string
    #
    # Converts a Zulu time string in to standard clock seconds.

    typemethod tosec {zulutime} {
        # FIRST, convert to uppercase
        set upzulu [string toupper $zulutime]

        # NEXT, the "clock" command doesn't know how to scan Zulu time,
        # so parse the string and convert it to something that "clock"
        # can scan: hhmm dd monthname yy
        if {![regexp {^(\d\d)(\d\d)(\d\d)Z([A-Z][A-Z][A-Z])(\d\d)$} $upzulu \
                  dummy dd hh mm monthname yy]} {
            error "invalid Zulu-time string: \"$zulutime\""
        }

        set time "$hh:$mm $dd $monthname $yy"

        if {[catch {clock scan $time -gmt 1} result]} {
            error "invalid Zulu-time string: \"$zulutime\""
        }

        return $result
    }

    # validate zulutime
    #
    # zulutime     A Zulu time string
    #
    # Validates a Zulu time string

    typemethod validate {zulutime} {
        # FIRST, convert to uppercase
        set upzulu [string toupper $zulutime]

        # NEXT, the "clock" command doesn't know how to scan Zulu time,
        # so parse the string and convert it to something that "clock"
        # can scan: hhmm dd monthname yy
        if {![regexp {^(\d\d)(\d\d)(\d\d)Z([A-Z][A-Z][A-Z])(\d\d)$} $upzulu \
                  dummy dd hh mm monthname yy]} {
            return -code error -errorcode INVALID \
                "invalid Zulu-time string: \"$zulutime\""
        }

        set time "$hh:$mm $dd $monthname $yy"

        if {[catch {clock scan $time -gmt 1} result]} {
            return -code error -errorcode INVALID \
                "invalid Zulu-time string: \"$zulutime\""
        }

        return $upzulu
    }

}











