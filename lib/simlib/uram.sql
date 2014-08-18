------------------------------------------------------------------------
-- TITLE: 
--   uram.sql
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
--   SQL Schema for the uram(n) module.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Conventions
--
-- Clients refer to entities using a unique name; URAM uses a unique
-- integer for speed.  The name column uses the index variable name
-- used in mathematical models, i.e., actor variables use the "a" 
-- subscript.  The unique ID is the index variable name plus "_id", e.g.,
-- "a_id".  The index variable name usually appears in the table name
-- as well.
--
-- Tables keyed on multiple entities have a unique record ID, plus 
-- foreign key links to the entity tables.  For example, the uram_mn table
-- contains pairwise neighborhood data.  It has a unique record ID as its
-- key, called "mn_id"; it also has "m_id" and "n_id" columns that link to
-- the uram_n table.
--
-- Tables which relate to curves managed by URAM have a unique record ID
-- plus entity links, as just described; they also have a curve_id field
-- that relates to a ucurve(n) curves.
--
-- Tables that link to data from a number of other tables will often have
-- views associated with them; in this case the table and the view will
-- have the same name, with the table name have a "_t" suffix, e.g.,
-- "uram_sat" and "uram_sat_t".


------------------------------------------------------------------------
-- Entity data
--
-- Tables in this section define the entities (actors, nbhoods, groups)
-- known to URAM, including pairwise data EXCEPT for curves managed by
-- ucurve(n).

CREATE TABLE uram_cause (
    -- Cause names known to URAM
    cause_id INTEGER PRIMARY KEY,   -- URAM unique cause ID
    cause    TEXT UNIQUE            -- Application name
);

CREATE TABLE uram_a (
    -- Actors known to URAM
    a_id    INTEGER PRIMARY KEY,   -- URAM unique actor ID
    a       TEXT UNIQUE            -- Application name
);

CREATE TABLE uram_n (
    -- Neighborhoods known to URAM
    n_id         INTEGER PRIMARY KEY, -- URAM unique nbhood ID
    n            TEXT UNIQUE,         -- Application name

    -- Outputs
    pop          INTEGER DEFAULT 0.0, -- Neighborhood population
    nbmood_denom DOUBLE DEFAULT 0.0,  -- Denominator for nbmood
    nbmood       DOUBLE DEFAULT 0.0,  -- Current neighborhood mood
    nbmood0      DOUBLE DEFAULT 0.0   -- Initial neighborhood mood
);

CREATE TABLE uram_mn (
    -- Pairwise neighborhood data

    mn_id     INTEGER PRIMARY KEY,      -- URAM Unique record ID
    m_id      INTEGER                   -- URAM unique nbhood ID
              REFERENCES uram_n(n_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    n_id      INTEGER                   -- URAM unique nbhood ID
              REFERENCES uram_n(n_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    -- Proximity of nbhood m to nbhood n from the point of view of 
    -- residents of m.
    --  0 if m is "here"
    --  1 if m is "near" n
    --  2 if m is "far" from n
    --  3 if m is "remote" from n
    proximity INTEGER,

    UNIQUE (m_id, n_id)    -- Provides constraint and fast index
);

CREATE TABLE uram_g (
    -- All groups known to URAM, by group type
    g_id    INTEGER PRIMARY KEY,   -- URAM unique group ID
    g       TEXT UNIQUE,           -- Application name
    gtype   TEXT                   -- Group type: CIV, FRC, ORG
);


CREATE TABLE uram_civ_g (
    -- Data specific to civilian groups
    g_id       INTEGER PRIMARY KEY              -- URAM unique group ID
               REFERENCES uram_g(g_id)
               ON DELETE CASCADE
               DEFERRABLE INITIALLY DEFERRED,

    -- Neighborhood in which g resides
    n_id       INTEGER REFERENCES uram_n(n_id)  -- URAM unique nbhood ID
               ON DELETE CASCADE
               DEFERRABLE INITIALLY DEFERRED,

    pop        INTEGER,                         -- g's population

    -- Outputs
    mood_denom DOUBLE DEFAULT 0.0,              -- Mood denominator
    mood       DOUBLE DEFAULT 0.0,              -- Current group mood
    mood0      DOUBLE DEFAULT 0.0               -- Initial group mood
);

-- View for retrieving group mood
CREATE VIEW uram_mood AS
SELECT g_id, g, mood_denom, mood, mood0
FROM uram_g JOIN uram_civ_g USING (g_id);

CREATE TABLE uram_c (
    -- Concerns used by URAM.  (Populated automatically by URAM)
    c_id   INTEGER PRIMARY KEY,  -- URAM unique concern ID
    c      TEXT UNIQUE           -- AUT, CUL, QOL, SFT
);

CREATE TABLE uram_civrel_t (
    -- Civilian group relationship table: for groups f and g, contains
    -- the proximity of f to g and a link to the HREL of f with g.
    -- Proximity is computed from neighborhood proximities.
    -- Used when computing COOP spread.

    fg_id     INTEGER PRIMARY KEY,            -- URAM unique FG record ID
    f_id      INTEGER,                        -- URAM unique group ID
    g_id      INTEGER,                        -- URAM unique group ID
    hrel_id   INTEGER UNIQUE,                 -- HREL curve_id

    proximity INTEGER,                        -- As in uram_mn, with -1 if
                                              -- f=g.

    UNIQUE (f_id, g_id)                       -- Constraint, fast index
);

-- View linking uram_civrel_t with ucurve_curves_t
CREATE VIEW uram_civrel AS
SELECT R.fg_id             AS fg_id,
       R.f_id              AS f_id,
       R.g_id              AS g_id,
       R.proximity         AS proximity,
       C.a                 AS hrel,
       C.tracked           AS tracked
FROM uram_civrel_t AS R
JOIN ucurve_curves_t AS C ON (C.curve_id = R.hrel_id);

CREATE TABLE uram_frcrel_t (
    -- Force group relationship table: for groups f and g, contains
    -- a link to the HREL of f with g. Proximity is computed from 
    -- neighborhood proximities.
    -- Used when computing COOP spread.

    fg_id     INTEGER PRIMARY KEY,            -- URAM unique FG record ID
    f_id      INTEGER,                        -- URAM unique group ID
    g_id      INTEGER,                        -- URAM unique group ID

    hrel_id   INTEGER UNIQUE,                 -- HREL curve_id

    UNIQUE (f_id, g_id)                       -- Constraint, fast index
);

CREATE VIEW uram_frcrel AS
SELECT R.fg_id             AS fg_id,
       R.f_id              AS f_id,
       R.g_id              AS g_id,
       C.a                 AS hrel
FROM uram_frcrel_t AS R
JOIN ucurve_curves_t AS C ON (C.curve_id = R.hrel_id);

------------------------------------------------------------------------
-- Horizontal Relationship Curves

CREATE TABLE uram_hrel_t (
    -- HREL table: Horizontal relationship curves between all pairs
    -- of groups f,g.  Relationships between groups need not be 
    -- symmetric; values in the table are from group f's point of view.

    fg_id     INTEGER PRIMARY KEY,            -- URAM unique FG record ID
    f_id      INTEGER                         -- URAM unique group ID
              REFERENCES uram_g(g_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,
    g_id      INTEGER                         -- URAM unique group ID
              REFERENCES uram_g(g_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    curve_id  INTEGER UNIQUE,                 -- ucurve(n) curve ID

    UNIQUE (f_id, g_id)                       -- Constraint, fast index
);

-- uram_hrel view; links uram_hrel_t with other tables.
CREATE VIEW uram_hrel AS
SELECT HREL.fg_id      AS fg_id,
       HREL.f_id       AS f_id,
       HREL.g_id       AS g_id,
       F.g             AS f,
       G.g             AS g,
       HREL.curve_id   AS curve_id,
       CRV.a0          AS hrel0,
       CRV.a           AS hrel,
       CRV.a           AS avalue,
       CRV.b           AS bvalue,
       CRV.c           AS cvalue,
       CRV.a0          AS avalue0,
       CRV.b0          AS bvalue0,
       CRV.c0          AS cvalue0,
       CRV.tracked     AS tracked
FROM uram_hrel_t       AS HREL 
JOIN ucurve_curves_t   AS CRV  USING (curve_id)
JOIN uram_g            AS F    ON    (HREL.f_id = F.g_id)
JOIN uram_g            AS G    ON    (HREL.g_id = G.g_id);

-- uram_hrel_effects; links uram_hrel_t with the ucurve effects
CREATE VIEW uram_hrel_effects AS
SELECT ATT.fg_id                           AS fg_id,
       ATT.f_id                            AS f_id,
       ATT.g_id                            AS g_id,
       ATT.f                               AS f,
       ATT.g                               AS g,
       ATT.curve_id                        AS curve_id,
       ATT.avalue0                         AS hrel0,
       ATT.avalue                          AS hrel,
       EFF.e_id                            AS e_id,
       EFF.driver_id                       AS driver_id,
       EFF.cause_id                        AS cause_id,
       coalesce(CAUSE.cause, EFF.cause_id) AS cause,
       EFF.pflag                           AS pflag,
       EFF.mag                             AS mag
FROM uram_hrel             AS ATT
JOIN ucurve_effects_t      AS EFF USING (curve_id)
LEFT OUTER JOIN uram_cause AS CAUSE ON (CAUSE.cause_id == EFF.cause_id);

-- uram_hrel_adjustments; links uram_hrel_t with the ucurve adjustments
CREATE VIEW uram_hrel_adjustments AS
SELECT ATT.fg_id           AS fg_id,
       ATT.f_id            AS f_id,
       ATT.g_id            AS g_id,
       ATT.f               AS f,
       ATT.g               AS g,
       ATT.curve_id        AS curve_id,
       ATT.avalue0         AS hrel0,
       ATT.avalue          AS hrel,
       ADJ.a_id            AS adj_id,
       ADJ.driver_id       AS driver_id,
       ADJ.delta           AS delta
FROM uram_hrel             AS ATT
JOIN ucurve_adjustments_t  AS ADJ USING (curve_id);


------------------------------------------------------------------------
-- Vertical Relationship Curves

CREATE TABLE uram_vrel_t (
    -- VREL table: Vertical relationship curves between all  
    -- groups g and actors a.

    ga_id     INTEGER PRIMARY KEY,            -- URAM unique record ID
    g_id      INTEGER                         -- URAM unique group ID
              REFERENCES uram_g(g_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,
    a_id      INTEGER                         -- URAM unique actor ID
              REFERENCES uram_a(a_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    curve_id  INTEGER UNIQUE,                 -- ucurve(n) curve ID

    UNIQUE (g_id, a_id)                       -- Constraint, fast index
);

-- uram_vrel view; links uram_vrel_t with other tables.
CREATE VIEW uram_vrel AS
SELECT VREL.ga_id      AS ga_id,
       VREL.g_id       AS g_id,
       VREL.a_id       AS a_id,
       G.g             AS g,
       A.a             AS a,
       VREL.curve_id   AS curve_id,
       CRV.a0          AS vrel0,
       CRV.a           AS vrel,
       CRV.a           AS avalue,
       CRV.b           AS bvalue,
       CRV.c           AS cvalue,
       CRV.a0          AS avalue0,
       CRV.b0          AS bvalue0,
       CRV.c0          AS cvalue0,
       CRV.tracked     AS tracked
FROM uram_vrel_t       AS VREL 
JOIN ucurve_curves_t   AS CRV  USING (curve_id)
JOIN uram_g            AS G    ON    (VREL.g_id = G.g_id)
JOIN uram_a            AS A    ON    (VREL.a_id = A.a_id);

-- uram_vrel_effects; links uram_vrel_t with the ucurve effects
CREATE VIEW uram_vrel_effects AS
SELECT ATT.ga_id                           AS ga_id,
       ATT.g_id                            AS g_id,
       ATT.a_id                            AS a_id,
       ATT.g                               AS g,
       ATT.a                               AS a,
       ATT.curve_id                        AS curve_id,
       ATT.avalue0                         AS vrel0,
       ATT.avalue                          AS vrel,
       EFF.e_id                            AS e_id,
       EFF.driver_id                       AS driver_id,
       EFF.cause_id                        AS cause_id,
       coalesce(CAUSE.cause, EFF.cause_id) AS cause,
       EFF.pflag                           AS pflag,
       EFF.mag                             AS mag
FROM uram_vrel             AS ATT
JOIN ucurve_effects_t      AS EFF USING (curve_id)
LEFT OUTER JOIN uram_cause AS CAUSE ON (CAUSE.cause_id == EFF.cause_id);

-- uram_vrel_adjustments; links uram_vrel_t with the ucurve adjustments
CREATE VIEW uram_vrel_adjustments AS
SELECT ATT.ga_id           AS ga_id,
       ATT.g_id            AS g_id,
       ATT.a_id            AS a_id,
       ATT.g               AS g,
       ATT.a               AS a,
       ATT.curve_id        AS curve_id,
       ATT.avalue0         AS vrel0,
       ATT.avalue          AS vrel,
       ADJ.a_id            AS adj_id,
       ADJ.driver_id       AS driver_id,
       ADJ.delta           AS delta
FROM uram_vrel             AS ATT
JOIN ucurve_adjustments_t  AS ADJ USING (curve_id);

--------------------------------------------------------------------------------
-- Satisfaction Curves

CREATE TABLE uram_sat_t (
    -- AUT/CUL/QOL/SFT table: Satisfaction of civilian group g with
    -- concern c.

    gc_id     INTEGER PRIMARY KEY,               -- URAM unique record ID
    g_id      INTEGER                            -- URAM unique group ID
              REFERENCES uram_civ_g(g_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,
    c_id      INTEGER                            -- URAM unique concern ID
              REFERENCES uram_c(c_id)  
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    curve_id  INTEGER UNIQUE,                    -- ucurve(n) curve ID

    saliency  DOUBLE DEFAULT 1.0,       -- Saliency, 0.0 to 1.0, of c to g.

    UNIQUE (g_id, c_id)                          -- Constraint, fast index
);

-- uram_sat view; links uram_sat_t with other tables.
CREATE VIEW uram_sat AS
SELECT SAT.gc_id       AS gc_id,
       SAT.g_id        AS g_id,
       SAT.c_id        AS c_id,
       G.g             AS g,
       CG.n_id         AS n_id,
       CG.pop          AS pop,
       C.c             AS c,
       SAT.saliency    AS saliency,
       SAT.curve_id    AS curve_id,
       CRV.a0          AS sat0,
       CRV.a           AS sat,
       CRV.a           AS avalue,
       CRV.b           AS bvalue,
       CRV.c           AS cvalue,
       CRV.a0          AS avalue0,
       CRV.b0          AS bvalue0,
       CRV.c0          AS cvalue0,
       CRV.tracked     AS tracked
FROM uram_sat_t        AS SAT
JOIN ucurve_curves_t   AS CRV USING (curve_id)
JOIN uram_g            AS G   ON    (SAT.g_id = G.g_id)
JOIN uram_c            AS C   ON    (SAT.c_id = C.c_id)
JOIN uram_civ_g        AS CG  ON    (SAT.g_id = CG.g_id);

-- uram_sat_effects; links uram_sat_t with the ucurve effects
CREATE VIEW uram_sat_effects AS
SELECT ATT.gc_id                           AS gc_id,
       ATT.g_id                            AS g_id,
       ATT.c_id                            AS c_id,
       ATT.g                               AS g,
       ATT.c                               AS c,
       ATT.curve_id                        AS curve_id,
       ATT.avalue0                         AS sat0,
       ATT.avalue                          AS sat,
       EFF.e_id                            AS e_id,
       EFF.driver_id                       AS driver_id,
       EFF.cause_id                        AS cause_id,
       coalesce(CAUSE.cause, EFF.cause_id) AS cause,
       EFF.pflag                           AS pflag,
       EFF.mag                             AS mag
FROM uram_sat              AS ATT
JOIN ucurve_effects_t      AS EFF USING (curve_id)
LEFT OUTER JOIN uram_cause AS CAUSE ON (CAUSE.cause_id == EFF.cause_id);

-- uram_sat_adjustments; links uram_sat_t with the ucurve adjustments
CREATE VIEW uram_sat_adjustments AS
SELECT ATT.gc_id           AS gc_id,
       ATT.g_id            AS g_id,
       ATT.c_id            AS c_id,
       ATT.g               AS g,
       ATT.c               AS c,
       ATT.curve_id        AS curve_id,
       ATT.avalue0         AS sat0,
       ATT.avalue          AS sat,
       ADJ.a_id            AS adj_id,
       ADJ.driver_id       AS driver_id,
       ADJ.delta           AS delta
FROM uram_sat              AS ATT
JOIN ucurve_adjustments_t  AS ADJ USING (curve_id);

------------------------------------------------------------------------
-- Cooperation Curves

CREATE TABLE uram_coop_t (
    -- COOP table: Cooperation curves between all civilian groups f
    -- and force groups g.

    fg_id     INTEGER PRIMARY KEY,            -- URAM unique FG record ID
    f_id      INTEGER                         -- URAM unique group ID
              REFERENCES uram_g(g_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,
    g_id      INTEGER                         -- URAM unique group ID
              REFERENCES uram_g(g_id)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    curve_id  INTEGER UNIQUE,                 -- ucurve(n) curve ID

    UNIQUE (f_id, g_id)                       -- Constraint, fast index
);

-- uram_coop view; links uram_coop_t with other tables.

CREATE VIEW uram_coop AS
SELECT COOP.fg_id      AS fg_id,
       COOP.f_id       AS f_id,
       COOP.g_id       AS g_id,
       F.g             AS f,
       CF.n_id         AS n_id,
       CF.pop          AS pop,
       G.g             AS g,
       COOP.curve_id   AS curve_id,
       CRV.a0          AS coop0,
       CRV.a           AS coop,
       CRV.a           AS avalue,
       CRV.b           AS bvalue,
       CRV.c           AS cvalue,
       CRV.a0          AS avalue0,
       CRV.b0          AS bvalue0,
       CRV.c0          AS cvalue0,
       CRV.tracked     AS tracked
FROM uram_coop_t       AS COOP 
JOIN ucurve_curves_t   AS CRV  USING (curve_id)
JOIN uram_g            AS F    ON    (COOP.f_id = F.g_id)
JOIN uram_civ_g        AS CF   ON    (COOP.f_id = CF.g_id)
JOIN uram_g            AS G    ON    (COOP.g_id = G.g_id);

-- uram_coop_effects; links uram_coop_t with the ucurve effects
CREATE VIEW uram_coop_effects AS
SELECT ATT.fg_id                           AS fg_id,
       ATT.f_id                            AS f_id,
       ATT.g_id                            AS g_id,
       ATT.f                               AS f,
       ATT.g                               AS g,
       ATT.curve_id                        AS curve_id,
       ATT.avalue0                         AS coop0,
       ATT.avalue                          AS coop,
       EFF.e_id                            AS e_id,
       EFF.driver_id                       AS driver_id,
       EFF.cause_id                        AS cause_id,
       coalesce(CAUSE.cause, EFF.cause_id) AS cause,
       EFF.pflag                           AS pflag,
       EFF.mag                             AS mag
FROM uram_coop             AS ATT
JOIN ucurve_effects_t      AS EFF USING (curve_id)
LEFT OUTER JOIN uram_cause AS CAUSE ON (CAUSE.cause_id == EFF.cause_id);

-- uram_coop_adjustments; links uram_coop_t with the ucurve adjustments
CREATE VIEW uram_coop_adjustments AS
SELECT ATT.fg_id           AS fg_id,
       ATT.f_id            AS f_id,
       ATT.g_id            AS g_id,
       ATT.f               AS f,
       ATT.g               AS g,
       ATT.curve_id        AS curve_id,
       ATT.avalue0         AS coop0,
       ATT.avalue          AS coop,
       ADJ.a_id            AS adj_id,
       ADJ.driver_id       AS driver_id,
       ADJ.delta           AS delta
FROM uram_coop             AS ATT
JOIN ucurve_adjustments_t  AS ADJ USING (curve_id);

-- uram_coop_spread
--
-- This view yields the values needed to compute cooperation spread.
-- Given an a civilian group df and force group dg, this view puts
-- together all pairs of civilian groups if and force groups ig, providing
-- the proximity and relationship between if and df and the relationship
-- between ig and dg, along with the COOP curve between if and ig.

CREATE VIEW uram_coop_spread AS
SELECT CREL.g_id      AS df_id,       -- Direct f
       CREL.f_id      AS if_id,       -- Indirect f
       CREL.proximity AS proximity,
       CREL.hrel      AS civrel,
       CREL.tracked   AS tracked,
       FREL.g_id      AS dg_id,       -- Direct g
       FREL.f_id      AS ig_id,       -- Indirect g
       FREL.hrel      AS factor,
       COOP.fg_id     AS ifg_id,
       COOP.curve_id  AS curve_id
FROM uram_civrel AS CREL
JOIN uram_frcrel AS FREL
JOIN uram_coop_t AS COOP ON (COOP.f_id = if_id AND COOP.g_id = ig_id);


------------------------------------------------------------------------
-- Output Tables
--
-- Some outputs appear in the tables above; tables devoted entirely to
-- storing outputs are defined here.

CREATE TABLE uram_nbcoop_t (
    -- Neighborhood cooperation
    ng_id        INTEGER PRIMARY KEY,            -- URAM Unique record ID
    n_id         INTEGER                         -- URAM unique nbhood ID
                 REFERENCES uram_n(n_id)
                 ON DELETE CASCADE
                 DEFERRABLE INITIALLY DEFERRED,
    g_id         INTEGER                         -- URAM unique group ID
                 REFERENCES uram_g(g_id)
                 ON DELETE CASCADE
                 DEFERRABLE INITIALLY DEFERRED,

    -- Outputs
    nbcoop       DOUBLE DEFAULT 0.0,  -- Current cooperation of n with g
    nbcoop0      DOUBLE DEFAULT 0.0,  -- Initial cooperation of n with g

    UNIQUE (n_id, g_id)               -- Constraint, fast index
);

CREATE VIEW uram_nbcoop  AS
SELECT COOP.ng_id        AS ng_id,
       COOP.n_id         AS n_id,
       COOP.g_id         AS g_id,
       N.n               AS n,
       G.g               AS g,
       COOP.nbcoop       AS nbcoop,
       COOP.nbcoop0      AS nbcoop0
FROM uram_nbcoop_t       AS COOP 
JOIN uram_n              AS N ON (COOP.n_id = N.n_id)
JOIN uram_g              AS G ON (COOP.g_id = G.g_id);

------------------------------------------------------------------------
-- History tables, required for rolling up historical contributions to
-- nbmood and nbcoop.

CREATE TABLE uram_civhist_t (
    -- Civilian history of civilian population figures over
    -- time, by group.

    t    INTEGER,   -- The timestamp, in ticks
    g_id INTEGER,   -- The group ID
    n_id INTEGER,   -- The group's neighborhood ID
    pop  INTEGER,   -- The number of people in the group at that time.

    PRIMARY KEY (t, g_id)
);

CREATE TABLE uram_nbhist_t (
    -- Civilian history of neighborhood civilian population figures over
    -- time, by neighborhood.

    t     INTEGER,       -- The timestamp, in ticks
    n_id  INTEGER,       -- The neighborhood ID
    pop   INTEGER,       -- The neighborhood's civilian population at 
                         -- the given time.
    nbmood_denom DOUBLE, -- The nbmood denominator for the neighborhood
                         -- at the given time.
    PRIMARY KEY (t, n_id)
);



