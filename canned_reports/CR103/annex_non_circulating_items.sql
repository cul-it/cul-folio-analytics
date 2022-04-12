/* This query finds items at the Annex that have a "non-circulating" permanent loan type, excluding rare and special collections.
 * It also finds items with an hourly loan type. 
 */

SELECT 

	to_char(current_date::DATE,'mm/dd/yyyy') AS todays_date,
	ll.library_name,
	he.permanent_location_name AS holdings_perm_loc_name,
	itemext.permanent_location_name AS item_perm_loc_name,
	itemext.temporary_location_name AS item_temp_loc_name,
	itemext.permanent_loan_type_name,
	itemext.temporary_loan_type_name,
	ie.instance_hrid,
	he.holdings_hrid,
	itemext.item_hrid,
	itemext.barcode,
	itemext.material_type_name,
	he.type_name as holdings_type,
	ie.index_title,
	he.call_number as holdings_call_number,
	itemext.enumeration,
	itemext.chronology,
	itemext.copy_number,
	ie.discovery_suppress AS instance_suppress,
	he.discovery_suppress AS holdings_suppress,
	itemext.status_name,
	to_char(itemext.status_date::DATE,'mm/dd/yyyy') AS item_status_date

FROM folio_reporting.instance_ext as ie 
	INNER JOIN folio_reporting.holdings_ext AS he
	ON ie.instance_id = he.instance_id 
	
	INNER JOIN folio_reporting.item_ext AS itemext 
	ON he.holdings_id = itemext.holdings_record_id 
	
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id 

WHERE ll.library_name = 'Library Annex'
	AND (he.permanent_location_name NOT IN ('RMC Annex', 'ILR Kheel Center - Annex')
		AND he.permanent_location_name NOT LIKE '%Rare%'
		AND he.permanent_location_name NOT LIKE 'Mann%Special%'
		AND itemext.permanent_loan_type_name = 'Non-circulating')
	OR ll.library_name = 'Library Annex'
	AND (itemext.permanent_loan_type_name LIKE '%our%'
		OR itemext.temporary_loan_type_name LIKE '%our%')

ORDER BY holdings_perm_loc_name, item_perm_loc_name, item_temp_loc_name, instance_hrid, holdings_hrid, item_hrid
;

