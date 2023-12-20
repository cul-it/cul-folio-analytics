-- 11-1-23: Find all titles and holdings records with Cornell University Press (includes Comstock Publishing, Cornelliana and ILR Press).
-- Match these results as a full outer join to the list of books provided to us by Cornell University Press
-- This method is meant to capture titles in our collection that were published by CU Press or one of its imprints and don't match by ISBN, 
-- or have no ISBNs at all and so can't be matched to the CUP list.

--1. Find all ISBNs (active and inactive) for all CUL titles

with isbns as 
(select 
	iid.instance_id,
	iid.instance_hrid,
	iid.identifier,
	substring (iid.identifier, '\d{9,13}[X]{0,}') as cul_normalized_isbn,
	case when substring (iid.identifier, '\d{9,13}[X]{0,}') like '978%' 
		then substring (iid.identifier, '\d{9,13}[X]{0,}') 
		else concat ('978', substring (iid.identifier, '\d{9,13}[X]{0,}')) 
		end as isbn_with_978,
	substring (case when substring (iid.identifier, '\d{9,13}[X]{0,}') like '978%' then substring (iid.identifier, '\d{9,13}[X]{0,}') 
		else concat ('978', substring (iid.identifier, '\d{9,13}[X]{0,}')) end,1,12) as cul_truncated_978_isbn

from folio_reporting.instance_identifiers as iid 
where iid.identifier_type_name ilike '%ISBN%'
),

-- 2. Find all records where the publisher in the 260 field is like Cornell University Press, Cornelliana, ILR Press or Comstock publishing

field_260 as 
(select 
	ii.id as instance_id,
	ii.hrid as instance_hrid,
	ii.discovery_suppress as instance_suppress,
	ii.title,
	sm.content as publisher

from inventory_instances as ii 
	left join srs_marctab as sm 
	on ii.hrid = sm.instance_hrid 

where sm.field = '260'
	and sm.sf = 'b'
	and sm.content similar to '%(Cornell%Press|Comstock Pub|ILR Press|Cornelliana)%'
),

-- 3. Find the same criteria for the 264 field

field_264 as 
(select 
	ii.id as instance_id,
	ii.hrid as instance_hrid,
	ii.discovery_suppress as instance_suppress,
	ii.title,
	sm.content as publisher

from inventory_instances as ii 
left join srs_marctab as sm 
on ii.hrid = sm.instance_hrid 

where sm.field = '264'
	and sm.sf = 'b'
	and sm.content similar to '%(Cornell%Press|Comstock Pub|ILR Press|Cornelliana)%'
),

-- 5. Union the results

recs as 

(select
	field_260.*
	from field_260
	
	union
	
select 
	field_264.*
	from field_264
),

-- 6. De-dup results

cul_titles as 

(select distinct 
	recs.title,
	recs.instance_id,
	recs.instance_hrid,
	recs.instance_suppress,
	recs.publisher,
	substring (ip.date_of_publication,'\d{4}') as cul_pubyear,
	isbns.cul_normalized_isbn,
	isbns.cul_truncated_978_isbn
	
from recs 
	left join isbns
	on recs.instance_hrid = isbns.instance_hrid 
	
	left join folio_reporting.instance_publication as ip 
	on recs.instance_hrid = ip.instance_hrid
),

-- 7. Join the CUL results to the CUP list showing all items in both lists and indicating matchings (on ISBN)

allrecs as 
(select 
	cul_titles.title,
	cul_titles.instance_id,
	cul_titles.instance_hrid,
	cul_titles.instance_suppress,
	cul_titles.publisher,
	cul_titles.cul_pubyear,
	cul_titles.cul_normalized_isbn,
	cul_titles.cul_truncated_978_isbn,
	cup.seq_no,
	cup.titleeditionvolume as cup_title,
	cup.isbn as cup_isbn,
	case when cup.isbn is null then '-' else substring(cup.isbn,1,12) end as cup_truncated_isbn,
	cup.binding,
	cup.pubyear

from local_core.cup_complete_catalog cup
	full join cul_titles 
	on (case when cup.isbn is null then '-' else substring(cup.isbn,1,12) end) = cul_titles.cul_truncated_978_isbn
)

-- 8. Aggregate the fields that were producing combinatorial rows

select 
	string_agg (distinct allrecs.seq_no::varchar,' | ') as cup_seq_no,
	string_agg (distinct allrecs.cup_title,' | ') as cup_title,
	allrecs.cup_isbn,
	string_agg (distinct allrecs.cup_truncated_isbn,' | ') as cup_truncated_isbn,
	string_agg (distinct allrecs.binding,' | ') as cup_binding,
	string_agg (distinct allrecs.pubyear::varchar,' | ') as cup_pubyear,
	allrecs.title as cul_title,
	string_agg (distinct allrecs.cul_pubyear,' | ') as cul_pubyear,
	allrecs.instance_hrid,
	allrecs.instance_suppress,
	he.holdings_hrid,
	he.discovery_suppress as holdings_suppress,
	string_agg (distinct he.permanent_location_name,' | ') as holdings_perm_location_names,
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix, 
		case when he.copy_number >'1' then concat ('c.',he.copy_number) else '' end)) as holdings_call_number,
	count (ie.item_id)::varchar as count_of_items,
	string_agg (distinct ie.permanent_loan_type_name,' | ') as loan_type_names,
	string_agg (distinct allrecs.publisher,' | ') as publisher,
	string_agg (distinct allrecs.cul_normalized_isbn,' | ') as cul_normalized_isbns,
	string_agg (distinct allrecs.cul_truncated_978_isbn,' | ') as cul_truncated_isbns
	
from allrecs 
	left join folio_reporting.holdings_ext as he 
	on allrecs.instance_id = he.instance_id
	
	left join folio_reporting.item_ext as ie 
	on he.holdings_id = ie.holdings_record_id

group by 
	allrecs.title, 
	allrecs.instance_hrid, 
	allrecs.instance_suppress, 
	he.holdings_hrid, 
	he.discovery_suppress, 
	he.call_number_prefix, 
	he.call_number, 
	he.call_number_suffix, 
	he.copy_number, 
	allrecs.seq_no, 
	allrecs.cup_isbn

order by allrecs.seq_no
;
