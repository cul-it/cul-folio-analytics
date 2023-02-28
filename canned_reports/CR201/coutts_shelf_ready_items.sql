--CR201
--coutts_shelf_ready_items

WITH recs AS 
(
SELECT
	DISTINCT
        sm.instance_hrid,
	sm.content
FROM
	public.srs_marctab AS sm
WHERE
	sm.field = '948'
	AND sm.content LIKE '%CouttsShelfReady%'
)

SELECT
	recs.content,
	ii.title,
	ll.library_name,
	he.permanent_location_name,
	ii.hrid AS instance_hrid,
	he.holdings_hrid,
	invitems.hrid AS item_hrid,
	invitems.barcode,
	he.type_name AS holdings_type_name,
	trim (CONCAT_WS (' ',
	he.call_number_prefix,
	he.call_number,
	he.call_number_suffix,
	invitems.enumeration,
	invitems.chronology,
	CASE
		WHEN invitems.copy_number >'1' THEN concat ('c.',
		invitems.copy_number)
		ELSE ''
	END)) AS whole_call_number,
	SUBSTRING (he.call_number,
	'^([a-zA-z]{1,3})') AS lc_class,
	to_char (ii.metadata__created_date::date,
	'mm/dd/yyyy') AS instance_create_date,
	ii.publication_period__start,
	ii.publication_period__end,
	ip.publisher,
	invitems.effective_shelving_order COLLATE "C"
FROM
	inventory_instances AS ii
LEFT JOIN folio_reporting.holdings_ext AS he 
                ON
	ii.id = he.instance_id
LEFT JOIN inventory_items AS invitems 
                ON
	he.holdings_id = invitems.holdings_record_id
LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON
	he.permanent_location_id = ll.location_id
LEFT JOIN folio_reporting.instance_publication AS ip 
                ON
	ii.hrid = ip.instance_hrid
INNER JOIN recs
                ON
	ii.hrid = recs.instance_hrid
WHERE
	SUBSTRING (he.call_number,
	'^([a-zA-z]{1,3})') SIMILAR TO '(A|K)%'
	AND ll.library_name = 'Olin Library'
	AND (he.discovery_suppress = 'False'
		OR he.discovery_suppress IS NULL)
	AND ip.publisher != ''
ORDER BY
	invitems.effective_shelving_order COLLATE "C"
;

