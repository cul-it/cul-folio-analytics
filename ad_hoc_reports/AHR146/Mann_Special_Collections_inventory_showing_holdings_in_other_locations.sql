--AHR146
--Mann_Special_Collections_inventory_showing_holdings_in_other_locations 
--This query shows Mann special collections inventory with holdings in other locations. 
--Query writeer: Joanne Leary (jl41)
--Query posted on: 5/31/24


-- 1. Get Mann Spec instances

with mann_inst as 
(select 
	ii.id as instance_id,
	ii.hrid as instance_hrid
	
	from inventory_instances as ii 
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id
	
	where he.permanent_location_name = 'Mann Special Collections'
),

--2. Get other locations and holdings

other_locs as 
(select 
	mann_inst.instance_id,
	mann_inst.instance_hrid,
	string_agg (distinct ll.library_name,chr(10)) as other_library_name,
	string_agg (concat (he.holdings_hrid,' | ',he.permanent_location_name,' ',concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,
		case when he.copy_number >'1' then concat ('c.',he.copy_number) else '' end), '  ',hs.statement),chr(10) order by he.permanent_location_name, he.holdings_hrid, hs.statement) 
		as other_holdings_statement

from mann_inst 
	inner join folio_reporting.holdings_ext as he 
	on mann_inst.instance_id = he.instance_id
	
	left join folio_reporting.holdings_statements as hs 
	on he.holdings_id = hs.holdings_id
	
	inner join folio_reporting.locations_libraries as ll 
	on he.permanent_location_id = ll.location_id

where he.permanent_location_name !='Mann Special Collections'
and (he.discovery_suppress = 'False' or he.discovery_suppress is null)

group by 
	mann_inst.instance_id,
	mann_inst.instance_hrid
)

--3. Get Mann Spec records and join to other locations records

select 
	ll.library_name,
	he.permanent_location_name,
	invloc.code as location_code,
	ii.title,			
	trim (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix,invitems.enumeration,invitems.chronology,
		CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)) as whole_call_number,
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	invitems.hrid AS item_hrid,
	invitems.barcode,
	ie.status_name as item_status_name,
	ie.status_date::date as item_status_date,
	string_agg (distinct itemnotes.note,' | ') as item_notes,	
	ie.material_type_name as item_material_type_name,
	he.type_name as holdings_type_name,
	instext.mode_of_issuance_name as instance_mode_of_issuance_name,
	string_agg (distinct hn.note,' | ') as Mann_spec_holdings_notes,
	string_agg (distinct hs.statement,chr(10)) as mann_spec_holdings_statements,
	other_locs.other_library_name,
	other_locs.other_holdings_statement,	
	concat ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid) as catalog_url,
	invitems.effective_shelving_order

from inventory_instances as ii 
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id
	
	LEFT JOIN inventory_items AS invitems 
	ON he.holdings_id = invitems.holdings_record_id
	
	left join other_locs 
	on ii.id = other_locs.instance_id
	
	left join folio_reporting.item_ext as ie 
	on invitems.id = ie.item_id
	
	left join folio_reporting.item_notes as itemnotes
	on invitems.id = itemnotes.item_id
	
	left join folio_reporting.holdings_statements as hs 
	on he.holdings_id = hs.holdings_id
	
	left join folio_reporting.holdings_notes as hn 
	on he.holdings_id = hn.holdings_id
	
	left join folio_reporting.locations_libraries as ll 
	on he.permanent_location_id = ll.location_id
	
	left join inventory_locations as invloc 
	on he.permanent_location_id = invloc.id
	
	LEFT JOIN folio_reporting.instance_ext AS instext 
	ON ii.id = instext.instance_id
	

where
	ll.library_name = 'Mann Library'
	and he.permanent_location_name = 'Mann Special Collections'
	and (ii.discovery_suppress = 'False' or ii.discovery_suppress is null)
	and (he.discovery_suppress = 'False' or he.discovery_suppress is null)
	
group by 
	ll.library_name,
	he.permanent_location_name,
	invloc.code,
	ii.title,			
	trim (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix,invitems.enumeration,invitems.chronology,
		CASE WHEN invitems.copy_number >'1' THEN concat ('c.',invitems.copy_number) ELSE '' END)),
	ii.hrid,
	he.holdings_hrid,
	invitems.hrid,
	invitems.barcode,
	ie.status_name,
	ie.status_date::date,
	ie.material_type_name,
	he.type_name,
	instext.mode_of_issuance_name,
	other_locs.other_library_name,
	other_locs.other_holdings_statement,	
	concat ('https://newcatalog.library.cornell.edu/catalog/',ii.hrid),
	invitems.effective_shelving_order
	
order by invitems.effective_shelving_order collate "C"
