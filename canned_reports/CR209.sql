--CR209.sql
--Identifying_VHS
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 05/16/2023
--This query identifies videotapes (VHS tapes) in a specified library. 


WITH parameters AS

(SELECT
 'Africana Library'::varchar AS library_filter -- Examples: Nestle Library', Library Annex, etc.
)

SELECT 
	ii.title,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	he.permanent_location_name,
	he.call_number,
	substring (he.call_number,'\d{1,}')::integer AS cn,
	ie.barcode,
	string_agg (DISTINCT sm4.CONTENT,' | ') AS field_300,
	substring (sm.CONTENT, 7,1) AS g, -- 000
	substring (sm2.CONTENT,1,2) AS vf, -- 007
	substring (sm3.CONTENT, 34,1) AS v -- 008

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
	AND (sm2.field = '007' AND substring (sm2.CONTENT,1,2) = 'vf')
	AND (sm3.field = '008' AND substring (sm3.CONTENT, 34,1) = 'v')
	AND ((sm4.field = '300') OR sm4.field IS NULL)
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
	AND (ll.library_name = (SELECT library_filter FROM parameters)
         OR '' = (SELECT library_filter FROM parameters))

GROUP BY 
	ii.title,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.barcode,
	he.permanent_location_name,
	he.call_number,
	substring (sm.CONTENT, 7,1), -- 000
	substring (sm2.CONTENT,1,2), -- 007
	substring (sm3.CONTENT, 34,1) -- 008

ORDER BY cn, call_number
