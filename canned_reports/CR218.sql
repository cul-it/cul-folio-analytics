--CR218
--Checkouts and Browses by location, date range and LC class
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 7/25/23
/*This query finds Folio charges and browses for a given location and date range (or semester) and LC class, and shows the total historical Voyager charges and browses.
  It also shows the most recent checkout up to the end of the date range or semester selected.
  If no date range or semester is selected, it uses a default date range of 7-1-21 through the current date.*/

with parameters as 
(select -- enter a custom date range, OR enter a semester (not both); OR leave both dates and semester blank to get everything since 7-1-2021
       '2022-12-01' as begin_date_filter, -- enter in format 'yyyy-mm-dd'
       '2023-03-01' as end_date_filter, -- enter in format 'yyyy-mm-dd'
       ''::varchar as semester_filter, -- can be any semester between Summer 2021 through Fall 2023
'Vet Core Resource'::varchar as location_name_filter, -- enter a location (required) -- see https://confluence.cornell.edu/display/folioreporting/Locations
'SF'::varchar as lc_class_filter -- enter an LC class or leave blank to get all records
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

from inventory_instances as ii 
       left join folio_reporting.holdings_ext as he 
       on ii.id = he.instance_id
       
       left join folio_reporting.item_ext as ie 
       on he.holdings_id = ie.holdings_record_id
       
       left join inventory_items as invitems 
       on ie.item_id = invitems.id
       
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

circs as 
(select 
       recs.item_id,
       max (li.loan_date::date) as most_recent_folio_loan_date,
       count (li.loan_id) as folio_loans_in_date_range
       from recs 
              inner join folio_reporting.loans_items as li
              on recs.item_id = li.item_id
       where 
              case 
                     when (select semester_filter from parameters) = '' and (select begin_date_filter from parameters) = '' 
                           then li.loan_date >='2021-07-01' and li.loan_date < current_date
                     when (select semester_filter from parameters) = '' then li.loan_date >= (select begin_date_filter from parameters)::date and li.loan_date < (select end_date_filter from parameters)::date
                     when (select semester_filter from parameters) = 'Summer 2021' then li.loan_date >= '2021-05-19' and li.loan_date < '2021-08-10'
                     when (select semester_filter from parameters) = 'Fall 2021' then li.loan_date >= '2021-08-10' and li.loan_date < '2021-12-18'
                     when (select semester_filter from parameters) = 'Winter 2022' then li.loan_date >= '2021-12-18' and li.loan_date < '2022-01-17'
                     when (select semester_filter from parameters) = 'Spring 2022' then li.loan_date >= '2022-01-17' and li.loan_date < '2022-05-19'
                     when (select semester_filter from parameters) = 'Summer 2022' then li.loan_date >= '2022-05-19' and li.loan_date < '2022-08-08'
                     when (select semester_filter from parameters) = 'Fall 2022' then li.loan_date >= '2022-08-08' and li.loan_date < '2022-12-17'
                     when (select semester_filter from parameters) = 'Winter 2023' then li.loan_date >= '2022-12-17' and li.loan_date < '2023-01-18'
                     when (select semester_filter from parameters) = 'Spring 2023' then li.loan_date >= '2023-01-18' and li.loan_date < '2023-05-20'
                     when (select semester_filter from parameters) = 'Summer 2023' then li.loan_date >= '2023-05-20' and li.loan_date < '2023-08-10'
                     when (select semester_filter from parameters) = 'Fall 2023' then li.loan_date>= '2023-08-10' and li.loan_date < '2023-12-18'
              else   
              li.loan_date::date >= (select begin_date_filter from parameters)::date and li.loan_date < (select end_date_filter from parameters)::date 
              end
       group by recs.item_id
),

-- 3. Get Folio browses

browses as 
(select 
       recs.item_id,
       count (cci.id) as folio_browses_in_date_range
       from recs 
              inner join circulation_check_ins as cci 
              on recs.item_id = cci.item_id
       where 
              (case 
                     when (select semester_filter from parameters) = '' and (select begin_date_filter from parameters) = '' 
                           then cci.occurred_date_time >='2021-07-01' and cci.occurred_date_time < current_date
                     when (select semester_filter from parameters) = '' then cci.occurred_date_time >= (select begin_date_filter from parameters)::date and cci.occurred_date_time < (select end_date_filter from parameters)::date
                     when (select semester_filter from parameters) = 'Summer 2021' then cci.occurred_date_time >= '2021-05-19' and cci.occurred_date_time < '2021-08-10'
                     when (select semester_filter from parameters) = 'Fall 2021' then cci.occurred_date_time >= '2021-08-10' and cci.occurred_date_time < '2021-12-18'
                     when (select semester_filter from parameters) = 'Winter 2022' then cci.occurred_date_time >= '2021-12-18' and cci.occurred_date_time < '2022-01-17'
                     when (select semester_filter from parameters) = 'Spring 2022' then cci.occurred_date_time >= '2022-01-17' and cci.occurred_date_time < '2022-05-19'
                     when (select semester_filter from parameters) = 'Summer 2022' then cci.occurred_date_time >= '2022-05-19' and cci.occurred_date_time < '2022-08-08'                   
                     when (select semester_filter from parameters) = 'Fall 2022' then cci.occurred_date_time >= '2022-08-08' and cci.occurred_date_time < '2022-12-17'
                     when (select semester_filter from parameters) = 'Winter 2023' then cci.occurred_date_time >= '2022-12-17' and cci.occurred_date_time < '2023-01-18'
                     when (select semester_filter from parameters) = 'Spring 2023' then cci.occurred_date_time >= '2023-01-18' and cci.occurred_date_time < '2023-05-20'
                     when (select semester_filter from parameters) = 'Summer 2023' then cci.occurred_date_time >= '2023-05-20' and cci.occurred_date_time < '2023-08-10'
                     when (select semester_filter from parameters) = 'Fall 2023' then cci.occurred_date_time >= '2023-08-10' and cci.occurred_date_time < '2023-12-18'
              else   
              (cci.occurred_date_time::date >= (select begin_date_filter from parameters)::date and cci.occurred_date_time::date < (select end_date_filter from parameters)::date) end)
       and cci.item_status_prior_to_check_in = 'Available'
       group by recs.item_id
)

-- 4. Join the results

select 
       to_char (current_date::date,'mm/dd/yyyy') as todays_date,
       (select semester_filter from parameters) as semester,
       case 
              when (select semester_filter from parameters) = '' and (select begin_date_filter from parameters) ='' then concat ('07/01/2021', ' - ',to_char (current_date::date,'mm/dd/yyyy'))
              when (select semester_filter from parameters) = 'Summer 2021' then '05/19/2021 - 08/10/2021'
              when (select semester_filter from parameters) = 'Fall 2021' then '08/10/2021 - 12/18/2021'
              when (select semester_filter from parameters) = 'Winter 2022' then '12/18/2021 - 01/17/2022'
              when (select semester_filter from parameters) = 'Spring 2022' then '01/17/2022 - 05/19/2022'
              when (select semester_filter from parameters) = 'Summer 2022' then '05/19/2022 - 08/08/2022'
              when (select semester_filter from parameters) = 'Fall 2022' then '08/08/2022 - 12/16/2022'
              when (select semester_filter from parameters) = 'Winter 2023' then '12/19/2022 - 01/22/2023'
              when (select semester_filter from parameters) = 'Spring 2023' then '01/18/2023 - 05/18/2023'
              when (select semester_filter from parameters) = 'Summer 2023' then '05/21/2023 - 08/27/2023'
              else 
              concat ((select begin_date_filter from parameters),' - ',(select end_date_filter from parameters)) 
              end as date_range,
       recs.permanent_location_name as holdings_location_name,
       recs.effective_location_name as item_location_name,
       recs.title,
       recs.instance_hrid,
       recs.holdings_hrid,
       recs.item_hrid,
       recs.instance_suppress,
       recs.holdings_suppress,
       recs.item_status_name,
       recs.item_status_date,
       recs.lc_class,
       recs.whole_call_number,
       recs.barcode,
       to_char (coalesce (recs.voyager_item_create_date, recs.folio_item_create_date)::date,'mm/dd/yyyy') as item_create_date,
       to_char (coalesce (circs.most_recent_folio_loan_date, recs.most_recent_voyager_charge_date)::date,'mm/dd/yyyy') as most_recent_loan_til_end_of_date_range,
       case when recs.voyager_charges is null then 0 else recs.voyager_charges end as voyager_charges,
       case when recs.voyager_browses is null then 0 else recs.voyager_browses end as voyager_browses,
       case when circs.folio_loans_in_date_range is null then 0 else circs.folio_loans_in_date_range end as folio_loans_in_date_range,
       case when browses.folio_browses_in_date_range is null then 0 else browses.folio_browses_in_date_range end as folio_browses_in_date_range

from recs    
       left join circs 
       on recs.item_id = circs.item_id
       
       left join browses 
       on recs.item_id = browses.item_id

order by recs.effective_shelving_order collate "C"
;
