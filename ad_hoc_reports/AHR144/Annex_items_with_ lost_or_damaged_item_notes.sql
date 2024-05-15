--AHR 144
--Annex items with lost or damaged item notes

--This query finds Annex items with item status "Available" and item notes indicating the item was lost, billed for replacement or otherwise damaged. QUery requested for Annex cleanup.
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 5/15/24

select 
	current_date::date as todays_date,
	ihi.instance_hrid,
	ihi.holdings_hrid,
	ihi.item_hrid,
	instext.discovery_suppress as instance_suppress,
	he.discovery_suppress as holdings_suppress,
	ie.discovery_suppress as item_suppress,
	ie.barcode,
	ihi.title,
	ie.effective_location_name,
	trim(concat (ihi.item_effective_call_number,' ',ihi.enumeration,' ',ihi.chronology,
		case when ihi.item_copy_number>'1' then concat ('c.',ihi.item_copy_number) else '' end)) as item_call_number,
	ie.status_name,
	ie.status_date::date as item_status_date,
	item_notes.note

from  folio_reporting.items_holdings_instances as ihi 
	inner join folio_reporting.item_ext as ie 
	on ie.item_id = ihi.item_id
	
	inner join folio_reporting.item_notes 
	on ie.item_id = item_notes.item_id
	
	left join folio_reporting.instance_ext as instext 
	on ihi.instance_hrid = instext.instance_hrid 
	
	left join folio_reporting.holdings_ext as he 
	on ihi.holdings_hrid = he.holdings_hrid

where ie.status_name = 'Available'
and ie.effective_location_name ilike '%Annex%'
and (item_notes.note ilike '%Lost%' 
	or item_notes.note ilike '%billed%' 
	or item_notes.note ilike '%damaged%' 
	or item_notes.note ilike '%stolen%' 
	or item_notes.note ilike '% fire%'
	or item_notes.note ilike '%withdraw%'
	or item_notes.note ilike '%flood%'
	or item_notes.note ilike '%deceased%')

order by ie.effective_location_name, trim(concat (ihi.item_effective_call_number,' ',ihi.enumeration,' ',ihi.chronology,
	case when ihi.item_copy_number>'1' then concat ('c.',ihi.item_copy_number) else '' end))
