--MCR410
--Annex Transfer Candidates
-- This query finds candidates for transferring to the Annex by location, LC class, material type, holdings type, mode of issuance, size, circ history, pub date, year added to collection; 
-- excludes bound-withs and titles with holdings at the Annex; "Available" item status only
--Query writer: Joanne LEary (jl41)
--Posted on: 10/7/25

WITH parameters as 
(select 
	'Mann' as location_name_filter, -- required
	'QD' as begin_lc_class_filter, -- required
	'QE' as end_lc_class_filter, -- required
	'' as material_type_filter, -- select from: 'Book','Periodical','Soundrec','Map','Microform','Music (score)','Newspaper','Object','Periodical','Visual','Serial','Textual resource','Unbound','Archivman'; leave blank for all items
	'' as holdings_type_filter, -- select from: 'Monograph', 'Multi-part monograph', 'Serial', 'Unmapped', 'Unknown'; leave blank for all items
	'' as mode_of_issuance_filter, -- select from: 'multipart monograph','single unit','serial','unspecified','integrating resource'; leave blank for all items
	'2015-01-01' as max_circ_date_filter, -- enter a date for most recent checkout; leave blank for all checkouts
	'' as size_filter, -- enter one of: '+', '++', '+++', 'regular size' or leave blank for all sizes
	'2005' as year_added_filter, -- select the latest year for items added to the collection (items selected will have been added BEFORE the year indicated; min year = 2001); leave blank to get all items
	'1980' as year_of_publication_filter -- select the latest year of publication (items selected will be published EARLIER than the year entered); for example, 2000; leave blank to get all items
),

recs AS

(SELECT 
	instext.instance_id,
	instext.instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.effective_location_name,
	ihi.index_title,
	trim (concat (ie.effective_call_number_prefix,' ',
		ie.effective_call_number,' ',
		ie.effective_call_number_suffix,' ',
		ie.enumeration,' ',
		ie.chronology, 
		case when ie.copy_number >'1' then concat  ('c.',ie.copy_number) else '' end)) as item_call_number,
	case 
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+++%' then '+++'
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%++%' then '++'
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+%' then '+'
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%Oversize%' then '+'
		else 'regular size' end as size,
		
	substring (ie.effective_call_number,'^[A-Z]{1,3}') as lc_class,
	ie.barcode,
	ie.status_name,
	instext.mode_of_issuance_name,
	ihi.holdings_type_name,
	ihi.material_type_name,
	string_agg (distinct (substring (ip.date_of_publication,'\d{4}')), ' | ') as year_of_publication,
	date_part ('year',coalesce (vitem.create_date::date,ie.created_date::date)) as year_added_to_collection,
	coalesce (vitem.historical_charges,0) as total_voyager_loans,
	coalesce (count (distinct li.loan_id),0) as total_folio_loans,
	(coalesce (vitem.historical_charges,0) + coalesce (count (distinct li.loan_id),0)) as total_loans,
	coalesce (max (li.loan_date::date), max (cta.charge_date::date)) as most_recent_checkout,
	item__t.effective_shelving_order

from folio_derived.item_ext as ie 
	left join vger.item as vitem
	on ie.item_hrid = vitem.item_id::varchar
	
	left join folio_inventory.item__t 
	on ie.item_id = item__t.id
	
	left join folio_derived.loans_items as li 
	on ie.item_id = li.item_id
	
	left join vger.circ_trans_archive as cta 
	on ie.item_hrid = cta.item_id::varchar
	
	left join folio_derived.items_holdings_instances as ihi 
	on ie.item_id = ihi.item_id 
		and ie.holdings_record_id = ihi.holdings_id
		
	left join folio_derived.instance_ext as instext 
	on ihi.instance_id = instext.instance_id
	
	left join folio_derived.instance_publication as ip 
	on instext.instance_id = ip.instance_id
	
	left join folio_derived.holdings_ext as he 
	on ie.holdings_record_id = he.id
		and ihi.holdings_id = he.id

where ie.effective_location_name = (select location_name_filter from parameters) --'Olin'
	and substring (ie.effective_call_number,'^[A-Z]{1,3}') >= (select begin_lc_class_filter from parameters) --'D'
	and substring (ie.effective_call_number,'^[A-Z]{1,3}') < (select end_lc_class_filter from parameters) --'DA'
	and ie.status_name = 'Available'
	and 
		case when (select material_type_filter from parameters) = '' 
		then ihi.material_type_name in('Book','Periodical','Soundrec','Map','Microform','Music (score)','Newspaper','Periodical','Visual','Serial','Textual resource','Unbound')
		else ihi.material_type_name = (select material_type_filter from parameters)
		end
		
	and case 
		when ihi.holdings_type_name is null then null
		when (SELECT holdings_type_filter FROM parameters) = '' then ihi.holdings_type_name in ('Monograph','Multi-part monograph','Serial','Unmapped','Unknown') 
		else ihi.holdings_type_name = (select holdings_type_filter from parameters) 
		end
		
	and case 
		when instext.mode_of_issuance_name is NULL then null
		when (select mode_of_issuance_filter from parameters) = '' then instext.mode_of_issuance_name in ('multipart monograph','single unit','serial','unspecified','integrating resource') 
		else instext.mode_of_issuance_name = (select mode_of_issuance_filter from parameters)
		end
		
	and ie.barcode is not null
	
	and case when (select size_filter from parameters) ='' then 
		(case 
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+++%' then '+++'
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%++%' then '++'
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+%' then '+'
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%Oversize%' then '+'
			else 'regular size' end) in ('+','++','+++','regular size')
		else 
		(case 
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+++%' then '+++'
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%++%' then '++'
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+%' then '+'
			when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%Oversize%' then '+'
			else 'regular size' end) = (select size_filter from parameters)
		end
	
	and (instext.discovery_suppress = false or instext.discovery_suppress is null)
	and (he.discovery_suppress = false or he.discovery_suppress is null)	
	and case when (select year_added_filter from parameters) = '' then date_part ('year',coalesce (vitem.create_date::date,ie.created_date::date)) < date_part ('year',current_date::date) 
		else date_part ('year',coalesce (vitem.create_date::date,ie.created_date::date)) < (select year_added_filter from parameters)::INT
		end

	
group by 
	instext.instance_id,
	instext.instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ihi.index_title,
	instext.mode_of_issuance_name,
	ihi.holdings_type_name,
	ihi.material_type_name,
	ie.effective_location_name,
	trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration,' ',ie.chronology, case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end
	)),
	case 
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+++%' then '+++'
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%++%' then '++'
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%+%' then '+'
		when trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix)) like '%Oversize%' then '+'
		else 'regular size' end,
	ie.barcode,
	substring (ie.effective_call_number,'^[A-Z]{1,3}'),
	ie.status_name,
	coalesce (vitem.create_date::date,ie.created_date::date),
	date_part ('year',coalesce (vitem.create_date::date,ie.created_date::date)),
	vitem.historical_charges,
	item__t.effective_shelving_order

having (case 
		when (select max_circ_date_filter from parameters) = '' 
		then coalesce (max (li.loan_date::date), max (cta.charge_date::date)) < current_date::date 
		else coalesce (max (li.loan_date::date), max (cta.charge_date::date)) < (select max_circ_date_filter from parameters)::date
		end --'2015-01-01' 
	or coalesce (max (li.loan_date::date), max (cta.charge_date::date)) is null
	)
	
	and (case when (select year_of_publication_filter from parameters) = '' 
		then string_agg (distinct (substring (ip.date_of_publication,'\d{4}')), ' | ') like '%%' or string_agg (distinct (substring (ip.date_of_publication,'\d{4}')), ' | ') is null 
		else string_agg (distinct (substring (ip.date_of_publication,'\d{4}')), ' | ') < (select year_of_publication_filter from parameters)
		end)
),

annex_hold AS 
(SELECT distinct
	recs.instance_hrid,
	ll.library_name,
	string_agg (distinct concat (he.holdings_hrid,' - ',he.permanent_location_name,' ',concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,
		case when he.copy_number >'1' then concat ('c.',he.copy_number) else '' end), '  ',hs.holdings_statement), chr(10)) 
		as annex_holdings_statements,
	STRING_AGG (DISTINCT
                        CASE WHEN item__t.hrid IS NULL 
                        THEN '' 
                        ELSE (
                            CONCAT (ii.hrid,' - ',he.holdings_hrid,' - ',item__t.hrid,' -- ', ll.location_name,' ',item.jsonb#>>'{effectiveCallNumberComponents,callNumber}',' ',
                            item__t.enumeration,' ',item__t.chronology, ' ',CASE WHEN item__t.copy_number >'1' THEN CONCAT ('c.',item__t.copy_number) ELSE '' END,
                            ' -- ',item.jsonb#>>'{status,name}',' - ',((item.jsonb#>>'{status,date}')::DATE))::VARCHAR
                            )                             
                        END,
                            chr(10)
                    )
             AS annex_items
	
FROM recs 
	LEFT JOIN folio_inventory.instance__t as ii 
	ON recs.instance_hrid = ii.hrid 
	
	LEFT JOIN folio_derived.holdings_ext AS he 
	ON ii.id = he.instance_id
	
	left join folio_inventory.item__t 
	on he.id = item__t.holdings_record_id
	
	left join folio_inventory.item 
	on item__t.id = item.id
	
	LEFT JOIN folio_derived.holdings_statements AS hs
	ON he.id = hs.holdings_id
	
	LEFT JOIN folio_derived.locations_libraries ll 
	ON he.permanent_location_id = ll.location_id

WHERE ll.library_name = 'Library Annex'
and (he.discovery_suppress = 'false' or he.discovery_suppress is null)

GROUP BY recs.instance_hrid, ll.library_name

)

select 
	recs.*,
	annex_hold.annex_items
	
from recs
	left join annex_hold 
	on recs.instance_hrid = annex_hold.instance_hrid

where annex_hold.instance_hrid is null

order by size, recs.effective_shelving_order collate "C"
;


