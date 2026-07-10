--marct_srs_id_fix
--daily automated MSQ105 to create new fixed marc__t table in local_derived schema
--last updated: 4/17/26
--written by: Joanne Leary
--This query fixes the marc__t table so it has only the most recent srs_id
--2/9/26: adapted by Sharon Markus to publish marc__t table in local_derived
--3/4/26: added WHERE clauses to exclude NULL records
--4/17/26: more changes to keep records from dropping out

DROP TABLE IF EXISTS local_derived.marc__t CASCADE;
CREATE TABLE local_derived.marc__t AS

-- 1. Get the max row number for each instance record in the records_lb table
 
WITH recs AS
        (SELECT
                records_lb.external_hrid,
                MAX (records_lb.__id) AS max_record

        FROM folio_source_record.records_lb
        --WHERE records_lb.external_hrid in ('15058802','10016344')
           WHERE records_lb.state = 'ACTUAL'

        GROUP BY records_lb.external_hrid
        ),

-- 2. Get the record_id associated with the max row number in the records_lb table

recs2 AS
        (SELECT
                records_lb.external_hrid,
                records_lb.id,
                recs.max_record

        FROM folio_source_record.records_lb
                INNER JOIN recs
                ON recs.max_record = records_lb.__id
 
        WHERE records_lb.state = 'ACTUAL'
        )

-- 3. Join the marc__t table's srs_id to the records_lb.id from the recs2 query

SELECT
   mt.*,
   recs2.id AS max_row_number_from_records_lb

FROM folio_source_record.marc__t as mt
        INNER JOIN recs2
        ON mt.instance_hrid = recs2.external_hrid
          AND mt.srs_id = recs2.id
--WHERE mt.instance_hrid in ('15058802','10016344')

ORDER BY 
mt.instance_hrid, 
mt.field, 
mt.sf

;

