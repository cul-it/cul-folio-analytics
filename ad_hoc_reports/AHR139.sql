--AHR139
--Asia collection with UMI Dissertation Services in descriptive fields

-- This query gets bibliographic detail and circ and browse counts for Kroch Asia Collections and Asia Annex (Jeff Peterson request. It also finds a subset of asia materials that are dissertation copies and identifies Ann Arbor, UMI dissertation services notes. 

--Query writer: Joanne Leary (JL41)
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

-- 3. get Folio browses

foliobrowses AS 
	(SELECT 
		ie.item_hrid,
		CASE WHEN count (DISTINCT cci.id) is null then 0 ELSE count(DISTINCT cci.id) END AS folio_browses 
	
	FROM folio_reporting.item_ext AS ie 
		LEFT JOIN circulation_check_ins AS cci 
		ON ie.item_id = cci.item_id 
	WHERE cci.item_status_prior_to_check_in = 'Available'
	
	GROUP BY ie.item_hrid 
),

-- 4. Get "UMI Dissertation" text string from marc fields 533, 260 and 264

field_533 AS 
	(SELECT 
		sm.instance_hrid,
		STRING_AGG (DISTINCT sm.content,' | ') AS dissertation_notes_in_marc
	
	FROM srs_marctab AS sm 
	WHERE 
		((sm.field = '533' AND sm.sf in ('b','c')) OR (sm.field = '260' AND sm.sf = 'b') OR (sm.field ='264' AND sm.sf = 'b'))
		AND sm.content ilike '%UMI Dissertation%'
	GROUP BY sm.instance_hrid
),

-- 5. Get Asia collections and Asia Annex records that have a UMI Dissertation Services note in instance notes OR holdings notes OR publisher

recs AS 
(SELECT 
	ll.library_name,
	he.permanent_location_name,
	invloc.code AS location_code,
	ii.title,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	he.call_number,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) AS whole_call_number,
	SUBSTRING (he.call_number,'^[A-Za-z]{1,3}') AS lc_class,
	REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::NUMERIC AS lc_class_number,
	STRING_AGG (DISTINCT hn.note, ' | ') AS holdings_notes,
	STRING_AGG (DISTINCT instnotes.note,' | ') AS instance_notes,
	field_533.dissertation_notes_in_marc,
	imoi.name AS mode_of_issuance,
	il.language,
	STRING_AGG (DISTINCT ip.publisher,' | ') AS publisher,
	SUBSTRING (ip.date_of_publication,'\d{4}') AS pub_date,
	ii.discovery_suppress AS instance_suppress,
	he.discovery_suppress AS holdings_suppress,
	DATE_PART ('year',coalesce (bm.create_date::DATE, ii.metadata__created_date::DATE)) AS year_title_added_to_collection,
	voycircs.voyager_circs,
	voycircs.voyager_browses,
	foliocircs.folio_circs,
	foliobrowses.folio_browses
	
FROM inventory_instances AS ii
	LEFT JOIN folio_reporting.holdings_ext AS he
	ON ii.id = he.instance_id 
	
	LEFT JOIN vger.bib_master AS bm 
	ON ii.hrid = bm.bib_id::varchar
	
	LEFT JOIN inventory_modes_of_issuance imoi 
	ON ii.mode_of_issuance_id = imoi.id
	
	LEFT JOIN folio_reporting.instance_publicatiON AS ip 
	ON ii.id = ip.instance_id
	
	LEFT JOIN folio_reporting.instance_languages il 
	ON ii.id = il.instance_id
	
	LEFT JOIN field_533 
	ON ii.hrid = field_533.instance_hrid
	
	LEFT JOIN folio_reporting.instance_notes AS instnotes 
	ON ii.id = instnotes.instance_id
	
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id
	
	LEFT JOIN inventory_locations AS invloc 
	ON he.permanent_location_id = invloc.id
	
	LEFT JOIN folio_reporting.holdings_notes AS hn 
	ON he.holdings_id = hn.holdings_id
	
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON he.holdings_id = ie.holdings_record_id
	
	LEFT JOIN voycircs 
	ON ie.item_hrid = voycircs.item_hrid

	LEFT JOIN foliocircs 
	ON ie.item_hrid = foliocircs.item_hrid
	
	LEFT JOIN foliobrowses 
	ON ie.item_hrid = foliobrowses.item_hrid
		
WHERE 
	invloc.code SIMILAR TO '%(ech|was|sasa|asia)%'
	AND (ip.publisher ilike '%UMI%Dissertation%' OR hn.note ilike '%UMI%Dissertation%' OR instnotes.note ILIKE '%UMI%Dissertation%')
	AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress is null)
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress is null)
		
GROUP BY 
	ll.library_name,
	he.permanent_location_name,
	invloc.code,
	ii.title,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ii.discovery_suppress,
	he.discovery_suppress,
	imoi.name ,
	he.call_number,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)),
	SUBSTRING (he.call_number,'^[A-Za-z]{1,3}'),
	REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.')::NUMERIC,
	il.language,
	SUBSTRING (ip.date_of_publication,'\d{4}'),
	DATE_PART ('year',coalesce (bm.create_date::DATE, ii.metadata__created_date::DATE)),
	voycircs.voyager_circs,
	voycircs.voyager_browses,
	foliocircs.folio_circs,
	foliobrowses.folio_browses,
	field_533.dissertation_notes_in_marc
)

-- 6. Count item records; sum the circs and browses; limit to publication date range 1970-2010
 
SELECT 	
	recs.library_name,
	recs.permanent_location_name,
	recs.location_code,
	recs.title,
	recs.instance_hrid,
	recs.holdings_hrid,
	COUNT (DISTINCT recs.item_hrid) AS count_of_items,
	recs.call_number,
	recs.whole_call_number,
	recs.lc_class,
	recs.lc_class_number,
	recs.holdings_notes,
	recs.instance_notes,
	recs.dissertation_notes_in_marc,
	recs.mode_of_issuance,
	recs.language,
	recs.publisher,
	recs.pub_date,
	recs.instance_suppress,
	recs.holdings_suppress,
	recs.year_title_added_to_collection,
	CASE WHEN SUM (recs.voyager_circs) is null then 0 ELSE SUM (recs.voyager_circs) END AS voyager_circs,
	CASE WHEN SUM (recs.voyager_browses) is null then 0 ELSE SUM (recs.voyager_browses) END AS voyager_browses,
	CASE WHEN SUM (recs.folio_circs) is null then 0 ELSE SUM (recs.folio_circs) END AS folio_circs,
	CASE WHEN SUM (recs.folio_browses) is null then 0 ELSE SUM (recs.folio_browses) END AS folio_browses
	
FROM recs

WHERE 
recs.pub_date >='1970' AND recs.pub_date <'2011'

GROUP BY 
	recs.library_name,
	recs.permanent_location_name,
	recs.location_code,
	recs.title,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.call_number,
	recs.whole_call_number,
	recs.lc_class,
	recs.lc_class_number,
	recs.holdings_notes,
	recs.instance_notes,
	recs.dissertation_notes_in_marc,
	recs.mode_of_issuance,
	recs.language,
	recs.publisher,
	recs.pub_date,
	recs.instance_suppress,
	recs.holdings_suppress,
	recs.year_title_added_to_collection
	
ORDER BY recs.library_name, recs.permanent_location_name, recs.lc_class, recs.lc_class_number, STRING_AGG (DISTINCT recs.call_number,' | ')
;
