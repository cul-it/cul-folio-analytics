--MSQ106
--created: 2/16/26
--written by: Joanne Leary and Sharon Markus
--This query counts distinct ids on the records_lb table associated with external_hrids on the records_lb table.
--This query is intended to provide an additional check related to the count done by the MSQ102 query. 
--Assumptions:
--instance_hrid on marc__t = external_hrid on records_lb 
--id on records_lb = srs_id on marc__t  


SELECT
CURRENT_DATE::timestamp,
rlb.external_hrid,
COUNT(DISTINCT rlb.id) AS count_of_ids
FROM folio_source_record.records_lb AS rlb
GROUP BY rlb.external_hrid
HAVING COUNT(DISTINCT rlb.id) > 1
;
