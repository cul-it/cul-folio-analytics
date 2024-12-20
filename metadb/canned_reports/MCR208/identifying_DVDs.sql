-- MCR208
--identifying DVDs 
--This query identifies DVDs in the library location specified.

--Query writer: Joanne Leary (jl41)
--Query posted on: 12/20/24

with parameters as 
(select 
'%%' as library_name_filter 
)

select distinct
	
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ii.title,
	ll.library_name,
	he.permanent_location_name,
	he.call_number_type_name,
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
		case when ie.copy_number >'1' then concat (' c.',ie.copy_number) else '' end)) as whole_call_number,
	ie.barcode,
	case when he.call_number_type_name = 'Library of Congress classification' then null else substring (he.call_number,'\d{1,}')::int end as videodisc_number,
	ie.status_name as item_status_name,
	ie.status_date::date as item_status_date,
	string_agg (distinct ipd.physical_description,' | ') as physical_description,
	substring (sm.content,7,2) as format_code,
	vs.leader0607description,
	item__t.effective_shelving_order collate "C"

from folio_inventory.instance__t as ii 
	left join folio_derived.holdings_ext as he 
	on ii.id = he.instance_id::UUID
	
	left join folio_derived.item_ext as ie 
	on he.holdings_id::UUID = ie.holdings_record_id::UUID
	
	left join folio_inventory.item__t 
	on ie.item_id::UUID = item__t.id
	
	left join folio_derived.locations_libraries as ll 
	on he.permanent_location_id::UUID = ll.location_id::UUID
	
	left join folio_source_record.marc__t as sm 
	on ii.id = sm.instance_id
	
	left join local_shared.vs_folio_physical_material_formats vs
	on vs.leader0607 = substring (sm.content,7,2)
	
	left join folio_derived.instance_physical_descriptions as ipd 
	on ii.id = ipd.instance_id
	
where sm.field = '000'
	and (substring(sm.content,7,1)='g'
		or (sm.field = '007' AND substring (sm.CONTENT,1,2) = 'vd')
		or (sm.field = '008' AND substring (sm.CONTENT, 34,1) = 'v')
		)
	and (ll.library_name ilike (select library_name_filter from parameters) or (select library_name_filter from parameters) = '')
	and ipd.physical_description not ilike '%cassette%'
	and he.call_number not similar to '%(On order|On Order|In Process|In process|on order|in process)%'
	and (ii.discovery_suppress = FALSE or ii.discovery_suppress is null)
	and (he.discovery_suppress = 'false' or he.discovery_suppress is null)
	and (ie.discovery_suppress = FALSE or ie.discovery_suppress is null)
	
group by 
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ii.title,
	ll.library_name,
	he.permanent_location_name,
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
		case when ie.copy_number >'1' then concat (' c.',ie.copy_number) else '' end)),
	he.call_number_type_name,	
	ie.barcode,
	substring (he.call_number,'\d{1,}'),
	ie.status_name,
	ie.status_date::date,
	substring (sm.content,7,2),
	vs.leader0607description,
	item__t.effective_shelving_order collate "C"
	
order by 
 library_name, permanent_location_name, videodisc_number, item__t.effective_shelving_order collate "C", title
;
