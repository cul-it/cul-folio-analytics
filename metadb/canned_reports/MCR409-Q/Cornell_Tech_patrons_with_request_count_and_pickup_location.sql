-- MCR409-Q - This query finds all active patrons in Cornell Tech, and shows request count and pickup location 
-- Because there is no standard department name or College code for Cornell Tech, we need to look at both fields and apply criteria.
-- Revised query for address fields. 8-14-23.
-- Revised to make the create date and update dates appear as dates in Excel - 8-26-24
-- Revised for Metadb - 9-8-25
-- 8-26-26: updated patron record created date to come from users table, and not users__t table
-- 8-26-26: added request count and pickup location detail (Elaine request)
-- Query writer: Joanne Leary (jl41)


WITH recs AS 
(SELECT DISTINCT
    to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
    jsonb_extract_path_text (users.jsonb,'personal','lastName') AS last_Name,
    jsonb_extract_path_text (users.jsonb,'personal','firstName') AS first_Name,
    users__t.username AS patron_netid,
    users__t.barcode,
    CASE WHEN users__t.active = true THEN 'ACTIVE' ELSE 'EXPIRED' END AS patron_status,
    --users__t.created_date::DATE AS create_date,
    users.creation_date::date as patron_record_created_date,
    users__t.updated_date::DATE AS patron_record_updated_date,
    STRING_AGG (distinct groups__t.group,' | ') AS patron_group_name,
    users.jsonb#>>'{customFields,college}' AS college,
    users.jsonb#>>'{customFields,department}' AS department,
    users_addresses.address_type_name,
    CONCAT (users_addresses.address_line_1,' ',users_addresses.address_line_2,' ',users_addresses.address_city,', ',users_addresses.address_region,' ',users_addresses.address_postal_code) as full_address,
	case 
		when service_point__t.name = 'Cornell Tech Remote Program' then 'Cornell Tech pickup'
		when service_point__t.name != 'Cornell Tech Remote Program' then 'Other pickup location'
		else null
		end as pickup_service_point,
	date_part ('year',request__t.request_date::date) as year_of_request,
	count (distinct request__t.id) as count_of_requests
	
FROM
    folio_users.users
    LEFT JOIN folio_users.users__t 
    on users.id = users__t.id 
    
    LEFT JOIN folio_users.groups__t 
    on users__t.patron_group = groups__t.id
    
    LEFT JOIN folio_derived.users_addresses
    on users__t.id = users_addresses.user_id
    
    left join folio_circulation.request__t 
    on users__t.id = request__t.requester_id
    
    left join folio_inventory.service_point__t 
    on request__t.pickup_service_point_id = service_point__t.id
       
WHERE 
	users__t.active = true
	AND 
	(jsonb_extract_path_text(users.jsonb, 'personal', 'addresses') LIKE '%Loop R%%New York%' 
		OR jsonb_extract_path_text(users.jsonb,'personal','addresses') LIKE '%10044%'
		OR jsonb_extract_path_text (users.jsonb,'customFields','college') ILIKE '%TECH%')
	--and (service_point__t.code = 'remote,tech' or service_point__t.id is null)
	--and (service_point__t2.code != 'remote,tech' or service_point__t2.id is null)
	
GROUP BY 
    jsonb_extract_path_text (users.jsonb,'personal','lastName'),
    jsonb_extract_path_text (users.jsonb,'personal','firstName'),
    users__t.username,
    users__t.barcode,
    CASE WHEN users__t.active = true THEN 'ACTIVE' ELSE 'EXPIRED' END,
    --users__t.created_date::DATE,
    users.creation_date::date,
    users__t.updated_date::DATE,
    users.jsonb#>>'{customFields,college}',
    users.jsonb#>>'{customFields,department}',
    users_addresses.address_type_name,
    CONCAT (users_addresses.address_line_1,' ',users_addresses.address_line_2,' ',users_addresses.address_city,', ',users_addresses.address_region,' ',users_addresses.address_postal_code),
	date_part ('year',request__t.request_date::date),
    case 
		when service_point__t.name = 'Cornell Tech Remote Program' then 'Cornell Tech pickup'
		when service_point__t.name != 'Cornell Tech Remote Program' then 'Other pickup location'
		else null
		end
   )
   
SELECT 
	recs.todays_date,
	recs.last_name,
	recs.first_name,
	recs.patron_netid,
	recs.barcode,
	recs.patron_status,
	recs.patron_record_created_date,
	recs.patron_record_updated_date,
	STRING_AGG (distinct recs.patron_group_name,' | ') as patron_group,
	STRING_AGG (distinct recs.college,' | ') as college,
	STRING_AGG (distinct recs.department,' | ') as department_name,
	STRING_AGG (distinct address_type_name,' | ') as address_type,
	STRING_AGG (distinct full_address,' | ') as full_address,
	recs.year_of_request,
	recs.pickup_service_point,
	recs.count_of_requests
	
FROM recs
GROUP BY 
	recs.todays_date,
	recs.last_name,
	recs.first_name,
	recs.patron_netid,
	recs.barcode,
	recs.patron_status,
	recs.patron_record_created_date,
	recs.patron_record_updated_date,
	recs.year_of_request,
	recs.pickup_service_point,
	recs.count_of_requests
		
ORDER BY last_Name, first_Name;
