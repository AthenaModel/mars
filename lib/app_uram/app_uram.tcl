#-----------------------------------------------------------------------
# FILE: app_uram.tcl
#
#   Package loader.  This file provides the package, requires all
#   other packages upon which this package depends, and sources in
#   all of the package's modules.
#
# PACKAGE:
#   app_uram(n) -- mars_uram(1) implementation package
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition
#
# Because this is an application package, the namespace is mostly
# unused.

namespace eval ::app_uram:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Provide the app_uram(n) package

package provide app_uram 1.0

#-----------------------------------------------------------------------
# Require infrastructure packages

# Active Tcl
package require sqlite3
package require snit

# JNEM Packages
package require marsutil
package require marsgui
package require simlib

namespace import ::marsutil::* 
namespace import ::marsgui::*
namespace import ::simlib::*

#-----------------------------------------------------------------------
# Load app_uram(n) submodules

source [file join $::app_uram::library app.tcl       ]
source [file join $::app_uram::library appwin.tcl    ]
source [file join $::app_uram::library executive.tcl ] 
source [file join $::app_uram::library parmdb.tcl    ]
source [file join $::app_uram::library sim.tcl       ]















