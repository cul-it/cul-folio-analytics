--CR239
--Campus_Store_ISBNs_matched_unaggregated
--This query matches a de-duped list of ISBNs from the Campus Store to library holdings
--In this query, the original two columns of ISBNs from the Store list have been added, and item record data has also been added. 
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 4/16/24

--1. Get all Store ISBNs and union the results to make a single list of ISBNs

with isbn_union as 

(select 
	store.seq_no,
	store."Adopted_ISBN" as isbn
	from local_core.jl_spring_2024_store as store
	where store."Adopted_ISBN" >''
	
	union

	(select 
	store.seq_no,
	store."Pricing_ISBN" as isbn 
	
	from local.jl_spring_2024_store as store 
	where store."Pricing_ISBN" >''
	)
	
order by seq_no
),

-- 2. Aggregate the ISBNs by sequence number

union_agg as 
(select 
	isbn_union.seq_no,
	string_agg (distinct isbn_union.isbn,' | ') as isbn_aggregated
	
	from isbn_union 
	group by seq_no 
),

-- 3. Get all Cornell Library ISBNs, including inactive ones, and normalize them

cornell_isbns as 
	(select 
	iid.instance_hrid,
	iid.identifier_type_name,
	substring (iid.identifier,'\d{1,}') as isbn 
	
	from folio_reporting.instance_identifiers as iid 
	where iid.identifier_type_name like '%ISBN%'
),

-- 4. Get all instance and holdings records and mark the holdings as print or electronic

print_or_e as 
(select 
	instext.instance_id,
	instext.instance_hrid,
	he.holdings_hrid,
	he.discovery_suppress as holdings_suppress,
	string_agg (distinct case when he.permanent_location_name = 'serv,remo' then 'Electronic' else 'Print' end,' | ') as holdings_format 
	
	from folio_reporting.instance_ext as instext 
	left join folio_reporting.holdings_ext as he 
	on instext.instance_id = he.instance_id 
	
	group by 
	instext.instance_id,
	instext.instance_hrid,
	he.holdings_hrid,
	he.discovery_suppress
),

-- 5. Get URLs for all instance records; if suppressed, mark URL field NULL

urls as 
(select 
	instext.title,
	instext.instance_id,
	instext.instance_hrid,
	instext.discovery_suppress as instance_suppress,
	case when instext.discovery_suppress = 'True' then null 
		else concat ('https://catalog.library.cornell.edu/catalog/',instext.instance_hrid) end as catalog_url
	
	from folio_reporting.instance_ext as instext 
),

-- 6. Get all necessary bibliographic information for instance, holdings and items; include item status

recs as 
(select 
	instext.title,
	instext.instance_id,
	instext.instance_hrid,
	instext.discovery_suppress as instance_suppress,
	he.holdings_hrid,
	he.discovery_suppress as holdings_suppress,
	ie.item_hrid,
	ie.discovery_suppress as item_suppress,
	ie.status_name as item_status,
	ie.status_date::date as item_status_date,
	eds.edition as edition,
	he.permanent_location_name,		
	concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
			case when ie.copy_number >'' then concat (' c.',ie.copy_number) else '' end) as call_number

	from folio_reporting.instance_ext as instext 
		left join folio_reporting.holdings_ext as he
		on instext.instance_id = he.instance_id
		
		left join folio_reporting.item_ext as ie 
		on he.holdings_id = ie.holdings_record_id
		
		left join folio_reporting.instance_editions as eds 
		on instext.instance_hrid = eds.instance_hrid
),

-- 7. Get the 899$a field for instance records; this contains codes for simultaneous users of electronic resources 

field_899 as 
(select 
	sm.instance_hrid,
	sm.content as field_899a,
	case 
		when trim (trailing '.' from sm.content) ilike '%mu' then 'multi-user'
		when (substring (sm.content,'\d{1,}u') is not null or substring (sm.content,'\d{1,}U') is not null) 
		then concat (substring (sm.content, '\d{1,}'),' users')
		else '?' end
	as number_of_simultaneous_users
	
	from srs_marctab as sm
	
	where sm.field = '899' and sm.sf = 'a'
)

-- 8. Join library records to Cornell Store records by ISBN

select distinct 
	store.seq_no,
	store."Catalog_Name_Term_Name",
	store."Department",
	store."Course",
	store."Section",
	store."Adopted_ISBN",
	store."Pricing_ISBN",
	--union_agg.isbn_aggregated as store_isbns,
	store."Author",
	store."Title",
	store."Publisher",
	store."Edition",
	store."Publication_Year",
	store."Content_Type",
	store."Total_Students_Enrolled",
	store."LMS_ID",
	recs.title,
	recs.permanent_location_name,
	recs.call_number,
	recs.instance_hrid,	
	recs.holdings_hrid,
	recs.item_hrid,
	recs.instance_suppress,
	recs.holdings_suppress,
	recs.item_suppress,
	recs.item_status,
	recs.item_status_date,
	string_agg (distinct recs.edition,' | ') as edition,
	string_agg (distinct ip.date_of_publication,' | ') as date_of_publication,
	print_or_e.holdings_format,
	cornell_isbns.isbn,
	field_899.field_899a,
	field_899.number_of_simultaneous_users,
	urls.catalog_url

from local.jl_spring_2024_store as store
	left join union_agg 
	on store.seq_no = union_agg.seq_no
	
	left join isbn_union 
	on union_agg.seq_no = isbn_union.seq_no
	
	left join cornell_isbns 
	on isbn_union.isbn = cornell_isbns.isbn

	left join recs 
	on cornell_isbns.instance_hrid = recs.instance_hrid
	
	left join urls 
	on recs.instance_hrid = urls.instance_hrid
	
	left join print_or_e 
	on recs.instance_hrid = print_or_e.instance_hrid
	
	left join field_899 
	on recs.instance_hrid = field_899.instance_hrid
	
	left join folio_reporting.instance_publication as ip 
	on recs.instance_hrid = ip.instance_hrid
	
group by 
	store.seq_no,
	store."Catalog_Name_Term_Name",
	store."Department",
	store."Course",
	store."Section",
	store."Adopted_ISBN",
	store."Pricing_ISBN",
	--union_agg.isbn_aggregated,
	store."Author",
	store."Title",
	store."Publisher",
	store."Edition",
	store."Publication_Year",
	store."Content_Type",
	store."Total_Students_Enrolled",
	store."LMS_ID",	
	recs.title,
	recs.instance_hrid,
	recs.instance_suppress,
	recs.holdings_hrid,
	recs.holdings_suppress,
	recs.item_hrid,
	recs.item_suppress,
	recs.item_status,
	recs.item_status_date,
	recs.permanent_location_name,
	recs.call_number,
	print_or_e.holdings_format,
	cornell_isbns.isbn,
	field_899.field_899a,
	field_899.number_of_simultaneous_users,
	urls.catalog_url
	
order by store.seq_no
;
