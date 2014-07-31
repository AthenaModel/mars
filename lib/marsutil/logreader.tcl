#-----------------------------------------------------------------------
# TITLE:
#   logreader.tcl
#
# AUTHOR:
#   Dave Jaffe
#   Will Duquette
# 
# DESCRIPTION:
#   Mars marsutil(n) package: logreader type.
# 
#   A logreader reads and parses a log file given a user-defined parsing 
#   function.  There are two ways to use a logreader:
#
#   * The "get" method returns the parsed contents of a log file in one
#     call.
#
#   * The "newentries" method reads, parses, and returns any new entries
#     in the file.  The file remains open until it is explicitly closed
#     or a differently file is selected.
#
#   The logreader expects that the file to be read consists of lines of
#   text (entries).  Beyond that, this module places no constraints on
#   the nature of the entries or on how they should be parsed.
# 
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required packages

package require snit

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::marsutil:: {
    namespace export logreader
}

#-----------------------------------------------------------------------
# Widget Definition

snit::type ::marsutil::logreader {
    #-------------------------------------------------------------------
    # Options

    # -parsecmd cmd
    # 
    # cmd
    # 
    # The command used to parse the contents of a log file.  
    option  -parsecmd
    
    #-------------------------------------------------------------------
    # Variables
    
    variable currentName ""   ;# Name of the current log file, or ""
    variable handle      ""   ;# Handle of the current log file, or ""

    #-------------------------------------------------------------------
    # Constructor & Destructor

    # No constructor needed; default constructor is adequate.

    destructor {
        catch {$self close}
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Parse contents
    #
    # contents         The contents of a log file
    #
    # Returns the parsed contents

    method Parse {contents} {
        set cmd $options(-parsecmd)
        lappend cmd $contents
        return [uplevel \#0 $cmd]
    }

    #-------------------------------------------------------------------
    # Public Methods
    
    # get file
    #
    # file    Pathname of a log file.
    #
    # Returns the contents of the named log file, as parsed by the
    # -parsecmd.

    method get {file} {
        # Save the file name.
        set currentName $file
        
        # Open the file, and configure it explicitly for "lf" mode.
        # This way, carriage returns in the data don't cause trouble.
        set handle [open $file]
        fconfigure $handle -translation lf
        
        # Read the file contents. 
        set contents [read -nonewline $handle]
        
        # Close the file.
        $self close
        
        # Parse and return the log data.
        return [$self Parse $contents]
    }
    
    # newentries file
    #
    # file     Pathname of a log file.
    #
    # For a new file, reads all current content from the file and returns
    # the parsed content, leaving the file open.  Subsequent calls for
    # the same file parse and return any new entries.  If the file name
    # changes, the previous file is closed.

    method newentries {file} {
        # FIRST, If the file name has changed then close the old file
        # and save the new name.
        if {$file ne $currentName} {
            $self close
            set currentName $file
        }
        
        # NEXT, Open the file if needed.
        if {$handle eq ""} {
            set handle [open $currentName]
            fconfigure $handle -translation lf
        }
        
        # NEXT, Get any new entries, skipping the newline at the end.
        set newData [read -nonewline $handle]
        seek $handle 0 end

        # NEXT, Parse and return the log data.
        return [$self Parse $newData]
    }

    # close
    #
    # Closes the current log file, if any
    method close {args} {
        if {$handle ne ""} {
            close $handle
            set handle ""
        }
    }

    # filename
    #
    # Returns the name of the current or most recently read
    # file name.

    method filename {args} {
        return $currentName
    }
    
    # isfileopen
    #
    # Returns 1 if the current file is open, else 0.

    method isfileopen {args} {
        if {$handle eq ""} {
            return 0
        } else {
            return 1
        }
    }
}







