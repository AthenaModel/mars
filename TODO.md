# athena-mars TODO List

* Goal:  Add "kite man" for building the man pages.
* Goal:  Kite updates lib requires in pkgModules.tcl
* Revise marsmisc(n)
  * Split into submodules as appropriate
  * Purge deadwood

* ehtml(n)
  * Complete ehtml(n) testing
  * Update ehtml(n) man page
  * Add ehtml(5) man page
* manpage(n)
  * Add test suite
  * Add manpage.

* Man Page Processing
  * Where do man pages go, when built?
    *   Do they simply live in the docs/manX directory, as now?
    *   A developer has to clone Mars and build the docs by hand?
    *   Perhaps we can push them out to https://oak/kite?
  * At present, man page references can have "roots" so that 
    Athena man pages can refer to Mars man pages or Tcl man pages
    or Tk man pages.  Does that even make sense, with this new world?
  * Athena man pages are now strictly for the developer; but the user
    of Mars might or might not be a developer.
  * An app/appkit could package up the docs, and install them locally.
  * An app/appkit could package up the docs, and display them in a 
    mybrowser (if mybrowser were part of Mars)