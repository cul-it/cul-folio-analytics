--MCR224
--approval_plan_titles_by_vendor_and_statistical_code
--This query uses the source of acquisition statistical code of "Approval/Blanket Order" to identify titles associated with approval plans.  
--It also shows approval plan titles associated with vendors using the vendor code from the MARC record 980 subfield "v" if it is available. 
--Getting vendor name out of this fields before vendor instance statistical code was implemented 
---in "vendor_prestat_code"
--980 $v:Aux, Harrass, Worldwide, Erasmus
--920  \\$dCasalini Libri
--948 Couttsshelfready
--using "vendor" statistical code name in "vendor_current_st_code"
WITH all_approvals AS 
(SELECT 
  ii.record_created_date::date AS created_date,
  isc.instance_hrid AS inst_hrid,
  isc.instance_id AS inst_id,
  isc.statistical_code_name AS appr_Stat_code,
  ii.title,
  isc.statistical_code,
  publication.data #>> '{dateOfPublication}' AS Date_of_publication,
  publication.data #>> '{place}' AS Place_of_publication,
  publication.data #>> '{publisher}' AS Publisher,
  publication.ordinality AS publication_ordinality
  FROM folio_derived.instance_statistical_codes isc
  LEFT JOIN folio_derived.instance_ext ii ON isc.instance_id =ii.instance_id
  LEFT JOIN folio_inventory.instance__ i ON i.id = isc.instance_id 
     CROSS JOIN jsonb_array_elements((i.jsonb #> '{publication}')::jsonb) 
     WITH ORDINALITY AS publication(data)
  WHERE (isc.statistical_code_type_name  IN ('Source of acquisition')
  AND isc.statistical_code_name IN ('Approval/Blanket order'))
     AND ii.record_created_date::date > '2021-07-01'
     AND publication.ordinality = '1')
,
 blanket_o AS (SELECT *
 FROM folio_derived.instance_statistical_codes isc
 WHERE isc.statistical_code IN ('npac', 'pl480', 'lccairo', 'LC Nairobi'))
 ,
 appr_no_bo AS (SELECT *
 FROM all_approvals aa
 LEFT JOIN  blanket_o bo ON bo.instance_hrid= aa.inst_hrid
 WHERE bo.instance_hrid IS NULL)
 ,
appr_vendor AS 
(SELECT 
  ii.record_created_date::date AS created_date,
  isc.instance_hrid,
  sm.CONTENT AS vendor_pre_stat_code
  FROM folio_derived.instance_statistical_codes isc
  LEFT JOIN folio_derived.instance_ext ii ON isc.instance_id =ii.instance_id
  LEFT JOIN folio_source_record.marc__t sm ON sm.instance_id::uuid= isc.instance_id::uuid
 WHERE (isc.statistical_code_name IN ('Approval/Blanket order')
    -- AND (sm.field = '980' AND sm.sf= 'v' AND sm.CONTENT ('Approval/Blanket order')
     AND (sm.field = '980' AND sm.sf= 'v' AND sm.CONTENT ILIKE ANY(ARRAY['Aux', 'Harrass', 'Worldwide', 'Erasmus', 
    'Cambeiro', 'Retta', 'cambeiro', 'Bach', 'Booksmex', 'Iturriaga', 'QingYin', 'GAIA', 'Beren',
    'kozmenko', 'Linardi', 'Leila', 'Andinos', 'bannawat', 'Martinbook', 'casalini%', 'Amalivre', 'eastview', 
    'kinokuniya', 'panmun'])))
     OR ((isc.statistical_code_name IN ('Approval/Blanket order')
     AND (sm.field = '948' AND sm.sf= 'h' AND sm.CONTENT iLIKE 'CouttsShelfReady')))
     AND isc.statistical_code_name NOT IN ('Delete')
     AND ii.record_created_date::date > '2021-07-01'
),
appr_vendor_stc AS
(SELECT 
  ii.record_created_date::date AS created_date,
  isc.instance_hrid,
  isc.statistical_code AS vendor_current_st_code
  FROM folio_derived.instance_statistical_codes isc
  LEFT JOIN folio_derived.instance_ext ii ON isc.instance_id =ii.instance_id
  WHERE (isc.statistical_code_type_name ='Vendor')
  AND ii.record_created_date::date > '2021-07-01'
)
SELECT 
  DISTINCT aa.inst_hrid,
  aa.created_date AS inst_created_date,
  CASE WHEN aa.created_date BETWEEN '07-01-2021' AND '06-30-2022' THEN 'FY22'
       WHEN aa.created_date BETWEEN '07-01-2022' AND '06-30-2023' THEN 'FY23'
       WHEN aa.created_date BETWEEN '07-01-2023' AND '06-30-2024' THEN 'FY24'
       WHEN aa.created_date BETWEEN '07-01-2024' AND '06-30-2025' THEN 'FY25'
       END AS "FY",
  aa.appr_stat_code, 
  av.vendor_pre_stat_code AS vendor,
  aps.vendor_current_st_code,
  substring(sm.content, 36,3) AS LANGUAGE,
  he.call_number,
  aa.title, 
  aa.Date_of_publication AS date_of_publ,
  aa.place_of_publication AS place_of_publ,
  aa.publisher
FROM appr_no_bo aa
LEFT JOIN appr_vendor av ON aa.inst_hrid = av.instance_hrid
LEFT JOIN appr_vendor_stc aps ON aa.inst_hrid = aps.instance_hrid
LEFT JOIN folio_source_record.marc__t sm ON aa.inst_hrid=sm.instance_hrid 
LEFT JOIN folio_derived.holdings_ext he ON aa.inst_id = he.instance_id 
WHERE (sm.field = '008')
ORDER BY aa.created_date DESC;
