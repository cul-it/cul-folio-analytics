-- CR106: Missing items


WITH parameters AS (
    SELECT 
         -- Fill out owning library filter ----
         'Adelson Library'::VARCHAR AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc. See list of libraries at https://confluence.cornell.edu/display/folioreporting/Locations
        ),
recs AS 
(SELECT
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        TRIM (CONCAT_WS (' ', he.call_number_prefix, he.call_number, he.call_number_suffix, ii.enumeration, ii.chronology,
                        CASE WHEN ii.copy_number >'1' THEN concat ('c.', ii.copy_number) ELSE '' END)) AS whole_call_number,
        ii.barcode,
        itemext.status_name,
        TO_CHAR (itemext.status_date::DATE,'mm/dd/yyyy') AS item_status_date,       
        CASE WHEN ii.last_check_in__date_time IS NULL THEN NULL 
         ELSE to_char (ii.last_check_in__date_time::TIMESTAMP, 'mm/dd/yyyy hh:mi am') END AS last_folio_check_in,
        max(to_char(discharge_date::timestamp,'mm/dd/yyyy hh:mi am')) as last_voyager_check_in,
        isp.name as last_folio_check_in_service_point,
        string_agg (DISTINCT srs."content",' | ') AS pagination_size,
        string_agg (DISTINCT itemnotes.note,' | ') AS item_note,
        itemext.material_type_name,
        he.type_name,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
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
        
        LEFT JOIN vger.circ_trans_archive AS cta 
        ON ii.hrid::VARCHAR = cta.item_id::VARCHAR
        
        LEFT JOIN inventory_service_points AS isp 
        ON ii.last_check_in__service_point_id = isp.id
        
        LEFT JOIN folio_reporting.item_notes AS itemnotes
        ON itemext.item_id = itemnotes.item_id
        
        LEFT JOIN srs_marctab AS srs 
        ON instext.instance_hrid = srs.instance_hrid
        
WHERE  (ll.library_name = (SELECT owning_library_name_filter FROM parameters)
        OR (SELECT owning_library_name_filter FROM parameters) = '')
    AND itemext.status_name LIKE '%issing%'
        --AND itemext.status_date >'2021/01/01'
    AND srs.field = '300'
    AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)

GROUP BY 
        ll.library_name,
        he.permanent_location_name,
        instext.title,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        ii.enumeration,
        ii.chronology,
        ii.copy_number,
        ii.barcode,
        instext.discovery_suppress,
        he.discovery_suppress,
        instext.instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        itemext.material_type_name,
        he.type_name,
        itemext.status_name,
        itemext.status_date,
        ii.last_check_in__date_time,
        isp.name,
        ii.effective_shelving_order
)
        
SELECT 
        TO_CHAR (CURRENT_DATE::date,'mm/dd/yyyy') AS todays_date,
                recs.library_name,
        recs.permanent_location_name,
        recs.title,
        recs.whole_call_number,
        recs.barcode,
        recs.status_name,
        recs.item_status_date,       
        COALESCE (recs.last_folio_check_in, recs.last_voyager_check_in,'-') AS last_check_in_date, 
        COALESCE (recs.last_folio_check_in_service_point,location.Location_name,'-') AS last_check_in_location,       
        recs.pagination_size,
        recs.item_note,
        recs.material_type_name,
        recs.type_name,
        recs.instance_hrid,
        recs.holdings_hrid,
        recs.item_hrid
        
FROM recs 
   LEFT JOIN vger.circ_trans_archive AS cta 
   ON recs.last_voyager_check_in = TO_CHAR (cta.discharge_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') 
      AND recs.item_hrid = cta.item_id::VARCHAR
        
   LEFT JOIN vger.location 
   ON cta.discharge_location = location.location_id
        
ORDER BY permanent_location_name, effective_shelving_order
;

