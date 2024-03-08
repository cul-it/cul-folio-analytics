SELECT
    sr.instance_hrid,
    sr.field,
    sr.CONTENT,
    ie.record_created_date::date,
    ie.updated_by_user_id,
    ie.updated_date::date
  FROM srs_marctab sr
  LEFT JOIN folio_reporting.instance_ext ie ON ie.instance_hrid=sr.instance_hrid
  WHERE (sr.field ='245' AND sr.sf='a')
       AND ie.updated_date::date > '2023-01-1'
  LIMIT 10
;
