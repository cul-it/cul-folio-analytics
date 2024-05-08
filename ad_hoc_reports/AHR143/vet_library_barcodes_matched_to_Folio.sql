--AHR 143
--vet_library_barcodes_matched_to_Folio
--This query finds matches to Folio data from a list of Vet library barcodes. The purpose is to update locations for special collections items.
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 5/8/2024


With recs as 
(select 
	jlv.seq_no,
	jlv.barcode as list_barcode,
	jlv.location_for_folio,
	ie.permanent_location_name as item_permanent_location_name,
	ie.temporary_location_name as item_temporary_location_name,
	ie.barcode as folio_barcode,
	ie.item_hrid,
	--ie.effective_location_name as item_effective_location_name_in_folio,
	case when ie.copy_number>'1' then concat (ie.effective_call_number,' ','c.',ie.copy_number) else ie.effective_call_number end as item_call_number

from local.jl_vet_barcodes_for_location_check as jlv 
	left join folio_reporting.item_ext as ie 
	on trim(jlv.barcode) = trim(ie.barcode) 

order by seq_no
)

select 
	recs.seq_no,
	recs.list_barcode,
	recs.location_for_folio,
	ii.title,
	recs.item_call_number,
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.barcode as folio_barcode,
	he.permanent_location_name as holidngs_permanent_location_name,
	--he.temporary_location_name as holdings_temporary_location_name,
	ie.permanent_location_name as item_permanent_location_name,
	--ie.temporary_location_name  as item_temporary_location_name,
	ie.effective_location_name as item_effective_location_name,
	ii.discovery_suppress as instance_suppress,
	he.discovery_suppress as holdings_suppress,
	ie.discovery_suppress as item_suppress,
	string_agg (distinct hn.note,' | ') as holdings_notes,
	string_agg (distinct notes.note,' | ') as item_notes

from recs 
	left join folio_reporting.item_ext as ie 
	on recs.list_barcode = ie.barcode
	
	left join folio_reporting.item_notes as notes 
	on ie.item_id = notes.item_id
	
	left join folio_reporting.holdings_ext as he 
	on ie.holdings_record_id = he.holdings_id
	
	left join folio_reporting.holdings_notes as hn 
	on he.holdings_id = hn.holdings_id
	
	left join inventory_instances as ii 
	on he.instance_id = ii.id

group by 
recs.seq_no,
	recs.list_barcode,
	recs.location_for_folio,
	ii.title,
	recs.item_call_number,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.barcode,
	he.permanent_location_name,
	--he.temporary_location_name,
	ie.permanent_location_name,
	--ie.temporary_location_name,
	ie.effective_location_name,
	ii.discovery_suppress,
	he.discovery_suppress,
	ie.discovery_suppress
order by recs.seq_no
;
