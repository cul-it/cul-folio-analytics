--AHR 141
--FAL Print Monographs
--This query finds all print monographs in FAL stacks by LC Class and LC Class Number. It groups the books by year added to collection and years circulated.
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandan Shah (vp25)
--Date posted: 04/16/2024

-- 1. Get Voyager circs

WITH voycircs AS 
(SELECT
	cta.item_id::VARCHAR AS item_hrid,
	DATE_PART ('year',cta.charge_date::DATE) AS year_of_circulation,
	COUNT (DISTINCT cta.circ_transaction_id) AS circs
	
	FROM vger.circ_trans_archive AS cta 

	GROUP BY cta.item_id::VARCHAR, DATE_PART ('year',cta.charge_date::DATE)
),

-- 2. Get Folio circs

foliocircs AS
(SELECT 
	 li.hrid AS item_hrid,
	 DATE_PART ('year',li.loan_date::DATE) AS year_of_circulation,
	 COUNT (DISTINCT li.loan_id) AS circs
	 
	FROM folio_reporting.loans_items AS li
	GROUP BY li.hrid, DATE_PART ('year',li.loan_date::date)
),

-- 3. Union the Voyager and Folio circs

allcircs AS 
	(SELECT
	voycircs.item_hrid,
	voycircs.year_of_circulation,
	voycircs.circs 
	FROM voycircs
	
	UNION 
	
	SELECT 
	foliocircs.item_hrid,
	foliocircs.year_of_circulation,
	foliocircs.circs
	FROM foliocircs
),

-- 4. Sum the circ counts by item HRID and year of circulation

totalcircs AS 
	(SELECT
	allcircs.item_hrid,
	allcircs.year_of_circulation,
	SUM (allcircs.circs) AS total_circs
	
	FROM allcircs 
	GROUP BY allcircs.item_hrid, allcircs.year_of_circulation
),

-- 5. Find the FAL print monographs with year added to the collection and various pieces of bibliographic information
-- in case it's needed later; join to circulation data

recs AS 
	(SELECT 
		ll.library_name,
		he.permanent_location_name,
		invloc.code,
		ii.hrid AS instance_hrid,
		he.holdings_hrid,
		ie.item_hrid,
		DATE_PART ('year', COALESCE (item.create_date::date,ie.created_date::date)) AS year_item_added_to_collection,
		ii.title,
		STRING_AGG (DISTINCT ip.publisher,' | ') AS publisher,
		TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) AS whole_call_number,
		SUBSTRING (he.call_number,'[A-Za-z]{1,3}') AS lc_class,
		REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.') AS lc_class_number,
		STRING_AGG (DISTINCT hn.note, ' | ') AS holdings_notes,
		SUBSTRING (ip.date_of_publication,'\d{4}') AS pub_date,
		STRING_AGG (DISTINCT il.language,' | ') AS language,
		CASE WHEN totalcircs.year_of_circulation < 2019 THEN '_Pre-2019' ELSE totalcircs.year_of_circulation::VARCHAR END AS circ_count_group,
		totalcircs.year_of_circulation,
		totalcircs.total_circs,
		invitems.effective_shelving_order COLLATE "C"
	
	FROM inventory_instances AS ii 
		LEFT JOIN folio_reporting.instance_publication AS ip 
		ON ii.id = ip.instance_id
		
		LEFT JOIN folio_reporting.holdings_ext AS he 
		ON ii.id = he.instance_id
		
		LEFT JOIN inventory_locations AS invloc 
		ON he.permanent_location_id = invloc.id
		
		LEFT JOIN folio_reporting.item_ext AS ie 
		ON he.holdings_id = ie.holdings_record_id
		
		LEFT JOIN inventory_items AS invitems 
		ON ie.item_id = invitems.id
		
		full join vger.item 
		ON invitems.hrid::VARCHAR = item.item_id::VARCHAR
	
		LEFT JOIN folio_reporting.locations_libraries AS ll 
		ON he.permanent_location_id = ll.location_id
		
		LEFT JOIN totalcircs 
		ON ie.item_hrid = totalcircs.item_hrid
		
		LEFT JOIN folio_reporting.instance_languages il 
		ON ii.id = il.instance_id
	
		LEFT JOIN folio_reporting.holdings_notes AS hn 
		ON he.holdings_id = hn.holdings_id

WHERE 
	invloc.code ='fine'
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL) 
	AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL)
	AND he.type_name !='Serial'

GROUP BY 
	ll.library_name,
	he.permanent_location_name,
	invloc.code,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	DATE_PART ('year',COALESCE (item.create_date::date,ie.created_date::date)),
	ii.title,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)),
	SUBSTRING (he.call_number,'[A-Za-z]{1,3}'),
	REPLACE (TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),'..','.'),
	SUBSTRING (ip.date_of_publication,'\d{4}'),
	CASE WHEN totalcircs.year_of_circulation < 2019 THEN '_Pre-2019' ELSE totalcircs.year_of_circulation::VARCHAR END,
	totalcircs.year_of_circulation,
	totalcircs.total_circs,
	invitems.effective_shelving_order COLLATE "C"

ORDER BY invitems.effective_shelving_order COLLATE "C"
)

-- 6. Group records by instance and holdings, count items and sum charges and browses 
-- (comment out bibliographic data not needed in preliminary result, but keep it in the query)

SELECT 
	recs.library_name,
	recs.permanent_location_name,
	--recs.code,
	--recs.instance_hrid,
	--recs.holdings_hrid,
	--recs.title,
	--recs.publisher,
	--recs.whole_call_number,
	recs.lc_class,
	recs.lc_class_number::NUMERIC,
	CONCAT (recs.lc_class,' ',recs.lc_class_number) AS lc_class_and_number,
	recs.year_item_added_to_collection,
	CASE WHEN recs.year_item_added_to_collection < 2019 THEN '_Pre-2019' ELSE '2019-2024' END AS year_added_group,
	COUNT (distinct recs.item_hrid) AS count_of_items,
	--recs.holdings_notes,
	--recs.pub_date,
	--recs.language,
	recs.year_of_circulation,
	recs.circ_count_group,
	CASE WHEN recs.total_circs IS NULL THEN 0 ELSE recs.total_circs END AS total_circs

FROM recs 

GROUP BY 
	recs.library_name,
	recs.permanent_location_name,
	--recs.code,
	--recs.instance_hrid,
	--recs.holdings_hrid,
	--recs.title,
	--recs.publisher,
	--recs.whole_call_number,
	recs.lc_class,
	recs.lc_class_number::NUMERIC,
	CONCAT (recs.lc_class,' ',recs.lc_class_number),
	recs.year_item_added_to_collection,
	CASE WHEN recs.year_item_added_to_collection < 2019 THEN '_Pre-2019' ELSE '2019-2014' END,
	recs.year_of_circulation,
	recs.circ_count_group,
	recs.total_circs
	--recs.holdings_notes,
	--recs.pub_date,
	--recs.language,
	--recs.year_title_added_to_collection
	--CASE WHEN recs.year_title_added_to_collection < 2019 THEN 'Pre-2019' ELSE recs.year_title_added_to_collection::VARCHAR END
	
ORDER BY recs.library_name, recs.permanent_location_name, recs.lc_class, recs.lc_class_number::numeric
;
