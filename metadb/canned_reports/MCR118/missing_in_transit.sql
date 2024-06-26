--MCR118
--missing_in_transit
--This is a revised version of the LDP query CR118 . It finds items that are still in transit after 10 days. This does not use the derived table "users_groups" because that table is wrong.
--Original query written by Joanne Leary (jl41)
--Query ported to Metadb by Joanne Leary (jl41)
--Query reviewers: Linda Miller (lm15), Vandana Shah(vp25)
--Date posted: 6/7/24

WITH parameters AS 
(SELECT 
'%%'::VARCHAR AS library_name_filter,
'In transit'::VARCHAR AS item_status_name_filter
),

intransit_items AS 
(SELECT 
	ll.library_name,
	ie.item_id,
	ie.item_hrid,
	ie.barcode,
	ihi.index_title AS title,
	ie.effective_location_name,
	TRIM (CONCAT (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)) AS call_number,
	ie.in_transit_destination_service_point_name,
	ie.status_name,
	ie.status_date,
	ri.request_date::DATE,
	ri.request_type,
	ri.request_status,
	jsonb_extract_path_text(users.jsonb, 'personal', 'lastName') AS requester_last_name,
	jsonb_extract_path_text(users.jsonb, 'personal', 'firstName') AS requester_first_name,
	jsonb_extract_path_text(users.jsonb, 'username') AS requester_net_id,
	jsonb_extract_path_text(users.jsonb, 'barcode') AS requester_barcode,
	jsonb_extract_path_text(users.jsonb, 'active') AS requester_status,
	jsonb_extract_path_text(users.jsonb, 'personal', 'email') AS requester_email,
	item__t.effective_shelving_order

FROM folio_derived.item_ext AS ie 
	INNER JOIN folio_derived.items_holdings_instances AS ihi 
	ON ie.item_id = ihi.item_id
	
	LEFT JOIN folio_derived.requests_items AS ri 
	ON ie.item_id = ri.item_id
	
	LEFT JOIN folio_users.users
	ON ri.requester_id = users.id
	
	INNER JOIN folio_inventory.item__t 
	ON ie.item_id = item__t.id
	
	INNER JOIN folio_derived.locations_libraries AS ll 
	ON ie.effective_location_id = ll.location_id

WHERE ie.status_name = (SELECT item_status_name_filter FROM parameters)
	AND ((SELECT library_name_filter FROM parameters) = '' OR ll.library_name ILIKE (SELECT library_name_filter FROM parameters))
	AND (ri.request_status LIKE 'Open%' OR ri.request_status IS NULL)
),


loc1 AS 
(SELECT 
	intransit_items.library_name,
	intransit_items.item_id,
	intransit_items.item_hrid,
	intransit_items.barcode,
	intransit_items.title,
	intransit_items.effective_location_name,
	intransit_items.call_number,
	intransit_items.in_transit_destination_service_point_name,
	intransit_items.status_name,
	intransit_items.status_date,
	intransit_items.request_date::DATE,
	intransit_items.request_type,
	intransit_items.request_status,
	intransit_items.requester_last_name,
	intransit_items.requester_first_name,
	intransit_items.requester_barcode,
	intransit_items.requester_status,
	intransit_items.requester_email,
	intransit_items.effective_shelving_order,
	MAX (check_in__t.occurred_date_time) AS most_recent_check_in

FROM intransit_items
	INNER JOIN folio_circulation.check_in__t
	ON intransit_items.item_id = check_in__t.item_id 

GROUP BY 
	intransit_items.library_name,
	intransit_items.item_id,
	intransit_items.item_hrid,
	intransit_items.barcode,
	intransit_items.title,
	intransit_items.effective_location_name,
	intransit_items.call_number,
	intransit_items.in_transit_destination_service_point_name,
	intransit_items.status_name,
	intransit_items.status_date,
	intransit_items.request_date::DATE,
	intransit_items.request_type,
	intransit_items.request_status,
	intransit_items.requester_last_name,
	intransit_items.requester_first_name,
	intransit_items.requester_barcode,
	intransit_items.requester_email,
	intransit_items.requester_status,
	intransit_items.effective_shelving_order
)

SELECT
	TO_CHAR (CURRENT_DATE::date,'mm/dd/yyyy') AS todays_date,	
	loc1.library_name,
	loc1.effective_location_name,
	loc1.title,
	loc1.call_number,
	loc1.item_hrid,
	loc1.barcode,
	loc1.status_name,
	loc1.status_date::DATE,
	loc1.most_recent_check_in::DATE,
	service_point__t.name AS discharge_service_point_name,
	loc1.in_transit_destination_service_point_name,
	CURRENT_DATE::DATE - loc1.most_recent_check_in::DATE AS days_in_transit,
	loc1.request_date::DATE,
	loc1.request_type,
	loc1.request_status,
	loc1.requester_last_name,
	loc1.requester_first_name,
	loc1.requester_barcode,
	loc1.requester_email,
	CASE 
		WHEN loc1.requester_status IS NULL THEN NULL 
		WHEN loc1.requester_status = 'true' THEN 'Active' 
		ELSE 'Inactive' END AS requester_status

FROM loc1 
INNER JOIN folio_circulation.check_in__t 
	ON loc1.item_id = check_in__t.item_id 
	AND loc1.most_recent_check_in = check_in__t.occurred_date_time
	
INNER JOIN folio_inventory.service_point__t 
	ON check_in__t.service_point_id = service_point__t.id
	
WHERE CURRENT_DATE::DATE - loc1.most_recent_check_in::DATE > 10

ORDER BY library_name, effective_location_name, effective_shelving_order COLLATE "C", call_number
