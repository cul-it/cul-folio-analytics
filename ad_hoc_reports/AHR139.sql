--AHR139
--Asia Collections with selected publishers and circ usage

--This query finds Asia collections items for three publishers: Lap Lambert, VDM and Scholar's Press and shows the Voyager and Folio circs and browses.
--Query writer: Joanne Leary (j41)

-- 1. Get Voyager circs and browses

WITH voycircs AS 
	(SELECT
		item.item_id::VARCHAR AS item_hrid,
		item.historical_charges AS voyager_circs,
		item.historical_browses AS voyager_browses

	FROM vger.item
),

-- 2. Get Folio circs

foliocircs AS
	(SELECT 
		li.hrid AS item_hrid,
		COUNT (DISTINCT li.loan_id) AS folio_circs
		 
		FROM folio_reporting.loans_items AS li
		GROUP BY li.hrid
),

-- 3. Get Folio browses

foliobrowses AS 
	(SELECT 
		ie.item_hrid,
		CASE WHEN COUNT (DISTINCT cci.id) IS NULL THEN 0 ELSE COUNT(DISTINCT cci.id) END AS folio_browses 
	
	FROM folio_reporting.item_ext AS ie 
		LEFT JOIN circulation_check_ins AS cci 
		ON ie.item_id = cci.item_id 
	WHERE cci.item_status_prior_to_check_in = 'Available'
	
	GROUP BY ie.item_hrid 
),

-- 4. Get Asia collections by location code and find the selected publishers

recs AS 
	(SELECT 
		ll.library_name,
		he.permanent_location_name,
		invloc.code,
		ii.hrid AS instance_hrid,
		he.holdings_hrid,
		ie.item_hrid,
		ii.title,
		ip.publisher,
		TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) AS whole_call_number,
		SUBSTRING (he.call_number,'^[A-Za-z]{1,3}') AS lc_class,
		REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.') AS lc_class_number,
		STRING_AGG (DISTINCT hn.note, ' | ') AS holdings_notes,
		SUBSTRING (ip.date_of_publication,'\d{4}') AS pub_date,
		STRING_AGG (DISTINCT il.language,' | ') AS language,
		DATE_PART ('year',COALESCE (bm.create_date::DATE, ii.metadata__created_date::DATE)) AS year_title_added_to_collection,
		voycircs.voyager_circs,
		voycircs.voyager_browses,
		foliocircs.folio_circs,
		foliobrowses.folio_browses
	
	FROM inventory_instances AS ii 
		LEFT JOIN folio_reporting.instance_publicatiON AS ip 
		ON ii.id = ip.instance_id
		
		LEFT JOIN folio_reporting.holdings_ext AS he 
		ON ii.id = he.instance_id
		
		LEFT JOIN inventory_locations AS invloc 
		ON he.permanent_location_id = invloc.id
		
		LEFT JOIN folio_reporting.item_ext AS ie 
		ON he.holdings_id = ie.holdings_record_id
	
		LEFT JOIN folio_reporting.locations_libraries AS ll 
		ON he.permanent_location_id = ll.location_id
	
		LEFT JOIN vger.bib_master AS bm 
		ON ii.hrid = bm.bib_id::varchar
		
		LEFT JOIN folio_reporting.instance_languages il 
		ON ii.id = il.instance_id
	
		LEFT JOIN folio_reporting.holdings_notes AS hn 
		ON he.holdings_id = hn.holdings_id
		
		LEFT JOIN voycircs 
		ON ie.item_hrid = voycircs.item_hrid
	
		LEFT JOIN foliocircs 
		ON ie.item_hrid = foliocircs.item_hrid
		
		LEFT JOIN foliobrowses 
		ON ie.item_hrid = foliobrowses.item_hrid

WHERE 
	(ip.publisher ILIKE '%Lap Lambert%' OR ip.publisher ILIKE '%VDM%' OR ip.publisher ILIKE '%Scholar%Press%')
	AND invloc.code SIMILAR TO '%(was|ech|asia|south)%'
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL) 
	AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL)

group by 
	ll.library_name,
	he.permanent_location_name,
	invloc.code,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ii.title,
	ip.publisher,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)),
	SUBSTRING (he.call_number,'^[A-Za-z]{1,3}'),
	REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.'),
	SUBSTRING (ip.date_of_publication,'\d{4}'),
	DATE_PART ('year',COALESCE (bm.create_date::DATE, ii.metadata__created_date::DATE)),
	voycircs.voyager_circs,
	voycircs.voyager_browses,
	foliocircs.folio_circs,
	foliobrowses.folio_browses
)

-- 5. Group records by instance and holdings, count items and sum charges and browses

SELECT 
	recs.library_name,
	recs.permanent_location_name,
	recs.code,
	recs.instance_hrid,
	recs.holdings_hrid,
	COUNT (recs.item_hrid) AS count_of_items,
	recs.title,
	recs.publisher,
	recs.whole_call_number,
	recs.lc_class,
	recs.lc_class_number,
	recs.holdings_notes,
	recs.pub_date,
	recs.language,
	recs.year_title_added_to_collection,
	CASE WHEN SUM (recs.voyager_circs) IS NULL THEN 0 ELSE SUM (recs.voyager_circs) END AS voyager_circs,
	CASE WHEN SUM (recs.voyager_browses) IS NULL THEN 0 ELSE SUM (recs.voyager_browses) END AS voyager_browses,
	CASE WHEN SUM (recs.folio_circs) IS NULL THEN 0 ELSE SUM (recs.folio_circs) END AS folio_circs,
	CASE WHEN SUM (recs.folio_browses) IS NULL THEN 0 ELSE SUM (recs.folio_browses) END AS folio_browses

FROM recs 

GROUP BY 
	recs.library_name,
	recs.permanent_location_name,
	recs.code,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.title,
	recs.publisher,
	recs.whole_call_number,
	recs.lc_class,
	recs.lc_class_number,
	recs.holdings_notes,
	recs.pub_date,
	recs.language,
	recs.year_title_added_to_collection
	
ORDER BY recs.library_name, recs.permanent_location_name, recs.lc_class, recs.lc_class_number, recs.whole_call_number
;
