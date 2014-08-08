#-----------------------------------------------------------------------
# TITLE:
#   commclient.tcl
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
#   marsutil(n) Comm Client
#
#   This object connects to a commserver(n).  It can send commands
#   and receive responses to them, and it can receive and process
#   update commands from the server.
#
#   The creator must specify the port ID, a logger(n) object for
#   logging, a log component name, and aliases for any update commands
#   it expects to receive.
#
#   See also commserver(n).
#
#-----------------------------------------------------------------------

namespace eval ::marsutil:: {
    namespace export commclient
}

snit::type ::marsutil::commclient {
    #-------------------------------------------------------------------
    # Components

    component comm           ;# The comm(n) channel
    component interp         ;# The interpreter for handling updates.
    component log            ;# The logger(n) object.
    component retryer        ;# Retry timeout
    component pinger         ;# Ping timeout

    #-------------------------------------------------------------------
    # Options

    delegate option -retrymsecs to retryer as -interval
    delegate option -pingmsecs to pinger as -interval

    # -clientname
    #
    # The logical name of this client.  Needed only if the server
    # implements validation on client name.
    
    option -clientname -default "" -readonly 1

    # -portid
    #
    # The port of the commserver(n) object to which this client will
    # connect.

    option -portid -default 10001 -readonly 1

    # -hostip
    #
    # The IP address of the host to which this client will connect,
    # or "" for the local host.

    option -hostip -default "" -readonly 1

    # -logger
    #
    # Passes in logger(n) component.
    
    option -logger -readonly 1

    # -logcomponent
    #
    # String used for "component" argument to the logger.
    
    option -logcomponent -default "commclient"

    # -connectcmd
    #
    # When the connection is established, -connectcmd will be called
    # with no additional arguments.

    option -connectcmd -default ""

    # -disconnectcmd
    #
    # When the connection is lost, or fails to be established on the
    # initial connect attempt, -disconnectcmd will be called
    # with no additional arguments.

    option -disconnectcmd -default ""

    # -refusedcmd
    #
    # When the connection is refused, -refusedcmd will be called
    # with one additional argument, the refusal error message.

    option -refusedcmd -default ""

    # -bgerrorcmd
    #
    # When a bgsend results in an error, this command is called with
    # two additional arguments, the command sent and the returned
    # error message.

    option -bgerrorcmd -default ""


    #-------------------------------------------------------------------
    # Instance Variables

    # The server's comm ID
    variable serverID ""

    # The connection status: NOT_CONNECTED, CONNECTING, CONNECTED
    variable connectionStatus NOT_CONNECTED

    # Tracks whether we're getting recursive updates
    variable levelCounter 0

    # Queue of update commands
    variable updateQueue {}

    # 1 if there's a HandleUpdate call scheduled, and 0 otherwise.
    variable updateScheduled 0

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the timeouts; name them so that they'll be
        # destroyed automatically.
        install retryer using timeout ${selfns}::retryer \
            -command [mymethod TryToConnect]             \
            -interval 500

        install pinger using timeout ${selfns}::pinger \
            -command [mymethod Ping]                   \
            -interval 5000                             \
            -repetition 1

        # NEXT, Handle the options after creating the timeouts, so
        # that options can be delegated.
        $self configurelist $args

        # NEXT, check requirements
        set log $options(-logger)

        require {[info commands $log] ne ""} "-log is not defined."


        # Create the interpreter
        install interp using interp create -safe

        # Create a new comm(n) channel, and configure it.
        #
        # Note: the -listen 1 is required in order for this
        # to work; all clients on the machine with -listen 0
        # share port 0, with bad results.
        
        set comm [::comm::comm new ${selfns}::commchan -listen 1]

        # Prepare to handle the return protocol.
        $comm hook reply {
            set return(-code) [lindex $ret 0]
            set ret [lindex $ret 1]
        }

        # Prepare to handle updates.
        $comm hook eval \
            [format {
                return [%s QueueUpdate $id $buffer]
            } $self]

        $self Log normal "Initialized."
    }

    # Destructor is not needed.

    #-------------------------------------------------------------------
    # Private Methods

    # Log severity message
    #
    # severity         A logger(n) severity level
    # message          The message text.

    method Log {severity message} {
        $log $severity $options(-logcomponent) $message
    }

    # QueueUpdate id buffer
    #
    # id       The id of the sender
    # buffer   The script sent.
    #
    # Receives update commands from commserver(n).  For each command,
    #
    # * Add the command to the updateQueue
    # * If necessary, schedule an after handler to process it.
    #
    # NOTE: Originally, this routine actually processed the command
    # itself.  This seemed to work OK, but eventually led to difficulties.
    # If the update command re-entered the event loop, then another 
    # update could be received and this method could be called recursively.
    # If the call stack got too deep, a mysterious error was thrown,
    # "too many nested evaluations (infinite loop?)"; figuring out what
    # the trouble was took a LONG time.

    method QueueUpdate {id buffer} {
        if {$id != $serverID} {
            $self Log warning "Ignoring command from comm(n) ID $id."
            
            # Ignore it.
            return
        }

        # Queue the update command.
        lappend updateQueue [lindex $buffer 0]

        # If there's no scheduled update handler, schedule one.
        if {!$updateScheduled} {
            set updateScheduled 1
            after 1 [mymethod HandleUpdate]
        }
    }

    # HandleUpdate
    #
    # Handles one queued update, and re-schedules itself if there 
    # are additional updates.

    method HandleUpdate {} {
        # FIRST, if there are no queued updates we shouldn't be here.
        # (This should never happen.)
        if {[llength $updateQueue] == 0} {
            puts "Wasted HandleUpdate call!"
            return
        }

        # NEXT, Dequeue the next command.
        set cmd [lindex $updateQueue 0]
        set updateQueue [lrange $updateQueue 1 end]

        # NEXT, Evaluate the command, and log any errors.
        # Note that the update queue might grow during this time.
        set code [catch {$interp eval $cmd} result]

        if {$code} {
            # There shouldn't be any update errors.
            $self Log warning \
                "Update error: $result\nCommand: $cmd\n$::errorInfo"
        }

        # NEXT, if there are any more updates to process, then reschedule.
        # Otherwise note that no handler is scheduled.
        if {[llength $updateQueue] > 0} {
            after 0 [mymethod HandleUpdate]
        } else {
            set updateScheduled 0
        }
    }
    

    # TryToConnect
    #
    # Tries to connect to the server.  On success, the connected status
    # is set; on failure, it is cleared and a retry is scheduled.

    method TryToConnect {} {
        # FIRST, If we're already trying to connect, don't bother.
        if {$connectionStatus ne "NOT_CONNECTED"} {
            $self Log warning "TryToConnect when $connectionStatus"
            return
        }

        # NEXT, we're trying to connect.
        set connectionStatus CONNECTING

        # NEXT, send the connection script, catching any error.  If
        # there's no error, we're connected.  If there's an error and
        # it doesn't indicate a lack of connection, we're OK.
        set connectScript [list connect $options(-clientname)]

        if {[catch {$self send $connectScript} result]} {
            if {![string match "lost connection" $result]} {
                set msg "Connection refused: $result"
                $self Log warning $msg

                if {$options(-refusedcmd) ne ""} {
                    # If they've got a refused callback, then it can
                    # decide what to do: halt the app, or keep trying.
                    callwith $options(-refusedcmd) $result

                    # They didn't halt, so we want to retry.

                    # FIRST, we aren't connected .
                    set connectionStatus "NOT_CONNECTED"

                    # NEXT, cancel any schedule ping, and 
                    # schedule a reconnection attempt.
                    $pinger cancel
                    $retryer schedule -nocomplain
                } else {
                    set connectionStatus REFUSED
                    error $msg
                }
            }
        } else {
            $self Log normal "connected"

            if {$options(-connectcmd) ne ""} {
                uplevel \#0 $options(-connectcmd)
            }

            # Ping the client
            $pinger schedule -nocomplain
        }
    }

    # Ping
    #
    # Pings the server by sending "".

    method Ping {} {
        if {$connectionStatus eq "CONNECTED"} {
            if {[catch {$self send ""} result]} {
                $self Log warning $result
            }
        }
    }


    #-------------------------------------------------------------------
    # Public methods

    # Methods delegated to the slave interpreter
    delegate method alias to interp

    # Methods delegated to the comm channel
    delegate method id to comm as self

    # connect
    #
    # Directs the client to connect to the server.  If an error is thrown
    # and indicates that there is no commserver, the script is retried
    # every -retrymsecs until the connection is made.  If any other error
    # is thrown, it is passed along to the caller.

    method connect {} {
        if {$connectionStatus ne "NOT_CONNECTED"} {
            error "client is already connected to the server"
        }

        set serverID $options(-portid)

        if {$options(-hostip) ne ""} {
            lappend serverID $options(-hostip)
        }

        $self TryToConnect
    }

    # send script
    #
    # Sends the script to the commserver for execution.  Returns the
    # return value of script execution; if the script throws an error
    # in the server, this command will throw the same error.

    method send {script} {
        if {$connectionStatus eq "NOT_CONNECTED"} {
            error "client is not connected to the server" "" NOT_CONNECTED
        }

        $self Log debug "Sent: $script"
        if {[catch {$comm send $serverID $script} result]} {
            set oldStatus $connectionStatus

            if {[string match "Connect to remote failed:*" $result] ||
                [string match "target application died*" $result]   ||
                [string match "protocol error*" $result]} {

                # FIRST, we aren't connected anymore.
                set connectionStatus "NOT_CONNECTED"

                # NEXT, cancel any schedule ping, and 
                # schedule a reconnection attempt.
                $pinger cancel
                $retryer schedule -nocomplain

                # NEXT, if we lost the connection, 
                # call the disconnect command, if any.  (I.e., don't
                # call it for failed connection attempts.
                if {$oldStatus eq "CONNECTED" &&
                    $options(-disconnectcmd) ne ""} {
                    uplevel \#0 $options(-disconnectcmd)
                }
                error "lost connection"
            } else {
                set connectionStatus "CONNECTED"
                error "$result"
            }
        }

        set connectionStatus "CONNECTED"
        return $result
    }

    # bgsend script
    #
    # Sends the script to the commserver for execution.  Returns the
    # return value of script execution.  If the script throws an error
    # in the server, this command will log the error, and call
    # -bgerrorcmd (if any).

    method bgsend {script} {
        $self Log normal "Sent: $script"

        if {[catch {$self send $script} result]} {
            if {$options(-bgerrorcmd) ne ""} {
                callwith $options(-bgerrorcmd) $script $result
            } else {
                $self Log warning $result
            }
        } else {
            return $result
        }
    }
}






