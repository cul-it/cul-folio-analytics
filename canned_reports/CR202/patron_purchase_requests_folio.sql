--CR202
--patron_purchase_requests_folio.sql


WITH parameters AS 
(
SELECT
	''::VARCHAR AS fund_code_filter,
	--select a fund code or leave blank
'%%'::VARCHAR AS location_filter,
	--select a location filter or leave blank
'%%'::VARCHAR AS library_filter
	--select a library filter or leave blank
),

orders AS 

(
SELECT
	DISTINCT
        po_instance.pol_instance_hrid,
	he.holdings_hrid,
	po_instance.title,
	"is".subject,
	po_instance.created_date::date AS request_create_date,
	po_lines.receipt_date::date AS receipt_date,
	po_lines.receipt_date::date - po_instance.created_date::date AS days_til_filled,
	--TO_CHAR (po_instance.created_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') AS request_create_date,
	--TO_CHAR (po_lines.receipt_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') AS receipt_date,
	po_lines.receipt_status,
	po_instance.pol_location_name,
	STRING_AGG (DISTINCT po_instance.publisher,
	' |') AS publisher,
	he.permanent_location_name AS holdings_location,
	ll.library_name,
	he.call_number AS holdings_call_number,
	TRIM (CONCAT (trim(he.call_number_prefix),
	' ',
	trim (he.call_number),
	' ',
	trim (he.call_number_suffix))) AS whole_call_number,
	CASE
		WHEN he.call_number_type_name ILIKE '%Library of Congress%' THEN SUBSTRING (he.call_number,
		'^([a-zA-z]{1,3})')
		ELSE ' - '
	END AS lc_class,
	SUBSTRING (he.call_number,
	'\d{1,}\.{0,}\d{0,}') AS lc_class_number,
	po_lines.requester,
	po_lines.order_format,
	po_lines.po_line_number,
	CASE
		WHEN po_lines.rush = 'True' THEN 'Rush'
		ELSE ''
	END AS rush,
	invoice_lines.quantity,
	invoice_lines.invoice_line_status,
	invoice_invoices.vendor_invoice_no,
	ilfd.fund_name,
	ilfd.finance_fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total
FROM
	po_lines
LEFT JOIN local.po_instance 
        ON
	po_lines.po_line_number = po_instance.po_line_number
LEFT JOIN folio_reporting.instance_subjects AS "is" 
        ON
	po_instance.pol_instance_id = "is".instance_id
LEFT JOIN folio_reporting.holdings_ext AS he 
        ON
	po_instance.pol_instance_id = he.instance_id
LEFT JOIN folio_reporting.locations_libraries ll 
        ON
	po_instance.pol_location_name = ll.location_name
LEFT JOIN invoice_lines 
        ON
	po_lines.id = invoice_lines.po_line_id
LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd
        ON
	invoice_lines.id = ilfd.invoice_line_id
LEFT JOIN invoice_invoices 
        ON
	invoice_lines.invoice_id = invoice_invoices.id
WHERE
	po_lines.requester NOTNULL
	AND he.permanent_location_name = po_instance.pol_location_name
	AND invoice_lines.invoice_line_status ILIKE '%Paid%'
	AND (ilfd.finance_fund_code = (
	SELECT
		fund_code_filter
	FROM
		parameters)
	OR (
	SELECT
		fund_code_filter
	FROM
		parameters) = '')
	AND ("is".subject_ordinality = 1
		OR "is".subject_ordinality IS NULL)
	AND (po_instance.pol_location_name ILIKE (
	SELECT
		location_filter
	FROM
		parameters)
	OR (
	SELECT
		location_filter
	FROM
		parameters) = '')
	AND (ll.library_name ILIKE (
	SELECT
		library_filter
	FROM
		parameters)
	OR (
	SELECT
		library_filter
	FROM
		parameters) = '')
	--and po_lines.receipt_date > '2022-08-01'        
GROUP BY
	po_instance.pol_instance_hrid,
	he.holdings_hrid,
	po_instance.title,
	"is".subject,
	po_instance.created_date::date,
	po_lines.receipt_date::date,
	--TO_CHAR (po_instance.created_date::TIMESTAMP,'mm/dd/yyyy hh:mi am'),
	--TO_CHAR (po_lines.receipt_date::TIMESTAMP,'mm/dd/yyyy hh:mi am'),
	po_lines.receipt_status,
	po_instance.pol_location_name,
	he.permanent_location_name,
	ll.library_name,
	he.call_number,
	TRIM (CONCAT (trim (he.call_number_prefix),
	' ',
	trim (he.call_number),
	' ',
	trim (he.call_number_suffix))),
	CASE
		WHEN he.call_number_type_name ILIKE '%Library of Congress%' THEN SUBSTRING (he.call_number,
		'^([a-zA-z]{1,3})')
		ELSE ' - '
	END,
	SUBSTRING (he.call_number,
	'\d{1,}\.{0,}\d{0,}'),
	po_lines.requester,
	po_lines.order_format,
	po_lines.po_line_number,
	CASE
		WHEN po_lines.rush = 'True' THEN 'Rush'
		ELSE ''
	END,
	invoice_lines.quantity,
	invoice_lines.invoice_line_status,
	invoice_invoices.vendor_invoice_no,
	ilfd.fund_name,
	ilfd.finance_fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total
),

circs AS  
(
SELECT
	instext.instance_hrid,
	STRING_AGG (DISTINCT ie.material_type_name,
	' | ') AS material_type,
	COUNT (li.loan_id) AS total_circs_in_folio
FROM
	orders
LEFT JOIN folio_reporting.instance_ext AS instext 
        ON
	orders.pol_instance_hrid = instext.instance_hrid
LEFT JOIN folio_reporting.holdings_ext AS he 
        ON
	orders.holdings_hrid = he.holdings_hrid
LEFT JOIN folio_reporting.item_ext AS ie 
        ON
	he.holdings_id = ie.holdings_record_id
LEFT JOIN folio_reporting.loans_items AS li 
        ON
	ie.item_id = li.item_id
GROUP BY
	instext.instance_hrid
),

main AS 
(
SELECT
	DISTINCT
        TO_CHAR (CURRENT_DATE::DATE,
	'mm/dd/yyyy') AS todays_date,
	orders.pol_instance_hrid,
	orders.holdings_hrid,
	orders.title,
	orders.subject,
	orders.request_create_date,
	orders.receipt_date,
	orders.days_til_filled,
	orders.receipt_status,
	orders.library_name,
	CASE
		WHEN orders.pol_location_name IS NULL THEN orders.holdings_location
		ELSE orders.pol_location_name
	END AS holdings_loc,
	orders.holdings_call_number,
	orders.whole_call_number,
	orders.lc_class,
	orders.lc_class_number,
	orders.publisher,
	circs.material_type,
	orders.requester,
	orders.order_format,
	orders.po_line_number,
	orders.rush,
	orders.quantity,
	orders.invoice_line_status,
	orders.vendor_invoice_no,
	orders.fund_name,
	orders.finance_fund_code,
	orders.fund_distribution_value,
	orders.invoice_line_total,
	circs.total_circs_in_folio
FROM
	orders
INNER JOIN circs 
        ON
	orders.pol_instance_hrid = circs.instance_hrid
)

SELECT
	DISTINCT
        main.todays_date,
	main.title,
	main.pol_instance_hrid,
	main.requester,
	main.subject,
	string_agg (DISTINCT main.lc_class,
	' | ') AS lc_class,
	string_agg (DISTINCT main.lc_class_number,
	' | ') AS class_number,
	string_agg (DISTINCT main.whole_call_number,
	' | ') AS call_number,
	string_agg (DISTINCT main.request_create_date::varchar,
	' | ') AS date_requested,
	string_agg (DISTINCT main.receipt_date::varchar,
	' | ') AS date_received,
	string_agg (DISTINCT main.receipt_status,
	' | ') AS receipt_status,
	main.days_til_filled,
	--main.vendor_invoice_no,
	main.finance_fund_code,
	--main.fund_distribution_value,
	main.total_circs_in_folio,
	sum (main.invoice_line_total::NUMERIC) AS total_paid
FROM
	main
WHERE
	receipt_status != 'Cancelled'
	AND requester != '0'
	AND requester NOT LIKE '%n/a%'
GROUP BY
	main.todays_date,
	main.title,
	main.pol_instance_hrid,
	main.requester,
	main.subject,
	main.finance_fund_code,
	main.days_til_filled,
	--main.vendor_invoice_no,
	--main.invoice_line_total,
	--main.fund_distribution_value,
	main.total_circs_in_folio
ORDER BY
	title,
	lc_class,
	class_number,
	subject
;

