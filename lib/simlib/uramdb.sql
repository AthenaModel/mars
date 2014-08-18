------------------------------------------------------------------------
-- TITLE: 
--   uramdb.sql
--
-- PACKAGE:
--   simlib(n) -- Simulation Infrastructure Package
--
-- PROJECT:
--   Mars Simulation Infrastructure Library
--
-- AUTHOR:
--   Will Duquette
--
-- DESCRIPTION:
--   SQL Schema for the uramdb(n) module.
--
------------------------------------------------------------------------


CREATE TABLE uramdb_c (
    -- Concern names
    c    TEXT PRIMARY KEY          -- Symbolic name
);

CREATE TABLE uramdb_a (
    -- Actor names
    a    TEXT PRIMARY KEY          -- Symbolic name
);

CREATE TABLE uramdb_n (
    -- Neighborhood names
    n    TEXT PRIMARY KEY          -- Symbolic name
);

CREATE TABLE uramdb_g (
    -- FRC group names and data
    g     TEXT PRIMARY KEY,        -- Symbolic group name
    gtype TEXT                     -- CIV, FRC, ORG   
);

CREATE TABLE uramdb_civ_g (
    -- CIV group names and data
    g    TEXT PRIMARY KEY,         -- Symbolic group name
    n    TEXT,                     -- Nbhood of reference
    pop  INTEGER DEFAULT 0 
);

CREATE TABLE uramdb_frc_g (
    -- FRC group names and data
    g    TEXT PRIMARY KEY          -- Symbolic group name
);

CREATE TABLE uramdb_org_g (
    -- ORG group names and data
    g    TEXT PRIMARY KEY          -- Symbolic group name
);


CREATE TABLE uramdb_mn (
    -- Pairwise neighborhood data
    m          TEXT,                     -- Symbolic nbhood name
    n          TEXT,                     -- Symbolic nbhood name

    proximity  TEXT DEFAULT 'REMOTE',    -- eproximity
    
    PRIMARY KEY (m, n)
);

CREATE TABLE uramdb_hrel (
    -- HREL: group-to-group horizontal relationships
    f      TEXT,                     -- Symbolic group name
    g      TEXT,                     -- Symbolic group name

    hrel   DOUBLE DEFAULT 0.0,       -- Horizontal relationship
    
    PRIMARY KEY (f, g)
);

CREATE TABLE uramdb_vrel (
    -- VREL: group-to-actor vertical relationships
    g      TEXT,                     -- Symbolic group name
    a      TEXT,                     -- Symbolic actor name

    vrel   DOUBLE DEFAULT 0.0,       -- Vertical relationship
    
    PRIMARY KEY (g, a)
);


CREATE TABLE uramdb_sat (
    -- SAT: Satisfaction levels
    g          TEXT,                     -- Symbolic group name
    c          TEXT,                     -- Symbolic concern name

    sat        DOUBLE DEFAULT 0.0,       -- Initial satisfaction
    saliency   DOUBLE DEFAULT 1.0,       -- Saliency

    PRIMARY KEY (g, c)
);

CREATE TABLE uramdb_coop (
    -- COOP: CIV group cooperation with FRC group
    f        TEXT,                     -- Symbolic group name
    g        TEXT,                     -- Symbolic group name

    coop     DOUBLE DEFAULT 50.0,      -- Cooperation
    
    PRIMARY KEY (f, g)
);

