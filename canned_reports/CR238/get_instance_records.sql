--This report uses LDP function and gets MARC record field content for a particular subfield.
--After function is created it can be called by using provided call statement example at the end of the report. 



DROP FUNCTION IF EXISTS local_automation.get_instance_records;
CREATE FUNCTION local_automation.get_instance_records()
RETURNS TABLE (
  instance_hrid text,
  instance_id text,
  marc_field TEXT ,
  marc_field_subfield text,
  marc_subfield_content TEXT,
  record_date_created date,
  record_created_by TEXT,
  record_updated_by text,
  record_updated_date date
) AS $$
  SELECT
    sr.instance_hrid,
    sr.instance_id,
    sr.field AS marc_field,
    sr.sf AS marc_field_subfield,
    sr.CONTENT marc_subfield_content,
    i.metadata__created_date::date AS record_date_created,
    i.metadata__created_by_user_id AS record_created_by,
    i.metadata__updated_by_user_id::uuid AS record_user_uuid,
    i.metadata__updated_date::date AS record_updated_date
  FROM srs_marctab sr
  LEFT JOIN inventory_instances AS i ON sr.instance_id::uuid= i.id::uuid
;
$$
LANGUAGE SQL
STABLE
PARALLEL SAFE;

---To call created function use:

SELECT * FROM local_automation.get_instance_records()
WHERE (marc_field ='899'AND marc_field_subfield='a' AND marc_subfield_CONTENT = 'HeinOnlineLaborLaw')
;
