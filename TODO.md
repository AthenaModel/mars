# athena-mars TODO List

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
* margui
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
