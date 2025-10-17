-- MCR202 - patron purchase requests by fund code - revised 10-16-25
-- This query finds purchase requests by fund code, location, library or fiscal year AND shows requester information, number of days FROM request DATE to receipt DATE, AND number of loans for that title (cannot get circulatiON informatiON at item level)

--Query writer: Joanne Leary (jl41)
--Posted on: 7/16/24
-- 9-26-25 - fixed by eliminating null joins for instance ids; updated LC class extract (still not perfect)
-- 10-15-25: corrected total paid calculation (depends on fund_distribution_type, which was not accounted for previously -- see line 124) and lc_class_number
	-- sorting by title doesn't work for some reason - DBeaver deletes spaces between words and sorts the remaining characters alphabetically
-- 10-16-25: deleted po_instance derivation and instance_subjects derivation; replaced with derived tables; deleted reference to receiving note; 
	-- coalesced title occurrences (instance index title, instance title, po_instance title)

WITH parameters AS 
(
SELECT
	''::VARCHAR AS fund_code_filter, --SELECT a fund code or leave blank
	'%%'::VARCHAR AS location_filter, --SELECT a locatiON filter or leave blank
	'%%'::VARCHAR AS library_filter, --SELECT a library filter or leave blank
	'FY2025'::VARCHAR AS fiscal_year_filter -- enter in format 'FY2023', 'FY2024', etc. lc_class
),

orders AS 
(SELECT DISTINCT
    po_instance.pol_instance_hrid,
	he.holdings_hrid,
	coalesce (instext.index_title, instext.title, po_instance.title) as title,
	"is".subjects,
	po_instance.created_date::DATE AS request_create_date,
	CASE 
		WHEN DATE_PART ('month',po_instance.created_date::DATE) > 6 
		THEN CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)+1) 
		ELSE CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)) 
		END AS fiscal_year,
	po_line__t.receipt_date::DATE AS receipt_date, 
	po_line__t.receipt_date::DATE - po_instance.created_date::DATE AS days_til_filled, 
	po_line__t.receipt_status,
	po_instance.pol_location_name,
	STRING_AGG (DISTINCT po_instance.publisher,' |') AS publisher,
	he.permanent_location_name AS holdings_location,
	ll.library_name,
	he.call_number AS holdings_call_number,
	TRIM (CONCAT (TRIM (he.call_number_prefix),' ',TRIM (he.call_number),' ',TRIM (he.call_number_suffix))) AS whole_call_number,
	CASE
		WHEN he.call_number_type_name ='Library of Congress classification'
		THEN SUBSTRING (he.call_number,'^[A-Z]{1,3}')
		ELSE '-' END AS lc_class,
	CASE
		WHEN he.call_number_type_name ='Library of Congress classification'
		then SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}') 
		else '' end AS lc_class_number,
	po_line__t.requester,
	po_line__t.order_format, 
	po_line__t.po_line_number,
	CASE
		WHEN po_line__t.rush = 'true' THEN 'Rush' 
		ELSE '' END AS rush,
	invoice_lines__t.quantity, 
	invoice_lines__t.invoice_line_status, 
	invoices__t.vendor_invoice_no, 
	invoice_lines__t.invoice_line_number, 
	invoices__t.status AS invoice_status, 
	invoices__t.payment_date::DATE, 
	ilfd.fund_name,
	ilfd.fund_code AS finance_fund_code, 
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total,
	case when ilfd.fund_distribution_type = 'amount' then ilfd.fund_distribution_value else ilfd.invoice_line_total end as cost
	
FROM folio_orders.po_line__t 
	LEFT JOIN folio_orders.po_line 
		ON po_line__t.id = po_line.id	
	LEFT JOIN folio_derived.po_instance
	    ON po_line__t.po_line_number = po_instance.po_line_number	
	LEFT JOIN folio_derived.instance_subjects as "is"  
	  	ON coalesce (po_instance.pol_instance_id::varchar,'') = "is".instance_id::varchar 
	LEFT JOIN folio_derived.holdings_ext AS he  
	   	ON coalesce (po_instance.pol_instance_id::varchar,'') = he.instance_id::varchar  
	LEFT JOIN folio_derived.instance_ext AS instext 
		ON he.instance_id = instext.instance_id
	LEFT JOIN folio_derived.locations_libraries AS ll  
	   	ON po_instance.pol_location_name = ll.location_name 
	LEFT JOIN folio_invoice.invoice_lines__t  
		ON po_line__t.id = invoice_lines__t.po_line_id 
	LEFT JOIN folio_derived.invoice_lines_fund_distributions AS ilfd
	    ON invoice_lines__t.id = ilfd.invoice_line_id
	LEFT JOIN folio_invoice.invoices__t 
	    ON invoice_lines__t.invoice_id = invoices__t.id 
WHERE
	po_line__t.requester notnull 
	AND he.permanent_location_name = po_instance.pol_location_name
	AND invoice_lines__t.invoice_line_status ILIKE '%Paid%'
	AND (ilfd.fund_code = (SELECT fund_code_filter FROM parameters) OR (SELECT fund_code_filter FROM parameters) = '')
	AND ("is".subjects_ordinality = 1 OR "is".subjects_ordinality IS NULL)
	AND (po_instance.pol_location_name ILIKE (SELECT location_filter FROM parameters) OR (SELECT location_filter FROM parameters) = '')
	AND (ll.library_name ILIKE (SELECT library_filter FROM parameters) OR (SELECT library_filter FROM parameters) = '')
      
	
GROUP BY
	po_instance.pol_instance_hrid,
	he.holdings_hrid,
	coalesce (instext.index_title, instext.title, po_instance.title),
	"is".subjects,
	po_instance.created_date::DATE,
	CASE 
		WHEN DATE_PART ('month',po_instance.created_date::DATE) > 6 
		THEN CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)+1) 
		ELSE CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)) 
		END,
	po_line__t.receipt_date::DATE, 
	po_line__t.receipt_status, 
	po_instance.pol_location_name,
	he.permanent_location_name,
	ll.library_name,
	he.call_number,
	TRIM (CONCAT (TRIM (he.call_number_prefix),' ',TRIM (he.call_number),' ',TRIM (he.call_number_suffix))),
	CASE
		WHEN he.call_number_type_name ='Library of Congress classification'
		THEN SUBSTRING (he.call_number,'^[A-Z]{1,3}')
		ELSE '-' END,
	CASE
		WHEN he.call_number_type_name ='Library of Congress classification'
		then SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}') 
		else '' end,
	po_line__t.requester, 
	po_line__t.order_format, 
	po_line__t.po_line_number, 
	CASE
		WHEN po_line__t.rush = 'true' 
		THEN 'Rush' 
		ELSE '' END, 
	invoice_lines__t.quantity,
	invoice_lines__t.invoice_line_status,
	invoices__t.vendor_invoice_no,
	invoice_lines__t.invoice_line_number,
	invoices__t.status,
	invoices__t.payment_date::DATE,
	ilfd.fund_name,
	ilfd.fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total,
	CASE WHEN ilfd.fund_distribution_type = 'amount' THEN ilfd.fund_distribution_value ELSE ilfd.invoice_line_total END
),

circs_after_purch AS  
(
	SELECT
		instext.instance_hrid,
		COUNT (DISTINCT li.loan_id) AS circs_after_purchase
		
	FROM orders
		LEFT JOIN folio_derived.instance_ext AS instext 
		    ON orders.pol_instance_hrid = instext.instance_hrid
		LEFT JOIN folio_derived.holdings_ext AS he  
		    ON orders.holdings_hrid = he.holdings_hrid
		LEFT JOIN folio_derived.item_ext AS ie  
		    ON he.id = ie.holdings_record_id
		LEFT JOIN folio_derived.loans_items AS li 
		    ON ie.item_id = li.item_id
		    
	WHERE li.loan_date::DATE >= orders.receipt_date::DATE or li.loan_id IS NULL
	
	GROUP BY
		instext.instance_hrid 
),

circs_overall AS  
(
	SELECT
		instext.instance_hrid,
		COUNT (DISTINCT li.loan_id) AS circs_on_title_overall
		
	FROM orders
		LEFT JOIN folio_derived.instance_ext AS instext  
		    ON coalesce (orders.pol_instance_hrid,'-') = instext.instance_hrid
		LEFT JOIN folio_derived.holdings_ext AS he  
		    ON orders.holdings_hrid = he.holdings_hrid
		LEFT JOIN folio_derived.item_ext AS ie  
		    ON he.id = ie.holdings_record_id
		LEFT JOIN folio_derived.loans_items AS li  
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
	orders.subjects,
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
	orders.cost,
	circs_after_purch.circs_after_purchase,
	circs_overall.circs_on_title_overall
	
FROM orders
	INNER JOIN circs_overall 
    ON coalesce (orders.pol_instance_hrid,'-') = circs_overall.instance_hrid
    
    LEFT JOIN circs_after_purch 
    ON coalesce (orders.pol_instance_hrid,'-') = circs_after_purch.instance_hrid
    
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
	main.subjects,
	trim (' | ' from trim ('-' from STRING_AGG (DISTINCT main.lc_class,' | '))) AS lc_class,
	trim (' | ' from TRIM (TRAILING '.' FROM STRING_AGG (DISTINCT main.lc_class_number,' | '))) AS class_number,
	trim (' | ' from STRING_AGG (DISTINCT main.whole_call_number,' | ')) AS call_number,
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
	main.quantity AS copies_ordered,
	main.cost as total_paid
	
FROM
	main
	
WHERE
	receipt_status != 'Cancelled'
	AND requester != '0'
	AND requester NOT LIKE '%n/a%'
	AND requester !='na'
	AND requester !='NA'
	AND requester not ILIKE 'no req%' 
	
GROUP BY
	main.todays_date,
	main.fiscal_year,
	main.title,
	main.pol_instance_hrid,
	main.requester,
	main.library_name,
	main.holdings_loc,
	main.subjects,
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
	main.cost
	
ORDER BY
	title,
	po_line_number,
	vendor_invoice_no,
	invoice_line_number,
	lc_class,
	class_number,
	subjects
;
