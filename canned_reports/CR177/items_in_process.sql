WITH parameters AS 
        (SELECT
        '%%'::VARCHAR AS owning_library
        )

SELECT 
        TO_CHAR(CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
        ll.library_name as owning_library,
        he.permanent_location_name as holdings_location,
        ie.effective_location_name as item_location,
        ii.hrid,
        he.holdings_hrid,
        ie.item_hrid,
        ie.barcode,
        ie.material_type_name,
        ii.index_title,
        CONCAT_WS (' ',he.call_number_prefix, he.call_number, he.call_number_suffix, ie.enumeration, ie.chronology,
                CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END) AS whole_call_number,
        ie.status_name AS item_status,
        TO_CHAR (ie.status_date::DATE,'mm/dd/yyyy') AS item_status_date,
        CONCAT ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid) AS catalog_link

FROM inventory_instances AS ii 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN folio_reporting.item_ext AS ie 
        ON he.holdings_id = ie.holdings_record_id 
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id

WHERE ie.status_name = 'In process'
        AND ll.library_name ILIKE (SELECT owning_library from parameters)
        AND he.call_number NOT ILIKE '%In%ro%'
        and he.call_number NOT ILIKE '%Order%'
        
ORDER BY ie.status_date::DATE
;

