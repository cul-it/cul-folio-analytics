--AHR148
--Annex_items_with_in_transit_status
--Query writer: Joanne Leary (jl41)
--Query posted on 9/12/24

SELECT
	TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
	ii.title,
	he.permanent_location_name AS holdings_location_name,
	ie.effective_location_name AS item_effective_location_name,
	CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) AS holdings_call_number,
	ie.enumeration,
	ie.chronology,
	ie.copy_number,
	ie.barcode,
	jsb."Item Barcode" AS jake_barcode,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.status_name AS item_status,
	ie.status_date::DATE AS item_status_date,
	CASE 
		WHEN uu.personal__first_name IS NOT NULL 
		THEN CONCAT (uu.personal__last_name,', ',uu.personal__first_name) 
		ELSE uu.personal__last_name 
		END AS update_user_name,
	ie.updated_date::DATE AS update_date


FROM local.jake_barcode as jsb ---local.jake_sample_barcodes AS jsb 
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON jsb."Item Barcode" = ie.barcode
	
	LEFT JOIN inventory_items AS invitems 
	ON ie.item_id = invitems.id
		
	LEFT JOIN folio_reporting.holdings_ext AS he  
	ON ie.holdings_record_id = he.holdings_id
	
	LEFT JOIN inventory_instances AS ii 
	ON he.instance_id = ii.id
	
	LEFT JOIN user_users AS uu
	ON ie.updated_by_user_id = uu.id

WHERE ie.status_name = 'In transit'
	
ORDER BY invitems.effective_shelving_order COLLATE "C"
;

