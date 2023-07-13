--AHR129
--Voyager and Folio circ counts for specified titles
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 7/11/2023

-- This query finds Voyager and Folio circ counts for two titles in Olin. The information will be used to inform a cancellation decision (requested by Susette Newberry).

WITH recs AS 
(
SELECT
	ii.title,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	ie.item_id,
	ie.item_hrid,
	ie.created_date::date AS folio_item_create_date,
	ll.library_name,
	he.permanent_location_name,
	concat (he.call_number_prefix,
	' ',
	he.call_number,
	' ',
	he.call_number_suffix,
	' ',
	ie.enumeration,
	' ',
	ie.chronology,
	' ',
	CASE
		WHEN ie.copy_number >'1' THEN concat ('c.',
		ie.copy_number)
		ELSE ''
	END) AS whole_call_number,
	ie.barcode,
	invitems.effective_shelving_order
FROM
	inventory_instances AS ii
LEFT JOIN folio_reporting.holdings_ext AS he 
       ON
	ii.id = he.instance_id
LEFT JOIN folio_reporting.item_ext AS ie 
       ON
	he.holdings_id = ie.holdings_record_id
LEFT JOIN inventory_items AS invitems 
       ON
	ie.item_id = invitems.id
LEFT JOIN folio_reporting.locations_libraries AS ll 
       ON
	he.permanent_location_id = ll.location_id
WHERE
	ii.hrid IN ('1020597', '3124171')
),
 
voycircs AS 
(
SELECT
	recs.item_hrid,
	item.item_id::varchar AS voy_item_id,
	item.create_date::date AS voyager_item_create_date,
	item.historical_charges AS historical_voyager_charges,
	max (cta.charge_date)::date AS most_recent_vger_circ,
	count (cta.circ_transaction_id) AS total_voyager_circs
FROM
	recs
LEFT JOIN vger.item 
       ON
	recs.item_hrid = item.item_id::varchar
LEFT JOIN vger.circ_trans_archive cta 
       ON
	item.item_id = cta.item_id
GROUP BY
	recs.item_hrid,
	item.item_id::varchar,
	item.create_date::date,
	item.historical_charges
),
 
foliocircs AS 
(
SELECT
	recs.item_hrid,
	max (li.loan_date)::date AS most_recent_folio_circ,
	count (li.loan_id) AS total_folio_circs
FROM
	recs
LEFT JOIN folio_reporting.loans_items AS li 
       ON
	recs.item_id = li.item_id
GROUP BY
	recs.item_hrid
)
 
SELECT
	recs.title,
	recs.instance_hrid,
	recs.holdings_hrid,
	recs.item_hrid,
	recs.library_name,
	recs.permanent_location_name,
	recs.whole_call_number,
	recs.barcode,
	COALESCE (voycircs.voyager_item_create_date,
	recs.folio_item_create_date) AS item_create_date,
	voycircs.historical_voyager_charges,
	voycircs.total_voyager_circs,
	voycircs.most_recent_vger_circ::date,
	foliocircs.most_recent_folio_circ,
	foliocircs.total_folio_circs,
	to_char (COALESCE (foliocircs.most_recent_folio_circ,
	voycircs.most_recent_vger_circ)::date,
	'mm/dd/yyyy') AS most_recent_checkout
FROM
	recs
LEFT JOIN voycircs 
       ON
	recs.item_hrid = voycircs.item_hrid::varchar
LEFT JOIN foliocircs 
       ON
	recs.item_hrid = foliocircs.item_hrid
ORDER BY
	recs.title,
	recs.effective_shelving_order COLLATE "C"
;
