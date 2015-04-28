#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

package require marsutil
package require marsgui
namespace import kiteutils::* marsutil::* marsgui::*

label .lab -text "Debugger Test"
pack .lab

debugger new

