--MCR413 
--marc_field_call_number_string_match.sql 
--Last updated: 11/10/25 
  
--This query retrieves MARC field data that matches items with a particular text string in the call number.

--The query spefically reports on the following MARC fields for all items with a call number that starts with "Disk," 
--and provides relevant inventory fields and the effective location name for items in the results. 
--Replace 'Disk' and the MARC fields indicated below to adjust query for similar purpose.

--Written by: Sharon Marcus, Reviewed by: Joanne Leary


SELECT DISTINCT
    sm.instance_hrid,
    he.holdings_hrid,
    itemext.item_hrid,
    itemext.barcode,
    TRIM(CONCAT(
        itemext.effective_call_number_prefix, ' ',
        itemext.effective_call_number, ' ',
        itemext.effective_call_number_suffix, ' ',
        CASE WHEN itemext.copy_number >'1' then CONCAT ('c.',itemext.copy_number) else ' ' end )) AS call_number,
    itemext.effective_location_name,
    sm.field,
    sm.content,
    sm.sf AS subfield,
    instext.title,
    itemext.status_name AS item_status,
    itemext.material_type_name AS format
    
FROM 
folio_derived.instance_ext AS instext 
LEFT JOIN folio_derived.holdings_ext AS he ON instext.instance_id = he.instance_id
LEFT JOIN folio_derived.item_ext AS itemext ON he.id = itemext.holdings_record_id
LEFT JOIN folio_derived.locations_libraries AS ll ON he.permanent_location_id = ll.location_id
LEFT JOIN folio_source_record.marc__t AS sm ON instext.instance_id = sm.instance_id
LEFT JOIN folio_source_record.records_lb as rec ON sm.instance_id = rec.external_id

WHERE
  TRIM(CONCAT(
        itemext.effective_call_number_prefix, ' ',
        itemext.effective_call_number, ' ',
        itemext.effective_call_number_suffix, ' ',
        CASE WHEN itemext.copy_number >'1' 
           THEN CONCAT ('c.',itemext.copy_number) ELSE ' ' END )) ILIKE '%Disk%'
 
  AND rec.state = 'ACTUAL' 
  AND (he.discovery_suppress = FALSE OR he.discovery_suppress IS NULL)
  AND sm.field IN ('035','041','245','260','300','500','538','546')

  --AND itemext.item_hrid = '10544767'  -- uncomment to just get results for one item HRID
  
GROUP BY
    sm.instance_hrid,
    he.holdings_hrid,
    itemext.item_hrid,
    itemext.barcode,
    TRIM(CONCAT(
        itemext.effective_call_number_prefix, ' ',
        itemext.effective_call_number, ' ',
        itemext.effective_call_number_suffix, ' ',
        CASE WHEN itemext.copy_number >'1' then CONCAT ('c.',itemext.copy_number) else ' ' end )),
    itemext.effective_location_name,
    sm.field,
    sm.content,
    sm.sf,
    instext.title,
    itemext.status_name,
    itemext.material_type_name

ORDER BY
    sm.field,
    sm.sf
    ;
