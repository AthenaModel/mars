------------------------------------------------------------------------
-- TITLE:
--    gui_views.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views
--
--    These views translate internal data formats into presentation format.
--    
------------------------------------------------------------------------

CREATE TEMPORARY VIEW gv_uram_hrel AS
SELECT fg_id                  AS fg_id,
       f                      AS f,
       g                      AS g,
       curve_id               AS curve_id,
       format('%.3f',avalue)  AS 'At', 
       format('%.3f',bvalue)  AS 'Bt', 
       format('%.3f',cvalue)  AS 'Ct', 
       format('%.3f',avalue0) AS 'A0', 
       format('%.3f',bvalue0) AS 'B0', 
       format('%.3f',cvalue0) AS 'C0'
FROM uram_hrel; 

CREATE TEMPORARY VIEW gv_uram_hrel_effects AS
SELECT fg_id                  AS fg_id,
       curve_id               AS curve_id,
       f                      AS f,
       g                      AS g,
       e_id                   AS e_id,
       driver_id              AS driver_id,
       cause                  AS cause,
       pflag                  AS pflag,
       format('%.3f',mag)     AS mag
FROM uram_hrel_effects; 


CREATE TEMPORARY VIEW gv_uram_vrel AS
SELECT ga_id                  AS ga_id,
       g                      AS g,
       a                      AS a,
       curve_id               AS curve_id,
       format('%.3f',avalue)  AS 'At', 
       format('%.3f',bvalue)  AS 'Bt', 
       format('%.3f',cvalue)  AS 'Ct', 
       format('%.3f',avalue0) AS 'A0', 
       format('%.3f',bvalue0) AS 'B0', 
       format('%.3f',cvalue0) AS 'C0'
FROM uram_vrel; 

CREATE TEMPORARY VIEW gv_uram_vrel_effects AS
SELECT ga_id                  AS ga_id,
       curve_id               AS curve_id,
       g                      AS g,
       a                      AS a,
       e_id                   AS e_id,
       driver_id              AS driver_id,
       cause                  AS cause,
       pflag                  AS pflag,
       format('%.3f',mag)     AS mag
FROM uram_vrel_effects; 


CREATE TEMPORARY VIEW gv_uram_sat AS
SELECT gc_id                  AS gc_id,
       g                      AS g,
       c                      AS c,
       saliency               AS saliency,
       curve_id               AS curve_id,
       format('%.3f',avalue)  AS 'At', 
       format('%.3f',bvalue)  AS 'Bt', 
       format('%.3f',cvalue)  AS 'Ct', 
       format('%.3f',avalue0) AS 'A0', 
       format('%.3f',bvalue0) AS 'B0', 
       format('%.3f',cvalue0) AS 'C0'
FROM uram_sat; 

CREATE TEMPORARY VIEW gv_uram_sat_effects AS
SELECT gc_id                  AS gc_id,
       curve_id               AS curve_id,
       g                      AS g,
       c                      AS c,
       e_id                   AS e_id,
       driver_id              AS driver_id,
       cause                  AS cause,
       pflag                  AS pflag,
       format('%.3f',mag)     AS mag
FROM uram_sat_effects; 

CREATE TEMPORARY VIEW gv_uram_coop AS
SELECT fg_id                  AS fg_id,
       f                      AS f,
       g                      AS g,
       curve_id               AS curve_id,
       format('%.3f',avalue)  AS 'At', 
       format('%.3f',bvalue)  AS 'Bt', 
       format('%.3f',cvalue)  AS 'Ct', 
       format('%.3f',avalue0) AS 'A0', 
       format('%.3f',bvalue0) AS 'B0', 
       format('%.3f',cvalue0) AS 'C0'
FROM uram_coop; 
       
CREATE TEMPORARY VIEW gv_uram_coop_effects AS
SELECT fg_id                  AS fg_id,
       curve_id               AS curve_id,
       f                      AS f,
       g                      AS g,
       e_id                   AS e_id,
       driver_id              AS driver_id,
       cause                  AS cause,
       pflag                  AS pflag,
       format('%.3f',mag)     AS mag
FROM uram_coop_effects; 
