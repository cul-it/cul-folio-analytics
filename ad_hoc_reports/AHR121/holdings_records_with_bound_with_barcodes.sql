--AHR121
--holdings_records_with_bound_with_barcodes

WITH holdbarcodes AS 
(
SELECT
	hn.holdings_id,
	hn.holdings_hrid,
	string_agg (DISTINCT hn.note,
	' | ') AS holdings_notes,
	substring (hn.note,
	'\d{14}') AS hn_barcode
FROM
	folio_reporting.holdings_notes AS hn
WHERE
	hn.note ILIKE '%31924%'
GROUP BY
	holdings_id,
	holdings_hrid,
	hn.note
),
--2. Find the holdings records that match Jake's list of barcodes
matches AS 
(
SELECT
	hb.holdings_id,
	hb.holdings_hrid,
	hb.hn_barcode,
	jsb."Item Barcode"
FROM
	holdbarcodes AS hb
INNER JOIN LOCAL.jake_sample_barcodes jsb 
ON
	hb.hn_barcode = jsb."Item Barcode"
)
-- 3. From the matched holdings records, find the item records associated with them. Show the item location, item enumeration, item barcodes
SELECT
	ii.title,
	he.permanent_location_name AS holdings_location_name,
	he.call_number,
	ii.hrid AS instance_hrid,
	matches.holdings_hrid,
	matches."Item Barcode" AS jake_barcode,
	ie.item_hrid AS item_hrid_for_matched_holdings_record,
	ie.barcode AS item_barcode_for_matched_holdings_record,
	ie.enumeration AS item_enumeration_for_matched_holdings_record,
	ie.effective_location_name AS item_location_for_matched_holdings_record
FROM
	matches
LEFT JOIN folio_reporting.item_ext AS ie 
ON
	matches.holdings_id = ie.holdings_record_id
LEFT JOIN folio_reporting.holdings_ext AS he 
ON
	matches.holdings_id = he.holdings_id
LEFT JOIN inventory_instances AS ii 
ON
	he.instance_id = ii.id
;
