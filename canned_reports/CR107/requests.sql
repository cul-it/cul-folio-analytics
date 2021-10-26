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
       invlib.name AS owning_library,
       ri.pickup_service_point_name,
       ri.request_type,
       ri.request_status,
       ri.request_id,
       ri.request_date AS rdate,
       to_char(ri.request_date:: DATE,'mm/dd/yyyy') AS request_date,
       ri.item_effective_location_name,
       ih.call_number,
       ri.enumeration,
       ri.chronology,
       ri.item_copy_number,
       ri.barcode AS item_barcode,
       json_extract_path_text (ii.data,'status','name') AS item_status,
       to_char (json_extract_path_text (ii.data, 'status','date'):: DATE,'mm/dd/yyyy') AS item_status_date,
       itmnote.note AS item_note,
       ihi.title,
       json_extract_path_text (uu.data,'personal','lastName') AS requestor_last_name,
       json_extract_path_text (uu.data,'personal','firstName') AS requestor_first_name,
       uu.barcode AS patron_barcode,
       uu.active,
       ri.patron_group_name,
       cr.patron_comments
 FROM  
		folio_reporting.requests_items AS ri 
       	LEFT JOIN user_users AS uu ON ri.requester_id = uu.id 
       	LEFT JOIN folio_reporting.items_holdings_instances AS ihi ON ri.item_id = ihi.item_id
       	LEFT JOIN inventory_items AS ii ON ri.item_id = ii.id
       	LEFT JOIN folio_reporting.item_notes AS itmnote ON ri.item_id = itmnote.item_id
       	LEFT JOIN inventory_holdings AS ih ON ihi.holdings_id = ih.id
       	LEFT JOIN circulation_requests AS cr ON ri.request_id = cr.id
       	LEFT JOIN inventory_locations AS invloc ON ri.item_effective_location_name = invloc.name
       	LEFT JOIN inventory_libraries AS invlib ON invloc.library_id = invlib.id
 	 WHERE
        ri.request_date::DATE >= (SELECT start_date FROM parameters)
            AND ri.request_date::DATE < (SELECT end_date FROM parameters)
			AND (ri.request_status LIKE (SELECT request_status_filter FROM parameters))
            AND (ri.request_type LIKE (SELECT request_type_filter FROM parameters))
            AND (ri.patron_group_name LIKE (SELECT patron_group_filter FROM parameters))
            AND (invlib.name LIKE (SELECT owning_library_filter FROM parameters))
              
       ORDER BY owning_library, pickup_service_point_name, request_date, item_effective_location_name, call_number, enumeration, chronology, item_copy_number;
