--MCR118
--missing_in_transit
--last updated: 3-20-25
--This query finds items that are still in transit after 10 days and shows requesters and designated pickup locations.
--Written by: Joanne Leary (jl41)
--Reviewed by: Linda Miller (lm15), Vandana Shah(vp25)
--Date posted: 6/7/24

WITH parameters AS 
(SELECT 
'%%'::varchar AS library_name_filter 
),

-- 1. Get MAX request date for open in-transit requests

requests1 AS 
(SELECT
	request__t.item_id,
	MAX (request__t.request_date)::DATE AS max_request_date,
	request__t.status
	
	FROM folio_circulation.request__t 
	WHERE request__t.status = 'Open - In transit'
	
	GROUP BY request__t.item_id, request__t.status
),

-- 2. Join results to requests__t table and users table to get name of requester, requester status and pickup service point name; select only active users

requests2 AS 
(SELECT 
	requests1.item_id,
	requests1.max_request_date,
	users.jsonb#>>'{personal,firstName}' AS requester_first_name,
	users.jsonb#>>'{personal,lastName}' AS requester_last_name,
	users.jsonb#>>'{username}' AS netid,
	users.jsonb#>>'{active}' AS requester_status,
	service_point__t.name AS pickup_service_point_name,
	requests1.status AS request_status,
	current_date::DATE - requests1.max_request_date AS days_since_requested

FROM requests1 
	INNER JOIN folio_circulation.request__t 
	ON requests1.item_id = request__t.item_id 
		AND requests1.max_request_date = request__t.request_date::DATE
	
	INNER JOIN folio_users.users 
	ON request__t.requester_id = users.id 
	
	INNER JOIN folio_inventory.service_point__t 
	ON request__t.pickup_service_point_id = service_point__t.id

WHERE (users.jsonb#>>'{active}')::boolean = true
),

-- 3. Get items with an "Open - In transit" status; get last check-in date and location; join to requests

recs AS 
(SELECT 
	loclibrary__t.name AS library_name,
	location__t.name AS holdings_location_name,
	instance__t.title,
	TRIM (CONCAT (item.jsonb#>>'{effectiveCallNumberComponents,prefix}',' ',
		item.jsonb#>>'{effectiveCallNumberComponents,callNumber}',' ',
		item.jsonb#>>'{effectiveCallNumberComponents,suffix}',' ',
		item.jsonb#>>'{enumeration}',' ',
		item.jsonb#>>'{chronology}',
		CASE 
			WHEN item.jsonb#>>'{copyNumber}' >'1' 
			THEN CONCAT ('c.',item.jsonb#>>'{copyNumber}') 
			ELSE NULL END)) AS item_call_number,
	item.jsonb#>>'{barcode}' AS item_barcode,
	instance__t.hrid AS instance_hrid,
	hrt.hrid AS holdings_hrid,
	item.jsonb#>>'{hrid}' AS item_hrid,	
	item.jsonb#>>'{status,name}' AS item_status_name,
	(item.jsonb#>>'{status,date}')::DATE AS item_status_date,
	service_point__t.name AS last_checkin_location,
	to_char ((item.jsonb#>>'{lastCheckIn,dateTime}')::TIMESTAMP,'mm-dd-yyyy hh:mi am') AS last_checkin_date,
	requests2.requester_last_name,
	requests2.requester_first_name,
	requests2.netid,
	requests2.max_request_date AS request_date,
	requests2.pickup_service_point_name,
	requests2.request_status,
	requests2.days_since_requested,
	item.jsonb#>>'{effectiveShelvingOrder}' AS shelving_order

FROM folio_inventory.instance__t 
	LEFT JOIN folio_inventory.holdings_record__t AS hrt 
	ON instance__t.id = hrt.instance_id 
	
	LEFT JOIN folio_inventory.item 
	ON hrt.id = (item.jsonb#>>'{holdingsRecordId}')::uuid
	
	LEFT JOIN folio_inventory.location__t 
	ON hrt.permanent_location_id = location__t.id 
	
	LEFT JOIN folio_inventory.loclibrary__t 
	ON location__t.library_id = loclibrary__t.id 
	
	LEFT JOIN folio_inventory.service_point__t 
	ON (item.jsonb#>>'{lastCheckIn,servicePointId}')::UUID = service_point__t.id
	
	LEFT JOIN requests2
	ON item.id = requests2.item_id
	

WHERE (loclibrary__t.name ILIKE (SELECT library_name_filter FROM parameters) OR (SELECT library_name_filter FROM parameters) ='') 
	AND item.jsonb#>>'{status,name}' = 'In transit'
	AND (instance__t.discovery_suppress = false OR instance__t.discovery_suppress IS NULL)
	AND (hrt.discovery_suppress = false OR hrt.discovery_suppress IS NULL)
)

-- 4. Get size based on the presence of plusses in the whole item call number; select items that have been in transit for more than 10 days; sort by library, location, size and call number

SELECT
	recs.library_name,
	recs.holdings_location_name,
	recs.title,
	CASE
		WHEN recs.item_call_number LIKE '%+++%' THEN '+++'
	    WHEN recs.item_call_number LIKE '%++%' THEN '++'
	    WHEN recs.item_call_number LIKE '%+%' THEN '+'
	    ELSE ''
	    END AS size_group,
	recs.item_call_number,
	recs.item_barcode,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.item_status_name,
	recs.item_status_date,
	recs.last_checkin_location,
	recs.last_checkin_date,
	recs.requester_last_name,
	recs.requester_first_name,
	recs.netid,
	recs.request_date,
	recs.pickup_service_point_name,
	recs.request_status,
	recs.days_since_requested

FROM recs
WHERE (recs.days_since_requested > 10 OR recs.days_since_requested IS NULL)

ORDER BY recs.library_name, recs.holdings_location_name, size_group, recs.shelving_order collate "C"
;
