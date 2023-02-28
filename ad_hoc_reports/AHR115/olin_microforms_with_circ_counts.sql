--AHR 115
--olin_microforms_with_circ_counts

WITH recs AS 
(
SELECT
	current_date::date AS todays_date,
	ll.library_name,
	he.permanent_location_name,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	invitems.hrid AS item_hrid,
	ii.title,
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
	invitems.barcode,
	CASE
		WHEN item.create_date::date IS NULL THEN invitems.metadata__created_date::date
		ELSE item.create_date::date
	END AS item_create_date,
	CASE
		WHEN pg.patron_group_name IS NULL
		AND item.historical_charges > 0 THEN 'Pre-Voyager'
		ELSE pg.patron_group_name
	END AS patron_group_name_voyager,
	cta.circ_transaction_id::varchar,
	cta.charge_date::date,
	cta.discharge_date::date,
	cta.discharge_date::date - cta.charge_date::date AS number_of_days_on_loan_voyager,
	item.historical_charges AS voyager_historical_charges,
	invitems.status__name AS item_status,
	invitems.status__date::date AS item_status_date,
	li.loan_id,
	li.patron_group_name AS patron_group_name_folio,
	uu.custom_fields__college,
	uu.custom_fields__department,
	uu.personal__last_name,
	uu.personal__first_name,
	CASE
		WHEN li.loan_return_date::date IS NOT NULL THEN li.loan_return_date::date - li.loan_date::date
		ELSE current_date::date - li.loan_date::date
	END AS number_of_days_on_loan_folio,
	he.type_name AS holdings_type_name,
	SUBSTRING (he.call_number,
	'^([A-Za-z]{1,3})') AS lc_class,
	SUBSTRING (call_number,
	'\d{1,}\.{0,}\d{0,}') AS lc_class_number,
	invitems.effective_shelving_order
FROM
	inventory_instances AS ii
LEFT JOIN folio_reporting.holdings_ext AS he 
        ON
	ii.id = he.instance_id
LEFT JOIN inventory_items AS invitems 
        ON
	he.holdings_id = invitems.holdings_record_id
LEFT JOIN folio_reporting.loans_items AS li 
        ON
	invitems.id = li.item_id
LEFT JOIN user_users uu 
        ON
	li.user_id = uu.id
LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON
	he.permanent_location_id = ll.location_id
LEFT JOIN vger.item  
        ON
	invitems.hrid::varchar = item.item_id::varchar
LEFT JOIN vger.circ_trans_archive AS cta 
        ON
	item.item_id::varchar = cta.item_id::varchar
LEFT JOIN vger.patron_group AS pg 
        ON
	cta.patron_group_id = pg.patron_group_id
WHERE
	(he.call_number SIMILAR TO '%(Film|Fiche|Micro|film|fiche|micro)%'
		OR ii.title ILIKE '%[microform]%'
		OR ii.hrid IN (
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
				AND sm.field = '007'))
	AND ll.library_name IN ('Olin Library', 'Kroch Library Asia')
	AND (he.discovery_suppress IS NULL
		OR he.discovery_suppress = 'False')
GROUP BY
	current_date::date,
	ll.library_name,
	he.permanent_location_name,
	ii.hrid,
	he.holdings_hrid,
	invitems.hrid,
	ii.title,
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
	END)),
	invitems.barcode,
	CASE
		WHEN item.create_date::date IS NULL THEN invitems.metadata__created_date::date
		ELSE item.create_date::date
	END,
	pg.patron_group_name,
	cta.circ_transaction_id::varchar,
	cta.charge_date::date,
	cta.discharge_date::date,
	cta.discharge_date::date - cta.charge_date::date,
	item.historical_charges,
	invitems.status__name,
	invitems.status__date::date,
	li.loan_id,
	li.patron_group_name,
	uu.custom_fields__college,
	uu.custom_fields__department,
	uu.personal__last_name,
	uu.personal__first_name,
	li.loan_date::date,
	li.loan_return_date::date,
	CASE
		WHEN li.loan_return_date IS NOT NULL THEN li.loan_return_date::date - li.loan_date::date
		ELSE current_date::date - li.loan_date::date
	END,
	he.type_name,
	SUBSTRING (he.call_number,
	'^([A-Za-z]{1,3})'),
	SUBSTRING (call_number,
	'\d{1,}\.{0,}\d{0,}'),
	invitems.effective_shelving_order
        ),
        
recs2 AS 
(
SELECT
	recs.todays_date,
	recs.library_name,
	recs.permanent_location_name,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.title,
	recs.whole_call_number,
	recs.barcode,
	recs.item_create_date,
	string_agg (DISTINCT recs.patron_group_name_voyager,
	' | ') AS patron_groups_voyager,
	count (DISTINCT recs.circ_transaction_id::varchar) AS voyager_circs,
	sum(recs.number_of_days_on_loan_voyager) AS total_days_on_loan_voyager,
	recs.voyager_historical_charges,
	recs.item_status,
	recs.item_status_date,
	count (DISTINCT recs.loan_id) AS folio_circs,
	string_agg (DISTINCT recs.patron_group_name_folio,
	' | ') AS folio_patron_groups,
	string_agg (DISTINCT recs.custom_fields__college,
	' | ') AS college,
	string_agg (DISTINCT recs.custom_fields__department,
	' | ') AS department,
	recs.number_of_days_on_loan_folio AS total_days_on_loan_folio,
	recs.holdings_type_name,
	recs.lc_class,
	recs.lc_class_number,
	recs.effective_shelving_order
FROM
	recs
GROUP BY
	recs.todays_date,
	recs.library_name,
	recs.permanent_location_name,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.title,
	recs.whole_call_number,
	recs.barcode,
	recs.item_create_date,
	recs.voyager_historical_charges,
	recs.item_status,
	recs.item_status_date,
	recs.personal__last_name,
	recs.personal__first_name,
	recs.number_of_days_on_loan_folio,
	recs.holdings_type_name,
	recs.lc_class,
	recs.lc_class_number,
	recs.effective_shelving_order
)

SELECT
	recs2.todays_date,
	recs2.library_name,
	recs2.permanent_location_name,
	recs2.instance_hrid,
	recs2.holdings_hrid,
	recs2.item_hrid,
	recs2.title,
	recs2.whole_call_number,
	recs2.barcode,
	recs2.item_create_date,
	recs2.patron_groups_voyager,
	recs2.voyager_circs,
	recs2.total_days_on_loan_voyager,
	recs2.voyager_historical_charges,
	recs2.item_status,
	recs2.item_status_date,
	sum (recs2.folio_circs) AS folio_circs,
	string_agg (DISTINCT recs2.folio_patron_groups,
	' | ') AS folio_patron_groups,
	string_agg (DISTINCT recs2.college,
	' | ') AS folio_colleges,
	string_agg (DISTINCT recs2.department,
	' | ') AS folio_depts,
	sum (recs2.total_days_on_loan_folio) AS total_days_on_loan_folio,
	recs2.holdings_type_name,
	recs2.lc_class,
	recs2.lc_class_number,
	recs2.effective_shelving_order
FROM
	recs2
GROUP BY
	recs2.todays_date,
	recs2.library_name,
	recs2.permanent_location_name,
	recs2.instance_hrid,
	recs2.holdings_hrid,
	recs2.item_hrid,
	recs2.title,
	recs2.whole_call_number,
	recs2.barcode,
	recs2.item_create_date,
	recs2.patron_groups_voyager,
	recs2.voyager_circs,
	recs2.total_days_on_loan_voyager,
	recs2.voyager_historical_charges,
	recs2.item_status,
	recs2.item_status_date,
	recs2.holdings_type_name,
	recs2.lc_class,
	recs2.lc_class_number,
	recs2.effective_shelving_order
ORDER BY
	recs2.permanent_location_name,
	recs2.effective_shelving_order COLLATE "C"
  ;
