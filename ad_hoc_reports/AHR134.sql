--5-10-23: this query finds Music MT items for possible transfer to the Annex 

WITH voycircs AS 
(SELECT
	cta.item_id::varchar AS item_hrid,
	max (cta.charge_date)::date AS most_recent_voyager_circ,
	count (DISTINCT cta.circ_transaction_id) AS circs
	
	FROM vger.circ_trans_archive AS cta 
	GROUP BY cta.item_id::varchar
),

voycircs2 AS 
(SELECT 
	voycircs.item_hrid,
	voycircs.most_recent_voyager_circ,
	sum (circs) AS total_voyager_circs

	FROM voycircs 
	GROUP BY item_hrid, most_recent_voyager_circ
),

foliocircs AS
(SELECT 
	 li.hrid AS item_hrid,
	 MAX (li.loan_date::date) AS most_recent_folio_circ,
	 count (DISTINCT li.loan_id) AS circs
	 
	 FROM folio_reporting.loans_items AS li
	 GROUP BY li.hrid
),

foliocircs2 AS 
(SELECT
	foliocircs.item_hrid,
	foliocircs.most_recent_folio_circ,
	sum (foliocircs.circs) AS total_folio_circs
	FROM foliocircs 
	GROUP BY foliocircs.item_hrid, foliocircs.most_recent_folio_circ
),

pub_year AS 
(SELECT
	sm.instance_hrid,
	substring (sm.CONTENT,8,4) AS year_of_publication
	FROM srs_marctab AS sm 
	WHERE sm.field = '008'
),

contrib AS 
(SELECT 
	ic.instance_id,
	string_agg (DISTINCT ic.contributor_name,' | ') AS contributors
	
	FROM folio_reporting.instance_contributors AS ic 
	GROUP BY ic.instance_id
),

main AS 
(SELECT 
	ll.library_name,
	he.permanent_location_name,
	ii.title,
	contrib.contributors,
	ii.id AS instance_id,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.barcode,
	he.call_number,
	concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END) AS whole_call_number,
	ie.status_name AS item_status_name,
	substring (he.call_number,'^[A-Za-z]{1,3}') AS lc_class,
	trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')) AS lc_class_number,
	he.type_name AS holdings_type_name,
	ie.material_type_name,
	pub_year.year_of_publication,
	CASE WHEN voycircs2.total_voyager_circs IS NULL THEN 0 ELSE voycircs2.total_voyager_circs END AS total_voyager_circs,
	CASE WHEN foliocircs2.total_folio_circs IS NULL THEN 0 ELSE foliocircs2.total_folio_circs END AS total_folio_circs,
	COALESCE (foliocircs2.most_recent_folio_circ::varchar, voycircs2.most_recent_voyager_circ::varchar,'-') AS most_recent_checkout,
	invitems.effective_shelving_order

FROM inventory_instances AS ii 
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN contrib 
	ON ii.id = contrib.instance_id
	
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id 
	
	LEFT JOIN inventory_items AS invitems 
	ON he.holdings_id = invitems.holdings_record_id 
	
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON invitems.hrid = ie.item_hrid 
	
	LEFT JOIN voycircs2 
	ON ie.item_hrid = voycircs2.item_hrid

	LEFT JOIN foliocircs2 
	ON ie.item_hrid = foliocircs2.item_hrid
	
	LEFT JOIN pub_year
	ON ii.hrid = pub_year.instance_hrid

WHERE ll.library_name = 'Music Library'
	AND substring (he.call_number,'^[A-Za-z]{1,3}') = 'MT'
	AND (he.discovery_suppress = 'False' or he.discovery_suppress is NULL)
	AND he.type_name !='Serial'

GROUP BY 
	ll.library_name,
	he.permanent_location_name,
	ii.id,
	ii.hrid,
	ii.title,
	contrib.contributors,
	he.holdings_hrid,
	ie.item_hrid,
	ie.barcode,
	he.call_number,
	ie.status_name,
	concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END),
	substring (he.call_number,'^[A-Za-z]{1,3}'),
	trim (TRAILING '.' FROM substring (he.call_number,'\d{1,}\.{0,}\d{0,}')),
	pub_year.year_of_publication,
	he.type_name,
	ie.material_type_name,
	voycircs2.total_voyager_circs,
	foliocircs2.total_folio_circs,
	foliocircs2.most_recent_folio_circ::varchar, 
	voycircs2.most_recent_voyager_circ::varchar,
	invitems.effective_shelving_order
),

annex_hold AS 
(SELECT 
	main.instance_hrid,
	ll.library_name,
	he.permanent_location_name,
	he.holdings_hrid 
	
	FROM main 
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON main.instance_id = he.instance_id
	
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id
	
	WHERE ll.library_name = 'Library Annex'
)

SELECT 
	to_char (current_date::date, 'mm/dd/yyyy') AS todays_date,
	main.library_name,
	main.permanent_location_name,
	main.title,
	main.contributors,
	main.instance_hrid,
	main.holdings_hrid,
	main.item_hrid,
	main.barcode,
	main.call_number,
	main.whole_call_number,
	main.item_status_name,
	main.lc_class,
	main.lc_class_number,
	main.holdings_type_name,
	main.material_type_name,
	main.year_of_publication,
	main.total_voyager_circs,
	main.total_folio_circs,
	main.total_voyager_circs + main.total_folio_circs AS total_circs,
	main.most_recent_checkout,
	main.effective_shelving_order,
	annex_hold.library_name,
	string_agg (DISTINCT annex_hold.permanent_location_name,' | ') AS annex_locations,
	string_agg (DISTINCT annex_hold.holdings_hrid,' | ') AS annex_holdings_hrids
	
	FROM main  
	LEFT JOIN annex_hold
	ON main.instance_hrid = annex_hold.instance_hrid
	
	WHERE annex_hold.library_name IS null
	
	GROUP BY 
	main.library_name,
	main.permanent_location_name,
	main.title,
	main.contributors,
	main.instance_hrid,
	main.holdings_hrid,
	main.item_hrid,
	main.barcode,
	main.call_number,
	main.whole_call_number,
	main.item_status_name,
	main.lc_class,
	main.lc_class_number,
	main.holdings_type_name,
	main.material_type_name,
	main.year_of_publication,
	main.total_voyager_circs,
	main.total_folio_circs,
	main.most_recent_checkout,
	main.effective_shelving_order,
	annex_hold.library_name
	
	ORDER BY main.effective_shelving_order COLLATE "C"
	;

