-- MSQ104
-- 1-22-26
-- Created by: Joanne Leary
-- This tester query selects the correct srs_id from the marc__t table, and then checks to see if there are any multiple srs_id's in the results.
-- takes about 11 minutes to run, as of 1-22-26 (NB: runs much faster with a Where condition in the recs subquery that specifies a marc__t.field)
-- 1. Get the marc__t.srs_id associated with the greatest row number in the records_lb table for each instance_hrid
-- This is a tester query. To run just the "fix" in regular queries, use the first subquery (recs) and specify marc fields.

WITH recs AS
	(SELECT
		marc__t.instance_hrid,
		marc__t.srs_id,
		MAX (records_lb.__id) AS max_record
	
	FROM folio_source_record.marc__t
		INNER JOIN folio_source_record.records_lb
		ON marc__t.srs_id = records_lb.matched_id
	
	GROUP BY
		marc__t.instance_hrid,
		marc__t.srs_id
)
-- 2. Check for multiple srs_ids in the results; should return zero entries
	
SELECT
	CURRENT_DATE::timestamp,
	recs.instance_hrid,
	COUNT (DISTINCT recs.srs_id)
FROM recs
GROUP BY recs.instance_hrid
HAVING COUNT (DISTINCT recs.srs_id) > 1
;

