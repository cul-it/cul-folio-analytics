WITH parameters AS (
    SELECT 
         -- Fill out -owning library filter ----
         'Olin Library'::varchar AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc.
        )
SELECT
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
        itemext.chronology,' ',CASE WHEN itemext.copy_number > '1' THEN CONCAT ('c.',itemext.copy_number) ELSE '' END) as whole_call_number,
        itemext.barcode,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        itemext.material_type_name,
        itemnotes.note,
        itemext.status_name,
        to_char(itemext.status_date::DATE,'mm/dd/yyyy') as item_status_date,
        string_agg(srs."content",' | ') AS pagination_size,
        CONCAT ('https://newcatalog.library.cornell.edu/catalog/', ii.hrid) AS catalog_link,
        ii.effective_shelving_order COLLATE "C"

                
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
    AND itemext.status_name ILIKE '%in process%'
        --AND itemext.status_date >'2019/01/01'
    AND (srs.field = '300' or srs.field is null)
    AND he.call_number NOT ILIKE '%In%ro%'
        AND he.call_number NOT ILIKE '%Order%'
        AND he.call_number not ILIKE '%Cancelled%'

GROUP BY 
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        itemext.effective_call_number_prefix,
        itemext.effective_call_number,
        itemext.effective_call_number_suffix,
        itemext.enumeration,
        itemext.chronology,
        itemext.copy_number,
        itemext.barcode,
        ii.hrid,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        itemext.material_type_name,
        itemext.status_name,
        itemext.status_date,
        itemnotes.note,
        ii.effective_shelving_order
        
 
ORDER BY permanent_location_name, effective_shelving_order COLLATE "C",  title
;

