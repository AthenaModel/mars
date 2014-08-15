# athena-mars TODO List

Current Goals:

* Get Mars 3.0 to where it can support Athena 6.2.

Next:
* Convert mars to mars.tcl/mars.kit
  * main in marsapp
  * Omit obsolete packages
      * commit (subversion dependent)
      * doc (replaced by 'kite docs')
      * link (subversion dependent)
      * man (replaced by 'kite docs')
      * replace (replaced by 'kite replace')
      * sequence (simply obsolete)
  * Retain useful packages
      * cmtool
      * gram? (when simlib has been included, if gram is retained)
      * icons
      * log?
      * sql
      * uram (when simlib has been included)
* Pull in simlib
  * As appropriate
* Pull in mars apps as appropriate.
  * Built mars(1) as a kit.
  * Some apps might go to Kite.


# Conversion Notes

* Grabbing modules
  * Look for test_*.tcl scripts for modules that have them
  * Look for ancillary data
* Figure out how to allow kite to easily run scripts in the context of the
  project.  "kite run"?  Or perhaps if the first argument to kite is a file
  name, set up for a run, and run it?  (I like that)
* Kite's going to need to support "-exact" syntax for version numbers.
* Restructure marsmisc
* Don't wrap test modules in namespaces.
* Organize modules so that related content is grouped together, across
  Tcl and Tk both; but don't load Tk content if Tk has not been required.
* marsutil modules remaining to convert:
  * Geometry/Coordinate Conversion
    * geometry
    * geoset
    * latlong
    * mapref
    * geotiff
* marsgui
  * Used
    * checkfield
    * cli
    * cmdbrowser
    * cmsheet
    * colorfield
    * commandentry
    * databrowser
    * datagrid
    * debugger
    * dispfield
    * dynabox
    * dynaview
    * enumfield
    * filter
    * finder
    * form
    * hbarchart
    * htmlframe
    * htmlviewer
    * isearch
    * keyfield
    * listfield
    * logdisplay
    * loglist
    * mapcanvas
    * marsicons
    * menubox
    * messagebox
    * messageline
    * mkicon
    * modeditor
    * multifield
    * newkeyfield
    * orderdialog
    * osgui
    * querybrowser
    * rangefield
    * rotext
    * scrollinglog
    * sqlbrowser
    * stripchart
    * subwin
    * texteditor
    * texteditorwin
    * textfield
    * winbrowser
  * Binary
    * gtifreader
      * Does this need anything in Tk?  If not, it should go in marsgeo_bin.
  * Unused  
    * paner
    * pwin
    * pwinman
    * reportbrowser
    * reportviewer
    * reportviewerwin
    * zuluspinbox

## After Integration with Athena

Note: you can define snit::widgets without requiring Tk.

* marsutil reorganization]
  with Athena
  * marscomm -- IPC
    * commclient
    * commserver
    * gtclient
    * gtserver
  * simulation/modeling (simlib?)  
    * eventq
    * simclock
    * cellmodel
  * GUI Support
    * dynaform
    * order
    * gradient
    * statecontroller
    * lazyupdater
  * Database
    * sqldocument
    * sqlib - merge into sqldocument?
    * undostack
  * Other
    * mat
    * vec
    * notifier
    * parmset
    * timeout
    * tabletext - Used only by simlib's test DBs
    * cmdinfo
    * logger
    * logreader
    * enum
    * quality
    * range
    * zcurve
    * zulu
