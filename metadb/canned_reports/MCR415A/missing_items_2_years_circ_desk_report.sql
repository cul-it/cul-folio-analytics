-- MCR415A 
-- Missing items 2 years report for circ desks 
-- written by Joanne Leary 
-- List of items missing before two years ago to be flipped to Long missing
-- 2-26-26: generalized for all libraries; capturing items that were missing the previous calendar years, two years ago (that is, before January 1, two years ago)

select
	current_date::date as run_date,
	loclibrary__t.name as library_name,
	ie.effective_location_name as item_effective_location_name,
	ihi.title,
	ie.item_id as item_uuid,
	ie.item_hrid,
	ie.barcode,
	trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
	case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)) as whole_call_number,
	ie.status_name,
	ie.status_date::date,
	string_agg (distinct itemnotes.note,' | ') as item_notes,
	concat ('Original missing date: ',(ie.status_date::date)::varchar) as added_note 

from folio_derived.item_ext as ie 
	left join folio_derived.item_notes as itemnotes 
	on ie.item_id = itemnotes.item_id 
	
	left join folio_inventory.item__t 
	on ie.item_id = item__t.id
	
	left join folio_derived.items_holdings_instances as ihi 
	on ie.item_id = ihi.item_id
	
	left join folio_inventory.location__t 
	on ie.effective_location_id = location__t.id 
	
	left join folio_inventory.loclibrary__t 
	on location__t.library_id = loclibrary__t.id

where 
	ie.status_name = 'Missing'
	and ie.status_date::date < '2024-01-01'

group by 
	current_date::date,
	loclibrary__t.name,
	ie.effective_location_name,
	ihi.title,
	ie.item_id,
	ie.item_hrid,
	ie.barcode,
	trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
	case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)),
	ie.status_name,
	ie.status_date,
	concat ('Original missing date: ',(ie.status_date::date)::varchar),
	item__t.effective_shelving_order

order by loclibrary__t.name, ie.effective_location_name, item__t.effective_shelving_order collate "C"
;
