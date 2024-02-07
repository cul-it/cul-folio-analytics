--CR230 
--collection_inventory_with_checkouts_and_browses_by_date_range
-- 7-20-23: Checkouts and browses by location or library and date range 
-- written by Joanne Leary, tested by Sharon Markus
-- This query finds all items in a given location or library, and shows all charges and browses within the specified date range
-- Shows all record component locations, which is helpful for record cleanup
-- 2-1-24: for Folio loan counts > 0, "most recent checkout" dates may be before 7-1-21 because of migrated open loans from Voyager

with parameters as 
(select 
'2000-01-01'::date as begin_date_filter, -- required; to get all loans, enter '2000-01-01'
'2024-02-02'::date as end_date_filter, -- required

-- Enter the library name (will get all records) or the location name (will get records just in that location). Required.

'%%'::varchar as library_filter,
'%Music Reserve%'::varchar as location_name_filter
),

--1. Get item records in location and show Voyager historical charges and browses 

recs as 
(select 
	ll.library_name,
	he.permanent_location_name as holdings_perm_loc_name,
	he.temporary_location_name as holdings_temp_loc_name,
	ie.permanent_location_name as item_perm_loc_name,
	ie.temporary_location_name as item_temp_loc_name,
	ie.effective_location_name as item_effective_loc_name,
	ii.title,
	ii.hrid as instance_hrid,
	he.holdings_hrid,
	ie.item_id,
	ie.item_hrid,
	ii.discovery_suppress as instance_suppress,
	he.discovery_suppress as holdings_suppress,
	ie.status_name as item_status_name,
	to_char (ie.status_date::date,'mm/dd/yyyy') as item_status_date,
	trim (concat (he.call_number_prefix, ' ', he.call_number,' ',he.call_number_suffix, ' ',ie.enumeration, ' ',ie.chronology, 
		case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)) as whole_call_number,
	ie.barcode,
	ie.created_date::date as folio_item_create_date,
	item.create_date::date as voyager_item_create_date,
	item.historical_charges as voyager_charges,
	item.historical_browses as voyager_browses,
	max (cta.charge_date::date) as most_recent_voyager_charge_date,
	invitems.effective_shelving_order collate "C"

from inventory_instances as ii 
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id
	
	left join folio_reporting.item_ext as ie 
	on he.holdings_id = ie.holdings_record_id
	
	left join folio_reporting.locations_libraries as ll 
	on ie.effective_location_id = ll.location_id
	
	left join inventory_items as invitems 
	on ie.item_id = invitems.id
	
	left join vger.item 
	on ie.item_hrid = item.item_id::varchar
	
	left join vger.circ_trans_archive as cta 
	on item.item_id = cta.item_id

where 
((select library_filter from parameters) = '' or ll.library_name ilike (select library_filter from parameters)) 
and 
(
((select location_name_filter from parameters) = '' or he.permanent_location_name ilike (select location_name_filter from parameters))
or ((select location_name_filter from parameters) = '' or he.temporary_location_name ilike (select location_name_filter from parameters))
or ((select location_name_filter from parameters) = '' or ie.effective_location_name ilike (select location_name_filter from parameters))
)

group by 
	ll.library_name,
	he.permanent_location_name,
	he.temporary_location_name,
	ie.permanent_location_name,
	ie.temporary_location_name,
	ie.effective_location_name,
	ii.title,
	ii.hrid,
	he.holdings_hrid,
	ie.item_id,
	ie.item_hrid,
	ii.discovery_suppress,
	he.discovery_suppress,
	ie.status_name,
	to_char (ie.status_date::date,'mm/dd/yyyy'),
	trim (concat (he.call_number_prefix, ' ', he.call_number,' ',he.call_number_suffix, ' ',ie.enumeration, ' ',ie.chronology, 
		case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)),
	ie.barcode,
	ie.created_date::date,
	item.create_date::date,
	item.historical_charges,
	item.historical_browses,
	invitems.effective_shelving_order collate "C"
),

-- 2. Get Folio circs

circs as 
(select 
	recs.item_id,
	max (li.loan_date::date) as most_recent_folio_loan_date,
	count (li.loan_id) as folio_loans
	from recs 
		inner join folio_reporting.loans_items as li
		on recs.item_id = li.item_id
	where (li.loan_date::date >= (select begin_date_filter from parameters)::date and li.loan_date::date < (select end_date_filter from parameters)::date) 
	group by recs.item_id
),

-- 3. Get Folio browses

browses as 
(select 
	recs.item_id,
	count (cci.id) as folio_browses,
	max (cci.occurred_date_time) as most_recent_browse
	
	from recs 
		left join circulation_check_ins as cci 
		on recs.item_id = cci.item_id
		
	where (cci.occurred_date_time >= (select begin_date_filter from parameters) and cci.occurred_date_time < (select end_date_filter from parameters))
		and 
		cci.item_status_prior_to_check_in = 'Available'
	group by recs.item_id
)

-- 4. Join the results

select 
	to_char (current_date::date,'mm/dd/yyyy') as todays_date,
	concat (to_char ((select begin_date_filter from parameters)::date,'mm/dd/yyyy'),' - ',
		to_char ((select end_date_filter from parameters)::date,'mm/dd/yyyy')) as usage_date_range,
	recs.library_name,
	recs.title,
	recs.whole_call_number,
	recs.barcode,
	to_char (coalesce (recs.voyager_item_create_date, recs.folio_item_create_date)::date,'mm/dd/yyyy') as item_create_date,
	to_char (coalesce (circs.most_recent_folio_loan_date, recs.most_recent_voyager_charge_date)::date,'mm/dd/yyyy') as most_recent_loan,
	to_char (browses.most_recent_browse::date,'mm/dd/yyyy') as most_recent_browse,
	case when recs.voyager_charges is null then 0 else recs.voyager_charges end as voyager_charges,
	case when recs.voyager_browses is null then 0 else recs.voyager_browses end as voyager_browses,
	case when circs.folio_loans is null then 0 else circs.folio_loans end as folio_loans_in_date_range,
	case when browses.folio_browses is null then 0 else browses.folio_browses end as folio_browses_in_date_range,
	recs.holdings_perm_loc_name,
	recs.holdings_temp_loc_name,
	recs.item_perm_loc_name,
	recs.item_temp_loc_name,
	recs.item_effective_loc_name,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.instance_suppress,
	recs.holdings_suppress,
	recs.item_status_name,
	recs.item_status_date
	
from recs 	
	left join circs 
	on recs.item_id = circs.item_id
	
	left join browses 
	on recs.item_id = browses.item_id
	
order by recs.effective_shelving_order collate "C"
;
