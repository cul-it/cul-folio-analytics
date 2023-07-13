--AHR130 
--Video Records in Africana
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 7/13/2023

-- This query finds video records in the Africana library. Requested by Cammie for record cleanup.

WITH recs AS 
(
SELECT
	sm.instance_hrid,
	substring (sm.content, 1, 2) AS video_type_code
FROM
	srs_marctab AS sm
WHERE
	sm.field = '007'
	AND substring(sm.content, 1, 2) LIKE 'v%'
)

SELECT
	recs.video_type_code,
	CASE
		WHEN recs.video_type_code = 'vf' THEN 'videocassette'
		WHEN recs.video_type_code = 'vd' THEN 'videodisc'
		WHEN recs.video_type_code = 'vc' THEN 'videocartridge'
		ELSE 'other video format'
	END AS video_format,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	substring (he.call_number, '\d{1,}')::integer AS video_number,
	trim (concat (he.call_number_prefix, ' ', he.call_number, ' ', he.call_number_suffix, ' ', ie.enumeration, ' ', ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN concat ('c.', ie.copy_number) ELSE '' END)) AS whole_call_number,
	ie.material_type_name,
	ii.title,
	ll.library_name,
	he.permanent_location_name,
	ie.barcode,
	ii.discovery_suppress AS instance_suppress,
	he.discovery_suppress AS holdings_suppress
FROM
	recs
LEFT JOIN inventory_instances AS ii ON recs.instance_hrid = ii.hrid
LEFT JOIN folio_reporting.holdings_ext AS he ON ii.id = he.instance_id
LEFT JOIN folio_reporting.locations_libraries AS ll ON he.permanent_location_id = ll.location_id
LEFT JOIN folio_reporting.item_ext AS ie ON he.holdings_id = ie.holdings_record_id
  
WHERE
	ll.library_name = 'Africana Library'
	AND (ie.material_type_name = 'Visual' OR ie.material_type_name IS NULL)
	AND trim (concat (he.call_number_prefix, ' ', he.call_number, ' ', he.call_number_suffix, ' ', ie.enumeration, ' ', ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN concat ('c.', ie.copy_number) ELSE '' END)) NOT LIKE '%di%s%'
ORDER BY
	he.permanent_location_name,
	video_number,
	he.call_number,
	ie.enumeration,
	ie.chronology,
	ie.copy_number
;
