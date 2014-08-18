------------------------------------------------------------------------
-- TITLE: 
--   ucurve.sql
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
--   SQL Schema for the ucurve(n) module.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Curve Types

-- ucurve(n) curve types table.  Stores the attributes of each 
-- curve type.
CREATE TABLE ucurve_ctypes_t (
    --------------------------------------------------------------------
    -- Keys and Pointers

    -- Curve Type ID
    ct_id        INTEGER PRIMARY KEY,

    --------------------------------------------------------------------
    -- Data

    -- Short name for this specific curve type
    name          TEXT UNIQUE NOT NULL,

    min           DOUBLE NOT NULL
        CHECK (min = CAST (min AS real)),

    -- Maximum and minimum bounds for curves of this type.
    max           DOUBLE NOT NULL
        CHECK (max = CAST (max AS real)),

    -- Alpha and Gamma smoothing parameters (Beta is computed)
    alpha         DOUBLE DEFAULT 0.0
        CHECK (alpha = CAST (alpha AS real))
        CHECK (0.0 <= alpha AND alpha <= 1.0),

    gamma         DOUBLE DEFAULT 0.0
        CHECK (gamma = CAST (gamma AS real))
        CHECK (0.0 <= gamma AND gamma <= 1.0),

    -- Global constraints
    CHECK (min < max),
    CHECK (alpha + gamma <= 1.0)
);

-- ucurve(n) types view that provides computed values

CREATE VIEW ucurve_ctypes AS
SELECT *,
       1.0 - (alpha + gamma) AS beta
FROM ucurve_ctypes_t;

------------------------------------------------------------------------
-- Curves

-- ucurve(n) curves table.

CREATE TABLE ucurve_curves_t (
    --------------------------------------------------------------------
    -- Keys and Pointers

    -- Curve ID
    curve_id     INTEGER PRIMARY KEY,

    -- Curve Type ID
    ct_id        INTEGER REFERENCES ucurve_ctypes_t(ct_id)
                 ON DELETE CASCADE
                 DEFERRABLE INITIALLY DEFERRED,

    --------------------------------------------------------------------
    -- Data

    --  Are we tracking changes to this curve?
    tracked      INTEGER DEFAULT 1
        CHECK (tracked IN (0,1)),

    -- The current A.t, B.t, C.t, and DeltaA.t values

    a            DOUBLE
        CHECK (a = CAST (a AS real)),

    b            DOUBLE
        CHECK (b = CAST (b AS real)),

    c            DOUBLE
        CHECK (c = CAST (c AS real)),

    delta        DOUBLE DEFAULT 0.0,

    -- The current scale factors
    posfactor    DOUBLE DEFAULT 0.0,
    negfactor    DOUBLE DEFAULT 0.0,

    -- The Initial values for A.t, B.t, and C.t
    -- TBD: We might decide not to use these.
    a0            DOUBLE
        CHECK (a0 = CAST (a0 AS real)),

    b0            DOUBLE
        CHECK (b0 = CAST (b0 AS real)),

    c0            DOUBLE
        CHECK (c0 = CAST (c0 AS real))
);

------------------------------------------------------------------------
-- Curve Effects


-- ucurve(n) effects table.

CREATE TABLE ucurve_effects_t (
    --------------------------------------------------------------------
    -- Keys and Pointers

    -- Effect ID
    e_id         INTEGER PRIMARY KEY,

    -- Curve ID: ID of the curve receiving the effect.
    curve_id     INTEGER REFERENCES ucurve_curves_t(curve_id)
                 ON DELETE CASCADE
                 DEFERRABLE INITIALLY DEFERRED,

    -- Driver ID, an integer assigned by the client.
    driver_id    INTEGER NOT NULL,

    -- Cause ID, an integer assigned by the client.
    cause_id     INTEGER NOT NULL,

    --------------------------------------------------------------------
    -- Data

    -- Persistence flag.  If 1, persistent, if 0, transient.
    pflag        INTEGER DEFAULT 0,

    -- Nominal (unscaled) magnitude of the effect.
    mag          DOUBLE DEFAULT 0.0
        CHECK (mag = CAST (mag AS real)),

    -- Actual (unscaled) magnitude of the effect, when causes are
    -- taken into account.
    actual       DOUBLE DEFAULT 0.0
);

CREATE INDEX ucurve_effects_cc_index ON ucurve_effects_t(curve_id,cause_id);

------------------------------------------------------------------------
-- Baseline Adjustments


-- ucurve(n) adjustments table.

CREATE TABLE ucurve_adjustments_t (
    --------------------------------------------------------------------
    -- Keys and Pointers

    -- Effect ID
    a_id         INTEGER PRIMARY KEY,

    -- Curve ID: ID of the curve receiving the effect.
    curve_id     INTEGER REFERENCES ucurve_curves_t(curve_id)
                 ON DELETE CASCADE
                 DEFERRABLE INITIALLY DEFERRED,

    -- Driver ID, an integer assigned by the client.
    driver_id    INTEGER NOT NULL,

    --------------------------------------------------------------------
    -- Data

    -- Delta to the curve
    delta          DOUBLE DEFAULT 0.0
        CHECK (delta = CAST (delta AS real))
);

------------------------------------------------------------------------
-- Contribution History

-- ucurve(n) contribs table
--
-- NOTE: We have no FK constraint on the curve_id, so that Athena can
-- exclude the contribs table (which can get quite large) from snapshots
-- without causing problems on snapshot import.

CREATE TABLE ucurve_contribs_t (
    --------------------------------------------------------------------
    -- Keys and Pointers

    -- Curve ID: ID of the curve receiving the effect.
    curve_id     INTEGER,

    -- Driver ID, an integer assigned by the client.
    driver_id    INTEGER NOT NULL,

    -- Timestamp
    t            INTEGER NOT NULL,

    --------------------------------------------------------------------
    -- Data

    -- Contribution to curve_id by driver_id at time t
    contrib      DOUBLE NOT NULL DEFAULT 0.0,    
    

    PRIMARY KEY (curve_id, driver_id, t)
);

