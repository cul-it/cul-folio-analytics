--MCR213 - 11-19-24 - rev. 5-14-25 and 5-27-25
-- Encumbrances by fund AND fiscal year
-- The results are limited to "Unreleased" encumbrances; comment out line 183 to show ALL encumbrance statuses
-- Ongoing problem: many entries still show unreleased encumbrances with a payment status of "Fully Paid"

--Query writer: Nancy Bolduc (nb299)
--Query reviewer: Joanne Leary (jl41), Sharon Markus (slm5)
--Date posted: 6/21/2023
-- Date revised: 5-14-25
--This query finds current encumbrances by fund AND fiscal year. It also shows titles AND locations. 	
--NOTE: AS of 6/21/23, Fully Paid orders may still have a current encumbrance; this is a system issue to be fixed.
-- 11-19-24: converted to Metadb
-- 11-21-24: corrected "order type" extractiON AND updated po_instance to vs_po_instance
-- 5-14-25: updated po_instance to the folio_derived table, which is now correct. (Commented out po_instance subquery.)
	-- added finance group filter (AND joins to group_fund_fiscal_year__t AND groups__t); also added a join to transaction__t table
	-- Added pol.receipt_status AND pol.receipt_date to Select stanza
-- 5-27-25: cleaned up commented-out lines

WITH parameters AS (
    SELECT
        'FY2025'::VARCHAR AS fiscal_year_code, -- enter fiscal year (FY2023, FY2024, etc.) or leave blank for all Fiscal Years
        '2030'::VARCHAR AS fund_code, -- enter a fund code (ex: 2030, p8154, etc.) or leave blank for all funds
        'Area Studies'::VARCHAR AS finance_group_filter -- (new AS of 5-14-25) enter a finance group (ex: Sciences, Humanities, Area Studies, etc.) or leave blank for all finance groups
)

SELECT DISTINCT
	fy.code AS fiscal_year_code,
 	ff.code AS transaction_from_fund_code,
 	groups__t.name AS finance_group_name, -- new 5-14-25
 	jsonb_extract_path_text(ft.jsonb, 'transactionType') AS transaction_type,
 	jsonb_extract_path_text(ft.jsonb, 'amount')::numeric(19, 4) AS current_encumbrance_transaction_amount,
 	jsonb_extract_path_text(ft.jsonb, 'currency') AS transaction_currency,
 	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'status') AS encumbrance_status,
    	oo.name AS po_vendor_name,
    	pol.po_line_number AS pol_number,
    	jsonb_extract_path_text(ft.jsonb, 'metadata', 'createdDate')::timestamptz AS encumbrance_created_date,
    	pol.title_or_package AS title,
    	poi.pol_location_name AS pol_location_name,
		poi.pol_instance_hrid,
		pol.receipt_status AS pol_receipt_status, -- new 5-14-25
		pol.receipt_date::date AS pol_receipt_date, -- new 5-14-25
    	pol.payment_status AS pol_payment_status, --note that Fully Paid orders may still have an unreleased encumbrance; this is a SYSTEM issue to be fixed
    	pol.descriptiON AS pol_description,
    	po.order_type AS po_order_type,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'amountAwaitingPayment')::numeric(19, 4) AS transaction_encumbrance_amount_awaiting_payment,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'amountExpended')::numeric(19, 4) AS transaction_encumbrance_amount_expended,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'initialAmountEncumbered')::numeric(19, 4) AS transaction_encumbrance_initial_amount,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'orderStatus') AS encumbrance_order_status,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance','orderType') AS transaction_encumbrance_order_type,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'reEncumber')::boolean AS encumbrance_re_encumber,
    	jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'subscription')::boolean AS transaction_encumbrance_subscription
FROM
    	folio_finance.transactiON AS ft 
    	LEFT JOIN folio_orders.po_line__t AS pol 
    	ON jsonb_extract_path_text (ft.jsonb, 'encumbrance','sourcePoLineId')::uuid = pol.id
    	
    	LEFT JOIN folio_finance.transaction__t -- new 5-14-25
    	ON ft.id = transaction__t.id
    	
    	LEFT JOIN folio_orders.purchase_order__t AS po 
    	ON jsonb_extract_path_text (ft.jsonb, 'encumbrance','sourcePurchaseOrderId')::uuid = po.id 
    	
    	LEFT JOIN folio_finance.fund__t AS ff 
    	ON ft.fromfundid = ff.id 
    	
    	LEFT JOIN folio_finance.budget__t AS fb 
    	ON ft.fromfundid = fb.fund_id 
    		AND ft.fiscalyearid = fb.fiscal_year_id
    		
    	LEFT JOIN folio_organizations.organizations__t AS oo 
    	ON po.vendor = oo.id
    	
    	LEFT JOIN folio_finance.fiscal_year__t AS fy  
    	ON fy.id = ft.fiscalyearid
 
        LEFT JOIN folio_derived.po_instance AS poi   
        ON jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'sourcePoLineId')::uuid = poi.po_line_id::uuid
       
        LEFT JOIN folio_finance.group_fund_fiscal_year__t -- new 5-14-25
        ON ff.id = group_fund_fiscal_year__t.fund_id       
	       AND transaction__t.fiscal_year_id = GROUP_FUND_FISCAL_YEAR__T.FISCAL_YEAR_ID 
	       AND fb.ID = group_fund_fiscal_year__t.budget_id
       
        LEFT JOIN folio_finance.groups__t -- new 5-14-25
        ON group_fund_fiscal_year__t.group_id = groups__t.id

WHERE
	jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Encumbrance'
    	AND jsonb_extract_path_text(ft.jsonb, 'amount')::numeric(19, 4) > 0 
    	AND jsonb_extract_path_text(ft.jsonb, 'encumbrance', 'status') = 'Unreleased'  
		AND ((fy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
		AND ((ff.code = (SELECT fund_code FROM parameters)) OR ((SELECT fund_code FROM parameters) = ''))
		AND ((groups__t.name = (SELECT finance_group_filter FROM parameters)) OR ((SELECT finance_group_filter FROM parameters) = '')) -- new 5-14-25
	
ORDER BY finance_group_name, fiscal_year_code, transaction_from_fund_code, pol_number
	;
