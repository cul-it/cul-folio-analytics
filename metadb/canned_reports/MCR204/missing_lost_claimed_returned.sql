-- MCR204
-- missing_lost_claimed_returned
--This query finds items whose status is missing, lost, claimed returned, or missing in transit.

--Query writer: Joanne Leary (jl41)
--Query posted on 6/7/24, revised version posted on 11/5/24
--Updated on 1/6/25


WITH parameters AS (
SELECT 
'%%'::VARCHAR AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc. or leave blank for all libraries. See list of libraries at https://confluence.cornell.edu/display/folioreporting/Locations
--''::VARCHAR AS item_status_filter -- enter one of: Missing, Aged to lost, Lost and paid, Declared lost, Claimed returned, Unavailable; or leave blank to get all statuses
),

field_300 AS 
	(SELECT 
	sm.instance_hrid,
	STRING_AGG (DISTINCT sm.content,' | ') AS pagination_size
	
	FROM folio_source_record.marc__t as sm 
	WHERE sm.field = '300'
	GROUP BY sm.instance_hrid 
),

recs AS 
	(SELECT
	ll.library_name,
	he.permanent_location_name,
	instext.title,
	TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, ii.enumeration, ii.chronology,
		CASE WHEN ii.copy_number >'1' THEN CONCAT ('c.', ii.copy_number) ELSE '' END)) AS whole_call_number,
	ii.barcode,
	itemext.status_name,
	itemext.status_date::DATE AS item_status_date, 
	CASE WHEN jsonb_extract_path_text (item__.jsonb,'lastCheckIn', 'dateTime')::TIMESTAMP IS NULL THEN NULL  
		ELSE jsonb_extract_path_text (item__.jsonb,'lastCheckIn', 'dateTime')::TIMESTAMP END AS last_folio_check_in,
	MAX (cta.charge_date::TIMESTAMP) AS last_voyager_checkout,
	MAX (cta.discharge_date::TIMESTAMP) AS last_voyager_check_in,
	isp.name AS last_folio_check_in_service_point,
	itemext.in_transit_destination_service_point_name,
	field_300.pagination_size,
	STRING_AGG (DISTINCT itemnotes.note,' | ') AS item_note,
	itemext.material_type_name,
	he.type_name,
	instext.instance_hrid,
	he.holdings_hrid,
	itemext.item_hrid,
	instext.discovery_suppress AS instance_suppress,
	he.discovery_suppress AS holdings_suppress,
	itemext.item_id,
	ii.effective_shelving_order

FROM folio_derived.instance_ext as instext 
	LEFT JOIN folio_derived.holdings_ext AS he 
	ON instext.instance_id = he.instance_id
	
	LEFT JOIN folio_derived.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id
	
	LEFT JOIN folio_derived.item_ext AS itemext 
	ON he.holdings_id = itemext.holdings_record_id
	
	LEFT JOIN folio_inventory.item__t AS ii 
	ON itemext.item_id = ii.id
	
	LEFT JOIN folio_inventory.item__ 
	ON ii.id = item__.id
	
	LEFT JOIN vger.circ_trans_archive AS cta 
	ON ii.hrid::VARCHAR = cta.item_id::VARCHAR
	
	LEFT JOIN folio_inventory.service_point__t AS isp  
	ON jsonb_extract_path_text (item__.jsonb,'lastCheckIn','servicePointId')::UUID = isp.id 
	
	LEFT JOIN folio_derived.item_notes AS itemnotes
	ON itemext.item_id = itemnotes.item_id
	
	LEFT JOIN field_300
	ON instext.instance_hrid = field_300.instance_hrid

WHERE 
	itemext.status_name SIMILAR TO '%(issing|ost|laim|navail|ransit)%'
	AND item__.__current = TRUE

GROUP BY 
	ll.library_name,
	he.permanent_location_name,
	instext.title,
	he.call_number_prefix,
	he.call_number,
	he.call_number_suffix,
	ii.enumeration,
	ii.chronology,
	ii.copy_number,
	ii.barcode,
	instext.discovery_suppress,
	he.discovery_suppress,
	itemext.in_transit_destination_service_point_name,
	field_300.pagination_size,
	instext.instance_hrid,
	he.holdings_hrid,
	itemext.item_hrid,
	itemext.item_id,
	itemext.material_type_name,
	he.type_name,
	itemext.status_name,
	itemext.status_date::date,
	jsonb_extract_path_text (item__.jsonb,'lastCheckIn', 'dateTime')::TIMESTAMP,
	isp.name,
	ii.effective_shelving_order
),

loan1 AS 
(SELECT 
	recs.item_id,
	recs.item_hrid,
	GREATEST (MAX (li.loan_date), recs.last_voyager_checkout) AS most_recent_loan
FROM recs 
	INNER JOIN folio_derived.loans_items AS li 
	ON recs.item_id = li.item_id 

GROUP BY 
	recs.item_hrid, recs.item_id, recs.last_voyager_checkout
),

loan2 AS 
(SELECT 
	loan1.item_id,
	loan1.item_hrid,
	loan1.most_recent_loan, 
	jsonb_extract_path_text (users__.jsonb,'personal','lastName') AS user_last_name,
	jsonb_extract_path_text (users__.jsonb,'personal','firstName') AS user_first_name,
	uu.active AS patron_status

FROM loan1 
	INNER JOIN folio_derived.loans_items AS li 
	ON loan1.most_recent_loan::date = li.loan_date::date 
		AND loan1.item_id = li.item_id

	INNER JOIN folio_users.users__t as uu 
	ON li.user_id::UUID = uu.id
	
	inner JOIN folio_users.users__ 
	ON uu.id = users__.id

WHERE users__.__current = TRUE
)

SELECT DISTINCT
	TO_CHAR (CURRENT_DATE::date,'mm/dd/yyyy') AS todays_date,
	recs.library_name,
	recs.permanent_location_name,
	recs.title,
	CASE
	        WHEN recs.whole_call_number like '%+++%' THEN '+++'
        	WHEN recs.whole_call_number like '%++%' THEN '++'
        	WHEN recs.whole_call_number like '%+%' THEN '+'
        	ELSE ''
        	END AS size,
	recs.whole_call_number,
	recs.barcode,
	recs.status_name,
	recs.item_status_date, 
	to_char (COALESCE (recs.last_folio_check_in, recs.last_voyager_check_in, NULL)::timestamp, 'mm/dd/yyyy hh:mi am') AS last_check_in_date, 
	COALESCE (recs.last_folio_check_in_service_point,location.Location_name,'-') AS last_check_in_location,
	recs.in_transit_destination_service_point_name,
	recs.pagination_size,
	recs.item_note,
	recs.material_type_name,
	recs.type_name as holdings_type_name,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.instance_suppress,
	recs.holdings_suppress,
	loan2.user_last_name,
	loan2.user_first_name,
	CASE WHEN loan2.patron_status = 'True' THEN 'Active' WHEN loan2.patron_status = 'False' THEN 'Expired' ELSE ' - ' END AS patron_status,
	TO_CHAR (loan2.most_recent_loan::timestamp,'mm/dd/yyyy hh:mi am') AS most_recent_loan,
	recs.effective_shelving_order COLLATE "C"

FROM recs 
	LEFT JOIN vger.circ_trans_archive AS cta 
	ON recs.last_voyager_check_in = cta.discharge_date::TIMESTAMP
		AND recs.item_hrid = cta.item_id::VARCHAR

	LEFT JOIN vger.location 
	ON cta.discharge_location = location.location_id
	
	LEFT JOIN loan2 
	ON recs.item_hrid = loan2.item_hrid

WHERE (recs.library_name ilike (SELECT owning_library_name_filter FROM parameters) OR (SELECT owning_library_name_filter FROM parameters) = '')
--recs.status_name = (SELECT item_status_filter FROM parameters) OR (SELECT item_status_filter FROM parameters) = '' 

ORDER BY library_name, permanent_location_name, size, effective_shelving_order COLLATE "C"
;

