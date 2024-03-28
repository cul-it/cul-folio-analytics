--CR234
--Campus_Store_ISBNs_matched

--This query matches a list of de-duped ISBNs from the Campus Store (books needed for course reserve) to library holdings. Campus NOTE: Store ISBNs are provided by the query requestor and are uploaded as a local table. 
--Query writer: Joanne Leary (jl41)
--Query tester: Vandana Shah (vp25)
--Query posted on 03/28/24

with isbn_union as 
(select 
	store.seq_no,
	store."Billing_ISBN" as isbn
	from local_core.jl_all_data_store as store
	where store."Billing_ISBN" >''

union 
	(select 
	store.seq_no,
	store."Adopted_ISBN" as isbn
	from local_core.jl_all_data_store as store
	where store."Adopted_ISBN" >''
	)

union 
	(select 
	store.seq_no,
	store."Pricing_ISBN" as isbn 
	
	from local_core.jl_all_data_store as store 
	where store."Pricing_ISBN" >''
	)
	
order by seq_no
),

union_agg as 
(select 
	isbn_union.seq_no,
	string_agg (distinct isbn_union.isbn,chr(10)) as isbn_aggregated
	
	from isbn_union 
	group by seq_no 
),

cornell_isbns as 
	(select 
	iid.instance_hrid,
	iid.identifier_type_name,
	iid.identifier as isbn 
	
	from folio_reporting.instance_identifiers as iid 
	where iid.identifier_type_name like '%ISBN%'
),

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

recs as 
(select 
	instext.title,
	instext.instance_id,
	instext.instance_hrid,
	instext.discovery_suppress as instance_suppress,
	he.holdings_hrid,
	he.discovery_suppress as holdings_suppress,
	eds.edition as edition,
	case 
		when instext.instance_hrid is not null  
		then concat (instext.instance_hrid, ' -- ', case when instext.discovery_suppress = 'True' then 'Suppressed' else 'Unsuppressed' end) 
		else 'No instance' end 
		as instance_hrid_with_supress_status,

	case 
		when he.holdings_id is not null
		then concat (he.holdings_hrid, ' -- ', case when he.discovery_suppress = 'True' then 'Suppressed' else 'Unsuppressed' end) 
		else 'No holdings' end
		as holdings_hrid_with_supress_status,
		
	string_agg (concat (he.permanent_location_name,' ',he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,
			case when he.copy_number >'' then concat (' c.',he.copy_number) else '' end, '  |  ',instext.instance_hrid,
			' -- ',he.holdings_hrid),chr(10) order by he.permanent_location_name, he.call_number, he.holdings_hrid, he.copy_number) as holdings

	from folio_reporting.instance_ext as instext 
		left join folio_reporting.holdings_ext as he
		on instext.instance_id = he.instance_id
		
		left join folio_reporting.instance_editions as eds 
		on instext.instance_hrid = eds.instance_hrid

	group by 
	instext.title,
	instext.instance_id,
	instext.instance_hrid,
	instext.discovery_suppress,
	he.holdings_hrid,
	he.discovery_suppress,
	eds.edition,
	case 
		when instext.instance_hrid is not null 
		then concat (instext.instance_hrid, ' -- ', case when instext.discovery_suppress = 'True' then 'Suppressed' else 'Unsuppressed' end) 
		else 'No instance' end,
	case 
		when he.holdings_id is not null 
		then concat (he.holdings_hrid, ' -- ', case when he.discovery_suppress = 'True' then 'Suppressed' else 'Unsuppressed' end) 
		else 'No holdings' end 	
),

field_899 as 
(select 
	sm.instance_hrid,
	sm.content as field_899a
	
	from srs_marctab as sm 
	where sm.field = '899' and sm.sf = 'a'
)

select distinct 
	store.seq_no,
	store."Catalog_Name_Term_Name",
	store."Department",
	store."Course",
	union_agg.isbn_aggregated as store_isbns,
	store."Author",
	store."Title",
	store."Publisher",
	store."Delivery_Method",
	store."Content_Type",
	store."Access_Codes_Required?",
	store."Total_Participating_Sections",
	store."Total_Students_Enrolled_in_Participating_Sections",
	store."Duration_Length",
	string_agg (distinct recs.title,chr(10)) as cul_title,
	string_agg (distinct recs.edition,chr(10)) as edition,
	string_agg (distinct ip.date_of_publication,' | ') as date_of_publication,
	string_agg (distinct instance_hrid_with_supress_status,chr(10)) as instance_hrids_with_suppress_status,
	string_agg (distinct holdings_hrid_with_supress_status,chr(10)) as holdings_hrids_with_suppress_status,
	string_agg (distinct recs.holdings,chr(10)) as holdings,
	string_agg (distinct cornell_isbns.isbn,chr(10)) as cornell_isbns,
	string_agg (distinct field_899.field_899a,chr(10)) as field_899a,
	string_agg (distinct urls.catalog_url,chr(10)) as catalog_urls,
	string_agg (distinct print_or_e.holdings_format,' | ') as holdings_format

from local_core.jl_all_data_store as store
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
	union_agg.isbn_aggregated,
	store."Author",
	store."Title",
	store."Publisher",
	store."Delivery_Method",
	store."Content_Type",
	store."Access_Codes_Required?",
	store."Total_Participating_Sections",
	store."Total_Students_Enrolled_in_Participating_Sections",
	store."Duration_Length"
	
order by store.seq_no;

