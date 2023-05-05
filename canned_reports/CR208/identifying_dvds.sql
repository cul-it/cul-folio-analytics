-- This query finds DVDs in the specified library

WITH parameters AS (
SELECT 
''::VARCHAR AS owning_library_name_filter
)

SELECT 
sm.instance_hrid,
he.holdings_hrid,
ie.item_hrid,
ii.title,
ll.library_name,
he.permanent_location_name,
he.call_number,
substring (he.call_number,'\d{1,}')::integer AS cn,
ie.barcode,
string_agg (DISTINCT sm4.CONTENT,' | ') AS field_300,
substring (sm.CONTENT,7,1) AS g,
substring (sm2.CONTENT,1,2) AS vd,
substring (sm3.CONTENT,34,1) AS v

FROM srs_marctab AS sm
LEFT JOIN srs_marctab AS sm2 
ON sm.instance_hrid = sm2.instance_hrid 

LEFT join srs_marctab AS sm3 
ON sm2.instance_hrid = sm3.instance_hrid

LEFT JOIN srs_marctab AS sm4 
ON sm3.instance_hrid = sm4.instance_hrid

LEFT JOIN inventory_instances AS ii 
ON sm.instance_hrid = ii.hrid
AND sm2.instance_hrid = ii.hrid
AND sm3.instance_hrid = ii.hrid
AND sm4.instance_hrid = ii.hrid

LEFT JOIN folio_reporting.holdings_ext AS he 
ON ii.id::varchar = he.instance_id 

LEFT JOIN folio_reporting.item_ext AS ie 
ON he.holdings_id = ie.holdings_record_id

LEFT JOIN folio_reporting.locations_libraries AS ll 
ON he.permanent_location_id = ll.location_id

WHERE (sm.field = '000' AND substring (sm.CONTENT,7,1) ='g')
AND (sm2.field = '007' AND substring (sm2.CONTENT,1,2) = 'vd')
AND (sm3.field = '008' AND substring (sm3.CONTENT, 34,1) = 'v')
AND ((sm4.field = '300') OR sm4.field IS NULL)
AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
(ll.library_name = (SELECT owning_library_name_filter FROM parameters) OR (SELECT owning_library_name_filter FROM parameters) = '')

GROUP BY 
sm.instance_hrid,
he.holdings_hrid,
ie.item_hrid,
ii.title,
ll.library_name,
he.permanent_location_name,
he.call_number,
substring (he.call_number,'\d{1,}')::integer,
ie.barcode,
substring (sm.CONTENT,7,1),
substring (sm2.CONTENT,1,2),
substring (sm3.CONTENT,34,1)

ORDER BY cn, call_number
;
