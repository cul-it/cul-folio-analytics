--MCR232
--inst_updated_date
--created 3-8-24
--query written by Natalya Pikulik
--This query pulls the updated_by_userid and the updated_date field data from 
--the inventory instance record JSONB data array. This data is then joined 
--to the MARC 245/a field to get the instance title and instance HRID. Please
--use the LIMIT shown or take it out, depending on your need.

SELECT
  sr.instance_hrid,
  sr.field,
  sr.CONTENT,
  i.creation_date::date, -- changed from record_created_date IN ldp
  i.__current,
  jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedByUserId') AS user_uuid,
  jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedDate')::date AS updated_date
FROM folio_source_record.marc__t sr
LEFT JOIN folio_inventory.instance__ as i ON sr.instance_id = i.id
WHERE (sr.field ='245' AND sr.sf='a')
  AND jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedDate') > '2023-01-1'
LIMIT 10
  ;
