--MCR409
--Active Patrons in Cornell Tech

--Query writer: Joanne Leary (jl41)
--Query posted in: 9/9/25

-- This query finds all active patrons in Cornell Tech. 
-- Because there is no standard department name or College code for Cornell Tech, we need to look at both fields and apply criteria.
-- Revised query for address fields. 8-14-23.
-- Revised to make the create date and update dates appear as dates in Excel - 8-26-24
-- Revised for Metadb - 9-8-25

WITH recs AS 
(SELECT DISTINCT
    to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
    jsonb_extract_path_text (users.jsonb,'personal','lastName') AS last_Name,
    jsonb_extract_path_text (users.jsonb,'personal','firstName') AS first_Name,
    users__t.username AS patron_netid,
    users__t.barcode,
    CASE WHEN users__t.active = true THEN 'ACTIVE' ELSE 'EXPIRED' END AS patron_status,
    users__t.created_date::DATE AS create_date,
    users__t.updated_date::DATE AS updated_date,
    STRING_AGG (groups__t.group,' | ') AS patron_group_name,
    users.jsonb#>>'{customFields,college}' AS college,
    users.jsonb#>>'{customFields,department}' AS department,
    users_addresses.address_type_name,
    CONCAT (users_addresses.address_line_1,' ',users_addresses.address_line_2,' ',users_addresses.address_city,', ',users_addresses.address_region,' ',users_addresses.address_postal_code) as full_address

FROM
    folio_users.users
    LEFT JOIN folio_users.users__t 
    on users.id = users__t.id 
    
    LEFT JOIN folio_users.groups__t 
    on users__t.patron_group = groups__t.id
    
    LEFT JOIN folio_derived.users_addresses
    on users__t.id = users_addresses.user_id 
    
WHERE 
	users__t.active = true
	AND 
	(jsonb_extract_path_text(users.jsonb, 'personal', 'addresses') LIKE '%Loop R%%New York%' 
		OR jsonb_extract_path_text(users.jsonb,'personal','addresses') LIKE '%10044%'
		OR jsonb_extract_path_text (users.jsonb,'customFields','college') ILIKE '%TECH%')
	
GROUP BY 
    jsonb_extract_path_text (users.jsonb,'personal','lastName'),
    jsonb_extract_path_text (users.jsonb,'personal','firstName'),
    users__t.username,
    users__t.barcode,
    CASE WHEN users__t.active = true THEN 'ACTIVE' ELSE 'EXPIRED' END,
    users__t.created_date::DATE,
    users__t.updated_date::DATE,
    users.jsonb#>>'{customFields,college}',
    users.jsonb#>>'{customFields,department}',
    users_addresses.address_type_name,
    CONCAT (users_addresses.address_line_1,' ',users_addresses.address_line_2,' ',users_addresses.address_city,', ',users_addresses.address_region,' ',users_addresses.address_postal_code)

   )
   
SELECT 
	recs.todays_date,
	recs.last_name,
	recs.first_name,
	recs.patron_netid,
	recs.barcode,
	recs.patron_status,
	recs.create_date,
	recs.updated_date,
	STRING_AGG (distinct recs.patron_group_name,' | ') as patron_group,
	STRING_AGG (distinct recs.college,' | ') as college,
	STRING_AGG (distinct recs.department,' | ') as department_name,
	STRING_AGG (distinct address_type_name,' | '),
	STRING_AGG (distinct full_address,' | ') as full_address
FROM recs
GROUP BY 
	recs.todays_date,
	recs.last_name,
	recs.first_name,
	recs.patron_netid,
	recs.barcode,
	recs.patron_status,
	recs.create_date,
	recs.updated_date
		
ORDER BY last_Name, first_Name;
