--AHR 120
--vet_special_collections

SELECT 
       TO_CHAR (current_date::date,'mm/dd/yyyy') AS todays_date,
       ll.library_name,
       he.permanent_location_name AS holdings_location_name,
       ie.effective_location_name AS item_location_name,
       ii.title,
       TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology),
              CASE WHEN ie.copy_number >'1' then CONCAT ('c.',ie.copy_number) ELSE '' END) AS whole_call_number,
       he.copy_number AS holdings_copy_number,
       ie.barcode,
       ii.discovery_suppress AS instance_suppress,
       he.discovery_suppress AS holdings_suppress,
       STRING_AGG (distinct hs.statement,' | ') AS holdings_statements,
       STRING_AGG (distinct hn.note,' | ') AS holdings_notes,
       he.type_name AS holdings_type_name,
       ie.material_type_name,
       ie.permanent_loan_type_name,
       ie.status_name AS item_status_name,
       TO_CHAR (ie.status_date::date,'mm/dd/yyyy') AS item_status_date,
       ii.hrid AS instance_hrid,
       he.holdings_hrid,
       ie.item_hrid

FROM inventory_instances AS ii 
       LEFT JOIN folio_reporting.holdings_ext AS he 
       ON ii.id = he.instance_id 
       
       LEFT JOIN folio_reporting.locations_libraries AS ll 
       ON he.permanent_location_id = ll.location_id 
       
       LEFT JOIN folio_reporting.item_ext AS ie 
       ON he.holdings_id = ie.holdings_record_id
       
       LEFT JOIN inventory_items AS invitems 
       ON ie.item_id = invitems.id
       
       LEFT JOIN folio_reporting.holdings_statements AS hs 
       ON he.holdings_id = hs.holdings_id
       
       LEFT JOIN folio_reporting.holdings_notes AS hn 
       ON he.holdings_id = hn.holdings_id

WHERE 
       (ll.library_name = 'Veterinary Library' 
       AND hn.note ILIKE '%perman%shelved%')
       
       OR
       
       (ll.library_name = 'Veterinary Library'
       AND he.permanent_location_name !='Vet')

GROUP BY
       TO_CHAR (current_date::date,'mm/dd/yyyy'),
       ll.library_name,
       ii.title,
       he.permanent_location_name,
       ie.effective_location_name,
       TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology),
              CASE WHEN ie.copy_number >'1' then CONCAT ('c.',ie.copy_number) ELSE '' END),
       he.copy_number,
       ii.discovery_suppress,
       he.discovery_suppress,
       ie.barcode,
       he.type_name,
       ie.material_type_name,
       ie.permanent_loan_type_name,
       ie.status_name,
       TO_CHAR (ie.status_date::date,'mm/dd/yyyy'),
       ii.hrid,
       he.holdings_hrid,
       ie.item_hrid,
       invitems.effective_shelving_order

ORDER BY holdings_location_name, item_location_name, invitems.effective_shelving_order COLLATE "C", holdings_copy_number, title, holdings_hrid  ;
