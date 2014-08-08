#-----------------------------------------------------------------------
# TITLE:
#   commserver.tcl
#
# PACKAGE:
#   marsutil(n) -- Tcl Utilities
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   marsutil(n) Comm Server
#
#   This object allows clients to connect via comm(n) and a known
#   port and send commands to a command executive for processing.
#   Incoming commands are handled and responded to synchronously.
#
#   The creator must specify the port ID, a logger(n) object for
#   logging, a log component name, and the command used to validate
#   connections.
#
#   See also commclient(n).
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export commserver
}

#-----------------------------------------------------------------------
# commserver

snit::type ::marsutil::commserver {
    #-------------------------------------------------------------------
    # Creation Options

    # -port
    #
    # comm(n) port ID for incoming connections

    option -port -readonly 1

    # -logger
    #
    # Passes in logger(n) component.
    
    option -logger -readonly 1

    # -logcomponent
    #
    # String used for "component" argument to the logger.
    
    option -logcomponent -default "commserver"

    # -validatecmd
    #
    # Command prefix, to which will be appended a client's logical
    # name and IP address ("localhost" if the client is local).

    option -validatecmd -default ""

    # -evalcmd
    #
    # Command prefix, to which will be appended a client name and
    # an incoming command to execute.
    
    option -evalcmd -default ""

    # -connectcmd
    #
    # Command prefix, to which will be appended a client's logical
    # name and IP address ("localhost" if the client is local) when
    # client successfully connects.

    option -connectcmd -default ""

    # -allowremote
    #
    # If 1, allow remote clients; if 0 (the default) do not.
    
    option -allowremote -default 0 -readonly 1

    #-------------------------------------------------------------------
    # Components

    component log            ;# logger(n) object
    component comm           ;# comm(n) channel

    #-------------------------------------------------------------------
    # Instance Variables

    variable currentClient ""  ;# ID of client for whom command is 
                                # currently being executed, or "".

    # info  -- array of client info.  Keys:
    #
    #    ids               List of comm(n) ids for attached clients.
    #    names             List of logical names of attached clients.
    #    name-$id          Logical name of client, given comm(n) $id
    #    ip-$id            IP address of client, or "localhost"
    #    id-$name          comm(n) ID given logical $name
    #    ex-$id            Executive which handles commands for client
    #    time-$name        Connection time of given logical $name
    #    stat-$name        Connection status of given logical $name
    variable info -array {
        ids   {}
        names {}
    }

    #-------------------------------------------------------------------
    # Constructor and Destructor
    
    constructor {args} {
        # FIRST, get options.
        $self configurelist $args

        # NEXT, check requirements
        set log $options(-logger)

        require {[info commands $log] ne ""} "-log is not defined."
        require {$options(-validatecmd)  ne ""} \
            "-validatecmd is not defined."

        # NEXT, configure the comm channel
        #
        # TBD: Possibly we should close the default channel and open
        # one specifically for this.  Alternatively, perhaps we should
        # leave the default channel strictly alone, and open one for
        # this.
        set comm ::comm::comm

        $self Log normal "Initialized"
    }

    destructor {
        catch {$comm destroy}
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Log severity message
    #
    # severity         A logger(n) severity level
    # message          The message text.

    method Log {severity message} {
        $log $severity $options(-logcomponent) $message
    }

    # ClientEval id script
    #
    # id          The id of the sender
    # buffer      The script to execute
    #
    # Logs and evaluates the script received from the client;
    # also, registers the sender as an attached client.

    method ClientEval {id buffer} {
        # Register the sender
        if {![info exists info(name-$id)]} {
            $self ClientConnect $id $buffer
            return
        }
        
        # Since the command is sent as a single script rather than
        # as a list of args, we need to extract the script
        # from the list.
        set script [lindex $buffer 0]

        # If the script is the empty string, this is just a ping;
        # don't log it, or we'll be awash in them.
        if {[string length $script] == 0} {
            return ""
        }

        # Next, save the ID so that the script can retrieve it
        # if need be.
        set currentClient $id

        # Ask the application to evaluate the command.
        $self Log detail "$info(name-$id): $script"
        set result [callwith $options(-evalcmd) $info(name-$id) $script]

        # Next, clear currentClient.
        set currentClient ""

        # Finally, return the result
        return $result
    }

    # ClientConnect id buffer
    #
    # id          The comm(n) client ID of the new client
    # buffer      The connection data
    #
    # Validates and accepts a connection from the client.  
    # The buffer should contain a Tcl list of the form 
    # {connect <name>}.
    #
    # The logical name and the IP address (or localhost) of the 
    # client will be passed to the -validatecmd, which will throw
    # an error if the connection is rejected.

    method ClientConnect {id buffer} {
        # FIRST, get the logical name.
        set buffer [lindex $buffer 0]
        
        if {[lindex $buffer 0] ne "connect"} {
            error "protocol error: expected 'connect <name>', got '$buffer'"
        }
        
        set name [lindex $buffer 1]

        if {$name eq ""} {
            set name [join $id _]
        }

        # NEXT, do we already have a connection from a client with
        # this name?
        if {[info exists info(id-$name)]} {
            # TBD: will the TCP/IP timeout cause erroneous refusals?
            error "client already connected with name '$name'"
        }

        # NEXT, get the IP address from the ID.  comm(n) IDs are one or
        # two tokens.  The first is a TCP/IP port; the second, if present,
        # is the host: a plain host name, a fully qualified domain name,
        # or an IP address.  We will standardize on IP addresses.

        if {[llength $id] == 1} {
            set ip "localhost"
        } else {
            set ip [lindex $id 1]
        }

        # NEXT, validate the client
        set cmd $options(-validatecmd)
        lappend cmd $name $ip

        if {[catch $cmd result]} {
            $self Log warning "Refused connection: '$name' at id <$id>"
            error $result
        }

        # NEXT, it's valid: save the data
        lappend info(ids)    $id
        lappend info(names)  $name
         
        set info(id-$name)   $id
        set info(name-$id)   $name
        set info(ip-$id)     $ip
        set info(time-$name) [clock seconds] 
        set info(stat-$name) "connected"

        $self Log detail "Connect: '$name' at id <$id>"

        callwith $options(-connectcmd) $name $ip
    }
    

    # ClientDisconnect id
    #
    # id          The comm(n) ID of an attached console.
    #
    # Called when the specified console disconnects.

    method ClientDisconnect {id} {
        if {![info exists info(name-$id)]} {
            # A client that's refused still has to disconnect.  We
            # haven't saved its info, so we should ignore it.
            return
        }

        $self Log detail "Disconnect: '$info(name-$id)' at <$id>"

        set name $info(name-$id)

        ldelete info(ids) $id
        ldelete info(names) $name

        unset info(id-$name)
        unset info(name-$id)
        unset info(ip-$id)

        set info(time-$name) [clock seconds] 
        set info(stat-$name) "disconnected"
    }

    #-------------------------------------------------------------------
    # Public methods

    # listen
    #
    # Opens the socket and begins to listen

    method listen {} {
        if {$options(-allowremote)} {
            set localFlag 0
        } else {
            set localFlag 1
        }

        if {[catch {
            $comm config -port $options(-port) -local $localFlag
        } result]} {
            # Throw a better error.
            error "Could not initialize $comm: $result"
        }

        # Prepare to receive commands from clients
        $comm hook eval \
            [format {
                set code [catch {%s ClientEval $id $buffer} result]
            
                if {$code} {
                    return [list error $result]
                } else {
                    return [list ok $result]
                }
            } $self]

        # Prepare to receive disconnects
        $comm hook lost [format {
            # Errors in this hook are swallowed; explicitly pass
            # them to bgerror so that they get logged.
            if {[catch {%s ClientDisconnect $id} result]} {
                bgerror $result
            }
        } $self]

        $self Log detail "listening"
    }

    # broadcast script
    #
    # script     A client update script
    #
    # Sends the script to all attached clients asynchronously;
    # the response is ignored.

    method broadcast {script} {
        $self Log debug "Broadcast: $script"
        foreach id $info(ids) {
            if {[catch {$comm send -async $id $script} result]} {
                $self Log detail "Error sending to <$id>: $result"
                
                # There's likely a disconnect further back in the queue
                # so just handle it now.
                if {[regexp "connection reset by peer" $result] ||
                    [regexp "broken pipe" $result]
                } {
                    catch {$self ClientDisconnect $id}
                }
            }
        }
    }

    # send name script
    #
    # name       A client logical name
    # script     A client update script
    #
    # Sends the script to the specified client asynchronously;
    # the response is ignored.

    method send {name script} {
        $self Log debug "Update client $name: $script"

        require {[info exists info(id-$name)]} "Unknown client name: '$name'"
        $comm send -async $info(id-$name) $script
    }

    # clientid
    #
    # While a client command is being evaluated, this method returns
    # the client's ID.
    
    method clientid {} {
        return $currentClient
    }

    # clientname
    #
    # While a client command is being evaluated, this method returns
    # the client's logical name
    
    method clientname {} {
        if {$currentClient ne ""} {
            return $info(name-$currentClient)
        } else {
            return ""
        }
    }

    # clients
    #
    # Returns a list of the logical names of all connected clients.
    
    method clients {} {
        return $info(names)
    }

    # clientStatus
    # 
    # name       A client logical name
    #  
    # Returns the client's connection status; connected or disconnected.
    
    method clientStatus {name} {
        if {[info exists info(stat-$name)]} {
            return $info(stat-$name)
        } else {
            return "disconnected"
        }
    }

    # clientTime
    # 
    # name       A client logical name
    #  
    # Returns the connection time of the client if connected, 0 if not.
    
    method clientTime {name} {
        if {[info exists info(time-$name)]} {
            return $info(time-$name)
        } else {
            return 0
        }
    }
}





