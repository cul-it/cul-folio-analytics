
WITH parameters AS (
    SELECT 
         -- Fill out -owning library filter ----
         'ILR Library'::varchar AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc.
        )
SELECT
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
        string_agg(distinct itemnotes.note,' | ') as item_note,
        itemext.status_name,
        to_char(itemext.status_date::DATE,'mm/dd/yyyy') as item_status_date,
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
        ON instext.instance_hrid = srs.instance_hrid
        
WHERE  (ll.library_name = (SELECT owning_library_name_filter FROM parameters)
        OR (SELECT owning_library_name_filter FROM parameters) = '')
    AND itemext.status_name LIKE '%issing%'
        --AND itemext.status_date >'2019/01/01'
    AND srs.field = '300'

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
        ii.effective_shelving_order
        
 
ORDER BY permanent_location_name, effective_shelving_order
;
