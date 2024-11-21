--MCR213 
--current_encumbrances
--last updated: 11-21-24
--query written by Nancy Bolduc, updated to Metadb by Joanne Leary, and reviewed by Sharon Markus and Ann Crowley
--This query finds current encumbrances by fund and fiscal year. It also shows titles and locations.
--NOTE: As of 6/21/23, Fully Paid orders may still have a current encumbrance; this is a system issue to be fixed.
--11-19-24: converted to Metadb
--11-21-24: corrected "order type" extraction and updated po_instance to vs_po_instance

WITH parameters AS (
    SELECT
        ''::VARCHAR AS fiscal_year_code, -- e.g., FY2025
        ''::VARCHAR AS fund_code
),

po_instance as -- use this subquery for po_instance as a substitute for using the local_shared.po_instance table or the folio_derived.po_instance (which is wrong as of 11-19-24)
(-- 9-19-24: this is a revision of the po_instance Metadb derived table

SELECT DISTINCT	
	po_line.purchaseorderid as po_number_id,
	purchase_order__t.po_number,	
	po_line.id AS po_line_id,
	JSONB_EXTRACT_PATH_TEXT (po_line.JSONB,'poLineNumber') AS po_line_number,
	(JSONB_EXTRACT_PATH_TEXT (po_line.JSONB,'instanceId'))::UUID AS pol_instance_id,
	instance__t.hrid AS pol_instance_hrid,
	po_line__t.title_or_package AS title,
	COALESCE (location__t.name, location__t2.name) AS location_name,
	CASE 
		WHEN location__t.name IS NOT NULL then 'pol_location'
		WHEN location__t2.name IS NOT NULL then 'holdings_location'
		ELSE 'no_source' END AS pol_location_source,
	po_line__t.publication_date,
	po_line__t.publisher,
	organizations__t.code AS vendor_code,
	purchase_order__t.manual_po::BOOLEAN,
	purchase_order__t.order_type,-- new	
	JSONB_EXTRACT_PATH_TEXT (po_line.JSONB,'paymentStatus') AS payment_status,--new
	JSONB_EXTRACT_PATH_TEXT (po_line.JSONB,'receiptStatus') AS receipt_status,--new	
	po_line__t.rush,
	po_line__t.requester,
	po_line__t.selector,  
    purchase_order__t.workflow_status AS po_workflow_status,
    purchase_order__t.approved::BOOLEAN AS status_approved,
    users__t.username AS po_created_by,
    JSONB_EXTRACT_PATH_TEXT (purchase_order.JSONB, 'metadata', 'createdDate')::TIMESTAMPTZ AS po_created_date, 
    users__t2.username as po_updated_by, -- new
    JSONB_EXTRACT_PATH_TEXT (purchase_order.JSONB, 'metadata', 'updatedDate')::TIMESTAMPTZ AS po_updated_date, -- new
    JSONB_EXTRACT_PATH_TEXT (cdt.value::JSONB, 'name') AS bill_to,
    JSONB_EXTRACT_PATH_TEXT (cdt2.value::JSONB, 'name') AS ship_to,	 
	(locations.JSONB #>> '{locationId}')::UUID AS pol_location_id,
	location__t.name AS pol_location_name,
	(locations.JSONB #>> '{holdingId}')::UUID AS pol_holding_id,
	location__t2.name AS holdings_location_name--new
	
FROM folio_orders.po_line
    CROSS JOIN LATERAL JSONB_ARRAY_ELEMENTS((po_line.JSONB #> '{locations}')::JSONB) AS locations (data)
    
    LEFT JOIN folio_orders.purchase_order__t 
	ON po_line.purchaseorderid = purchase_order__t.id 
	
	LEFT JOIN folio_orders.po_line__t 
	ON po_line.id = po_line__t.id
		
	LEFT JOIN folio_organizations.organizations__t 
	ON purchase_order__t.vendor = organizations__t.id
	
	LEFT JOIN folio_orders.purchase_order 
	ON purchase_order__t.id = purchase_order.id
    
	LEFT JOIN folio_inventory.instance__t 
	ON (JSONB_EXTRACT_PATH_TEXT (po_line.JSONB,'instanceId'))::UUID = instance__t.id
	
	LEFT JOIN folio_inventory.holdings_record__t 
	ON (locations.JSONB #>> '{holdingId}')::UUID = holdings_record__t.id
	
	LEFT JOIN folio_inventory.location__t 
	ON (locations.JSONB #>> '{locationId}')::UUID = location__t.id
	
	LEFT JOIN folio_inventory.location__t AS location__t2 
	ON location__t2.id = holdings_record__t.permanent_location_id
	
	LEFT JOIN folio_configuration.config_data__t cdt 
	ON JSONB_EXTRACT_PATH_TEXT (purchase_order.JSONB, 'billTo')::UUID = cdt.id
	    
	LEFT JOIN folio_configuration.config_data__t cdt2 
	ON JSONB_EXTRACT_PATH_TEXT (purchase_order.JSONB, 'shipTo')::UUID = cdt2.id
	    
	LEFT JOIN folio_users.users__t 
	ON JSONB_EXTRACT_PATH_TEXT (purchase_order.JSONB, 'metadata', 'createdByUserId')::UUID = users__t.id
	
	LEFT JOIN folio_users.users__t as users__t2 
	ON JSONB_EXTRACT_PATH_TEXT (purchase_order.JSONB, 'metadata', 'updatedByUserId')::UUID = users__t2.id
)

SELECT DISTINCT
	fy.code AS fiscal_year_code,
 	ff.code AS transaction_from_fund_code,
 	jsonb_extract_path_text(ft.jsonb, 'transactionType') as transaction_type,
 	jsonb_extract_path_text(ft.jsonb, 'amount')::numeric(19, 4) AS current_encumbrance_transaction_amount,
    	--ft.amount::numeric AS current_encumbrance_transaction_amount,
 	jsonb_extract_path_text(ft.jsonb, 'currency') AS transaction_currency,
    	--ft.currency AS transaction_currency,
 	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'status') as encumbrance_status,
    	--ft.encumbrance__status AS encumbrance_status,
    	oo.name AS po_vendor_name,
    	pol.po_line_number AS pol_number,
    	jsonb_extract_path_text(ft.jsonb, 'metadata', 'createdDate')::timestamptz AS encumbrance_created_date,
    	--ft.metadata__created_date::DATE AS encumbrance_created_date,
    	pol.title_or_package AS title,
    	poi.location_name as pol_location_name,
		poi.pol_instance_hrid,
    	pol.payment_status, --note that Fully Paid orders may still have an encumbrance; this is a SYSTEM issue to be fixed
    	pol.description AS pol_description,
    	po.order_type AS po_order_type,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'amountAwaitingPayment')::numeric(19, 4) AS transaction_encumbrance_amount_awaiting_payment,
    	--ft. encumbrance__amount_awaiting_payment::numeric AS transaction_encumbrance_amount_awaiting_payment,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'amountExpended')::numeric(19, 4) AS transaction_encumbrance_amount_expended,
    	--ft. encumbrance__amount_expended::numeric AS transaction_encumbrance_amount_expended,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'initialAmountEncumbered')::numeric(19, 4) AS transaction_encumbrance_initial_amount,
    	--ft. encumbrance__initial_amount_encumbered::numeric AS transaction_encumbrance_initial_amount,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'orderStatus') AS encumbrance_order_status,
    	--ft.encumbrance__order_status AS encumbrance_order_status,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance','orderType') AS transaction_encumbrance_order_type,
    	--ft.encumbrance__order_type AS transaction_encumbrance_order_type,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'reEncumber')::boolean as encumbrance_re_encumber,
    	--ft.encumbrance__re_encumber AS encumbrance_re_encumber,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'subscription')::boolean AS transaction_encumbrance_subscription
	    --ft.encumbrance__subscription AS transaction_encumbrance_subscription 
FROM
    	folio_finance.transaction as ft --finance_transactions AS ft
    	left JOIN folio_orders.po_line__t as pol 
    	on jsonb_extract_path_text (ft.jsonb, 'encumbrance','sourcePoLineId')::uuid = pol.id --po_lines AS pol ON json_extract_path_text(ft.data, 'encumbrance', 'sourcePoLineId') = pol.id
    	
    	LEFT JOIN folio_orders.purchase_order__t as po 
    	on jsonb_extract_path_text (ft.jsonb, 'encumbrance','sourcePurchaseOrderId')::uuid = po.id --po_purchase_orders AS po ON json_extract_path_text(ft.data, 'encumbrance', 'sourcePurchaseOrderId') = po.id
    	
    	LEFT JOIN folio_finance.fund__t as ff --finance_funds AS ff 
    	ON ft.fromfundid = ff.id --ft.from_fund_id = ff.id
    	
    	LEFT JOIN folio_finance.budget__t as fb --finance_budgets AS fb 
    	ON ft.fromfundid = fb.fund_id 
    		AND ft.fiscalyearid = fb.fiscal_year_id
    		
    	LEFT JOIN folio_organizations.organizations__t as oo --organization_organizations AS oo 
    	ON po.vendor = oo.id
    	
    	LEFT JOIN folio_finance.fiscal_year__t as fy --finance_fiscal_years AS fY 
    	ON fy.id = ft.fiscalyearid
    	
        --LEFT JOIN po_instance as poi 
        --ON jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'sourcePoLineId')::uuid = poi.po_line_id 
        
        left join local_shared.vs_po_instance AS poi -- if not using the local_shared table, use the po_instance derivation in the first subquery, un-comment out the join above this, and comment out this join 
        ON jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'sourcePoLineId')::uuid = poi.po_line_id::uuid        

where
	jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Encumbrance'
   	--ft.transaction_type = 'Encumbrance'
    	AND jsonb_extract_path_text(ft.jsonb, 'amount')::numeric(19, 4) > 0 --ft.amount >0.01
    	AND jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'status') = 'Unreleased' --FT.encumbrance__status = 'Unreleased' 
	AND ((fy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
	AND ((ff.code = (SELECT fund_code FROM parameters)) OR ((SELECT fund_code FROM parameters) = ''))
	
order by pol_number
	;
