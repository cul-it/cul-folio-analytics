-AHR116
--olin_microforms_with_circs_and_srs_marctab_fields
-- This query gets Olin and Kroch microforms and finds Voyager and Folio circ transactions with patron groups.

-- 1. Get microform records

WITH recs AS 
(
SELECT
	DISTINCT
        ii.title,
	ii.id AS instance_id,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	invitems.id AS item_id,
	invitems.hrid AS item_hrid,
	ll.library_name,
	he.permanent_location_name AS location_name,
	trim (concat_ws (' ',
	he.call_number_prefix,
	he.call_number,
	he.call_number_suffix,
	invitems.enumeration,
	invitems.chronology,
	CASE
		WHEN invitems.copy_number>'1' THEN concat ('c.',
		invitems.copy_number)
		ELSE ''
	END)) AS whole_call_number,
	invitems.effective_shelving_order
FROM
	inventory_instances AS ii
LEFT JOIN folio_reporting.holdings_ext AS he 
                ON
	ii.id = he.instance_id
LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON
	he.permanent_location_id = ll.location_id
LEFT JOIN inventory_items AS invitems 
                ON
	he.holdings_id = invitems.holdings_record_id
WHERE
	(he.call_number SIMILAR TO '%(Film|Fiche|Micro|film|fiche|micro)%'
		OR ii.title ILIKE '%[microform]%'
		OR ii.hrid IN 
                        (
		SELECT
			ii.hrid
		FROM
			srs_marctab AS sm
		INNER JOIN inventory_instances AS ii 
                                        ON
			sm.instance_hrid = ii.hrid
		WHERE
			substring (sm.content,
			1,
			1) = 'h'
				AND sm.field = '007')
                )
	AND ll.library_name IN ('Olin Library', 'Kroch Library Asia')
	AND (he.discovery_suppress IS NULL
		OR he.discovery_suppress = 'False')
),
--2. Get Voyager circs

voycircs AS
(
SELECT
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	count (cta.circ_transaction_id) AS number_of_circs_voyager,
	string_agg (DISTINCT pg.patron_group_name,
	' | ') AS patron_groups_voyager,
	sum (cta.discharge_date::date - cta.charge_DATE::DATE) AS total_days_on_loan_voyager
FROM
	recs
LEFT JOIN vger.circ_trans_archive AS cta 
        ON
	recs.item_hrid::varchar = cta.item_id::varchar
LEFT JOIN vger.patron_group AS pg 
        ON
	cta.patron_group_id = pg.patron_group_id
GROUP BY
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid
),
-- 3. Get Folio circs

folio_circs AS 
(
SELECT
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	count (li.loan_id) AS number_of_circs_folio,
	string_agg (DISTINCT li.patron_group_name,
	' | ') AS patron_groups_folio,
	sum (CASE
		WHEN li.loan_return_date IS NOT NULL THEN li.loan_return_date::date - li.loan_date::DATE
		ELSE current_date::date - li.loan_date::date
	END) AS total_days_on_loan_folio
FROM
	recs
LEFT JOIN folio_reporting.loans_items AS li 
        ON
	recs.item_id = li.item_id
GROUP BY
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid
),
-- 4. Get Sudoc numbers, GPO numbers, OCLC numbers, 300 field and 533e field descriptions

sudoc AS 
(
SELECT
	sm.instance_hrid,
	string_agg (sm.content,
	' | ') AS sudoc_number
FROM
	srs_marctab AS sm
WHERE
	sm.field = '086'
GROUP BY
	sm.instance_hrid
),

gpo AS 
(
SELECT
	sm.instance_hrid,
	string_agg (DISTINCT sm.content,
	' | ') AS gpo_number
FROM
	srs_marctab AS sm
WHERE
	sm.field = '074'
GROUP BY
	sm.instance_hrid
),

field_300 AS 
(
SELECT
	sm.instance_hrid,
	string_agg (DISTINCT sm.content,
	' | ') AS description_field_300
FROM
	srs_marctab AS sm
WHERE
	sm.field = '300'
GROUP BY
	sm.instance_hrid
),

field_533e AS 
(
SELECT
	sm.instance_hrid,
	string_agg(sm.content, ' | ') AS number_of_reels_or_fiche
FROM
	srs_marctab AS sm
WHERE
	sm.field = '533'
	AND sm.sf = 'e'
GROUP BY
	sm.instance_hrid
        ),

oclc AS 
        (
SELECT
	instid.instance_hrid,
	string_agg (DISTINCT trim(substring (instid.identifier, 8, 10)),
	' | ') AS oclc_numbers
FROM
	folio_reporting.instance_identifiers AS instid
WHERE
	instid.identifier_type_name = 'OCLC'
GROUP BY
	instid.instance_hrid 
),
-- 5. Get microform type from 007 field and call number

field_007_type AS 
(
SELECT
	sm.instance_hrid,
	CASE
		WHEN substring (sm."content",
		2,
		1) IN ('b', 'c', 'd', 'h', 'j') THEN 'Microfilm'
		WHEN substring (sm."content",
		2,
		1) IN ('e', 'f') THEN 'Microfiche'
		WHEN substring (sm."content",
		2,
		1) = 'g' THEN 'Microopaque'
		WHEN substring (sm."content",
		2,
		1) = '|' THEN 'No attempt to code'
		ELSE ''
	END AS microform_type_007
FROM
	srs_marctab AS sm
WHERE
	sm.field = '007'
	AND substring (sm.content,
	1,
	1) = 'h'
),

cn_type AS 
(
SELECT
	recs.instance_hrid,
	CASE
		WHEN recs.whole_call_number ILIKE '%fiche%' THEN 'Microfiche'
		WHEN recs.whole_call_number ILIKE '%film%' THEN 'Microfilm'
		WHEN recs.whole_call_number ILIKE '%microprint%' THEN 'Microprint'
		WHEN recs.whole_call_number ILIKE '%opaque%' THEN 'Microopaque'
		WHEN recs.whole_call_number ILIKE '%microcard%' THEN 'Microcard'
		ELSE ''
	END AS microform_type_cn
FROM
	recs 
)
-- 6. Combine results of previous subqueries

SELECT
	DISTINCT
        recs.title,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.library_name,
	recs.location_name,
	recs.whole_call_number,
	string_agg (DISTINCT CASE
		WHEN cn_type.microform_type_cn != '' THEN cn_type.microform_type_cn
		WHEN field_007_type.microform_type_007 != '' THEN field_007_type.microform_type_007
		ELSE 'Unknown'
	END,
	' | ') AS microform_type,
	field_533e.number_of_reels_or_fiche,
	field_300.description_field_300,
	oclc.oclc_numbers,
	gpo.gpo_number,
	sudoc.sudoc_number,
	voycircs.number_of_circs_voyager,
	CASE
		WHEN voycircs.patron_groups_voyager IS NULL THEN '-'
		ELSE voycircs.patron_groups_voyager
	END AS patron_groups_voyager,
	CASE
		WHEN voycircs.total_days_on_loan_voyager IS NULL THEN 0
		ELSE voycircs.total_days_on_loan_voyager
	END AS total_days_on_loan_voyager,
	CASE
		WHEN folio_circs.number_of_circs_folio IS NULL THEN 0
		ELSE folio_circs.number_of_circs_folio
	END AS number_of_circs_folio,
	CASE
		WHEN folio_circs.patron_groups_folio IS NULL THEN '-'
		ELSE folio_circs.patron_groups_folio
	END AS patron_groups_folio,
	CASE
		WHEN folio_circs.total_days_on_loan_folio IS NULL THEN 0
		ELSE folio_circs.total_days_on_loan_folio
	END 
        AS total_days_on_loan_folio,
	recs.effective_shelving_order COLLATE "C"
FROM
	recs
LEFT JOIN voycircs 
        ON
	recs.instance_hrid = voycircs.instance_hrid
	AND recs.holdings_hrid = voycircs.holdings_hrid
	AND recs.item_hrid = voycircs.item_hrid
LEFT JOIN folio_circs 
        ON
	recs.instance_hrid = folio_circs.instance_hrid
	AND recs.holdings_hrid = folio_circs.holdings_hrid
	AND recs.item_hrid = folio_circs.item_hrid
LEFT JOIN gpo 
        ON
	recs.instance_hrid = gpo.instance_hrid
LEFT JOIN sudoc 
        ON
	recs.instance_hrid = sudoc.instance_hrid
LEFT JOIN field_300 
        ON
	recs.instance_hrid = field_300.instance_hrid
LEFT JOIN field_533e 
        ON
	recs.instance_hrid = field_533e.instance_hrid
LEFT JOIN oclc 
        ON
	recs.instance_hrid = oclc.instance_hrid
LEFT JOIN field_007_type 
        ON
	recs.instance_hrid = field_007_type.instance_hrid
LEFT JOIN cn_type 
        ON
	recs.instance_hrid = cn_type.instance_hrid
GROUP BY
	recs.title,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.library_name,
	recs.location_name,
	recs.whole_call_number,
	field_533e.number_of_reels_or_fiche,
	field_300.description_field_300,
	oclc.oclc_numbers,
	gpo.gpo_number,
	sudoc.sudoc_number,
	voycircs.number_of_circs_voyager,
	voycircs.patron_groups_voyager,
	voycircs.total_days_on_loan_voyager,
	folio_circs.number_of_circs_folio,
	folio_circs.patron_groups_folio,
	folio_circs.total_days_on_loan_folio,
	recs.effective_shelving_order COLLATE "C"
ORDER BY
	recs.library_name,
	recs.location_name,
	recs.effective_shelving_order COLLATE "C"
;
