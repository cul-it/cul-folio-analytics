--CR232
--inst_updated_date
--created 3-8-24
--query written by Natalya Pikulik
--This query pulls the updated_by_userid and the updated_date field data from 
--the inventory instance record using the instance_ext derived table. 
--This data is then joined to the MARC 245/a field to get the instance title 
--and instance HRID. Please use the LIMIT shown or take it out, depending on your need.
    
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
