#-----------------------------------------------------------------------
# TITLE:
#    pkgModules.tcl
#
# PROJECT:
#    athena-mars - Mars Simulation Support Library
#
# DESCRIPTION:
#    app_mars(n) package modules file
#
#    Generated by Kite.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition

# -kite-provide-start  DO NOT EDIT THIS BLOCK BY HAND
package provide app_mars 3.0.23
# -kite-provide-end

#-----------------------------------------------------------------------
# Required Packages

# Add 'package require' statements for this package's external 
# dependencies to the following block.  Kite will update the versions 
# numbers automatically as they change in project.kite.

# -kite-require-start ADD EXTERNAL DEPENDENCIES

# -kite-require-end

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::app_mars:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Modules

source [file join $::app_mars::library main.tcl]
