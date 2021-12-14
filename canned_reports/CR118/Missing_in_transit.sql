WITH parameters AS (
    SELECT
        		
        ---- Fill out owning library filter ----
        'Library Annex'::varchar AS owning_library_filter -- 'Olin Library, Mann Library, etc.'
        
),

audit1 AS 
                (SELECT
                    items.ordinality,
                    json_extract_path_text(items.data, 'itemBarcode') AS item_barcode,
                    max(acl.date) as latest_action_date
                FROM
                    audit_circulation_logs as acl
                    CROSS JOIN LATERAL json_array_elements(json_extract_path(data, 'items')) WITH ORDINALITY AS items (data)
                
                WHERE acl.description like '%n transit%'
                
                GROUP BY 
                    items.ordinality,
                    json_extract_path_text(items.data, 'itemBarcode')            
                    ),
audit2 AS 
                (SELECT
                    acl.service_point_id,
                    items.ordinality,
                    json_extract_path_text(items.data, 'itemBarcode') AS audit2_item_barcode,
                    acl.date AS audit2_action_date
                FROM
                    audit_circulation_logs AS acl
                    CROSS JOIN LATERAL json_array_elements(json_extract_path(data, 'items')) WITH ORDINALITY AS items (data)
                
                WHERE acl.description LIKE '%n transit%'
),
                
servpt AS 
                (SELECT distinct
                        audit1.item_barcode,
                        audit1.latest_action_date,
                        max(audit2.audit2_action_date),
                        audit2.audit2_item_barcode,
                        audit2.service_point_id,
                        isp.id,
                        isp.name AS discharge_service_point
                        
                FROM
                        audit1
                        INNER JOIN audit2 ON audit2.audit2_action_date = audit1.latest_action_date
                        INNER JOIN inventory_service_points AS isp ON audit2.service_point_id = isp.id
                GROUP BY 
                        audit1.item_barcode,
                        audit1.latest_action_date,
                        audit2.audit2_item_barcode,
                        audit2.service_point_id,
                        isp.id,
                        isp.name)
    
---------MAIN QUERY---------

SELECT distinct
        ll.library_name,
        ixt.instance_hrid,
        he.holdings_hrid,
        iext.item_hrid,
        ixt.title,
        iext.barcode,
        he.permanent_location_name,
        iext.effective_location_name as item_effective_location,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        iext.enumeration,
        iext.chronology,
        iext.copy_number,
        iext.material_type_name,
        iext.status_name,
        to_char(CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
        to_char(iext.status_date::DATE,'mm/dd/yyyy') AS item_status_date,
        DATE_PART('day', NOW() - date(iext.status_date::DATE)) AS days_in_transit,
        servpt.discharge_service_point,
        iext.in_transit_destination_service_point_name,
        ii.effective_shelving_order

FROM folio_reporting.instance_ext as ixt 
        LEFT JOIN folio_reporting.holdings_ext as he 
        ON ixt.instance_id = he.instance_id 
        
        LEFT JOIN folio_reporting.item_ext as iext 
        ON he.holdings_id = iext.holdings_record_id
        
        LEFT JOIN servpt
        ON iext.barcode = servpt.item_barcode
        
        left join audit1 
        on iext.status_date::DATE = audit1.latest_action_date::DATE
        
        LEFT JOIN inventory_items as ii 
        ON iext.item_id = ii.id
        
        LEFT JOIN folio_reporting.locations_libraries as ll 
        ON he.permanent_location_id = ll.location_id 
 
        WHERE ll.library_name = (SELECT owning_library_filter FROM parameters)
        AND  iext.status_name = 'In transit'
            	
ORDER BY permanent_location_name, effective_shelving_order, barcode
;

