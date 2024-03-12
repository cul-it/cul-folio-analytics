--AHR138
--Adelson_and_Adelson_Annex_checkouts_by_patron_group_and_fiscal_year

--This query finds Adelson and Adelson Annex checkouts by patron group and fiscal year (no aggregation)
--Query write: Joanne Leary (jl41), 3/5/2024

-- 1. Get Voyager circs 

WITH voycircs AS 
(SELECT
	'Voyager' AS loan_group,
	cta.item_id::VARCHAR AS item_hrid,
	CASE WHEN DATE_PART ('month', cta.charge_date::DATE) > 6 THEN CONCAT ('FY ', DATE_PART ('year',cta.charge_date::DATE)+1)
		ELSE CONCAT ('FY ', DATE_PART ('year', cta.charge_date::DATE)) END AS fiscal_year_of_checkout,
	pg.patron_group_name,
	COUNT (DISTINCT cta.circ_transaction_id)::int AS circs
	
FROM vger.circ_trans_archive AS cta 
	LEFT JOIN vger.patron_group AS pg 
	ON cta.patron_group_id = pg.patron_group_id

GROUP BY 
	loan_group,
	cta.item_id::VARCHAR,
	CASE WHEN DATE_PART ('month', cta.charge_date::DATE) > 6 THEN CONCAT ('FY ', DATE_PART ('year',cta.charge_date::DATE)+1)
		ELSE CONCAT ('FY ', DATE_PART ('year', cta.charge_date::DATE)) END,
	pg.patron_group_name
),

-- 2. Get Folio circs 

foliocircs AS
	(SELECT 
		'Folio' AS loan_group,
		li.hrid AS item_hrid,
		CASE WHEN DATE_PART ('month', li.loan_date::DATE) > 6 THEN CONCAT ('FY ', DATE_PART ('year',li.loan_date::DATE)+1)
			ELSE CONCAT ('FY ', DATE_PART ('year', li.loan_date::DATE)) END AS fiscal_year_of_checkout,
		li.patron_group_name,
		COUNT (DISTINCT li.loan_id)::int AS circs
		 
	FROM folio_reporting.loans_items AS li
	GROUP BY 
		loan_group,
		li.hrid,
		CASE WHEN DATE_PART ('month', li.loan_date::DATE) > 6 THEN CONCAT ('FY ', DATE_PART ('year',li.loan_date::DATE)+1)
			ELSE CONCAT ('FY ', DATE_PART ('year', li.loan_date::DATE)) END,
		li.patron_group_name
),

-- 3. Combine Voyager and Folio circs

combo AS 
	(SELECT 
		voycircs.loan_group,
		voycircs.item_hrid,
		voycircs.fiscal_year_of_checkout,
		voycircs.patron_group_name,
		voycircs.circs
	
	FROM voycircs 
	
	UNION
	
	SELECT 
		foliocircs.loan_group,
		foliocircs.item_hrid,
		foliocircs.fiscal_year_of_checkout,
		foliocircs.patron_group_name,
		foliocircs.circs
		
	FROM foliocircs 
	
	ORDER BY item_hrid, fiscal_year_of_checkout, patron_group_name, loan_group
),

-- 4. Group results of union by loan group, item_hrid, fiscal year of checkout and patron group; sum the circs
 
recs AS 
(SELECT 
	combo.loan_group,
	combo.item_hrid,
	combo.fiscal_year_of_checkout,
	combo.patron_group_name,
	sum (combo.circs) AS total_circs

FROM combo
GROUP BY combo.loan_group,
	combo.item_hrid,
	combo.fiscal_year_of_checkout,
	combo.patron_group_name
)

-- 5. Find all Adelson and Adelson Annex items, and join them to the circ data by item hrid; 
-- sort patron groups into three categories as an additional field: CUL patron, SPEC and BD/ILL

SELECT DISTINCT	
	invloc.name AS item_location_name,
	invloc.code AS item_location_code,
	ii.title,
	STRING_AGG (DISTINCT ic.contributor_name,' | ') AS authors,
	
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', ie.enumeration,' ',ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END)) AS whole_call_number,
		
	CASE WHEN 
		(TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', ie.enumeration,' ',ie.chronology,
			CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END))) LIKE '%Thesis%' 
		THEN '-'
		ELSE SUBSTRING (he.call_number,'[A-Z]{1,3}') END AS lc_class,
		
	TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')) AS lc_class_number,
	STRING_AGG (DISTINCT (SUBSTRING (ip.date_of_publication,'\d{4}'))::varchar,' | ') AS date_of_publication,
	STRING_AGG (DISTINCT il.language,' | ') AS language,
	ie.material_type_name,
	STRING_AGG (DISTINCT hn.note,' | ') AS holdings_notes,
	STRING_AGG (DISTINCT hs.statement,' | ') AS holdings_statements,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	recs.loan_group,
	recs.fiscal_year_of_checkout,
	
	CASE 
		WHEN recs.fiscal_year_of_checkout IS NULL THEN NULL
		WHEN recs.patron_group_name IN ('Borrow Direct','Interlibrary Loan') THEN 'BD/ILL' 
		WHEN recs.patron_group_name LIKE 'SPEC%' THEN 'SPEC'
		ELSE 'CUL patron' END AS patron_category,
		
	recs.patron_group_name,
	recs.total_circs,
	invitems.effective_shelving_order COLLATE "C"
	
FROM inventory_instances AS ii 
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id
	
	LEFT JOIN folio_reporting.holdings_notes AS hn 
	ON he.holdings_id = hn.holdings_id 
	
	LEFT JOIN folio_reporting.holdings_statements AS hs 
	ON he.holdings_id = hs.holdings_id
	
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON he.holdings_id = ie.holdings_record_id 
	
	LEFT JOIN inventory_items AS invitems 
	ON ie.item_id = invitems.id
	
	LEFT JOIN inventory_locations AS invloc 
	ON ie.effective_location_id = invloc.id 
	
	LEFT JOIN recs 
	ON ie.item_hrid = recs.item_hrid 
	
	LEFT JOIN folio_reporting.instance_publicatiON AS ip 
	ON ii.id = ip.instance_id 
	
	LEFT JOIN folio_reporting.instance_languages AS il 
	ON ii.id = il.instance_id 
	
	LEFT JOIN folio_reporting.instance_contributors AS ic 
	ON ii.id = ic.instance_id

WHERE invloc.code LIKE '%orni%'
	AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL)
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)

GROUP BY 
	invloc.name,
	invloc.code,
	ii.title,
	
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', ie.enumeration,' ',ie.chronology,
		CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END)),
		
	CASE WHEN 
		(TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ', ie.enumeration,' ',ie.chronology,
			CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END))) LIKE '%Thesis%' 
		THEN '-'
		ELSE SUBSTRING (he.call_number,'[A-Z]{1,3}') END,
		
	TRIM (TRAILING '.' FROM SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}')),
	
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ie.material_type_name,
	recs.loan_group,
	recs.fiscal_year_of_checkout,
	recs.patron_group_name,
	CASE 
		WHEN recs.fiscal_year_of_checkout IS NULL THEN NULL
		WHEN recs.patron_group_name IN ('Borrow Direct','Interlibrary Loan') THEN 'BD/ILL' 
		WHEN recs.patron_group_name LIKE 'SPEC%' THEN 'SPEC'
		ELSE 'CUL patron' END,
	recs.total_circs,
	invitems.effective_shelving_order COLLATE "C"

ORDER BY invloc.code, invitems.effective_shelving_order COLLATE "C"
;
