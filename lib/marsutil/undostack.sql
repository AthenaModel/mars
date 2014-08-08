------------------------------------------------------------------------
-- FILE: undostack.sql
--
-- SQL Schema for the undostack(n) module.
--
-- PACKAGE:
--    marsutil(n) -- Utility Package
--
-- PROJECT:
--    Mars Simulation Infrastructure Library
--
-- AUTHOR:
--    Will Duquette
--
------------------------------------------------------------------------

CREATE TABLE undostack_stack (
    -- undostack(n) undo stack table.  Operations are undone in 
    -- reverse order, back to the previous mark.  The script is
    -- a Tcl script that undoes the operation.  For explicitly
    -- inserted marks, the script will be NULL.

    id     INTEGER PRIMARY KEY,  -- Unique undo script ID
    tag    TEXT,                 -- Tag for undostack instance

    mark   INTEGER DEFAULT 0,    -- Added by "edit mark" or -automarks
    script TEXT,                 -- Undo script, or NULL

    UNIQUE (tag, id)
);
