--- transaction type notes are moved from holdings records to instance records and we are taking it from 
--- instance_administrative_notes instead of holdings administeative notes derived table
WITH PARAMETERS AS (
SELECT
    /*choose a date range for the cataloging period
    enter the year and month exactly as the example shows, in front of the %sign */
  '202205%'::VARCHAR AS date_range,
    /*enter the userid exactly as the example shows, in front of the % sign,or leave blank (also delete the % sign)*/
  'cac%' as userid_filter
)
SELECT
ie.instance_hrid,
ie.title,
hn.administrative_note,
hn.administrative_note_ordinality,
substring (hn.administrative_note,21,1) as ttype,
substring (hn.administrative_note,6,8) as date,
substring(substring (hn.administrative_note, 30,6),'^[a-z]{2,3}\d{1,4}') as user_id,
split_part (hn.administrative_note, ':', 5) AS unit
FROM folio_derived.instance_ext AS ie
LEFT JOIN folio_derived.instance_administrative_notes AS hn ON hn.instance_id = ie.instance_id
WHERE ie.discovery_suppress IS NOT TRUE 
AND substring (hn.administrative_note,21,1) in ('c','s','o','u','z','f')
AND substring (hn.administrative_note,6,8) like (select date_range from parameters)
AND (substring(substring (hn.administrative_note, 30,6),'^[a-z]{2,3}\d{1,4}') ilike (select userid_filter FROM parameters) OR (select userid_filter FROM parameters)='')
;
