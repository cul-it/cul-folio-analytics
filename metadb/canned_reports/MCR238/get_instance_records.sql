--This report uses metadb function and gets MARC record field content for a particular subfield.
--After function is created it can be called by using provided call statement example at the end of the report. 


DROP FUNCTION IF EXISTS local_automation.get_instance_records;
CREATE FUNCTION local_automation.get_instance_records()
RETURNS TABLE (
  instance_hrid text,
  marc_field TEXT ,
  marc_field_subfield text,
  marc_subfield_content text,
  record_date_created date,
  record_created_by TEXT,
  "current" BOOLEAN,
  record_updated_by text,
  record_updated_date date
) AS $$
  SELECT
    sr.instance_hrid,
    sr.field AS marc_field,
    sr.sf AS marc_field_subfield,
    sr.CONTENT marc_subfield_content,
    i.creation_date::date AS record_date_created,
    i.created_by AS record_created_by,
    i.__current AS "current",
    jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedByUserId')::uuid AS record_user_uuid,
    jsonb_extract_path_text(i.jsonb, 'metadata', 'updatedDate')::date AS record_updated_date
  FROM folio_source_record.marc__t sr
  LEFT JOIN folio_inventory.instance AS i ON sr.instance_id::uuid= i.id::uuid
;
$$
LANGUAGE SQL
STABLE
PARALLEL SAFE

---To call created function use:
SELECT * FROM get_instance_records()
WHERE (marc_field ='899'AND marc_field_subfield='a' AND marc_subfield_CONTENT = 'HeinOnlineLaborLaw');
