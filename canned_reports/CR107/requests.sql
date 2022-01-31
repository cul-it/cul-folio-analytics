WITH parameters AS (
    SELECT
  /*This is the date range for the requests; change the range as needed*/  
        '2021-09-01'::DATE AS start_date,
        '2021-11-01'::DATE AS end_date,
   /*Other filters - fill in or leave blank*/  
   /*Enter filter value IN BETWEEN the % signs, for example: %Open% ::VARCHAR AS request_status_filter */    
     	'%%'::VARCHAR AS request_status_filter, 
     	'%%'::VARCHAR AS request_type_filter, 
        '%%'::VARCHAR AS patron_group_filter, 
		'%%'::VARCHAR AS owning_library_filter
)

SELECT
        (
            SELECT
                start_date::VARCHAR
            FROM
                parameters) || ' to '::VARCHAR || (
            SELECT
                end_date::VARCHAR
            FROM
                parameters) AS date_range, 
 
        to_char(current_date,'mm/dd/yyyy') as todays_date,
		ri.request_id,
        invlib.name as owning_library,
        ri.pickup_service_point_name,
        ri.request_type,
        to_char (ri.request_date:: DATE,'mm/dd/yyyy') as request_date,
        ri.request_status,
        to_char(json_extract_path_text(cr.data,'metadata','updatedDate')::DATE,'mm/dd/yyyy') as request_status_date,
        ri.material_type_name,
        ri.item_effective_location_name,
        ih.call_number,
        ri.enumeration,
        ri.chronology,
        ri.item_copy_number,
        ri.barcode as item_barcode,
        json_extract_path_text (ii.data,'status','name') as item_status,
        to_char (json_extract_path_text (ii.data, 'status','date'):: DATE,'mm/dd/yyyy') as item_status_date,
        itmnote.note as item_note,
        ihi.title,
        json_extract_path_text (uu.data,'personal','lastName') as requestor_last_name,
        json_extract_path_text (uu.data,'personal','firstName') as requestor_first_name,
        uu.barcode as patron_barcode,
        uu.username as net_id,
        ug.group as patron_group,
        udu.department_name,
        udu.department_code,
        uu.active,
        cr.patron_comments

FROM
folio_reporting.requests_items as ri 
        LEFT JOIN user_users as uu on ri.requester_id = uu.id
        left join folio_reporting.users_departments_unpacked as udu on uu.id = udu.user_id
        LEFT JOIN folio_reporting.items_holdings_instances as ihi on ri.item_id = ihi.item_id
        LEFT JOIN inventory_items as ii on ri.item_id = ii.id
        LEFT JOIN folio_reporting.item_notes as itmnote on ri.item_id = itmnote.item_id
        LEFT JOIN inventory_holdings as ih on ihi.holdings_id = ih.id
        LEFT JOIN circulation_requests as cr on ri.request_id = cr.id
        LEFT JOIN inventory_locations as invloc on ri.item_effective_location_name = invloc.name
        LEFT JOIN inventory_libraries as invlib on invloc.library_id = invlib.id
        left join user_groups as ug on uu.patron_group = ug.id
        
WHERE
        ri.request_date::DATE >= (SELECT start_date FROM parameters)
            AND ri.request_date::DATE < (SELECT end_date FROM parameters)
	    AND (ri.request_status LIKE (SELECT request_status_filter FROM parameters))
            AND (ri.request_type LIKE (SELECT request_type_filter FROM parameters))
            AND (ug.group LIKE (SELECT patron_group_filter FROM parameters))
            AND (invlib.name LIKE (SELECT owning_library_filter FROM parameters))    
        
ORDER BY owning_library, pickup_service_point_name, request_date, item_effective_location_name, call_number, enumeration, chronology, item_copy_number;
