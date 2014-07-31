# athena-mars TODO List

* Restructure marsmisc
* Don't wrap test modules in namespaces.
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
    * Local IPC
      * commclient
      * commserver
      * gtclient
      * gtserver
    * Simulation
      * eventq
      * simclock
    * Data Structures
      * mat
      * vec
  * Old Modules used by Athena
    * Flow of Control
      * notifier
    * Data Entry and Validation
      * dynaform
      * order
    * GUI Support
      * gradient
      * statecontroller
    * Data Structure
      * parmset
    * Event Loop
      * lazyupdater
      * timeout
    * File I/O
      * tabletext - Used only by simlib's test DBs
    * Geometry/Coordinate Conversion
      * geometry
      * geoset
      * latlong
      * mapref
    * Introspection
      * cmdinfo
    * Logging
      * logger
      * logreader
    * Math/Modeling
      * cellmodel - Separate package?
    * SQL Database
      * sqldocument
      * sqlib - merge into sqldocument?
    * Validation Types
      * enum
      * quality
      * range
      * zcurve
      * zulu
    * Other
      * undostack
  * Binary modules
    * geotiff
    * Etc.
