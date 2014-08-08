# athena-mars TODO List

* Grabbing modules
  * Updated headers
  * Make tests pass
  * Look for test_*.tcl scripts for modules that have them
  * Look for ancillary data
  * Update all man pages.
* Restructure marsmisc
* Don't wrap test modules in namespaces.
* Organize modules so that related content is grouped together, across
  Tcl and Tk both; but don't load Tk content if Tk has not been required.
* marsutil
  * Moved to kite
    * ehtml
    * smartinterp
    * tclchecker
    * template
  * Old Modules not used by Athena
    * Truly Obsolete
      * callbacklist -- replaced by notifier(n)
      * mat3d        -- Bad idea
      * reporter     -- Replaced by myserver
      * sequence     -- Pixane is defunct
    * Local IPC -- marscomm
      * commclient
      * commserver
      * gtclient
      * gtserver
    * Simulation -- Some simlib
      * eventq
      * simclock
    * Data Structures
      * mat
      * vec
  * Old Modules used by Athena
    * Flow of Control
      x notifier
    * Data Entry and Validation -- GUI Support Package
      x dynaform
      x order
    * GUI Support -- GUI Support Package
      x gradient
      x statecontroller
      x lazyupdater
    * Data Structure
      x parmset
    * Event Loop
      x timeout
    * File I/O
      * tabletext - Used only by simlib's test DBs
    * Geometry/Coordinate Conversion
      * geometry
      * geoset
      * latlong
      * mapref
    * Introspection
      x cmdinfo
    * Logging  - marslog
      x logger
      x logreader
    * Math/Modeling
      * cellmodel - Separate package?
    * SQL Database
      x sqldocument
      x sqlib - merge into sqldocument?
    * Validation Types
      x enum
      x quality
      x range
      x zcurve
      x zulu
    * Other
      x undostack
  * Binary modules
    * geotiff
    * Etc.
