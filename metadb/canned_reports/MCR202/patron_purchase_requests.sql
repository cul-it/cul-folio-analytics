-- DO NOT USE, QUERY WILL NOT RUN AS IS, IT IS UNDER REVIEW (3/5/2025)
-- MCR202
-- This query finds purchase requests by fund code, location, library or fiscal year AND shows requester information, number of days FROM request DATE to receipt DATE, AND number of loans for that title (cannot get circulatiON informatiON at item level)

--Query writer: Joanne Leary (jl41)
--Posted on: 7/16/24

WITH parameters AS 
(
SELECT
	''::VARCHAR AS fund_code_filter, --SELECT a fund code or leave blank
	'%%'::VARCHAR AS location_filter, --SELECT a locatiON filter or leave blank
	'%%'::VARCHAR AS library_filter, --SELECT a library filter or leave blank
	''::VARCHAR AS fiscal_year_filter -- enter in format 'FY2023', 'FY2024', etc.
),

po_instance AS
(SELECT DISTINCT 
    pot.manual_po AS manual_po,
    poltt.rush::boolean AS rush,
    poltt.requester AS requester,
    poltt.selector AS selector,
    pot.po_number AS po_number,
    pot.id AS po_number_id,
    poltt.po_line_number AS po_line_number,
    poltt.id AS po_line_id,
    ot.code AS vendor_code, ---vendor id CONNECT TO vendor name
    ut.username AS created_by_username,
    pot.workflow_status AS po_workflow_status,
    pot.approved::boolean AS status_approved,
    JSONB_EXTRACT_PATH_TEXT (po.jsonb, 'metadata', 'createdDate')::timestamptz AS created_date,  
    JSONB_EXTRACT_PATH_TEXT (cdt.value::jsonb, 'name') AS bill_to,
    JSONB_EXTRACT_PATH_TEXT (cdt2.value::jsonb, 'name') AS ship_to,
    poltt.instance_id AS pol_instance_id,
    it.hrid AS pol_instance_hrid,
    JSONB_EXTRACT_PATH_TEXT (locations.jsonb, 'holdingId')::UUID AS pol_holding_id,
    JSONB_EXTRACT_PATH_TEXT (locations.jsonb,'locationId')::UUID AS pol_location_id,     
    COALESCE (lot.name, lot2.name,'deleted_holding') AS pol_location_name,
    CASE 
        WHEN lot.name IS NULL AND lot2.name IS NULL THEN 'no source'
        WHEN lot.name IS NULL AND lot2.name IS NOT NULL THEN 'pol_holding'
        WHEN lot.name IS NOT NULL AND lot2.name IS NULL THEN 'pol_location'
        ELSE 'x' END AS pol_location_source,    -- there are none 
    it.title AS title,
    poltt.publication_date AS publication_date,
    poltt.publisher AS publisher
    FROM folio_orders.po_line AS pol
    CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS((pol.jsonb #> '{locations}')::jsonb) AS locations (data)
    LEFT JOIN folio_orders.po_line__t AS poltt ON pol.id = poltt.id
    LEFT JOIN folio_inventory.instance__t AS it ON poltt.instance_id = it.id
    LEFT JOIN folio_inventory.location__t AS lot ON (locations.jsonb #>> '{locationId}')::UUID = lot.id
    LEFT JOIN folio_orders.purchase_order__t pot ON pol.purchaseorderid = pot.id 
    LEFT JOIN folio_inventory.holdings_record__t AS ih ON JSONB_EXTRACT_PATH_TEXT (locations.jsonb, 'holdingId')::UUID = ih.id
    LEFT JOIN folio_inventory.location__t AS lot2 ON ih.permanent_location_id = lot2.id 
    LEFT JOIN folio_organizations.organizations__t AS ot ON pot.vendor = ot.id
    LEFT JOIN folio_orders.purchase_order AS po ON pot.id = po.id
    LEFT JOIN folio_configuration.config_data__t AS cdt ON JSONB_EXTRACT_PATH_TEXT (po.jsonb, 'billTo')::UUID = cdt.id
    LEFT JOIN folio_configuration.config_data__t AS cdt2 ON JSONB_EXTRACT_PATH_TEXT (po.jsonb, 'shipTo')::UUID = cdt2.id
    LEFT JOIN folio_users.users__t AS ut ON JSONB_EXTRACT_PATH_TEXT (po.jsonb, 'metadata', 'createdByUserId')::UUID = ut.id
),

instance_subjects AS 
	(SELECT
	       instances.id AS instance_id,
	       JSONB_EXTRACT_PATH_TEXT  (jsonb,'hrid') AS instance_hrid,
	       subjects.data #>> '{value}' AS subject,
	       subjects.ordinality AS subjects_ordinality
	FROM
	       folio_inventory.instance__ AS instances
	CROSS JOIN JSONB_ARRAY_ELEMENTS((instances.jsonb #> '{subjects}')::jsonb)
	WITH ORDINALITY AS subjects (data)
	
	WHERE instances.__current = 'true'
),

orders AS 
(SELECT DISTINCT
    po_instance.pol_instance_hrid,
	he.holdings_hrid,
	po_instance.title,
	"is".subject,
	po_instance.created_date::DATE AS request_create_date,
	CASE 
		WHEN DATE_PART ('month',po_instance.created_date::DATE) > 6 
		THEN CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)+1) 
		ELSE CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)) 
		END AS fiscal_year,
	po_line__t.receipt_date::DATE AS receipt_date, --po_lines.receipt_date::DATE AS receipt_date,
	po_line__t.receipt_date::DATE - po_instance.created_date::DATE AS days_til_filled, --po_lines.receipt_date::DATE - po_instance.created_date::DATE AS days_til_filled,
	po_line__t.receipt_status,--po_lines.receipt_status,
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
	po_line__t.requester, --po_lines.requester,
	JSONB_EXTRACT_PATH_TEXT  (jsonb,'details','receivingNote') AS receiving_note,
	po_line__t.order_format, --po_lines.order_format,
	po_line__t.po_line_number, --po_lines.po_line_number,
	CASE
		WHEN po_line__t.rush = 'true' THEN 'Rush' -- WHEN po_lines.rush = 'True' THEN 'Rush'
		ELSE '' END AS rush,
	invoice_lines__t.quantity, --invoice_lines.quantity,
	invoice_lines__t.invoice_line_status, --invoice_lines.invoice_line_status,
	invoices__t.vendor_invoice_no, --invoice_invoices.vendor_invoice_no,
	invoice_lines__t.invoice_line_number, --invoice_lines.invoice_line_number,
	invoices__t.status AS invoice_status, --invoice_invoices.status AS invoice_status,
	invoices__t.payment_date::DATE, --invoice_invoices.payment_date::DATE,
	ilfd.fund_name,
	ilfd.fund_code AS finance_fund_code, --ilfd.finance_fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total
	
FROM folio_orders.po_line__t --po_lines
	LEFT JOIN folio_orders.po_line__ 
	ON po_line__t.id = po_line__.id
	
	LEFT JOIN po_instance --LEFT JOIN folio_reporting.po_instance --local.po_instance
	   ON po_line__t.po_line_number = po_instance.po_line_number	--ON po_lines.po_line_number = po_instance.po_line_number
	LEFT JOIN instance_subjects AS "is" --LEFT JOIN folio_reporting.instance_subjects AS "is" 
	  	ON po_instance.pol_instance_id = "is".instance_id --ON po_instance.pol_instance_id = "is".instance_id
	LEFT JOIN folio_derived.holdings_ext AS he --LEFT JOIN folio_reporting.holdings_ext AS he 
	   	ON po_instance.pol_instance_id = he.instance_id --ON po_instance.pol_instance_id = he.instance_id
	LEFT JOIN folio_derived.locations_libraries AS ll --LEFT JOIN folio_reporting.locations_libraries ll 
	   	ON po_instance.pol_location_name = ll.location_name --ON po_instance.pol_location_name = ll.location_name
	LEFT JOIN folio_invoice.invoice_lines__t --LEFT JOIN invoice_lines 
		ON po_line__t.id = invoice_lines__t.po_line_id --ON po_lines.id = invoice_lines.po_line_id
	LEFT JOIN folio_derived.invoice_lines_fund_distributions AS ilfd --LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd
	    ON invoice_lines__t.id = ilfd.invoice_line_id --ON invoice_lines.id = ilfd.invoice_line_id
	LEFT JOIN folio_invoice.invoices__t -- LEFT JOIN invoice_invoices 
	    ON invoice_lines__t.invoice_id = invoices__t.id --ON invoice_lines.invoice_id = invoice_invoices.id
WHERE
	(po_line__t.requester notnull or (JSONB_EXTRACT_PATH_TEXT  (jsonb,'details','receivingNote') NOTNULL AND po_line__.__current = 'true')) --(po_lines.requester notnull or po_lines.details__receiving_note notnull)
	
	AND he.permanent_location_name = po_instance.pol_location_name
	AND invoice_lines__t.invoice_line_status ILIKE '%Paid%'--invoice_lines.invoice_line_status ILIKE '%Paid%'
	AND (ilfd.fund_code = (SELECT fund_code_filter FROM parameters) OR (SELECT fund_code_filter FROM parameters) = '')
	AND ("is".subjects_ordinality = 1 OR "is".subjects_ordinality IS NULL)
	AND (po_instance.pol_location_name ILIKE (SELECT location_filter FROM parameters) OR (SELECT location_filter FROM parameters) = '')
	AND ((ll.library_name ILIKE (SELECT library_filter FROM parameters) OR (SELECT library_filter FROM parameters) = ''))
      
	
GROUP BY
	po_instance.pol_instance_hrid,
	he.holdings_hrid,
	po_instance.title,
	"is".subject,
	po_instance.created_date::DATE,
	CASE 
		WHEN DATE_PART ('month',po_instance.created_date::DATE) > 6 
		THEN CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)+1) 
		ELSE CONCAT ('FY',DATE_PART ('year',po_instance.created_date::DATE)) 
		END,
	po_line__t.receipt_date::DATE, --po_lines.receipt_date::DATE,
	po_line__t.receipt_status, --po_lines.receipt_status,
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
	po_line__t.requester, --po_lines.requester,
	JSONB_EXTRACT_PATH_TEXT (jsonb,'details','receivingNote'),
	po_line__t.order_format, --po_lines.order_format,
	po_line__t.po_line_number, --po_lines.po_line_number,
	CASE
		WHEN po_line__t.rush = 'true' 
		THEN 'Rush' 
		ELSE '' END, --po_lines.rush = 'True' THEN 'Rush' ELSE '' END,
	invoice_lines__t.quantity, --invoice_lines.quantity,
	invoice_lines__t.invoice_line_status, --invoice_lines.invoice_line_status,
	invoices__t.vendor_invoice_no, --invoice_invoices.vendor_invoice_no,
	invoice_lines__t.invoice_line_number, -- invoice_lines.invoice_line_number,
	invoices__t.status, --invoice_invoices.status,
	invoices__t.payment_date::DATE, --invoice_invoices.payment_date::DATE,
	ilfd.fund_name,
	ilfd.fund_code,--ilfd.finance_fund_code,
	ilfd.fund_distribution_value,
	ilfd.invoice_line_total
),

circs_after_purch AS  
(
	SELECT
		instext.instance_hrid,
		COUNT (DISTINCT li.loan_id) AS circs_after_purchase
		
	FROM orders
		LEFT JOIN folio_derived.instance_ext AS instext--folio_reporting.instance_ext AS instext 
		    ON orders.pol_instance_hrid = instext.instance_hrid
		LEFT JOIN folio_derived.holdings_ext AS he ---folio_reporting.holdings_ext AS he 
		    ON orders.holdings_hrid = he.holdings_hrid
		LEFT JOIN folio_derived.item_ext AS ie --folio_reporting.item_ext AS ie 
		    ON he.holdings_id = ie.holdings_record_id
		LEFT JOIN folio_derived.loans_items AS li --folio_reporting.loans_items AS li 
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
		LEFT JOIN folio_derived.instance_ext AS instext --folio_reporting.instance_ext AS instext 
		    ON orders.pol_instance_hrid = instext.instance_hrid
		LEFT JOIN folio_derived.holdings_ext AS he --folio_reporting.holdings_ext AS he 
		    ON orders.holdings_hrid = he.holdings_hrid
		LEFT JOIN folio_derived.item_ext AS ie --folio_reporting.item_ext AS ie 
		    ON he.holdings_id = ie.holdings_record_id
		LEFT JOIN folio_derived.loans_items AS li --folio_reporting.loans_items AS li 
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
	main.quantity AS copies_ordered,
	main.invoice_line_total::NUMERIC AS total_paid
	
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
	main.invoice_line_total::numeric
	
ORDER BY
	title,
	po_line_number,
	vendor_invoice_no,
	invoice_line_number,
	lc_class,
	class_number,
	subject
;
