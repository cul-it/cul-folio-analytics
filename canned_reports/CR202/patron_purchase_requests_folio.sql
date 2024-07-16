-- CR202 - This query finds purchase requests by fund code, location, library or fiscal Year, and shows requester information, number of days from request DATE to receipt DATE, and number of loans for that title (cannot get circulation information at item level)


WITH parameters AS 
(
SELECT
	''::VARCHAR AS fund_code_filter, --select a fund code or leave blank
	'%%'::VARCHAR AS location_filter, --select a location filter or leave blank
	'%%'::VARCHAR AS library_filter, --select a library filter or leave blank
	''::varchar AS fiscal_year_filter -- enter in format 'FY2023', 'FY2024', etc.
),

orders AS 

(
SELECT DISTINCT
    po_instance.pol_instance_hrid,
	he.holdings_hrid,
	po_instance.title,
	"is".subject,
	po_instance.created_date::DATE AS request_create_date,
	CASE 
		WHEN DATE_PART ('month',po_instance.created_date::DATE) > 6 
		THEN concat ('FY',DATE_PART ('year',po_instance.created_date::DATE)+1) 
		ELSE concat ('FY',DATE_PART ('year',po_instance.created_date::DATE)) 
		END AS fiscal_year,
	po_lines.receipt_date::DATE AS receipt_date,
	po_lines.receipt_date::DATE - po_instance.created_date::DATE AS days_til_filled,
	po_lines.receipt_status,
	po_instance.pol_location_name,
	STRING_AGG (DISTINCT po_instance.publisher,' |') AS publisher,
	he.permanent_location_name AS holdings_location,
	ll.library_name,
	he.call_number AS holdings_call_number,
	TRIM (CONCAT (TRIM(he.call_number_prefix),' ',TRIM (he.call_number),' ',TRIM (he.call_number_suffix))) AS whole_call_number,
	CASE
		WHEN he.call_number_type_name ILIKE '%Library of Congress%' 
		THEN SUBSTRING (he.call_number,'^([a-zA-z]{1,3})')
		ELSE ' - ' END AS lc_class,
	SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}') AS lc_class_number,
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
	invoice_lines.invoice_line_number,
	invoice_invoices.status as invoice_status,
	invoice_invoices.payment_date::DATE,
	ilfd.fund_name,
	ilfd.finance_fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total
	
FROM po_lines
	LEFT JOIN folio_reporting.po_instance 
	   	ON po_lines.po_line_number = po_instance.po_line_number
	LEFT JOIN folio_reporting.instance_subjects AS "is" 
	  	ON po_instance.pol_instance_id = "is".instance_id
	LEFT JOIN folio_reporting.holdings_ext AS he 
	   	ON po_instance.pol_instance_id = he.instance_id
	LEFT JOIN folio_reporting.locations_libraries ll 
	   	ON po_instance.pol_location_name = ll.location_name
	LEFT JOIN invoice_lines 
		ON po_lines.id = invoice_lines.po_line_id
	LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd
	    ON invoice_lines.id = ilfd.invoice_line_id
	LEFT JOIN invoice_invoices 
	    ON invoice_lines.invoice_id = invoice_invoices.id
WHERE
	(po_lines.requester NOTNULL OR po_lines.details__receiving_note NOTNULL)
	AND he.permanent_location_name = po_instance.pol_location_name
	AND invoice_lines.invoice_line_status ILIKE '%Paid%'
	AND (ilfd.finance_fund_code = (SELECT fund_code_filter FROM parameters) OR (SELECT fund_code_filter FROM parameters) = '')
	AND ("is".subject_ordinality = 1 OR "is".subject_ordinality IS NULL)
	AND (po_instance.pol_location_name ILIKE (SELECT location_filter FROM parameters) OR (SELECT location_filter FROM parameters) = '')
	AND (ll.library_name ILIKE (select library_filter FROM parameters) OR (SELECT library_filter FROM parameters) = '')
	
GROUP BY
	po_instance.pol_instance_hrid,
	he.holdings_hrid,
	po_instance.title,
	"is".subject,
	po_instance.created_date::DATE,
	CASE 
		WHEN DATE_PART ('month',po_instance.created_date::DATE) > 6 
		THEN concat ('FY',DATE_PART ('year',po_instance.created_date::DATE) + 1) 
		ELSE concat ('FY',DATE_PART ('year',po_instance.created_date::DATE)) 
		END,
	po_lines.receipt_date::DATE,
	po_lines.receipt_status,
	po_instance.pol_location_name,
	he.permanent_location_name,
	ll.library_name,
	he.call_number,
	TRIM (CONCAT (TRIM (he.call_number_prefix),' ',TRIM (he.call_number),' ',TRIM (he.call_number_suffix))),
	CASE
		WHEN he.call_number_type_name ILIKE '%Library of Congress%' 
		THEN SUBSTRING (he.call_number,'^([a-zA-z]{1,3})')
		ELSE ' - ' END,
	SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}'),
	po_lines.requester,
	po_lines.order_format,
	po_lines.po_line_number,
	CASE
		WHEN po_lines.rush = 'True' THEN 'Rush' ELSE '' END,
	invoice_lines.quantity,
	invoice_lines.invoice_line_status,
	invoice_invoices.vendor_invoice_no,
	invoice_lines.invoice_line_number,
	invoice_invoices.status,
	invoice_invoices.payment_date::DATE,
	ilfd.fund_name,
	ilfd.finance_fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total
),

circs_after_purch AS  
(
	SELECT
		instext.instance_hrid,
		COUNT (DISTINCT li.loan_id) AS circs_after_purchase
		
	FROM orders
		LEFT JOIN folio_reporting.instance_ext AS instext 
		    ON orders.pol_instance_hrid = instext.instance_hrid
		LEFT JOIN folio_reporting.holdings_ext AS he 
		    ON orders.holdings_hrid = he.holdings_hrid
		LEFT JOIN folio_reporting.item_ext AS ie 
		    ON he.holdings_id = ie.holdings_record_id
		LEFT JOIN folio_reporting.loans_items AS li 
		    ON ie.item_id = li.item_id
		    
	WHERE li.loan_date::DATE >= orders.receipt_date::DATE OR li.loan_id IS NULL
	
	GROUP BY
		instext.instance_hrid 
),

circs_overall AS  
(
	SELECT
		instext.instance_hrid,
		COUNT (distinct li.loan_id) AS circs_on_title_overall
		
	from orders
		LEFT JOIN folio_reporting.instance_ext AS instext 
		    ON orders.pol_instance_hrid = instext.instance_hrid
		LEFT JOIN folio_reporting.holdings_ext AS he 
		    ON orders.holdings_hrid = he.holdings_hrid
		LEFT JOIN folio_reporting.item_ext AS ie 
		    ON he.holdings_id = ie.holdings_record_id
		LEFT JOIN folio_reporting.loans_items AS li 
		    ON ie.item_id = li.item_id
	
	GROUP BY
		instext.instance_hrid 
),

main AS 
(
SELECT DISTINCT
    TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
	orders.pol_instance_hrid,
	orders.holdings_hrid,
	orders.title,
	orders.subject,
	orders.request_create_date,
	orders.fiscal_year,
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
	orders.requester,
	orders.order_format,
	orders.po_line_number,
	orders.rush,
	orders.quantity,
	orders.invoice_line_status,
	orders.vendor_invoice_no,
	orders.invoice_line_number,
	orders.invoice_status,
	orders.payment_date::DATE,
	orders.fund_name,
	orders.finance_fund_code,
	orders.fund_distribution_value,
	orders.invoice_line_total,
	circs_after_purch.circs_after_purchase,
	circs_overall.circs_on_title_overall
	
FROM orders
	INNER JOIN circs_overall 
    ON orders.pol_instance_hrid = circs_overall.instance_hrid
    
    LEFT JOIN circs_after_purch 
    ON orders.pol_instance_hrid = circs_after_purch.instance_hrid
    
WHERE ((orders.fiscal_year = (SELECT fiscal_year_filter FROM parameters)) OR ((SELECT fiscal_year_filter FROM parameters) = ''))
)

SELECT DISTINCT
    main.todays_date,
    main.fiscal_year,
	main.title,
	main.pol_instance_hrid,
	main.requester,
	main.library_name,
	main.holdings_loc AS location_name,
	main.subject,
	STRING_AGG (DISTINCT main.lc_class,' | ') AS lc_class,
	TRIM (TRAILING '.' FROM STRING_AGG (DISTINCT main.lc_class_number,' | ')) AS class_number,
	STRING_AGG (DISTINCT main.whole_call_number,' | ') AS call_number,
	STRING_AGG (DISTINCT main.request_create_date::varchar,' | ') AS date_requested,
	STRING_AGG (DISTINCT main.receipt_date::varchar,' | ') AS date_received,
	STRING_AGG (DISTINCT main.receipt_status,' | ') AS receipt_status,
	main.days_til_filled,
	main.po_line_number,
	main.vendor_invoice_no,
	main.invoice_line_number,
	main.invoice_status,
	main.payment_date::DATE,
	main.finance_fund_code,
	main.circs_on_title_overall,
	main.circs_after_purchase,
	main.quantity as copies_ordered,
	main.invoice_line_total::NUMERIC AS total_paid
FROM
	main
WHERE
	receipt_status != 'Cancelled'
	AND requester != '0'
	AND requester NOT LIKE '%n/a%'
	AND requester !='na'
	AND requester !='NA'
	AND requester NOT ILIKE 'no req%' 
	
GROUP BY
	main.todays_date,
	main.fiscal_year,
	main.title,
	main.pol_instance_hrid,
	main.requester,
	main.library_name,
	main.holdings_loc,
	main.subject,
	main.finance_fund_code,
	main.days_til_filled,
	main.po_line_number,
	main.vendor_invoice_no,
	main.invoice_line_number,
	main.invoice_status,
	main.payment_date::DATE,
	main.circs_on_title_overall,
	main.circs_after_purchase,
	main.quantity,
	main.invoice_line_total::NUMERIC

ORDER BY
	title,
	po_line_number,
	vendor_invoice_no,
	invoice_line_number,
	lc_class,
	class_number,
	subject
;
