-- MCR229
-- inventory by call number range, with links to online access
--This query gets the holdings-level inventory for a library/location/call number range and shows item count and circ count since 2015

--Query writer: Joanne LEary (jl41)
--Query tester: Vandana Shah (vp25)
--Date posted: 11/19/24


WITH parameters AS 
(SELECT
	'%Mann%'::VARCHAR AS library_name_filter, -- Required. ex: Mann library, Mui Ho Fine Arts library, Cox Library of Music and Dance, Clark Africana library, etc.
	'Mann'::VARCHAR AS location_name_filter, -- Required. ex: Mann, Fine Arts, Music, Fine Arts Reference, etc.
	'QH'::VARCHAR AS begin_lc_class_filter, -- Required. ex: SB, T, QA, PE, NAC, etc. (results will include the beginning LC class)
	'QL'::VARCHAR AS end_lc_class_filter,-- Required. 
	'1'::numeric as begin_class_number_filter, -- Required. Ex: 1 
	'9999'::numeric as end_class_number_filter -- Required (up to but not including this number). Ex: 9999 
),

-- 1. Get Voyager circs since 2015 (if another cutoff year is desisred, change the year on  line 18)

voycircs AS 
(select distinct
	cta.item_id::VARCHAR AS item_hrid,
	DATE_PART ('year',cta.charge_date::DATE) AS year_of_circulation,
	COUNT (DISTINCT cta.circ_transaction_id) AS circs
	
	FROM vger.circ_trans_archive AS cta 
	WHERE DATE_PART ('year',cta.charge_date::DATE)>='2015'
	GROUP BY cta.item_id::VARCHAR, DATE_PART ('year',cta.charge_date::DATE)
),

voycircsmax AS 
(SELECT distinct
	voycircs.item_hrid,
	MAX (voycircs.year_of_circulation) AS last_year_of_checkout
	
	FROM voycircs
	GROUP BY voycircs.item_hrid
),

-- 2. Get Folio circs

foliocircs AS
(SELECT distinct
	 li.hrid AS item_hrid,
	 DATE_PART ('year',li.loan_date::DATE) AS year_of_circulation,
	 COUNT (DISTINCT li.loan_id) AS circs
	 
	FROM folio_derived.loans_items AS li
	WHERE li.hrid IS NOT NULL 
	GROUP BY li.hrid, date_part ('year',li.loan_date::date)
),

foliocircsmax AS 
(select distinct
	foliocircs.item_hrid,
	MAX (foliocircs.year_of_circulation) AS last_year_of_checkout
	
	FROM foliocircs 
	GROUP BY foliocircs.item_hrid
),

-- 3. Get year of publication

pub_year AS 
(select distinct
	sm.instance_hrid,
	SUBSTRING (sm.CONTENT,8,4) AS year_of_publication
	
FROM folio_source_record.marc__t AS sm 
WHERE sm.field = '008'
),

-- 4. Get publication status 

pub_status AS 
(SELECT distinct
	sm.instance_hrid,
	ps."PubStatusDesc",
	SUBSTRING (sm.content,7,1) AS pub_status_code

FROM folio_source_record.marc__t AS sm
	LEFT JOIN local_shared.publication_status1 AS ps
	ON trim (SUBSTRING (sm.content,7,1)) = trim (ps."PubStatusCode")

WHERE sm.field = '008'
),

-- 5. Get open access titles

open_access AS 
(SELECT DISTINCT
	iid.instance_hrid,
	de.oa_publish_start_date,
	de.journal_url,
	de.url_in_doaj

FROM folio_derived.instance_identifiers AS iid
	LEFT JOIN local_shared.doaj_20240930 AS de 
	ON iid.identifier = de.journal_issn_print_version

	LEFT JOIN folio_derived.instance_identifiers AS iid2 
	ON iid2.identifier = de.journal_eissn_online_version

WHERE iid.identifier_type_name ILIKE '%ISSN%'
	AND iid2.identifier_type_name ILIKE '%ISSN%'
),

-- 6. Get electronic version of print titles through 776x (next two subqueries)
	
	-- 6a. Get issn FROM 776x

online_issn_776 AS 
	(select distinct
		sm.instance_hrid,
		ii.title,
		ii.discovery_suppress,
		sm.content AS online_issn_from_776
	
	FROM folio_source_record.marc__t AS sm 
	INNER JOIN folio_inventory.instance__t AS ii 
	ON sm.instance_hrid = ii.hrid
	
	WHERE sm.field = '776'
		AND sm.sf = 'x'
		AND (ii.discovery_suppress = FALSE OR ii.discovery_suppress IS NULL)
	),
	
	-- 6b. Get the URL
	
online_title AS 
	(select distinct
		oi.instance_hrid AS print_instance_hrid,
		oi.online_issn_from_776,
		string_agg (distinct ii.title,chr(10)) AS online_title,
		ii.hrid AS online_instance_hrid,
		string_agg (distinct sm.content,chr(10)) AS url_for_online_title
	
	FROM online_issn_776 AS oi 
		INNER JOIN folio_derived.instance_identifiers AS iid  
		ON oi.online_issn_from_776 = iid.identifier
		
		INNER JOIN folio_inventory.instance__t AS ii 
		ON iid.instance_hrid = ii.hrid
		
		INNER JOIN folio_source_record.marc__t AS sm 
		ON ii.hrid = sm.instance_hrid 
		
	WHERE sm.field = '856'
		AND sm.sf = 'u'
		
	group by 
		oi.instance_hrid,
		oi.online_issn_from_776,		
		ii.hrid
	),

-- 7. Get EBSCO online identifiers FROM 773 subfield o and get the URL FROM the 856 subfield u
ebsco AS 
	(SELECT
	    DISTINCT 
	    sm.instance_hrid,
	    sm2.content AS ebsco_open_access_url,
	    ie.title,
	    ie.mode_of_issuance_name,
	    ie.discovery_suppress AS instance_suppress
	FROM
	    folio_source_record.marc__t as sm --public.srs_marctab sm
	INNER JOIN folio_derived.instance_ext ie
	    ON sm.instance_hrid = ie.instance_hrid
	INNER JOIN folio_source_record.marc__t as sm2--srs_marctab AS sm2 
		ON sm2.instance_hrid = ie.instance_hrid
			AND sm.instance_hrid = sm2.instance_hrid
	INNER JOIN folio_derived.instance_identifiers ii
	    ON ie.instance_hrid = ii.instance_hrid
	    
	WHERE
	    sm.field = '773'
	    AND sm.sf = 'o'
	    AND sm."content" in ('642','4476','5937','2797172','2418090','1118986','3329754','3550804')
	    AND ii.identifier ILIKE '%EBZ%'
	    AND sm2.field = '856'
	    AND sm2.sf = 'u'
),

-- 8. Get online matches WHERE the print and online ISSN are the same (next 4 subqueries)

	-- 8a. Get ISSNs for print journals in selected location (Mann stacks in this case)
	
unitrecs AS 
	(SELECT distinct
		ii.title,
		ii.hrid AS instance_hrid,
		he.holdings_hrid,
		ii.discovery_suppress AS instance_suppress,
		he.discovery_suppress AS holdings_suppress,
		he.permanent_location_name AS mann_location,
		he.call_number,
		he.type_name AS holdings_type_name,
		iid.identifier AS print_issn
	
	FROM folio_inventory.instance__t AS ii 
		LEFT JOIN folio_derived.holdings_ext AS he 
		ON ii.id = he.instance_id 
		
		LEFT JOIN folio_derived.instance_identifiers AS iid 
		ON ii.id = iid.instance_id  
	
	WHERE he.permanent_location_name = (SELECT location_name_filter FROM parameters)
		AND iid.identifier_type_name = 'ISSN'
		
	ORDER BY ii.title
	),
	
	-- 8b. Get URLs for any instance that has an 856 link 
	
urls AS 
	(SELECT distinct
		sm.instance_hrid,
		STRING_AGG (DISTINCT sm.content,' | ') AS URL
	
	FROM folio_source_record.marc__t AS sm 
	WHERE sm.field = '856' AND sm.sf = 'u'
	GROUP BY sm.instance_hrid
	),
	
	-- 8c. Get instance HRIDs for anything with a serv,remo location WHERE the ISSN matches the ISSN found in the first subquery
	 
recs2 AS 
	(SELECT distinct
		unitrecs.title AS unit_title,
		unitrecs.instance_hrid AS unit_instance_hrid,
		STRING_AGG (DISTINCT unitrecs.holdings_hrid,' | ') AS unit_holdings_hrid,
		STRING_AGG (DISTINCT unitrecs.mann_location,' | ') AS unit_location,
		STRING_AGG (DISTINCT unitrecs.call_number,' | ') AS unit_call_number,
		STRING_AGG (DISTINCT unitrecs.holdings_type_name,' | ') AS unit_holdings_type_name,
		STRING_AGG (DISTINCT unitrecs.print_issn,' | ') AS unit_print_issns,
		ii.hrid AS serv_remo_instance_hrid,
		STRING_AGG (DISTINCT ii.title,' | ') AS serv_remo_title,
		STRING_AGG (DISTINCT he.holdings_hrid,' | ') AS serv_remo_holdings_hrid,
		STRING_AGG (DISTINCT he.permanent_location_name,' | ') AS serv_remo_location_name,
		STRING_AGG (DISTINCT he.call_number,' | ') AS serv_remo_call_numbers,
		STRING_AGG (DISTINCT iid.identifier,' | ') AS serv_remo_issns
	
	FROM unitrecs 
		LEFT JOIN folio_derived.instance_identifiers AS iid 
		ON unitrecs.print_issn = iid.identifier 
		
		LEFT JOIN folio_inventory.instance__t AS ii 
		ON iid.instance_id = ii.id 
		
		LEFT JOIN folio_derived.holdings_ext AS he 
		ON ii.id = he.instance_id
	
	WHERE iid.identifier_type_name = 'ISSN' 
		AND he.permanent_location_name = 'serv,remo'
	
	GROUP BY unitrecs.title, unitrecs.instance_hrid, ii.hrid
	),
	
	-- 8d. Link the records that have URLs (second subquery) to the records WHERE the print and online ISSNs match (third subquery)
	
unitrecs3 AS
 
	(SELECT 
		recs2.*,
		urls.URL
	
	FROM recs2 
		LEFT JOIN urls 
		ON recs2.serv_remo_instance_hrid = urls.instance_hrid 
	),
	
-- 9. Get last issue received - next three subqueries

lastissue as 
(select distinct
	row_number () over (order by po_line__t.title_or_package, pieces__t.received_date, pieces__t.caption) as row_no,
	purchase_order__t.order_type,
	po_line__t.title_or_package,
	instance__t.hrid as instance_hrid,
	purchase_order__t.workflow_status,
	po_line__t.po_line_number,
	pieces__t.format,
	pieces__t.title_id,
	pieces__t.receiving_status,
	po_line__t.receipt_status,
	pieces__t.received_date,
	pieces__t.display_summary,
	pieces__t.comment,
	ll2.library_name,
	coalesce (ll.location_name, he.permanent_location_name) as location

from folio_orders.purchase_order__t 
	left join folio_orders.po_line__t 
	on purchase_order__t.id = po_line__t.purchase_order_id
	
	left join folio_orders.pieces__t 
	on po_line__t.id = pieces__t.po_line_id

	left join folio_orders.titles__t 
	on pieces__t.title_id = titles__t.id
	
	left join folio_derived.locations_libraries ll 
	on pieces__t.location_id = ll.location_id
	
	left join folio_derived.holdings_ext as he 
	on pieces__t.holding_id = he.holdings_id
	
	left join folio_derived.locations_libraries as ll2 
	on coalesce (ll.location_name, he.permanent_location_name) = ll2.location_name
	
	left join folio_inventory.instance__t 
	on po_line__t.instance_id = instance__t.id
	
where pieces__t.receiving_status = 'Received'
	and ll.library_name like (select library_name_filter from parameters)
),

lastissue2 as 
	(select 
		lastissue.title_id,
		lastissue.title_or_package,
		max (lastissue.row_no) as max_row_no
	from lastissue
	
	group by lastissue.title_id, lastissue.title_or_package
	
	order by lastissue.title_or_package
),

lastissue3 as 
	(select 
		lastissue.*
	from lastissue 
		inner join lastissue2 
		on lastissue.title_id = lastissue2.title_id
			and lastissue.row_no = lastissue2.max_row_no
	order by lastissue.title_or_package
	),
	

-- 10. Join results from the preceding queries; apply criteria for call number range, Library, holdings suppression status

unitrecs2 AS 
(SELECT distinct
	ll.library_name,
	he.permanent_location_name,
	ii.title,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ii.discovery_suppress AS instance_suppress,
	he.discovery_suppress AS holdings_suppress,
	ie.item_hrid,
	imoi.name AS mode_of_issuance,
	he.call_number,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', 
		CASE WHEN he.copy_number >'1' then CONCAT ('c.',he.copy_number) else '' end)) AS whole_call_number,
	pub_status."PubStatusDesc" AS publication_status,
	he.receipt_status,
	lastissue3.display_summary as last_issue_received,--last_issue3.last_issue_received,
	lastissue3.received_date::date as date_last_issue_received, --last_issue3.date_last_issue_received,
	lastissue3.receiving_status, --last_issue3.po_line_receipt_status,
	lastissue3.receipt_status as po_line_receipt_status,
	open_access.oa_publish_start_date::varchar AS open_access_start_year,
	open_access.journal_url,
	open_access.url_in_doaj,
	online_title.online_issn_from_776,
	online_title.online_instance_hrid,
	online_title.online_title,
	STRING_AGG (DISTINCT online_title.url_for_online_title,' | ') AS url_for_online_title,
	ebsco.ebsco_open_access_url,
	case when hs.holdings_statement is null then null else concat (he.holdings_hrid,' | ',he.permanent_location_name,'  ',STRING_AGG (DISTINCT hs.holdings_statement,' | ')) end AS unit_holdings_statements,
	SUBSTRING (he.call_number,'^[A-Za-z]{1,3}') AS lc_class,
	REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.') AS lc_class_number,
	TRIM (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')) AS first_cutter, 
	he.type_name AS holdings_type_name,
	pub_year.year_of_publication,
	CASE WHEN SUM (voycircs.circs) IS NULL THEN 0 ELSE SUM (voycircs.circs) END AS total_voyager_circs_since_2015,
	CASE WHEN SUM (foliocircs.circs) IS NULL THEN 0 ELSE SUM (foliocircs.circs) END AS total_folio_circs,
	COALESCE (foliocircsmax.last_year_of_checkout::VARCHAR, voycircsmax.last_year_of_checkout::VARCHAR) AS last_year_of_checkout,
	invitems.effective_shelving_order

FROM folio_inventory.instance__t AS ii 
	LEFT JOIN folio_derived.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN folio_inventory.mode_of_issuance__t as imoi--inventory_modes_of_issuance imoi 
	ON ii.mode_of_issuance_id = imoi.id
	
	LEFT JOIN folio_derived.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id 
	
	LEFT JOIN folio_derived.holdings_statements AS hs 
	ON he.holdings_id = hs.holdings_id
	
	LEFT JOIN folio_inventory.item__t as invitems -- inventory_items AS invitems 
	ON he.holdings_id = invitems.holdings_record_id 
	
	LEFT JOIN folio_derived.item_ext AS ie 
	ON invitems.id = ie.item_id 
	
	LEFT JOIN voycircs 
	ON ie.item_hrid = voycircs.item_hrid
	
	LEFT JOIN voycircsmax 
	ON ie.item_hrid = voycircsmax.item_hrid
	
	LEFT JOIN foliocircs 
	ON ie.item_hrid = foliocircs.item_hrid
	
	LEFT JOIN foliocircsmax 
	ON ie.item_hrid = foliocircsmax.item_hrid
	
	LEFT JOIN pub_year
	ON ii.hrid = pub_year.instance_hrid
	
	LEFT JOIN pub_status 
	ON ii.hrid = pub_status.instance_hrid
	
	LEFT JOIN open_access 
	ON ii.hrid = open_access.instance_hrid
	
	LEFT JOIN ebsco 
	ON ii.hrid = ebsco.instance_hrid
	
	LEFT JOIN online_title 
	ON ii.hrid = online_title.print_instance_hrid
	
	LEFT JOIN lastissue3 
	ON ii.hrid = lastissue3.instance_hrid


WHERE 

/*(ll.library_name like (select library_name_filter from parameters) --'Mann Library'
	AND substring (he.call_number,'^[A-Za-z]{1,3}') >= 'HN'
	AND substring (he.call_number,'^[A-Za-z]{1,3}') < 'HQ'
	--and REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::numeric >=9000
	--and REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::numeric <9000
	--AND trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')) = '1'
	--AND trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')) < '1996'
	--AND trim (trailing '.' FROM SUBSTRING (he.call_number, '\.{0,}[A-Z][0-9]{1,}')) <='1996'
	AND (he.discovery_suppress = 'false' or he.discovery_suppress IS NULL)
	)
	
	or 
	
	(ll.library_name like (select library_name_filter from parameters) --'Mann Library'
	AND substring (he.call_number,'^[A-Za-z]{1,3}') = 'HQ'
	and REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::numeric >=1
	and REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::numeric <=999
	AND (he.discovery_suppress = 'false' or he.discovery_suppress IS NULL)
	)*/

	ll.library_name ILIKE (SELECT library_name_filter FROM parameters)
		AND SUBSTRING (he.call_number,'^[A-Za-z]{1,3}') >= (SELECT begin_lc_class_filter FROM parameters)
		AND SUBSTRING (he.call_number,'^[A-Za-z]{1,3}') <= (SELECT end_lc_class_filter FROM parameters)
		and REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::numeric >= (select begin_class_number_filter from parameters)
		and REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::numeric < (select end_class_number_filter from parameters)
		AND (he.discovery_suppress = 'false' or he.discovery_suppress IS NULL)

GROUP BY 
	ll.library_name,
	he.permanent_location_name,
	ii.title,
	ii.hrid,
	he.holdings_hrid,
	ii.discovery_suppress,
	he.discovery_suppress,
	ie.item_hrid,
	he.call_number,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', 
		CASE WHEN he.copy_number >'1' THEN CONCAT ('c.',he.copy_number) ELSE '' END)),
	pub_status."PubStatusDesc",
	he.receipt_status,
	lastissue3.display_summary,--last_issue3.last_issue_received,
	lastissue3.received_date, --last_issue3.date_last_issue_received,
	lastissue3.receiving_status, --last_issue3.po_line_receipt_status,
	lastissue3.receipt_status, 
	open_access.oa_publish_start_date::varchar,
	open_access.journal_url,
	open_access.url_in_doaj,
	online_title.online_issn_from_776,
	online_title.online_instance_hrid,
	online_title.online_title,
	ebsco.ebsco_open_access_url,
	SUBSTRING (he.call_number,'^[A-Za-z]{1,3}'),
	REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.'),
	TRIM (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')),
	pub_year.year_of_publication,
	imoi.name,
	he.type_name,
	hs.holdings_statement,
	ie.material_type_name,
	foliocircsmax.last_year_of_checkout::VARCHAR,
	voycircsmax.last_year_of_checkout::VARCHAR,
	invitems.effective_shelving_order
),

-- 11. Get Annex holdings

annex_hold AS 
(SELECT distinct
	unitrecs2.instance_hrid,
	ll.library_name,
	STRING_AGG (DISTINCT ll.location_name,' | ') AS annex_locations,
	string_agg (DISTINCT concat (he.holdings_hrid,' | ',he.permanent_location_name,' ',concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,
		case when he.copy_number >'1' then concat ('c.',he.copy_number) else '' end), '  ',hs.holdings_statement), chr(10)) 
		as annex_holdings_statements
	
FROM unitrecs2 
	LEFT JOIN folio_inventory.instance__t as ii --inventory_instances AS ii 
	ON unitrecs2.instance_hrid = ii.hrid 
	
	LEFT JOIN folio_derived.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN folio_derived.holdings_statements AS hs
	ON he.holdings_id = hs.holdings_id
	
	LEFT JOIN folio_derived.locations_libraries ll 
	ON he.permanent_location_id = ll.location_id

WHERE ll.library_name = 'Library Annex'
and (he.discovery_suppress = 'false' or he.discovery_suppress is null)

GROUP BY unitrecs2.instance_hrid, ll.library_name, he.permanent_location_name, he.holdings_hrid, hs.holdings_statement

),

-- 12. Join unit library results to Annex results; join to records with other online versions (from unitrecs3 subquery, 8d)

final AS 
(SELECT distinct
	unitrecs2.library_name,
	unitrecs2.permanent_location_name,
	unitrecs2.title,
	unitrecs2.instance_hrid,
	unitrecs2.holdings_hrid,
	unitrecs2.instance_suppress,
	unitrecs2.holdings_suppress,
	unitrecs2.item_hrid,
	unitrecs2.whole_call_number,unitrecs2.lc_class,
	unitrecs2.lc_class_number::numeric,
	unitrecs2.first_cutter,
	unitrecs2.total_voyager_circs_since_2015,
	unitrecs2.total_folio_circs,
	unitrecs2.last_year_of_checkout,
	unitrecs2.mode_of_issuance,
	unitrecs2.holdings_type_name,
	unitrecs2.year_of_publication,	
	unitrecs2.publication_status,
	unitrecs2.receipt_status,
	unitrecs2.last_issue_received,
	unitrecs2.date_last_issue_received,
	unitrecs2.po_line_receipt_status,
	unitrecs2.open_access_start_year,
	unitrecs2.journal_url,
	unitrecs2.url_in_doaj,
	unitrecs2.ebsco_open_access_url,
	unitrecs2.online_issn_from_776,
	unitrecs2.online_instance_hrid,
	unitrecs2.online_title,
	unitrecs2.url_for_online_title,
	unitrecs3.serv_remo_instance_hrid,
	unitrecs3.URL AS other_online_url,
	unitrecs2.unit_holdings_statements,
	annex_hold.annex_holdings_statements,
	unitrecs2.effective_shelving_order
	
FROM unitrecs2 
	LEFT JOIN annex_hold
	ON unitrecs2.instance_hrid = annex_hold.instance_hrid
	
	LEFT JOIN unitrecs3 
	ON unitrecs2.instance_hrid = unitrecs3.unit_instance_hrid

WHERE unitrecs2.permanent_location_name = (SELECT location_name_filter FROM parameters)
)

SELECT distinct
	final.library_name,
	final.permanent_location_name,
	final.title,
	final.instance_hrid,
	final.holdings_hrid,
	final.instance_suppress,
	final.holdings_suppress::boolean,
	final.whole_call_number,
	STRING_AGG (DISTINCT hn.note,' | ') AS holdings_notes,
	final.lc_class,
	final.lc_class_number::numeric,
	final.first_cutter,
	COUNT (DISTINCT final.item_hrid) AS count_of_items,
	SUM (final.total_voyager_circs_since_2015 + final.total_folio_circs) AS total_circs_since_2015,
	STRING_AGG (DISTINCT final.last_year_of_checkout,' | ') AS years_of_checkout,
	final.mode_of_issuance,
	final.holdings_type_name,
	final.year_of_publication,
	final.publication_status,
	final.receipt_status,
	final.last_issue_received,
	STRING_AGG (DISTINCT (final.date_last_issue_received)::varchar,' | ') AS date_last_issue_received,
	final.po_line_receipt_status,
	final.open_access_start_year,
	final.journal_url,
	final.url_in_doaj,
	final.ebsco_open_access_url,
	final.online_issn_from_776,
	final.online_instance_hrid,
	final.online_title,
	final.url_for_online_title,
	final.serv_remo_instance_hrid,
	final.other_online_url,
	string_agg (distinct final.unit_holdings_statements,chr(10)) as unit_holdings_statements,
	string_agg (distinct final.annex_holdings_statements,chr(10)) as annex_holdngs_statements
	
FROM final
	LEFT JOIN folio_derived.holdings_notes AS hn 
	ON final.holdings_hrid = hn.holding_hrid

GROUP BY 
	final.library_name,
	final.permanent_location_name,
	final.title,
	final.instance_hrid,
	final.holdings_hrid,
	final.instance_suppress,
	final.holdings_suppress::boolean,
	final.whole_call_number,
	final.lc_class,
	final.lc_class_number::numeric,
	final.first_cutter,
	final.mode_of_issuance,
	final.holdings_type_name,
	final.year_of_publication,
	final.publication_status,
	final.receipt_status,
	final.last_issue_received,
	final.po_line_receipt_status,
	final.open_access_start_year,
	final.journal_url,
	final.url_in_doaj,
	final.ebsco_open_access_url,
	final.online_issn_from_776,
	final.online_instance_hrid,
	final.online_title,
	final.url_for_online_title,
	final.serv_remo_instance_hrid,
	final.other_online_url

ORDER BY final.permanent_location_name, final.lc_class, final.lc_class_number::numeric, final.first_cutter, final.whole_call_number 
;
