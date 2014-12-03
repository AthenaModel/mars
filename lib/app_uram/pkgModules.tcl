#-----------------------------------------------------------------------
# TITLE:
#    pkgModules.tcl
#
# PROJECT:
#    athena-mars - Mars Simulation Support Library
#
# DESCRIPTION:
#    app_uram(n) package modules file
#
#    Generated by Kite.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition

# -kite-provide-start  DO NOT EDIT THIS BLOCK BY HAND
package provide app_uram 3.0.7
# -kite-provide-end

#-----------------------------------------------------------------------
# Required Packages

# Add 'package require' statements for this package's external 
# dependencies to the following block.  Kite will update the versions 
# numbers automatically as they change in project.kite.

# -kite-require-start ADD EXTERNAL DEPENDENCIES
package require sqlite3 3.8
package require snit 2.3
package require kiteutils 0.4.3
package require -exact marsutil 3.0.7
package require -exact marsgui 3.0.7
package require -exact simlib 3.0.7
# -kite-require-end

namespace import ::kiteutils::*
namespace import ::marsutil::*
namespace import ::marsgui::*
namespace import ::simlib::*

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::app_uram:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Modules

source [file join $::app_uram::library app.tcl      ]
source [file join $::app_uram::library appwin.tcl   ]
source [file join $::app_uram::library executive.tcl] 
source [file join $::app_uram::library parmdb.tcl   ]
source [file join $::app_uram::library sim.tcl      ]
