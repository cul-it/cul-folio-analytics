WITH parameters AS 
(
SELECT
	'2022-07-01'::date AS received_date_start
	-- enter a start date in the format 'yyyy-mm-dd'
),

recs AS 
(
SELECT
	to_char (current_date::date,
	'mm/dd/yyyy') AS todays_date,
	prh.id,
	prh.received_date::date AS date_received,
	CASE
		WHEN date_part ('month',
		prh.received_date) < 7 
                THEN concat ('FY ',
		date_part ('year',
		prh.received_date))
		ELSE concat ('FY ',
		date_part ('year',
		prh.received_date)+ 1)
	END AS fiscal_year_received,
	prh.po_line_number,
	popo.order_type,
	poi.pol_instance_hrid,
	il.language AS primary_language,
	prh.title,
	prh.caption AS piece_received,
	ll.library_name,
	ll.location_name,
	prh.receiving_note,
	prh.receiving_status,
	popo.workflow_status
FROM
	po_receiving_history prh
LEFT JOIN folio_reporting.locations_libraries ll 
        ON
	prh.location_id = ll.location_id
LEFT JOIN po_purchase_orders AS popo 
        ON
	substring (prh.po_line_number,
	'^\d{0,}[a-zA-Z]{0,}\d{1,}[a-z]{0,}') = popo.po_number
LEFT JOIN local_core.po_instance AS poi 
        ON
	prh.po_line_number = poi.po_line_number
LEFT JOIN folio_reporting.instance_languages AS il 
        ON
	poi.pol_instance_hrid = il.instance_hrid
WHERE
	prh.receiving_status = 'Received'
	AND prh.received_date >= (
	SELECT
		received_date_start
	FROM
		parameters)
	AND (il.language_ordinality = 1
		OR il.language_ordinality IS NULL)
	--and ll.library_name = 'Library Annex'
)

SELECT
	recs.todays_date,
	recs.fiscal_year_received,
	recs.primary_language,
	CASE
		WHEN recs.order_type IS NULL THEN 'Unknown order type'
		ELSE recs.order_type
	END AS order_type,
	recs.library_name,
	recs.location_name,
	CASE
		WHEN recs.library_name = 'Library Annex' THEN 'Library Annex'
		WHEN recs.location_name = 'serv,remo' THEN 'serv,remo'
		WHEN recs.location_name IS NULL THEN 'Unknown Library'
		ELSE 'Other libraries'
	END AS owning_library,
	count (recs.id) AS items_received
FROM
	recs
GROUP BY
	recs.todays_date,
	recs.fiscal_year_received,
	recs.primary_language,
	recs.order_type,
	recs.library_name,
	recs.location_name
ORDER BY
	fiscal_year_received,
	owning_library,
	location_name,
	primary_language  
;
