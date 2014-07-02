#-----------------------------------------------------------------------
# TITLE:
#   marsutil.tcl
#
# PROJECT:
#   athena-mars
#
# AUTHOR:
#   TBD
#
# DESCRIPTION:
#   marsutil(n) Package, marsutil module.
#
#   FIXME: Description of this module
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export \
        hello

    namespace ensemble create
}

#-----------------------------------------------------------------------
# Commands

# hello
#
# Dummy example proc.

proc ::marsutil::hello {args} {
    puts "marsutil(n): Hello, world!"
    return
}
