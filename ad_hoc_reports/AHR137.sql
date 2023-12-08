-- 10-23-23: this query finds Mann items in call numbers A - E for possible transfer to the Annex; 
-- also to be used for record cleanup
-- 10-24-23: added receipt status. Get last issue received and date received (for issues rec'd after 7-1-21).
-- 10-24-23: get open access status of journals by linking to DOAJ list through print ISSN
-- 10-27-23: get online subscriptions to print title through the ISSN in 776$x
-- 11-5-23: get the EBSCO open access links
-- 11-7-23: add online titles with the same ISSN as the print titles
-- 11-13-23: add final subquery that converts the results to a holdings-level report
-- 12-08-23: This query was written by Joanne Leary and reviewed by Sharon Beltaine

-- 1. Get Voyager circs since 2015

WITH voycircs AS 
(SELECT
	cta.item_id::varchar AS item_hrid,
	date_part ('year',cta.charge_date::date) AS year_of_circulation,
	count (DISTINCT cta.circ_transaction_id) AS circs
	
	FROM vger.circ_trans_archive AS cta 
	WHERE date_part ('year',cta.charge_date::date)>='2015'
	GROUP BY cta.item_id::varchar, date_part ('year',cta.charge_date::date)
),

voycircsmax AS 
(SELECT 
	voycircs.item_hrid,
	max(voycircs.year_of_circulation) AS last_year_of_checkout
	FROM voycircs
	GROUP BY voycircs.item_hrid
),

-- 2. Get Folio circs

foliocircs AS
(SELECT 
	 li.hrid AS item_hrid,
	 date_part ('year',li.loan_date::date) AS year_of_circulation,
	 count (DISTINCT li.loan_id) AS circs
	 
	 FROM folio_reporting.loans_items AS li
	 WHERE li.hrid IS NOT null
	 GROUP BY li.hrid, date_part ('year',li.loan_date::date)
),

foliocircsmax AS 
(SELECT
	foliocircs.item_hrid,
	max (foliocircs.year_of_circulation) AS last_year_of_checkout
	FROM foliocircs 
	GROUP BY foliocircs.item_hrid
),

-- 3. Get year of publication

pub_year AS 
(SELECT
	sm.instance_hrid,
	substring (sm.CONTENT,8,4) AS year_of_publication
	FROM srs_marctab AS sm 
	WHERE sm.field = '008'
),

-- 4. Get publication status 

pub_status as 
(select 
	sm.instance_hrid,
	ps.pubstatusdesc,
	substring (sm.content,7,1) as pub_status_code

from srs_marctab as sm
	left join local_core.publication_status1 as ps
	on substring (sm.content,7,1) = ps.pubstatuscode

where sm.field = '008'
	--and substring (sm.content,7,1) in ('c','d','u')
),

-- 5. Get open access titles

open_access as 
(select distinct
	iid.instance_hrid,
	de.oa_publish_start_year::varchar,
	de."Journal URL",
	de."URL in DOAJ"
	--de."Journal ISSN (print version)" as print_issn,
	--de."Journal EISSN (online version)" as online_issn

from folio_reporting.instance_identifiers as iid
	left join local_core.doaj_edited as de 
	on iid.identifier = de."Journal ISSN (print version)" 

	left join folio_reporting.instance_identifiers as iid2 
	on iid2.identifier = de."Journal EISSN (online version)"

where iid.identifier_type_name ilike '%ISSN%'
	and iid2.identifier_type_name ilike '%ISSN%'
),

/*linking_issns as 
(select 
	iid.instance_hrid,
	ii.title,
	he.permanent_location_name,
	iid.identifier_type_name,
	iid.identifier as main_issn, 
	iid2.identifier as linking_issn

from folio_reporting.instance_identifiers as iid 
	left join folio_reporting.instance_identifiers as iid2 
	on iid.instance_hrid = iid2.instance_hrid
	
	left join inventory_instances as ii 
	on iid.instance_id = ii.id
	
	left join folio_reporting.holdings_ext as he 
	on ii.id = he.instance_id

where iid.identifier_type_name = 'ISSN'
	and iid2.identifier_type_name = 'Linking ISSN'
	and iid2.identifier != iid.identifier
),*/

-- 6. Get electronic version of print titles through 776x (next two subqueries)
	
	-- 6a. Get issn from 776x

	online_issn_776 as 
	(select
		sm.instance_hrid,
		ii.title,
		ii.discovery_suppress,
		sm.content as online_issn_from_776
	
	from srs_marctab as sm 
	inner join inventory_instances as ii 
	on sm.instance_hrid = ii.hrid
	
	where sm.field = '776'
		and sm.sf = 'x'
		and (ii.discovery_suppress = 'False' or ii.discovery_suppress is null)
	),
	
	-- 6b. Get the URL
	
	online_title as 
	(select
		oi.instance_hrid as print_instance_hrid,
		oi.online_issn_from_776,
		ii.title as online_title,
		ii.hrid as online_instance_hrid,
		sm.content as url_for_online_title
	
	from online_issn_776 as oi 
		inner join folio_reporting.instance_identifiers as iid  
		on oi.online_issn_from_776 = iid.identifier
		
		inner join inventory_instances as ii 
		on iid.instance_hrid = ii.hrid
		
		inner join srs_marctab as sm 
		on ii.hrid = sm.instance_hrid 
		
	where sm.field = '856'
		and sm.sf = 'u'
	),

-- 7. Get EBSCO online identifiers from 773 subfield o and get the URL from the 856 subfield u
	ebsco as 
	(SELECT
	    DISTINCT 
	    SM.instance_hrid,
	    sm2.content as ebsco_open_access_url,
	    IE.title,
	    IE.mode_of_issuance_name,
	    IE.discovery_suppress as instance_suppress
	FROM
	    public.srs_marctab SM
	INNER JOIN folio_reporting.instance_ext IE ON
	    SM.instance_hrid = IE.instance_hrid
	inner join srs_marctab as sm2 
		on sm2.instance_hrid = IE.instance_hrid
		and sm.instance_hrid = sm2.instance_hrid
	INNER JOIN folio_reporting.instance_identifiers II ON
	    IE.instance_hrid = II.instance_hrid
	WHERE
	    sm.field = '773'
	    AND sm.sf = 'o'
	    AND SM."content" in ('642','4476','5937','2797172','2418090','1118986','3329754','3550804')
	    AND II.identifier ilike '%EBZ%'
	    and sm2.field = '856'
	    and sm2.sf = 'u'
),

-- 8. Get online matches where the print and online ISSN are the same (next 4 subqueries)

	-- 8a. Get ISSNs for print journals in selected location (Mann stacks in this case)
	
	mannrecs as 
	(SELECT 
		ii.title,
		ii.hrid as instance_hrid,
		he.holdings_hrid,
		he.permanent_location_name as mann_location,
		he.call_number,
		he.type_name as holdings_type_name,
		iid.identifier as print_issn
	
	from inventory_instances as ii 
		left join folio_reporting.holdings_ext as he 
		on ii.id = he.instance_id 
		
		left join folio_reporting.instance_identifiers as iid 
		on ii.id = iid.instance_id  
	
	where he.permanent_location_name ='Mann'
		and iid.identifier_type_name = 'ISSN'
		and substring (he.call_number,'[A-Z]{1,3}') <'F'
		and (ii.discovery_suppress is null or ii.discovery_suppress = 'False')
		and (he.discovery_suppress is null or he.discovery_suppress = 'False')
		
		order by ii.title
	),
	
	-- 8b. Get URLs for any instance that has an 856 link 
	
	urls as 
	(select 
		sm.instance_hrid,
		string_agg (distinct sm.content,' | ') as URL
	
	from srs_marctab as sm 
	where sm.field = '856' and sm.sf = 'u'
	group by sm.instance_hrid
	),
	
	-- 8c. Get instance HRIDs for anything with a serv,remo location where the ISSN matches the ISSN found in the first subquery
	 
	recs2 as 
	(select 
		mannrecs.title as mann_title,
		mannrecs.instance_hrid as mann_instance_hrid,
		string_agg (distinct mannrecs.holdings_hrid,' | ') as mann_holdings_hrid,
		string_agg (distinct mannrecs.mann_location,' | ') as mann_location,
		string_agg (distinct mannrecs.call_number,' | ') as mann_call_number,
		--string_agg (distinct mannrecs.mode_of_issuance,' | ') as mann_mode_of_issuance,
		string_agg (distinct mannrecs.holdings_type_name,' | ') as mann_holdings_type_name,
		string_agg (distinct mannrecs.print_issn,' | ') as mann_print_issns,
		ii.hrid as serv_remo_instance_hrid,
		--string_agg (distinct ii.hrid,' | ') as serv_remo_instance_hrid,
		string_agg (distinct ii.title,' | ') as serv_remo_title,
		string_agg (distinct he.holdings_hrid,' | ') as serv_remo_holdings_hrid,
		string_agg (distinct he.permanent_location_name,' | ') as serv_remo_location_name,
		string_agg (distinct he.call_number,' | ') as serv_remo_call_numbers,
		string_agg (distinct iid.identifier,' | ') as serv_remo_issns
	
	from mannrecs 
		left join folio_reporting.instance_identifiers as iid 
		on mannrecs.print_issn = iid.identifier 
		
		left join inventory_instances as ii 
		on iid.instance_id = ii.id 
		
		left join folio_reporting.holdings_ext as he 
		on ii.id = he.instance_id
	
	where iid.identifier_type_name = 'ISSN' 
		and he.permanent_location_name = 'serv,remo'
	
	group by mannrecs.title, mannrecs.instance_hrid, ii.hrid
	),
	
	-- 8d. Link the records that have URLs (second subquery) to the records where the print and online ISSNs match (third subquery)
	
	mannrecs3 as 
	(select 
		recs2.*,
		urls.URL
	
	from recs2 
		left join urls 
		on recs2.serv_remo_instance_hrid = urls.instance_hrid 
	),
	

-- 9. Get last issue received since 7-1-21 (does not show info for titles whose last issues were received before that date) - next three subqueries

	-- 9a. Get all receipt receords
	last_issue as 
	(select 
		ll.library_name,
		ll.location_name,
		por.title,
		por.po_line_number,	
		max (por.received_date) as date_last_issue_received,
		por.receiving_status
	
	from po_receiving_history as por
		left join folio_reporting.locations_libraries as ll 
		on por.location_id = ll.location_id 
	
	where por.receiving_status = 'Received'
	
	group by por.title, por.po_line_number, ll.library_name, ll.location_name, por.receiving_status
	),
	
	-- 9b. Get last issue (max of receipt date)
	last_issue2 as 
	(select
		last_issue.library_name,
		last_issue.location_name,
		poi.pol_instance_hrid as instance_hrid,
		last_issue.title,
		last_issue.po_line_number,
		max (por.id) as max_id,
		to_char (last_issue.date_last_issue_received::date, 'mm/dd/yyyy') as date_last_issue_received
		
	from last_issue 
		inner join po_receiving_history as por
			on last_issue.title = por.title
			and por.received_date = last_issue.date_last_issue_received
			
		left join folio_reporting.po_instance as poi
		on por.po_line_number = poi.po_line_number
	
	group by 
		last_issue.library_name,
		last_issue.location_name,
		poi.pol_instance_hrid,
		last_issue.title,
		last_issue.po_line_number,
		to_char (last_issue.date_last_issue_received::date, 'mm/dd/yyyy')
	),
	
	--9c. Get the caption associated with the date of last issue (shows the enum/chron of issue)
	
	last_issue3 as 
	(select distinct
		last_issue2.library_name,
		last_issue2.location_name,
		last_issue2.instance_hrid,
		last_issue2.title,
		last_issue2.po_line_number,
		por.caption as last_issue_received,
		por.po_line_receipt_status,
		last_issue2.date_last_issue_received
		
	from last_issue2
		inner join po_receiving_history as por 
		on last_issue2.max_id = por.id
),

-- 10. Join results from the preceding queries; apply criteria for call number range, Library, holdings suppression status

mannrecs2 AS 
(SELECT 
	ll.library_name,
	he.permanent_location_name,
	ii.title,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	imoi.name as mode_of_issuance,
	--ie.barcode,
	--ie.status_name AS item_status_name,
	--to_char (ie.status_date::date,'mm/dd/yyyy') AS item_status_date,
	he.call_number,
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', 
		case when he.copy_number >'1' then concat ('c.',he.copy_number) else '' end)) AS whole_call_number,
	pub_status.pubstatusdesc as publication_status,
	he.receipt_status,
	last_issue3.last_issue_received,
	last_issue3.date_last_issue_received,
	last_issue3.po_line_receipt_status,
	open_access.oa_publish_start_year::varchar as open_access_start_year,
	open_access."Journal URL",
	open_access."URL in DOAJ",
	online_title.online_issn_from_776,
	online_title.online_instance_hrid,
	online_title.online_title,
	string_agg (distinct online_title.url_for_online_title,' | ') as url_for_online_title,
	ebsco.ebsco_open_access_url,
	string_agg (DISTINCT hs.STATEMENT,' | ') AS mann_holdings_statements,
	substring (he.call_number,'^[A-Za-z]{1,3}') AS lc_class,
	replace (trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.') AS lc_class_number,
	trim (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')) AS first_cutter, 
	he.type_name AS holdings_type_name,
	--ie.material_type_name,
	pub_year.year_of_publication,
	CASE when sum (voycircs.circs) IS NULL THEN 0 ELSE sum (voycircs.circs) END AS total_voyager_circs_since_2015,
	CASE WHEN sum (foliocircs.circs) IS NULL THEN 0 ELSE sum (foliocircs.circs) END AS total_folio_circs,
	COALESCE (foliocircsmax.last_year_of_checkout::varchar, voycircsmax.last_year_of_checkout::varchar,'-') AS last_year_of_checkout,
	invitems.effective_shelving_order

FROM inventory_instances AS ii 
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	left join inventory_modes_of_issuance imoi 
		on ii.mode_of_issuance_id = imoi.id
	
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id 
	
	LEFT JOIN folio_reporting.holdings_statements AS hs 
	ON he.holdings_id = hs.holdings_id
	
	LEFT JOIN inventory_items AS invitems 
	ON he.holdings_id = invitems.holdings_record_id 
	
	LEFT JOIN folio_reporting.item_ext AS ie 
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
	
	left join pub_status 
	on ii.hrid = pub_status.instance_hrid
	
	left join open_access 
	on ii.hrid = open_access.instance_hrid
	
	left join ebsco 
	on ii.hrid = ebsco.instance_hrid
	
	left join online_title 
	on ii.hrid = online_title.print_instance_hrid
	
	left join last_issue3 
	on ii.hrid = last_issue3.instance_hrid

WHERE 
	ll.library_name = 'Mann Library'
	AND substring (he.call_number,'^[A-Za-z]{1,3}') < 'F'
	AND (he.discovery_suppress = 'False' or he.discovery_suppress IS NULL)

GROUP BY 
	ll.library_name,
	he.permanent_location_name,
	ii.title,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	--ie.barcode,
	--ie.status_name,
	--to_char (ie.status_date::date,'mm/dd/yyyy'),
	he.call_number,
	trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', 
		case when he.copy_number >'1' then concat ('c.',he.copy_number) else '' end)),
	--trim (concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
		--CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)),
	pub_status.pubstatusdesc,
	he.receipt_status,
	last_issue3.last_issue_received,
	last_issue3.date_last_issue_received,
	last_issue3.po_line_receipt_status,
	open_access.oa_publish_start_year::varchar,
	open_access."Journal URL",
	open_access."URL in DOAJ",
	ebsco.EBSCO_open_access_url,
	online_title.online_issn_from_776,
	online_title.online_instance_hrid,
	online_title.online_title,
	ebsco.ebsco_open_access_url,
	substring (he.call_number,'^[A-Za-z]{1,3}'),
	replace (trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.'),
	trim (LEADING '.' FROM SUBSTRING (he.call_number, '\.[A-Z][0-9]{1,}')),
	pub_year.year_of_publication,
	imoi.name,
	he.type_name,
	ie.material_type_name,
	foliocircsmax.last_year_of_checkout::varchar,
	voycircsmax.last_year_of_checkout::varchar,
	invitems.effective_shelving_order
),

-- 11. Get Annex holdings

annex_hold AS 
(SELECT 
	mannrecs2.instance_hrid,
	ll.library_name,
	string_agg (distinct ll.location_name,' | ') AS annex_locations,
	string_agg (DISTINCT he.holdings_hrid,' | ') AS annex_holdings_hrids,
	string_agg (DISTINCT concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix),' | ') AS annex_call_numbers,
	string_agg (DISTINCT hs.STATEMENT,' | ') AS annex_holdings_statements
	
FROM mannrecs2 
	LEFT JOIN inventory_instances AS ii 
	ON mannrecs2.instance_hrid = ii.hrid 
	
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN folio_reporting.holdings_statements AS hs
	ON he.holdings_id = hs.holdings_id
	
	LEFT JOIN folio_reporting.locations_libraries ll 
	ON he.permanent_location_id = ll.location_id

WHERE ll.library_name = 'Library Annex'
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)

GROUP BY mannrecs2.instance_hrid, ll.library_name
),

-- 12. Join Mann results to Annex results; join to records with other online versions (from mannrecs3 subquery, 8d)

final as 
(SELECT 
	mannrecs2.library_name,
	mannrecs2.permanent_location_name,
	mannrecs2.title,
	mannrecs2.instance_hrid,
	mannrecs2.holdings_hrid,
	mannrecs2.item_hrid,
	mannrecs2.whole_call_number,mannrecs2.lc_class,
	mannrecs2.lc_class_number::numeric,
	mannrecs2.first_cutter,
	--mannrecs2.barcode,
	--mannrecs2.item_status_name,
	--mannrecs2.item_status_date,
	mannrecs2.total_voyager_circs_since_2015,
	mannrecs2.total_folio_circs,
	mannrecs2.last_year_of_checkout,
	mannrecs2.mode_of_issuance,
	mannrecs2.holdings_type_name,
	--mannrecs2.material_type_name,
	mannrecs2.year_of_publication,
	
	mannrecs2.publication_status,
	mannrecs2.receipt_status,
	mannrecs2.last_issue_received,
	mannrecs2.date_last_issue_received,
	mannrecs2.po_line_receipt_status,
	mannrecs2.open_access_start_year,
	mannrecs2."Journal URL",
	mannrecs2."URL in DOAJ",
	mannrecs2.ebsco_open_access_url,
	mannrecs2.online_issn_from_776,
	mannrecs2.online_instance_hrid,
	mannrecs2.online_title,
	mannrecs2.url_for_online_title,
	mannrecs3.serv_remo_instance_hrid,
	mannrecs3.URL as other_online_url,
	mannrecs2.mann_holdings_statements,
	annex_hold.annex_locations,
	annex_hold.annex_holdings_hrids,
	annex_hold.annex_call_numbers,
	annex_hold.annex_holdings_statements,
	mannrecs2.effective_shelving_order
	
FROM mannrecs2 
	LEFT JOIN annex_hold
	ON mannrecs2.instance_hrid = annex_hold.instance_hrid
	
	left join mannrecs3 
	on mannrecs2.instance_hrid = mannrecs3.mann_instance_hrid

where mannrecs2.permanent_location_name = 'Mann'
)

select 
	final.library_name,
	final.permanent_location_name,
	final.title,
	final.instance_hrid,
	final.holdings_hrid,
	count (distinct final.item_hrid) as count_of_items,
	final.whole_call_number,
	final.lc_class,
	final.lc_class_number::numeric,
	final.first_cutter,
	--mannrecs2.barcode,
	--mannrecs2.item_status_name,
	--mannrecs2.item_status_date,
	sum (final.total_voyager_circs_since_2015 + final.total_folio_circs) as total_circs_since_2015,
	string_agg (distinct final.last_year_of_checkout,' | ') as years_of_checkout,
	final.mode_of_issuance,
	final.holdings_type_name,
	--string_agg (distinct final.material_type_name,' | ') as material_type_names,
	final.year_of_publication,
	
	final.publication_status,
	final.receipt_status,
	final.last_issue_received,
	string_agg (distinct final.date_last_issue_received,' | ') as dates_last_issues_received,
	final.po_line_receipt_status,
	final.open_access_start_year,
	final."Journal URL",
	final."URL in DOAJ",
	final.ebsco_open_access_url,
	final.online_issn_from_776,
	final.online_instance_hrid,
	final.online_title,
	final.url_for_online_title,
	final.serv_remo_instance_hrid,
	final.other_online_url,
	final.mann_holdings_statements,
	final.annex_locations,
	final.annex_holdings_hrids,
	final.annex_call_numbers,
	final.annex_holdings_statements
	--final.effective_shelving_order
	
from final

group by 
	final.library_name,
	final.permanent_location_name,
	final.title,
	final.instance_hrid,
	final.holdings_hrid,
	final.whole_call_number,
	final.lc_class,
	final.lc_class_number::numeric,
	final.first_cutter,
	--mannrecs2.barcode,
	--mannrecs2.item_status_name,
	--mannrecs2.item_status_date,
	--final.total_voyager_circs_since_2015 + final.total_folio_circs,
	final.mode_of_issuance,
	final.holdings_type_name,
	final.year_of_publication,	
	final.publication_status,
	final.receipt_status,
	final.last_issue_received,
	--final.date_last_issue_received,
	final.po_line_receipt_status,
	final.open_access_start_year,
	final."Journal URL",
	final."URL in DOAJ",
	final.ebsco_open_access_url,
	final.online_issn_from_776,
	final.online_instance_hrid,
	final.online_title,
	final.url_for_online_title,
	final.serv_remo_instance_hrid,
	final.other_online_url,
	final.mann_holdings_statements,
	final.annex_locations,
	final.annex_holdings_hrids,
	final.annex_call_numbers,
	final.annex_holdings_statements
	--final.effective_shelving_order
ORDER BY final.permanent_location_name, final.lc_class, final.lc_class_number::numeric, final.first_cutter, final.whole_call_number 
;

