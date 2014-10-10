# athena-mars TODO List

Current Goals:

* Get Mars 3.0 to where it can support Athena 6.2.
* Build mars as exe

Next:

* Revise Mars CM plan

# To Be Cleaned Up

* Consider restructuring marmisc(n).
* Consider breaking the Mars packages up into logical pieces.
* Consider removing uram(n)'s undo/redo capability.  
  * We don't use it, and don't plan to.
  * Then, remove undostack.
* Revise/remove the ENVIRONMENT section in all man pages.
* Revise file headers for the app_* Tcl files.

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
