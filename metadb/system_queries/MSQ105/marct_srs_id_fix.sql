--MSQ105
--last updated: 1/28/26
--written by: Joanne Leary
--This query fixes the marc__t table so it has only the most recent srs_id

-- 1. Find the max record in the records_lb table for every external_id
WITH recs AS
     (SELECT
       records_lb.external_id,
       MAX (records_lb.__id) AS max_record

FROM folio_source_record.records_lb

GROUP BY records_lb.external_id

)

-- 2. Join the max record from the first query to the records_lb table, 
-- which is inner joined by srs_id to the marc__t table

SELECT
    marc__t.*    -- get all marc__t fields

FROM folio_source_record.marc__t
INNER JOIN folio_source_record.records_lb
   ON marc__t.srs_id = records_lb.id
INNER JOIN recs
   ON records_lb.__id = recs.max_record    -- join the records_lb table to the max_record from the recs result
;
