--CR193
--filled_delivery_requests

WITH PARAMETERS AS (
SELECT
	/* Choose a start and end date for the requests period */
	?::date AS start_date,
	?::date AS end_date)
   ,
   
users AS 
(
SELECT
	uu.id,
	json_extract_path_text (uu.data,
	'personal',
	'lastName') AS requestor_last_name,
	json_extract_path_text (uu.data,
	'personal',
	'firstName') AS requestor_first_name
FROM
	user_users AS uu 
)

SELECT
	to_char(current_date::DATE, 'mm/dd/yyyy') AS todays_date,
	ri.request_type,
	ll.library_name AS owning_library,
	ri.item_effective_location_name AS item_location,
	ri.patron_group_name,
	ri.pickup_service_point_name,
	CASE
		WHEN ri.pickup_service_point_name LIKE '%Contactless%' THEN 'Contactless Pickup'
		ELSE 'Circ Desk Pickup'
	END AS pickup_type,
	
	CASE WHEN
    	date_part ('month',ri.request_date ::DATE) >'6' 
        THEN concat ('FY ', date_part ('year',ri.request_date::DATE) + 1) 
        ELSE concat ('FY ', date_part ('year',ri.request_date::DATE))
        END as fiscal_year_of_request,
                
	count(ri.request_id) AS number_of_requests
	
FROM
	folio_reporting.requests_items AS ri
LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON
	ri.item_effective_location_id = ll.location_id
LEFT JOIN users 
                ON
	ri.requester_id = users.id
WHERE
		ri.request_date::DATE >= (SELECT start_date FROM Parameters)
	AND ri.request_date::DATE <(SELECT end_date FROM Parameters)
	AND ri.request_status IN ('Closed - Filled', 'Closed - Pickup expired', 'Open - In transit', 'Open - Awaiting pickup')
	AND ri.material_type_name NOT IN ('BD MATERIAL', 'ILL MATERIAL')
	AND ri.item_effective_location_name !~~* 'Borrow%'
	AND ri.item_effective_location_name !~~* 'Interlibrary%'
	AND users.requestor_last_name !~~* '%reserve%'
	AND users.requestor_first_name !~~* '%reserve%'
	AND users.requestor_last_name !~~* 'Collection'
	AND users.requestor_last_name !~~* '%Bindery%'
	AND users.requestor_last_name !~~* '%Conservation%'
	AND users.requestor_last_name !~~* '%heine%'
	AND users.requestor_last_name !~~* '%DMG%'
	AND users.requestor_last_name !~~* '%New books%'
	AND users.requestor_last_name !~~* '%project%'
	--and ri.request_type = 'Page'
GROUP BY
	to_char(current_date::DATE, 'mm/dd/yyyy'),
	ll.library_name,
	ri.request_type,
	ri.request_status,
	ri.pickup_service_point_name,
	ri.patron_group_name,
	ri.item_effective_location_name,
	ri.material_type_name,
	fiscal_year_of_request
ORDER BY
	owning_library,
	item_effective_location_name,
	patron_group_name,
	pickup_service_point_name 
;
