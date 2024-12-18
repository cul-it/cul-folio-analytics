--MCR218
--Checkouts and Browses by location, date range and LC class
--This query finds the the most recent checkouts and browses by date range, location and LC class (total checkouts and most recent checkout in Voyager and in Folio).

--Query writer: Joanne Leary (jl41)
---Query posted on: 12/18/24

with parameters as 
(select -- enter a custom date range (REQUIRED). To get the most recent checkout for all years, enter '2000-07-01' for begin date, and today's date (or a date in the future) for end date
       	'2021-07-01' as begin_date_filter, -- enter in format 'yyyy-mm-dd'
       	'2024-12-31' as end_date_filter, -- enter in format 'yyyy-mm-dd'
		'Math'::varchar as location_name_filter, -- enter a location (required) -- see https://confluence.cornell.edu/display/folioreporting/Locations
		'Q'::varchar as lc_class_filter -- enter an LC class or leave blank to get all records
),

--1. Get item records in location and show Voyager historical charges and browses 

recs as 
(select 
       he.permanent_location_name,
       ie.effective_location_name,
       ii.title,
       ii.hrid as instance_hrid,
       he.holdings_hrid,
       ie.item_id,
       ie.item_hrid,
       ii.discovery_suppress as instance_suppress,
       he.discovery_suppress as holdings_suppress,
       ie.status_name as item_status_name,
       to_char (ie.status_date::date,'mm/dd/yyyy') as item_status_date,
       substring (he.call_number, '^([A-Za-z]{1,3})') as lc_class,
       trim (concat (he.call_number_prefix, ' ', he.call_number,' ',he.call_number_suffix, ' ',ie.enumeration, ' ',ie.chronology, 
              case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)) as whole_call_number,
       ie.barcode,
       ie.created_date::date as folio_item_create_date,
       item.create_date::date as voyager_item_create_date,
       item.historical_charges as voyager_charges,
       item.historical_browses as voyager_browses,
       max (cta.charge_date::date) as most_recent_voyager_charge_date,
       invitems.effective_shelving_order collate "C"

from folio_inventory.instance__t as ii  
       left join folio_derived.holdings_ext as he  
       on ii.id = he.instance_id::UUID
       
       left join folio_derived.item_ext as ie 
       on he.holdings_id = ie.holdings_record_id
       
       left join folio_inventory.item__t as invitems 
       on ie.item_id::UUID = invitems.id
       
       left join vger.item 
       on ie.item_hrid = item.item_id::varchar
       
       left join vger.circ_trans_archive as cta 
       on item.item_id = cta.item_id

where (he.permanent_location_name = (select location_name_filter from parameters) or ie.effective_location_name = (select location_name_filter from parameters))
and ((select lc_class_filter from parameters) = '' or substring (he.call_number, '^([A-Za-z]{1,3})') = (select lc_class_filter from parameters))

group by 
he.permanent_location_name,
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
       substring (he.call_number, '^([A-Za-z]{1,3})'),
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

circsever as 
(select 
       recs.item_id,
       max (li.loan_date::date) as most_recent_folio_loan_date_ever,
       count (li.loan_id) as total_folio_loans --folio_loans_in_date_range
       
       from recs 
              left join folio_derived.loans_items as li --folio_reporting.loans_items as li
              on recs.item_id::UUID = li.item_id::UUID
            
       /*where 
              ((case 
                     when (select begin_date_filter from parameters) = '' and (select end_date_filter from parameters) = '' 
                     then (li.loan_date::DATE >='2021-07-01' and li.loan_date::DATE < current_date::date)
                     else (li.loan_date::DATE >= (select begin_date_filter from parameters)::DATE and li.loan_date < (select end_date_filter from parameters)::DATE)
                     end))*/
       
       group by recs.item_id
),

circsdaterange as 
(select 
       recs.item_id,
       max (li.loan_date::date) as most_recent_folio_loan_date,
       count (li.loan_id) as folio_loans_in_date_range
       
       from recs 
              left join folio_derived.loans_items as li --folio_reporting.loans_items as li
              on recs.item_id::UUID = li.item_id::UUID
            
       where 
              ((case 
                     when (select begin_date_filter from parameters) = '' and (select end_date_filter from parameters) = '' 
                     then (li.loan_date::DATE >='2021-07-01' and li.loan_date::DATE < current_date::date)
                     else (li.loan_date::DATE >= (select begin_date_filter from parameters)::DATE and li.loan_date < (select end_date_filter from parameters)::DATE)
                     end))
       
       group by recs.item_id
),

-- 3. Get Folio browses

browses as 
(select 
       recs.item_id,
       count (cci.id) as folio_browses_in_date_range,
       max (cci.occurred_date_time::date) as most_recent_browse_in_date_range
 from recs 
      inner join folio_circulation.check_in__t as cci -- circulation_check_ins as cci 
      on recs.item_id::UUID = cci.item_id
      
   where 
        ((case 
            when (select begin_date_filter from parameters) = '' and (select end_date_filter from parameters) = '' 
            then (cci.occurred_date_time::date >='2021-07-01' and cci.occurred_date_time::date < current_date::date)
            else (cci.occurred_date_time::date >= (select begin_date_filter from parameters)::DATE and cci.occurred_date_time::date < (select end_date_filter from parameters)::DATE)
            end)
            
         and (cci.item_status_prior_to_check_in = 'Available'))
         
  group by recs.item_id
)

-- 4. Join the results

select 
       to_char (current_date::date,'mm/dd/yyyy') as todays_date,
       (select begin_date_filter from parameters) as begin_date,
       (select end_date_filter from parameters) as end_date,
       recs.permanent_location_name as holdings_location_name,
       recs.effective_location_name as item_effective_location_name,
       recs.title,
       recs.instance_hrid,
       recs.holdings_hrid,
       recs.item_hrid,
       recs.instance_suppress,
       recs.holdings_suppress::boolean,
       recs.item_status_name,
       recs.item_status_date,
       recs.lc_class,
       recs.whole_call_number,
       recs.barcode,
       to_char (coalesce (recs.voyager_item_create_date, recs.folio_item_create_date)::date,'mm/dd/yyyy') as item_create_date,
       to_char (coalesce (circsever.most_recent_folio_loan_date_ever, recs.most_recent_voyager_charge_date)::date,'mm/dd/yyyy') as most_recent_loan_since_2000,
       
       to_char ((case when (coalesce (circsdaterange.most_recent_folio_loan_date, recs.most_recent_voyager_charge_date))::date >= (select begin_date_filter from parameters)::date
       					then (coalesce (circsdaterange.most_recent_folio_loan_date, recs.most_recent_voyager_charge_date))::date
       					else null 
       				end),'mm/dd/yyyy') as most_recent_loan_date_in_date_range,
       
       to_char (browses.most_recent_browse_in_date_range,'mm/dd/yyyy') as most_recent_folio_browse_in_date_range,
       case when recs.voyager_charges is null then 0 else recs.voyager_charges end as total_voyager_charges,
       case when recs.voyager_browses is null then 0 else recs.voyager_browses end as total_voyager_browses,
       circsever.total_folio_loans,
       case when circsdaterange.folio_loans_in_date_range is null then 0 else circsdaterange.folio_loans_in_date_range end as folio_loans_in_date_range,
       case when browses.folio_browses_in_date_range is null then 0 else browses.folio_browses_in_date_range end as folio_browses_in_date_range

from recs    
       left join circsever --circs 
       on recs.item_id = circsever.item_id --circs.item_id
       
       left join circsdaterange --circs 
       on recs.item_id = circsdaterange.item_id --circs.item_id
       
       left join browses 
       on recs.item_id = browses.item_id

order by recs.effective_shelving_order collate "C"
;
