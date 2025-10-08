--MCR411
--Print serials with max payment date and last piece received 
--This query uses an input list of PO numbers providedby the report user to find serials that we get in print. 

-- 8-27-25: find serials that we get in print from input list of PO's
-- 8-29-25: removed receipt_status as a filter
-- 9-2-25: find OCLC numbers for instances; aggregate instances by OCLC number and link to final result
-- 9-24-25: use external list of po_numbers as data source for query; comment out Where conditions
-- 9-29-25: updated input list of PO's

--Query writer: Joanne LEary (jl41)
--Posted on: 10/8/25

-- 1. Get fund distribution from purchase order lines

WITH fundist AS 
(SELECT 
	po_line.id AS po_line_id,
	po_line.jsonb#>>'{poLineNumber}' AS po_line_number,
	purchase_order__t.id AS purchase_order_id,
	SPLIT_PART (po_line.jsonb#>>'{poLineNumber}','-',1) AS po_number,
	dist.jsonb#>>'{code}' AS fund_code,
	dist.jsonb#>>'{distributionType}' AS distribution_type,
	dist.jsonb#>>'{value}' AS distribution_pct_or_value

FROM folio_orders.po_line 
LEFT JOIN folio_orders.purchase_order__t
ON SPLIT_PART (po_line.jsonb#>>'{poLineNumber}','-',1) = purchase_order__t.po_number

CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (po_line.jsonb,'fundDistribution')) AS dist (jsonb)
),

-- 2. Get vendor account info

vendor_info AS 
(SELECT 
	po_line.jsonb#>>'{purchaseOrderId}' AS purchase_order_id,
	SPLIT_PART (po_line.jsonb#>>'{poLineNumber}','-',1) AS purchase_order_number,
	po_line.id AS po_line_id,
	po_line.jsonb#>>'{poLineNumber}' AS po_line_number,
	po_line.jsonb#>>'{titleOrPackage}' AS title_or_package,
	po_line.jsonb#>>'{instanceId}' AS instance_id,
	po_line.jsonb#>>'{orderFormat}' AS order_format,
	po_line.jsonb#>>'{vendorDetail,vendorAccount}' AS vendor_account_number,
	vendor.jsonb#>>'{refNumber}' AS vendor_reference_number

FROM folio_orders.po_line
CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(po_line.jsonb,'vendorDetail','referenceNumbers')) AS vendor (jsonb)
),

-- 3. Get most recent piece received AND date

recs AS 
(SELECT 
	pieces__t.po_line_id,
	titles__t.title,
	instance__t.hrid AS instance_t_hrid,
	titles__t.instance_id,
	MAX (pieces__t.received_date::timestamptz) AS date_last_received

FROM folio_orders.pieces__t
	LEFT JOIN folio_orders.po_line__t
	ON pieces__t.po_line_id = po_line__t.id
	
	LEFT JOIN folio_orders.titles__t 
	ON pieces__t.title_id = titles__t.id
	
	LEFT JOIN folio_derived.po_instance 
	ON titles__t.instance_id = po_instance.pol_instance_id
		AND pieces__t.po_line_id = po_instance.po_line_id
		
	LEFT JOIN folio_inventory.instance__t 
	ON titles__t.instance_id = instance__t.id

GROUP BY 
	pieces__t.po_line_id,
	titles__t.title,
	instance__t.hrid,
	titles__t.instance_id
),

recs2 AS 
(SELECT 
	recs.po_line_id,
	recs.title,
	recs.instance_id,
	recs.instance_t_hrid,
	pieces__t.receiving_status,
	recs.date_last_received::date,
	pieces__t.display_summary AS piece_most_recently_received

FROM recs 
	INNER JOIN folio_orders.pieces__t 
	ON recs.po_line_id = pieces__t.po_line_id
		AND recs.date_last_received = pieces__t.received_date::timestamptz
)

-- 4. Get other order and invoice informatiON based on the po_numbers from external data

SELECT DISTINCT
	jpi.po_number,
	polt.title_or_package,
	mode_of_issuance__t.name AS instance_mode_of_issuance,
	instance__t.hrid AS instance_hrid,
	instance__t.discovery_suppress AS instance_suppress,
	po_lines_locations.pol_location_name,
	polt.po_line_number,
	acquisition_method__t.value AS acquisition_method,
	(po_line.jsonb#>>'{metadata,createdDate}')::date AS po_line_created_date,
	(po_line.jsonb#>>'{metadata,updatedDate}')::date AS po_line_updated_date,
	STRING_AGG (DISTINCT vendor_info.vendor_reference_number,' | ') AS vendor_reference_number,
	polt.order_format,
	polt.receipt_status,
	polt.publisher,
	fundist.fund_code,
	STRING_AGG (DISTINCT 
		CONCAT (invoices__t.vendor_invoice_no,'-',invoice_lines__t.invoice_line_number),' | ') AS vendor_invoice_line_numbers,
	STRING_AGG (DISTINCT invoice_lines__t.comment,' | ') AS invoice_line_comments,
	STRING_AGG (DISTINCT invoice_lines__t.description,' | ') AS invoice_line_desciptions,
	expense_class__t.name AS expense_class,
	recs2.piece_most_recently_received,
	recs2.date_last_received,
	MAX (invoices__t.payment_date::date) AS most_recent_invoice_payment_date,
	MAX (fiscal_year__t.code) AS most_recent_fiscal_year_payment
	

FROM local_open.jl_poids_9_29_25 jpi 
	LEFT JOIN folio_orders.purchase_order__t 
	ON jpi.po_number = purchase_order__t.po_number
	
	LEFT JOIN folio_orders.po_line__t AS polt
	ON purchase_order__t.po_number = SPLIT_PART (polt.po_line_number,'-',1)

	LEFT JOIN vendor_info 
	ON polt.po_line_number = vendor_info.po_line_number
	
	LEFT JOIN folio_inventory.instance__t 
	ON polt.instance_id = instance__t.id
	
	LEFT JOIN folio_inventory.mode_of_issuance__t 
	ON instance__t.mode_of_issuance_id = mode_of_issuance__t.id
	
	LEFT JOIN folio_inventory.holdings_record__t  AS hrt 
	ON instance__t.id = hrt.instance_id
	
	LEFT JOIN folio_inventory.location__t 
	ON hrt.permanent_location_id = location__t.id
	
	LEFT JOIN folio_orders.po_line 
	ON polt.id = po_line.id
	
	LEFT JOIN folio_orders.acquisition_method__t
	ON polt.acquisition_method = acquisition_method__t.id 
	
	LEFT JOIN recs2 
	ON polt.id = recs2.po_line_id
	
	LEFT JOIN fundist 
	ON po_line.id = fundist.po_line_id
	
	LEFT JOIN folio_derived.po_lines_locations 
	ON polt.id = po_lines_locations.pol_id
	
	LEFT JOIN folio_invoice.invoice_lines__t 
	ON polt.id = invoice_lines__t.po_line_id
	
	LEFT JOIN folio_invoice.invoices__t 
	ON invoice_lines__t.invoice_id = invoices__t.id 
	
	LEFT JOIN folio_finance.transaction__t 
	ON invoice_lines__t.id = transaction__t.source_invoice_line_id
	
	LEFT JOIN folio_finance.expense_class__t 
	ON transaction__t.expense_class_id = expense_class__t.id
	
	LEFT JOIN folio_finance.fiscal_year__t 
	ON transaction__t.fiscal_year_id = fiscal_year__t.id
	
 
GROUP BY
	jpi.po_number,
	polt.title_or_package,
	instance__t.hrid,
	mode_of_issuance__t.name,
	instance__t.discovery_suppress,
	po_lines_locations.pol_location_name,
	polt.po_line_number,
	acquisition_method__t.value,
	(po_line.jsonb#>>'{metadata,createdDate}')::date,
	(po_line.jsonb#>>'{metadata,updatedDate}')::date,
	polt.order_format,
	polt.receipt_status,
	polt.publisher,
	fundist.fund_code,
	expense_class__t.name,
	recs2.piece_most_recently_received,
	recs2.date_last_received

ORDER BY title_or_package, fund_code
;

