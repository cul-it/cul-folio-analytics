--MAHR102
--physical_items_acquired_since_2019.sql
--description: This query provides physical items acquired since 2019 with OCLC numbers and circulation counts.


-- 2-25-25: Physical items acquired 2019-2024 with OCLC numbers, circs counts and language codes

-- This is a continuation of a project, begun in 2019, that analyzes usage of titles that match OCLC data, for instances acquired 2019-2024 inclusive.
-- This query finds all instances connected to CIRCULATING items at CUL (as indicated by the loan type), shows the language code and shows OCLC identifiers. 
-- Looks at Cornell-affiliated vs BD/ILL circ usage since 2019-2024.
-- 2-27-25: corrected lc_marc extract to get just the first LC class when there are multiple 050 fields
-- 3-12-25: Used COALESCE function to replace NULL values with zeroes in circ subqueries. Takes 15 mins to run as of 3-12-25.


-- 1. Get LC class 

	-- a. Get LC class from marc 050a field, for all records that have that field

WITH lc_marc AS 
	(SELECT DISTINCT
		sm.instance_hrid,
		SUBSTRING (STRING_AGG (SUBSTRING (sm.content,'[A-Z]{1,3}'),' | ' ORDER BY sm.ord),'[A-Z]{1,3}') AS lc_class
	
	FROM folio_source_record.marc__t AS sm 
		
	WHERE sm.field = '050'
		AND  sm.sf = 'a'
		AND  sm.ord = 1
	GROUP BY sm.instance_hrid
),
	-- b. get format code from leader (000 field) 

formats AS 
	(SELECT 
		sm.instance_hrid,
		SUBSTRING (sm.content,7,2) AS format_code,
		vspmf.folio_format_type
		
	FROM folio_source_record.marc__t AS sm 
	LEFT JOIN local_shared.vs_folio_physical_material_formats AS vspmf 
	ON SUBSTRING (sm.content,7,2) = vspmf.leader0607
	
	WHERE sm.field = '000'
),

	-- c. Get LC class from holdings call number, then use the COALESCE function to pick the final LC class in the priority of 050 LC class, then call number LC class

lc_final AS 
	(
	SELECT
		instance__t.hrid AS instance_hrid,
		CASE WHEN STRING_AGG (DISTINCT call_number_type__t.name,' | ') like '%Library of Congress%' THEN 'LC' ELSE 'Other' END AS call_number_type,
		lc_marc.lc_class AS lc_class_050,
		
		CASE WHEN 
			call_number_type__t.name !='Library of Congress classification' 
			THEN NULL 
			ELSE SUBSTRING (STRING_AGG (DISTINCT SUBSTRING (holdings_record__t.call_number,'[A-Z]{1,3}'),' | '),'[A-Z]{1,3}') 
			END AS lc_class_holdings,
			
		CASE WHEN 
			lc_marc.lc_class IS NULL AND SUBSTRING (STRING_AGG (DISTINCT SUBSTRING (holdings_record__t.call_number,'[A-Z]{1,3}'),' | '),'[A-Z]{1,3}') IS NULL 
			THEN NULL
			ELSE 
				COALESCE (lc_marc.lc_class, 
					CASE WHEN call_number_type__t.name !='Library of Congress classification' 
						THEN NULL 
						ELSE SUBSTRING (STRING_AGG (DISTINCT SUBSTRING (holdings_record__t.call_number,'[A-Z]{1,3}'),' | '),'[A-Z]{1,3}') 
						END) 
			END AS lc_class_final, 
			formats.folio_format_type
			
	FROM folio_inventory.instance__t
		LEFT JOIN folio_inventory.holdings_record__t 
		ON instance__t.id = holdings_record__t.instance_id
		
		LEFT JOIN folio_inventory.call_number_type__t 
		ON holdings_record__t.call_number_type_id = call_number_type__t.id
		
		LEFT JOIN folio_inventory.location__t 
		ON holdings_record__t.permanent_location_id = location__t.id
		
		LEFT JOIN lc_marc 
		ON instance__t.hrid = lc_marc.instance_hrid
		
		LEFT JOIN formats 
		ON instance__t.hrid = formats.instance_hrid
	
	WHERE (instance__t.discovery_suppress = false OR instance__t.discovery_suppress IS NULL)
		AND (holdings_record__t.discovery_suppress = false OR holdings_record__t.discovery_suppress IS NULL)
		AND holdings_record__t.call_number NOT SIMILAR TO '%(n%rder|n%rocess|ON ORDER|IN PROCESS|vailable|elector|No call number)%' --- exclude records with non-standard OR temporary call numbers
		
	GROUP BY instance__t.hrid, lc_marc.lc_class, call_number_type__t.name, formats.folio_format_type
),

-- 2. Get the publicatiON information (first publisher in the record):

publ AS 
	(select 
		instance.id,
		instance.jsonb#>>'{hrid}' AS instance_hrid,
		pubs.jsonb#>>'{publisher}' AS publisher,
		pubs.jsonb#>>'{dateOfPublication}' AS publisher_date,
		SUBSTRING (pubs.jsonb#>>'{dateOfPublication}','\d{4}') AS begin_pub_date

	FROM folio_inventory.instance 
		CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (instance.jsonb,'publication'))
		WITH ordinality AS pubs (jsonb)

	WHERE pubs.ordinality = 1
),

-- 3. Get first language

langs AS 
	(SELECT 
		instance.id,
		instance.jsonb#>>'{hrid}' AS instance_hrid,
		langs.jsonb#>>'{}' AS language

	FROM folio_inventory.instance 
		CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (instance.jsonb,'languages')) 
		WITH ordinality AS langs (jsonb)

	WHERE langs.ordinality = 1
),

-- 4.Get OCLC number for all records

oclc AS 
	(SELECT 
		instids.instance_hrid,
		instids.identifier,
		SUBSTRING (instids.identifier,'\d{1,}') AS oclc_number

	FROM folio_derived.instance_identifiers AS instids 
	WHERE instids.identifier_type_name = 'OCLC'
),

-- Get circs 2019 - 2024 inclusive for all records (next 7 subqueries, steps 5 - 11)

-- 5. Get Borrow Direct charges in Voyager

vgerBD as
	(SELECT 
		cta.item_id::varchar AS item_hrid,
		pg.patron_group_name,
		COUNT (cta.circ_transaction_id) AS total_circs
		
	FROM vger.circ_trans_archive AS cta 
		LEFT JOIN vger.patron_group AS pg 
		ON cta.patron_group_id = pg.patron_group_id
		
	WHERE (cta.charge_date::DATE >= '2019-01-01'
		AND  pg.patron_group_name = 'Borrow Direct')
		
	GROUP BY cta.item_id::varchar, pg.patron_group_name
),

-- 6. Get ILL charges in Voyager

vgerILL AS 
	(SELECT 
		cta.item_id::varchar AS item_hrid,
		pg.patron_group_name,
		COUNT (cta.circ_transaction_id) AS total_circs
		
	FROM vger.circ_trans_archive AS cta 
		LEFT JOIN vger.patron_group AS pg 
		ON cta.patron_group_id = pg.patron_group_id
		
	WHERE cta.charge_date::DATE >= '2019-01-01'
		AND  pg.patron_group_name = 'Interlibrary Loan'
		
	GROUP BY cta.item_id::varchar, pg.patron_group_name
),

-- 7. Get all other charges in Voyager AS "CU Affiliated"

vgerCU AS 
	(SELECT 
		cta.item_id::varchar AS item_hrid,
		'CU Affiliated' patron_group_name,
		COUNT (cta.circ_transaction_id) AS total_circs
		
	FROM vger.circ_trans_archive AS cta 
		LEFT JOIN vger.patron_group AS pg 
		ON cta.patron_group_id = pg.patron_group_id
		
	WHERE cta.charge_date::DATE >= '2019-01-01'
		AND  pg.patron_group_name not in ('Borrow Direct', 'Interlibrary Loan')
		
	GROUP BY cta.item_id::varchar
),

-- 8. Get Borrow Direct charges in Folio

folioBD AS 
	(SELECT 
		COALESCE (item__t.hrid,'0') AS item_hrid,
		groups__t.group AS patron_group_name,
		COUNT (loan__t.id) AS total_circs 
		
	FROM folio_circulation.loan__t
		LEFT JOIN folio_users.groups__t 
		ON loan__t.patron_group_id_at_checkout = groups__t.id
		
		LEFT JOIN folio_inventory.item__t 
		ON loan__t.item_id = item__t.id 
		
	WHERE groups__t.group = 'Borrow Direct'
		AND loan__t.loan_date::date >= '2021-07-01'
		AND loan__t.loan_date::date <'2025-01-01'
	GROUP BY item__t.hrid, groups__t.group
),

-- 9. Get ILL charges in Folio 

folioILL as
(SELECT 
		COALESCE (item__t.hrid,'0') AS item_hrid,
		groups__t.group AS patron_group_name,
		COUNT (loan__t.id) AS total_circs 
		
	FROM folio_circulation.loan__t
		LEFT JOIN folio_users.groups__t 
		ON loan__t.patron_group_id_at_checkout = groups__t.id
		
		LEFT JOIN folio_inventory.item__t 
		ON loan__t.item_id = item__t.id 
		
	WHERE groups__t.group = 'Interlibrary Loan'
		AND loan__t.loan_date::date >= '2021-07-01'
		AND loan__t.loan_date::date <'2025-01-01'
	GROUP BY item__t.hrid, groups__t.group 
),

-- 10. Get all other charges in Folio, grouped under "CU Affiliated"

folioCU AS 
	(SELECT 
		COALESCE (item__t.hrid,'0') AS item_hrid,
		'CU Affiliated' AS patron_group_name,
		COUNT (loan__t.id) AS total_circs 
		
	FROM folio_circulation.loan__t
		LEFT JOIN folio_users.groups__t 
		ON loan__t.patron_group_id_at_checkout = groups__t.id
		
		LEFT JOIN folio_inventory.item__t 
		ON loan__t.item_id = item__t.id 
		
	WHERE groups__t.group not in ('Borrow Direct','Interlibrary Loan') 
		AND loan__t.loan_date::date >= '2021-07-01'
		AND loan__t.loan_date::date <'2025-01-01'
	GROUP BY item__t.hrid
),

-- 11. Total up the charges from Voyager AND Folio

circs AS 
	(
	select DISTINCT
		item__t.hrid AS item_hrid,
		SUM (COALESCE (vgerBD.total_circs,0) + COALESCE (folioBD.total_circs,0)) AS bd_total_circs,
		SUM (COALESCE (vgerILL.total_circs,0)  + COALESCE (folioILL.total_circs,0)) AS ill_total_circs,
		SUM (COALESCE (vgerCU.total_circs,0)+ COALESCE (folioCU.total_circs,0)) AS cu_aff_total_circs
		
		FROM folio_inventory.instance__t 
			LEFT JOIN folio_inventory.holdings_record__t 
			ON instance__t.id = holdings_record__t.instance_id 
			
			LEFT JOIN folio_inventory.item__t
			ON holdings_record__t.id = item__t.holdings_record_id 
		
			LEFT JOIN vgerBD 
			ON item__t.hrid = vgerBD.item_hrid 
			
			LEFT JOIN vgerILL 
			ON item__t.hrid = vgerILL.item_hrid 
			
			LEFT JOIN vgerCU 
			ON item__t.hrid = vgerCU.item_hrid
			
			LEFT JOIN folioBD 
			ON item__t.hrid = folioBD.item_hrid 
			
			LEFT JOIN folioILL 
			ON item__t.hrid = folioILL.item_hrid 
			
			LEFT JOIN folioCU 
			ON item__t.hrid = folioCU.item_hrid
		
		GROUP BY
		item__t.hrid
),

-- 12. Get all item records that circulate, whose instances were created 2019 - 2024
	-- exclude holdings with temporary or non-standard call numbers, suppressed records, and records for equipment, reserves, etc.
	-- include instance mode of issuance, item material type and record source to help determine what the form of the item is
	 
recs AS 
	(SELECT
		ii.id AS instance_id,
		hrt.id AS holdings_id,
		item.id AS item_id,
		ii.hrid AS instance_hrid,
		hrt.hrid AS holdings_hrid,
		item.jsonb#>>'{hrid}' AS item_hrid,
		ii.title,
		ii.source AS record_source,
		mt.name AS material_type_name,
		moi.name AS mode_of_issuance_name,
		location__t.code AS holdings_permanent_location_code,
		loan_type__t.name AS permanent_loan_type_name,
		(instance.jsonb#>>'{metadata,createdDate}')::DATE AS folio_create_date,
		bm.create_date::DATE AS voyager_create_date, 
		COALESCE (bm.create_date::DATE, (instance.jsonb#>>'{metadata,createdDate}')::DATE) AS instance_create_date,
		DATE_PART ('year',COALESCE (bm.create_date::DATE, (instance.jsonb#>>'{metadata,createdDate}')::DATE)) AS year_created
	
	
	FROM folio_inventory.instance__t AS ii	
		LEFT JOIN folio_inventory.instance 
		ON ii.id = instance.id
		
		LEFT JOIN folio_inventory.mode_of_issuance__t AS moi 
		ON ii.mode_of_issuance_id = moi.id
		
		LEFT JOIN folio_inventory.holdings_record__t AS hrt 
		ON ii.id = hrt.instance_id 
		
		LEFT JOIN folio_inventory.item 
		ON hrt.id = (item.jsonb#>>'{holdingsRecordId}')::uuid
		
		LEFT JOIN folio_inventory.material_type__t AS mt 
		ON (item.jsonb#>>'{materialTypeId}')::UUID = mt.id 
		
		LEFT JOIN folio_inventory.location__t 
		ON hrt.permanent_location_id = location__t.id
		
		LEFT JOIN folio_inventory.loan_type__t 
		ON (item.jsonb#>>'{permanentLoanTypeId}')::UUID = loan_type__t.id
		
		LEFT JOIN vger.bib_master AS bm 
		ON ii.hrid = bm.bib_id::varchar
		
	WHERE loan_type__t.name !='Non-circulating'
		AND location__t.code !='serv,remo'
		AND (hrt.discovery_suppress = false OR hrt.discovery_suppress IS NULL)
		AND (ii.discovery_suppress = false OR ii.discovery_suppress IS NULL)
		AND DATE_PART ('year',COALESCE (bm.create_date::DATE, (instance.jsonb#>>'{metadata,createdDate}')::DATE)) >='2019'
		AND DATE_PART ('year',COALESCE (bm.create_date::DATE, (instance.jsonb#>>'{metadata,createdDate}')::DATE)) <'2025'
		AND hrt.call_number NOT SIMILAR TO '%(n%rder|n%rocess|ON ORDER|IN PROCESS|elector|vailable|No call number)%'
		AND mt.name NOT IN ('BD MATERIAL','Carrel Keys','Equipment','ILL MATERIAL','Laptop','Locker Keys','Object','Peripherals','Room Keys','Supplies','Umbrella')
)

-- 13. JOIN all subqueries to the "recs" subquery (that finds only circulating items) AS the source data

SELECT DISTINCT
	recs.instance_hrid, 
	recs.title,
	recs.record_source,
	recs.instance_create_date, 
	to_char (recs.instance_create_date::DATE,'yyyy-mm') AS instance_created_yrmo,
	recs.year_created,
	SUM (circs.bd_total_circs) AS bd_circs,
	SUM (circs.ill_total_circs) AS ill_circs,
	SUM (circs.cu_aff_total_circs) AS cu_aff_circs,	
	langs.language AS language_code,
	lc_final.folio_format_type AS instance_format,
	STRING_AGG (DISTINCT recs.material_type_name,' | ') AS item_material_type,
	recs.mode_of_issuance_name, 
	--lc_final.lc_class_050,
	--lc_final.lc_class_holdings,
	TRIM (' | ' from STRING_AGG (DISTINCT CASE WHEN lc_final.lc_class_final IS NULL THEN 'Other' ELSE 'LC' END,' | ')) AS call_number_type_name,
	TRIM (' | ' from STRING_AGG (DISTINCT lc_final.lc_class_final,' | ')) AS lc_class,
	SUBSTRING (STRING_AGG (DISTINCT lc_final.lc_class_final,' | '),1,1) AS first_letter,
	SUBSTRING (STRING_AGG (DISTINCT lc_final.lc_class_final,' | '),2,1) AS second_letter,
	publ.publisher,
	publ.publisher_date,
	publ.begin_pub_date,
	DATE_PART ('year', current_date::DATE) - recs.year_created AS age, 
	oclc.oclc_number AS oclc_id_norm,
	(CASE WHEN langs.language = 'eng' THEN TRUE ELSE FALSE END)::BOOLEAN AS lang_is_english
	

FROM recs 
	LEFT JOIN publ  
	ON recs.instance_id = publ.id
	
	LEFT JOIN langs 
	ON recs.instance_id = langs.id
	
	LEFT JOIN lc_final 
	ON recs.instance_hrid = lc_final.instance_hrid
	
	LEFT JOIN oclc 
	ON recs.instance_hrid = oclc.instance_hrid 
	
	LEFT JOIN circs
	ON recs.item_hrid = circs.item_hrid


GROUP BY 
	recs.instance_hrid,
	recs.title,
	recs.record_source,
	recs.instance_create_date,
	to_char (recs.instance_create_date::DATE,'yyyy-mm'), 
	recs.year_created, 
	langs.language,
	lc_final.folio_format_type,
	recs.mode_of_issuance_name, 
	publ.publisher,
	publ.publisher_date,
	publ.begin_pub_date,
	DATE_PART ('year', current_date::DATE) - recs.year_created, 
	oclc.oclc_number,	
	(CASE WHEN langs.language = 'eng' THEN TRUE ELSE FALSE END)::BOOLEAN
;

