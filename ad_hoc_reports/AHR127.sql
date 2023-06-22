-AHR127
--Management and Hotel peripherals and supplies 
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 6/22/2023

--This is an inventory query that finds Management and Hotel (Nestle) library items that show a material type of “Peripherals” or “Supplies”, and includes item status. 

SELECT 
                to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
                ll.library_name,
                ie.effective_location_name,
                ii.hrid AS instance_hrid,
                he.holdings_hrid,
                ie.item_hrid,
                ii.title,
                concat (ie.effective_call_number_prefix, ' ',ie.effective_call_number,' ',ie.effective_call_number_suffix) AS call_number,
                ie.enumeration,
                ie.chronology,
                ie.copy_number,
                ie.barcode,
                ie.material_type_name,
                ie.status_name AS item_status_name,
                to_char (ie.status_date::date,'mm/dd/yyyy') AS item_status_date

FROM inventory_instances AS ii 
                LEFT JOIN folio_reporting.holdings_ext AS he 
                ON ii.id = he.instance_id 
                
                LEFT JOIN folio_reporting.item_ext AS ie 
                ON he.holdings_id = ie.holdings_record_id 
                 
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON ie.effective_location_id = ll.location_id

WHERE ll.library_name IN ('Nestle Library','Sage Hall Management Library')
AND ie.material_type_name in ('Supplies','Peripherals')

ORDER BY ll.library_name, ie.effective_location_name, ie.material_type_name,ii.title, ie.effective_call_number, ie.enumeration, ie.chronology, ie.copy_number
;
