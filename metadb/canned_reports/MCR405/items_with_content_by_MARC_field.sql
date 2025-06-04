-- MCR405
-- items_with_content_by_MARC_field
-- Last updated: 11-8-24
-- Written by Sharon Markus, reviewed by Joanne Leary
-- This query finds items within a specified MARC field with a specified entry in the content field on the MARC table. 
-- The MARC 899 field with 'CULectures' in the MARC content field are included as examples, which can be replaced
-- with different criteria. The results include location, item HRID, instance HRID, barcode, title, item status, 
-- and format for the records found.  

SELECT DISTINCT
    sm.field,
    sm.content,
    itemext.permanent_location_name,
    sm.instance_hrid,
    itemext.item_hrid,
    itemext.barcode,
    instext.title,
    itemext.status_name AS item_status,
    itemext.material_type_name AS format
    
FROM
    folio_source_record.marc__t AS sm  
    LEFT JOIN folio_derived.instance_ext AS instext ON instext.instance_hrid = sm.instance_hrid  
    LEFT JOIN folio_derived.holdings_ext AS he ON instext.instance_id = he.instance_id  
    LEFT JOIN folio_derived.locations_libraries AS ll ON he.permanent_location_id = ll.location_id  
    LEFT JOIN folio_derived.item_ext AS itemext ON he.id = itemext.holdings_record_id  
    LEFT JOIN folio_inventory.item__t AS ii ON itemext.item_id = ii.id 
    LEFT JOIN folio_derived.item_notes AS itemnotes ON itemext.item_id = itemnotes.item_id  

WHERE sm.field = '899'
   AND sm.content LIKE '%CULectures%'

GROUP BY
    sm.field,
    sm.content,
    sm.instance_hrid,
    sm.instance_id,
    ll.library_name,           
    itemext.permanent_location_name,
    instext.instance_hrid,
    he.holdings_hrid,
    itemext.item_id,
    itemext.item_hrid,
    itemext.barcode,
    instext.title,
    itemext.status_name,
    itemext.material_type_name
;
