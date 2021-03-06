#-----------------------------------------------------------------------
# TITLE:
#    pkgModules.tcl
#
# PROJECT:
#    athena-mars - Mars Simulation Support Library
#
# DESCRIPTION:
#    app_cmtool(n) package modules file
#
#    Generated by Kite.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition

# -kite-provide-start  DO NOT EDIT THIS BLOCK BY HAND
package provide app_cmtool 3.0.23
# -kite-provide-end

#-----------------------------------------------------------------------
# Required Packages

# Add 'package require' statements for this package's external 
# dependencies to the following block.  Kite will update the versions 
# numbers automatically as they change in project.kite.

# -kite-require-start ADD EXTERNAL DEPENDENCIES
package require snit 2.3
package require kiteutils 0.5.0
package require -exact marsutil 3.0.23
# -kite-require-end

namespace import ::kiteutils::*
namespace import ::marsutil::* 


#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::app_cmtool:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Modules

source [file join $::app_cmtool::library app.tcl]
source [file join $::app_cmtool::library app_check.tcl]
source [file join $::app_cmtool::library app_dump.tcl]
source [file join $::app_cmtool::library app_mash.tcl]
source [file join $::app_cmtool::library app_run.tcl]
source [file join $::app_cmtool::library app_solve.tcl]
source [file join $::app_cmtool::library app_xref.tcl]
