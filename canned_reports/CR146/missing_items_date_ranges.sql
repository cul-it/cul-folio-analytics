--Missing Items with Date Ranges

WITH parameters AS (
    SELECT 
         /* Enter the name of library location between the green single quotes below to see missing items for a specific location 
          * or leave blank to display all locations. For a list of all locations, refer to the FOLIO Reports Filter Directory 
          * at https://confluence.cornell.edu/display/folio/FOLIO+Reports+Filter+Directory */
    
        ''::VARCHAR AS owning_library_name_filter, -- Examples: Olin Library, Library Annex, etc.
          
        /* Enter freeform date range in YYYY-MM-DD format to see missing items in a specific date range
         * Comment out 2 lines below to use different date range and uncomment another date range
         * "interval" range from the selections that follow.*/         
        
        '2021-07-01'::DATE AS start_date,
        '2021-12-31'::DATE AS end_date
        
        /* Remove comments to see missing items from last 2 weeks */         
        --CURRENT_DATE - INTERVAL '2 weeks' AS start_date,
        --CURRENT_DATE AS end_date
  
        /* Remove comments to see missing items from last 6 months */         
        --CURRENT_DATE - INTERVAL '6 months' AS start_date,
        --CURRENT_DATE AS end_date
        
        /* Remove comments to see missing items from last year */        
        --CURRENT_DATE - INTERVAL '1 year' AS start_date,
        --CURRENT_DATE AS end_date       
        
        /* Remove comments to see missing items from last 2 years */        
        --CURRENT_DATE - INTERVAL '2 years' AS start_date,
        --CURRENT_DATE AS end_date
           
)
SELECT
        (SELECT start_date::varchar FROM parameters) || ' to '::varchar || (SELECT end_date::varchar FROM parameters) AS date_range,  
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        itemext.enumeration,
        itemext.chronology,
        itemext.copy_number,
        itemext.barcode,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        he.type_name,
        itemnotes.note,
        itemext.status_name,
        itemext.status_date::DATE,
        string_agg(srs."content",' | ') AS pagination_size,
        ii.effective_shelving_order
                
FROM folio_reporting.instance_ext AS instext
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON instext.instance_id = he.instance_id      
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id      
        LEFT JOIN folio_reporting.item_ext AS itemext 
        ON he.holdings_id = itemext.holdings_record_id       
        LEFT JOIN inventory_items AS ii 
        ON itemext.item_id = ii.id       
        LEFT JOIN folio_reporting.item_notes AS itemnotes
        ON itemext.item_id = itemnotes.item_id      
        LEFT JOIN srs_marctab AS srs 
        ON instext.instance_id = srs.instance_id
        
WHERE  (ll.library_name = (SELECT owning_library_name_filter FROM parameters)
        OR (SELECT owning_library_name_filter FROM parameters) = '')
    AND itemext.status_name LIKE '%issing%'    
    AND srs.field = '300'
 	AND (itemext.status_date::DATE >= (SELECT start_date FROM parameters)
    	AND itemext.status_date::DATE < (SELECT end_date FROM parameters))
    
GROUP BY 
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        itemext.enumeration,
        itemext.chronology,
        itemext.copy_number,
        itemext.barcode,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        he.type_name,
        itemext.status_name,
        itemext.status_date,
        itemnotes.note,
        ii.effective_shelving_order
        
ORDER BY 
date_range,
permanent_location_name, 
effective_shelving_order
;
