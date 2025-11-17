--MSQ102
--last updated: 11/17/25
--multiple_srs_id_check.sql
--written by Joanne Leary, reviewed by Sharon Markus
--This query finds instance_hrid records that are linked to multiple distinct srs_ids. 
--For each instance_hrid in folio_source_record.marc__t, it counts the unique srs_id values and returns only 
--those instances where that count is greater than one, such as potential duplicates or one-to-many linkage anomalies. 
--The result includes the instance_hrid and the number of distinct srs_id records attached to it.

SELECT
-- The instance identifier (one output row per instance after GROUP BY)
sm.instance_hrid,
-- Aggregate: count unique SRS record IDs associated with the instance
COUNT(DISTINCT sm.srs_id) AS count_of_srs_ids
-- Read rows from the MARC source table
FROM folio_source_record.marc__t AS sm
-- Group rows by instance so aggregates are computed per instance
GROUP BY sm.instance_hrid
-- Filter groups: keep only instances that have >1 distinct SRS ID
HAVING COUNT(DISTINCT sm.srs_id) > 1
;
