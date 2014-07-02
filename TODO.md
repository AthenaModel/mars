# athena-mars TODO List

* Goal:  Add "kite man" for building the man pages.
* Goal:  Kite updates lib requires in pkgModules.tcl
* Revise marsmisc(n)
  * Split into submodules as appropriate
  * Purge deadwood

* manpage(n): a module for building manpages.  Replaces app_man; it's
  a core for an app, not an app itself.
* manpage(n) should create an ehtml module of its own, to use for processing;
  we don't want to share it with other tools, as it will have its own
  macros.
* We need ehtml module as an object, not a singleton.
  * As a module, makes macros harder.  But could use slave interpreter;
    then it doesn't matter as much.
  * Allows us to keep man pages from interfering with each other.
* We need manpage(n) module as a normal library singleton, not as an
  app_* package.
* Then Kite uses marsutil, and can use manpage(n) to build manpages in
  docs/mann.

* Man Page Processing
  * How do we get the project version into the man pages?
    <<version>>?
  * Do I want to use templates, or htools?
  * Where do man pages go, when built?
    *   Do they simply live in the docs/manX directory, as now?
    *   A developer has to clone Mars and build the docs by hand?
    *   Perhaps we can push them out to https://oak/kite?
  * At present, man page references can have "roots" so that 
    Athena man pages can refer to Mars man pages or Tcl man pages
    or Tk man pages.  Does that even make sense, with this new world?
    *   I don't think it does; relying on includes for this is silly.
  * Athena man pages are now strictly for the developer; but the user
    of Mars might or might not be a developer.
  * An app/appkit could package up the docs, and install them locally.
  * An app/appkit could package up the docs, and display them in a 
    mybrowser (if mybrowser were part of Mars)