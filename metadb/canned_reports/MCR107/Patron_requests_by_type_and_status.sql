--MCR107
--Patron_requests_by_type_and_status
--This query provides a list of patron requests within a specified date range, and by request type. Data fields also included are patron group, patron status, delivery method (pick-up vs. delivery), owning location, pick-up location.
--Query writer: Joane Leary (JL41)
--Posted on: 6/24/24


WITH parameters AS (
    SELECT
  /*This is the date range for the requests; change the range AS needed*/  
        '2023-07-01' AS start_date, --enter date in YYYY-MM-DD format
        '2024-07-01' AS end_date, --enter date in YYYY-MM-DD format
   /*Other filters - fill in or leave blank*/  
   /*Enter filter value IN BETWEEN the % signs, for example: %Open% ::VARCHAR AS request_status_filter */    
     	'%%'::VARCHAR AS request_status_filter, 
     	'%%'::VARCHAR AS request_type_filter, 
        '%%'::VARCHAR AS patron_group_filter, 
		'%%'::VARCHAR AS owning_library_filter
)

SELECT 
       (SELECT start_date::VARCHAR FROM parameters) || ' to '::VARCHAR || (SELECT end_date::VARCHAR FROM parameters) AS date_range, 
        to_char(current_date,'mm/dd/yyyy') AS todays_date,
	requests_items.request_id,
        folio_inventory.loclibrary__t."name" AS owning_library,
        requests_items.pickup_service_point_name,
        requests_items.request_type,
        to_char (requests_items.request_date:: DATE,'mm/dd/yyyy') AS request_date,
        requests_items.request_status,
        MAX (jsonb_extract_path_text(folio_circulation.request__.jsonb, 'metadata', 'updatedDate')::DATE) as request_status_date,
        requests_items.material_type_name,
        requests_items.item_effective_location_name, --not same as folio_inventory.loclibrary__t."name"
        folio_inventory.holdings_record__t.call_number,
        requests_items.enumeration,
        requests_items.chronology,
        requests_items.item_copy_number,
        requests_items.barcode AS item_barcode,
        jsonb_extract_path_text (folio_inventory.item__.jsonb,'status','name') AS item_status,
        to_char (jsonb_extract_path_text (folio_inventory.item__.jsonb, 'status','date'):: DATE,'mm/dd/yyyy') AS item_status_date,
        string_agg (distinct item_notes.note,' | ') AS item_note,
        items_holdings_instances.title,
        jsonb_extract_path_text(users__.jsonb,'personal','lastName') AS requestor_last_name,
        jsonb_extract_path_text(users__.jsonb,'personal','firstName') AS requestor_first_name,
        jsonb_extract_path_text(users__.jsonb,'barcode') AS patron_barcode,
        jsonb_extract_path_text(users__.jsonb,'username') AS netid,
        groups__t.group as patron_group,
        users_departments_unpacked.department_name,
        users_departments_unpacked.department_code,
        jsonb_extract_path_text (users__.jsonb, 'active') AS active,
        jsonb_extract_path_text(folio_circulation.request__.jsonb, 'patronComments') AS patron_comments 

FROM
folio_derived.requests_items   
        LEFT JOIN folio_users.users__  ON folio_derived.requests_items.requester_id = folio_users.users__.id
        LEFT JOIN folio_derived.users_departments_unpacked ON folio_users.users__.id = folio_derived.users_departments_unpacked.user_id
        LEFT JOIN folio_derived.items_holdings_instances ON folio_derived.requests_items.item_id = folio_derived.items_holdings_instances.item_id
        LEFT JOIN folio_inventory.item__ ON folio_derived.requests_items.item_id = folio_inventory.item__.id
        LEFT JOIN folio_derived.item_notes ON folio_derived.requests_items.item_id = folio_derived.item_notes.item_id
        LEFT JOIN folio_inventory.holdings_record__t ON folio_derived.items_holdings_instances.holdings_id = folio_inventory.holdings_record__t.id
        LEFT JOIN folio_circulation.request__ ON folio_derived.requests_items.request_id = folio_circulation.request__.id
        --Below: In the LDP query, we have the join below as: LEFT JOIN inventory_locations as invloc on folio_reporting.requests_items.item_effective_location_name = invloc.name
        --This won't work in Metadb because the 'name' in inventory.location__t is NOT the same as the item_effective_location_name in the derived table requests_items. 
        LEFT JOIN folio_inventory.location__t ON folio_derived.requests_items.item_effective_location_id= folio_inventory.location__t.id      
        LEFT JOIN folio_inventory.loclibrary__t ON folio_inventory.location__t.library_id=folio_inventory.loclibrary__t.id
        --Below: Did not users.users__t because we anyway need to use the users_users__ table to extract names
        LEFT JOIN folio_users.groups__t ON folio_users.users__.patrongroup = folio_users.groups__t.id
        
WHERE
       	(((SELECT start_date FROM parameters) ='') OR (requests_items.request_date >= (SELECT start_date FROM parameters)::DATE)) 
     		AND (((SELECT end_date FROM parameters) ='') OR (requests_items.request_date < (SELECT end_date FROM parameters)::DATE))
     and item__.__current = 'true'
     and users__.__current = 'true'  
	    AND ((requests_items.request_status LIKE (SELECT request_status_filter FROM parameters)) OR (SELECT request_status_filter FROM parameters) = '' )
            AND ((requests_items.request_type LIKE (SELECT request_type_filter FROM parameters)) OR (SELECT request_type_filter FROM parameters)  = '')
            AND ((folio_users.groups__t.group LIKE (SELECT patron_group_filter FROM parameters)) OR (SELECT patron_group_filter FROM parameters)  = '')
            AND ((folio_inventory.loclibrary__t.name LIKE (SELECT owning_library_filter FROM parameters)) OR (SELECT owning_library_filter FROM parameters)  = '')    
            
group by 
(SELECT start_date::VARCHAR FROM parameters) || ' to '::VARCHAR || (SELECT end_date::VARCHAR FROM parameters), 
        to_char(current_date,'mm/dd/yyyy'),
	requests_items.request_id,
        folio_inventory.loclibrary__t."name",
        requests_items.pickup_service_point_name,
        requests_items.request_type,
        to_char (requests_items.request_date:: DATE,'mm/dd/yyyy'),
        requests_items.request_status,
        requests_items.material_type_name,
        requests_items.item_effective_location_name, --not same as folio_inventory.loclibrary__t."name"
        folio_inventory.holdings_record__t.call_number,
        requests_items.enumeration,
        requests_items.chronology,
        requests_items.item_copy_number,
        requests_items.barcode,
        jsonb_extract_path_text (folio_inventory.item__.jsonb,'status','name'),
        to_char (jsonb_extract_path_text (folio_inventory.item__.jsonb, 'status','date'):: DATE,'mm/dd/yyyy'),
        items_holdings_instances.title,
        jsonb_extract_path_text(users__.jsonb,'personal','lastName'),
        jsonb_extract_path_text(users__.jsonb,'personal','firstName'),
        jsonb_extract_path_text(users__.jsonb,'barcode'),
        groups__t.group,
        jsonb_extract_path_text(users__.jsonb,'username'),
        users_departments_unpacked.department_name,
        users_departments_unpacked.department_code,
        jsonb_extract_path_text (users__.jsonb, 'active'),
        jsonb_extract_path_text(folio_circulation.request__.jsonb, 'patronComments')
        
ORDER BY owning_library, pickup_service_point_name, request_date, item_effective_location_name, call_number, enumeration, chronology, item_copy_number;
