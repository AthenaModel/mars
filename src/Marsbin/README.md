# Marsbin Package

This package contains a Tcl extension implemented using the TEA
architecture.  The extension consists of a single binary library
(.so or .dll) and a pkgIndex.tcl file.  It contains a few Tcl commands
that are implemented only in C, and C versions of commands that are
also implemented in pure Tcl in marsutil(n).

The Marsbin package is never loaded explicitly by application code.
Instead, marsutil(n) will load it if it's available, and fall back to
the pure-Tcl code if it is not.  (This allows marsutil(n) to be used
for development on platforms where the C code won't build.)

In order to set the Marsbin version number to the project version, we
need a 2-tier approach:

* The MakeTEA "all" target updates configure.in with current version 
  number, runs autoconf, configure, make, and make install, putting the
  new package in $root/lib/Marsbin$version

* The configure step creates the actual Makefile.

Thus, to build everything do this:

* make -f MakeTEA clean all

WARNING: For some reason, the initial capital letter in "Marsbin" is 
significant.  If you change the name to "marsbin", it won't compile.