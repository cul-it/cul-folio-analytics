--AHR132
--No Library Records
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 8/15/23
/*This query finds records that have an owning library of "No Library" or a holdings or item location of "No Library". 
This will be used by the Annex for record cleanup.*/

SELECT
	DISTINCT
       ll.library_name,
	he.permanent_location_name AS holdings_permanent_location_name,
	ie.effective_location_name AS item_effective_location_name,
	trim (concat_ws (' ',
	he.call_number_prefix,
	he.call_number,
	he.call_number_suffix,
	invitems.enumeration,
	invitems.chronology,
	CASE
		WHEN invitems.copy_number >'1' THEN concat ('c.',
		invitems.copy_number)
		ELSE ''
	END)) AS whole_call_number,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	invitems.hrid AS item_hrid,
	invitems.barcode,
	ii.title,
	ii.discovery_suppress AS instance_suppress,
	he.discovery_suppress AS holdings_suppress,
	invitems.effective_shelving_order COLLATE "C"


FROM inventory_instances AS ii
LEFT JOIN folio_reporting.holdings_ext AS he 
              ON
ii.id = he.instance_id
LEFT JOIN folio_reporting.locations_libraries AS ll 
              ON
he.permanent_location_id = ll.location_id
LEFT JOIN inventory_items AS invitems 
              ON
he.holdings_id = invitems.holdings_record_id
LEFT JOIN folio_reporting.item_ext AS ie 
              ON
invitems.id = ie.item_id
WHERE 
       (ll.library_name = 'No Library'
	OR he.permanent_location_name = 'No Library'
	OR ie.effective_location_name = 'No Library')
AND he.permanent_location_name NOT SIMILAR TO '%(serv,remo|LTS)%'
AND (he.discovery_suppress = 'False'
	OR he.discovery_suppress IS NULL)
AND (ii.discovery_suppress = 'False'
	OR ii.discovery_suppress IS NULL)
ORDER BY
ll.library_name,
he.permanent_location_name,
ie.effective_location_name,
invitems.effective_shelving_order COLLATE "C"
;
