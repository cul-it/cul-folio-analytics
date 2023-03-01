--AHR118
--Mismatched_locations_for_Annex

SELECT
	ll.library_name,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ii.title,
	trim (concat_ws (' ',
	he.call_number_prefix,
	he.call_number,
	he.call_number_suffix)) AS holdings_call_number,
	ie.enumeration,
	ie.chronology,
	ie.copy_number,
	ie.barcode,
	he.permanent_location_name AS holdings_location,
	ie.effective_location_name AS item_location,
	ie.status_name AS item_status,
	to_char (ie.status_date::timestamp,
	'mm/dd/yyyy hh:mi am') AS item_status_date,
	he.type_name AS holdings_type_name,
	ie.material_type_name
FROM
	inventory_instances AS ii
LEFT JOIN folio_reporting.holdings_ext AS he
        ON
	ii.id = he.instance_id
LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON
	he.permanent_location_id = ll.location_id
LEFT JOIN folio_reporting.item_ext AS ie 
        ON
	he.holdings_id = ie.holdings_record_id
LEFT JOIN inventory_items AS invitems 
        ON
	ie.item_id = invitems.id
WHERE
	(ll.library_name = 'Library Annex'
		AND he.permanent_location_name != ie.effective_location_name
		AND (he.discovery_suppress = 'False'
			OR he.discovery_suppress IS NULL))
	OR

        (ll.library_name != 'Library Annex'
		AND (he.permanent_location_name ILIKE '%Annex%'
			OR ie.effective_location_name ILIKE '%Annex%'))
ORDER BY
	ll.library_name,
	he.permanent_location_name,
	ie.effective_location_name,
	invitems.effective_shelving_order COLLATE "C"
;
