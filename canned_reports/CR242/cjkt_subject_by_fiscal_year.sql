-- CR241
-- last updated: 5/15/24
-- cjkt_subject_by_fiscal_year
-- query written and tested by Joanne Leary and Sharon Markus
-- This query finds all item or holdings records with Chinese, Japanese, Korean AND Tibetan 
-- subject headings that were added to the collection in the fiscal year specified.
-- Query excludes those works in languages chi,jpn,kor,tib.
-- All libraries AND locations are included. Counts are sorted by month added.
-- The instance format is extracted FROM the leader, 
-- and the form of the work (print, e-resource or microform) is determined by the holdings location and call number.
-- The query excludes suppressed instance and holdings records.
-- 4-19-24: Added a clause to exclude purchase_on_demand ebooks (EBA books: Evidence based acquisitions) 
-- that aren't yet in the collection.
-- 4-20-24: Changed sorting statement for form of work to include 007 and title determinants for microforms
-- and updated CASE WHEN statements for fiscal year created in item_create and holdings_create subqueries.
-- To get cumulative language items that include Voyager data going back to FY2000, use FY 2000 in the 
-- fiscal year filter and change the COALESCE statment for fiscal year in the 
-- WHERE clause on line 156 to  '>=' instead of '='
-- The results of this query are combined with the results of CR241 cjkt_language_by_fiscal_year to provide
-- the CEAL Stats and the All Items reports needed by Asia Studies. The language field is changed to "non-CJKT" in the final reports to 
-- show items within a given fiscal year (for CEAL) or acquired from a given fiscal year forward (for All Items) that have CJKT subjects, 
-- but are not in CJKT languages. 

/* A fiscal year must be entered below in order to retrieve data */
WITH parameters AS 
	(SELECT 
	'FY 2023'::VARCHAR AS fiscal_year_filter -- ex: FY 2022, FY 2023, etc.
), 

marc_formats AS
	(SELECT DISTINCT 
		sm.instance_hrid,
		substring(sm."content", 7, 2) AS leader0607
	FROM srs_marctab AS sm
	WHERE sm.field = '000'
),

item_create AS 
	(SELECT 
		ie.item_hrid,
		item.item_id::varchar,
		ie.created_date::DATE AS folio_create_date,
		item.create_date::DATE AS voyager_create_date,
		COALESCE (item.create_date::DATE, ie.created_date::DATE) AS item_create_date,
		DATE_PART ('year',COALESCE (item.create_date::DATE, ie.created_date::DATE)) AS year_created,
		CASE 
			
			WHEN DATE_PART ('month',COALESCE (item.create_date::DATE, ie.created_date::DATE))> 6 
			THEN concat ('FY ',DATE_PART ('year',COALESCE (item.create_date::DATE, ie.created_date::DATE))+1)
			ELSE concat ('FY ',DATE_PART ('year',COALESCE (item.create_date::DATE, ie.created_date::DATE))) 
			END AS fiscal_year_created
	
	FROM folio_reporting.item_ext AS ie 
	LEFT JOIN vger.item 
	on ie.item_hrid = item.item_id::varchar
),

holdings_create AS 
	(SELECT 
		he.holdings_hrid,
		mm.create_date::DATE AS voyager_create_date,
		he.created_date::DATE AS folio_create_date,
		COALESCE (mm.create_date::DATE, he.created_date::DATE) AS holdings_create_date,
		CASE 	
			WHEN DATE_PART ('month',COALESCE (mm.create_date::DATE, he.created_date::DATE))> 6 
			THEN concat ('FY ',DATE_PART ('year',COALESCE (mm.create_date::DATE, he.created_date::DATE))+1)
			ELSE concat ('FY ',DATE_PART ('year',COALESCE (mm.create_date::DATE, he.created_date::DATE))) 
			END AS fiscal_year_created
			
		FROM folio_reporting.holdings_ext AS he 
		LEFT JOIN vger.mfhd_master AS mm 
		on he.holdings_hrid = mm.mfhd_id::varchar
),

recs AS 
(SELECT DISTINCT
	COALESCE (item_create.fiscal_year_created, holdings_create.fiscal_year_created)	as fiscal_year,
	CASE WHEN item_create.item_create_date::DATE IS NOT NULL
		THEN DATE_PART ('month',item_create.item_create_date::DATE) 
		ELSE DATE_PART ('month',holdings_create.holdings_create_date::DATE) 
		END AS month_created,	
	CASE 
		WHEN item_create.item_create_date::DATE IS NOT NULL 
		THEN to_char (item_create.item_create_date::DATE,'Mon')
		ELSE to_char (holdings_create.holdings_create_date::DATE,'Mon') 
		END AS month_name,	
    ii.title,
    instlang.language,
    STRING_AGG (DISTINCT instsubj.subject,' | ') AS subjects,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ll.library_name AS holdings_library_name,	
	il.code AS holdings_location_code,
	adc.adc_loc_translation,
	he.permanent_location_name,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',
		ie.enumeration, ' ',ie.chronology)) AS whole_call_number,
    fmg.folio_format_type,
    CASE 
	    WHEN he.permanent_location_name = 'serv,remo' THEN 'Eresource'
	    WHEN 
		    (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix) SIMILAR TO '%(Film|Fiche|Micro|film|fiche|micro|FILM|FICHE|MICRO)%'
			OR ii.title ILIKE '%[microform]%'
			OR ii.hrid IN 
				(SELECT 
					ii.hrid
					FROM srs_marctab AS sm
					INNER JOIN inventory_instances AS ii 
						ON sm.instance_hrid = ii.hrid
					WHERE SUBSTRING (sm.content,1,1) = 'h'
					AND sm.field = '007')
			)
	    THEN 'Microform' 
	    ELSE 'Print' 
      END AS print_eresource_or_microform
	
FROM inventory_instances AS ii 
	LEFT JOIN marc_formats AS mf
	ON ii.hrid = mf.instance_hrid
	
	LEFT JOIN folio_reporting.instance_subjects AS instsubj
	ON ii.hrid = instsubj.instance_hrid
	
	LEFT JOIN folio_reporting.instance_languages AS instlang 
	ON ii.hrid = instlang.instance_hrid
	
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON ii.id = he.instance_id 
	
	LEFT JOIN folio_reporting.item_ext AS ie 
	ON he.holdings_id = ie.holdings_record_id
	
	LEFT JOIN item_create 
	ON ie.item_hrid = item_create.item_hrid
	
	LEFT JOIN holdings_create 
	ON he.holdings_hrid = holdings_create.holdings_hrid
	
	LEFT JOIN inventory_locations AS il 
	ON he.permanent_location_id = il.id
	
	LEFT JOIN folio_reporting.locations_libraries AS ll 
	ON he.permanent_location_id = ll.location_id
	
	LEFT JOIN local_core.vs_folio_physical_material_formats AS fmg 
	ON mf.leader0607 = fmg.leader0607 
	
    LEFT JOIN local_core.lm_adc_location_translation_table AS adc 
    ON il.code = adc.adc_invloc_location_code
	
WHERE 
	(ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL)
	AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
	AND he.holdings_hrid is NOT NULL 
	AND TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix)) NOT ILIKE ALL
		(ARRAY ['%On order%', '%in process%', '%Available for the library to purchase%', '%selector%', '%vault%'])
	AND instlang.language not IN ('chi','jpn','kor','tib')
	AND UPPER(instsubj.subject) SIMILAR TO '%(CHINA|CHINESE|JAPAN|KOREA|TIBET)%'
	AND COALESCE (item_create.fiscal_year_created, holdings_create.fiscal_year_created) = (SELECT fiscal_year_filter FROM parameters)
	AND ii.hrid NOT IN 
		(SELECT distinct sm.instance_hrid FROM srs_marctab AS sm WHERE sm.field = '856' AND sm.content ILIKE '%Not yet in permanent collection%')
	--AND ii.hrid NOT IN 
		--(SELECT distinct sm.instance_hrid FROM srs_marctab AS sm WHERE sm.field = '899' AND sm.sf ='a' AND (sm.content LIKE 'EBA%' or sm.content LIKE 'DDA%'))
		
GROUP BY 
	COALESCE (item_create.fiscal_year_created, holdings_create.fiscal_year_created),
	CASE WHEN item_create.item_create_date::DATE IS NOT NULL
		THEN DATE_PART ('month',item_create.item_create_date::DATE) 
		ELSE DATE_PART ('month',holdings_create.holdings_create_date::DATE) 
		END,
		
	CASE 
		WHEN item_create.item_create_date::DATE is NOT NULL 
		THEN to_char (item_create.item_create_date::DATE,'Mon')
		ELSE to_char (holdings_create.holdings_create_date::DATE,'Mon') 
		END,
		
    ii.title,
    instlang.language,
	ii.hrid,
	he.holdings_hrid,
	ie.item_hrid,
	ll.library_name,	
	il.code,
	adc.adc_loc_translation,
	he.permanent_location_name,
	TRIM (CONCAT (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix,' ',
		ie.enumeration, ' ',ie.chronology)),
    fmg.folio_format_type,
    CASE 
	    WHEN he.permanent_location_name = 'serv,remo' THEN 'Eresource'
	    WHEN 
		    (CONCAT_WS (' ',he.call_number_prefix,he.call_number,he.call_number_suffix) SIMILAR TO '%(Film|Fiche|Micro|film|fiche|micro|FILM|FICHE|MICRO)%'
			OR ii.title ILIKE '%[microform]%'
			OR ii.hrid IN 
				(SELECT 
					ii.hrid
					FROM srs_marctab AS sm
					INNER JOIN inventory_instances AS ii 
						ON sm.instance_hrid = ii.hrid
					WHERE SUBSTRING (sm.content,1,1) = 'h'
					AND sm.field = '007')
			)
	    THEN 'Microform' 
	    ELSE 'Print' 
      END
	)
	
SELECT 
	current_date::DATE,
    recs.fiscal_year,	
	recs.month_created,
	recs.month_name,
	recs.language,
    recs.folio_format_type,
    recs.print_eresource_or_microform,     
    CASE 
	    WHEN COUNT (DISTINCT recs.item_hrid) = 0 THEN COUNT (DISTINCT recs.holdings_hrid) 
		ELSE COUNT (DISTINCT recs.item_hrid) END AS count_of_volumes
   	      
FROM recs
      
GROUP BY 
    current_date::DATE,
    recs.fiscal_year,	
	recs.month_created,
	recs.month_name,
	recs.language,
    recs.folio_format_type,
    recs.print_eresource_or_microform

ORDER BY 
	fiscal_year,  
	month_created, 
	language,  
	folio_format_type,
	print_eresource_or_microform
;

