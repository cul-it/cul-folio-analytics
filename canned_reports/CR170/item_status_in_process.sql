WITH parameters AS (
    SELECT 
         -- Fill out -owning library filter ----
         '%%'::varchar AS owning_library 
        )

select 
	to_char(current_date::DATE,'mm/dd/yyyy') as todays_date,
	ll.library_name as owning_library,
	he.permanent_location_name as holdings_location,
	ie.effective_location_name as item_location,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.barcode,
	ie.material_type_name,
	ii.index_title,
	concat_ws(' ',he.call_number_prefix,he.call_number, he.call_number_suffix, ie.enumeration, ie.chronology,
		case when ie.copy_number >'1' then concat('c.',ie.copy_number) else '' END) as whole_call_number,
	ie.status_name as item_status,
	to_char(ie.status_date::DATE,'mm/dd/yyyy') as item_status_date,
	concat('https://newcatalog.library.cornell.edu/catalog/',ii.hrid) as catalog_link

from inventory_instances as ii 
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id 
	
	left join folio_reporting.item_ext as ie 
	on he.holdings_id = ie.holdings_record_id 
	
	left join folio_reporting.locations_libraries as ll 
	on he.permanent_location_id = ll.location_id

where ie.status_name = 'In process'
	and ((ll.library_name ilike (select owning_library from parameters) OR (ll.library_name ilike '')))
	and he.call_number not ilike '%In%rocess%'
	and he.call_number not ilike '%Order%'
--	and  (ll.library_name = (SELECT owning_library_name_filter FROM parameters)
      --  OR (SELECT owning_library_name_filter FROM parameters) = '')
	
order by holdings_location, he.call_number, ie.status_date, index_title ;
