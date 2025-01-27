-- MCR157 (corrected 10-2-24) - revised 1-24-25
-- Funds and teams with expense class
-- last updated 1-24-25
-- This query provides a detailed current date report of funds and teams with amounts spent, encumbered, and remaining.
-- Query writer: Joanne Leary (jl41)
-- Posted on: 7/25/24
-- 10-2-24: corrected the query to add a join from expense class fiscal year code to finance fiscal year code
-- 1-24-25: replaced derived table finance_transaction_invoices with derivation for derived table; gets up-to-the-minute data

WITH parameters AS (
    SELECT
        '' AS fiscal_year_code,
        '' as team_filter
),

fintraninv as 
(
SELECT
    ft.id AS transaction_id,
    jsonb_extract_path_text(ft.jsonb, 'amount')::numeric(19,4) AS transaction_amount,
    CASE WHEN jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Credit'
        THEN 
            jsonb_extract_path_text(ft.jsonb, 'amount') :: NUMERIC(19,4) * -1
        ELSE 
            jsonb_extract_path_text(ft.jsonb, 'amount') :: NUMERIC(19,4)
    END AS effective_transaction_amount,
    jsonb_extract_path_text(ft.jsonb, 'currency') AS transaction_currency,
    jsonb_extract_path_text(ft.jsonb, 'metadata', 'createdDate')::date AS transaction_created_date,
    jsonb_extract_path_text(ft.jsonb, 'metadata', 'updatedDate')::date AS transaction_updated_date,
	jsonb_extract_path_text(ft.jsonb, 'description') AS transaction_description,
    ft.expenseclassid AS transaction_expense_class_id,
    ft.fiscalyearid AS transaction_fiscal_year_id,
    ft.fromfundid AS transaction_from_fund_id,
    jsonb_extract_path_text(ff.jsonb, 'name') AS transaction_from_fund_name,
    jsonb_extract_path_text(ff.jsonb, 'code') AS transaction_from_fund_code,
    ft.tofundid AS transaction_to_fund_id,
    jsonb_extract_path_text(tf.jsonb, 'name') AS transaction_to_fund_name,
    jsonb_extract_path_text(tf.jsonb, 'code') AS transaction_to_fund_code,
    CASE WHEN ft.tofundid IS NULL THEN ft.fromfundid ELSE ft.tofundid END AS effective_fund_id,
    CASE WHEN jsonb_extract_path_text(ff.jsonb, 'name') IS NULL THEN jsonb_extract_path_text(tf.jsonb, 'name') ELSE jsonb_extract_path_text(ff.jsonb, 'name') END AS effective_fund_name,
    CASE WHEN jsonb_extract_path_text(ff.jsonb, 'code') IS NULL THEN jsonb_extract_path_text(tf.jsonb, 'code') ELSE jsonb_extract_path_text(ff.jsonb, 'code') END AS effective_fund_code,
    fb.id AS transaction_from_budget_id,
    jsonb_extract_path_text(fb.jsonb, 'name') AS transaction_from_budget_name,
    jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceId')::uuid AS invoice_id,
    jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceLineId')::uuid AS invoice_line_id,
    jsonb_extract_path_text(ft.jsonb, 'transactionType') AS transaction_type,
    jsonb_extract_path_text(ii.jsonb, 'invoiceDate') AS invoice_date,
    jsonb_extract_path_text(ii.jsonb, 'paymentDate') AS invoice_payment_date,
    jsonb_extract_path_text(ii.jsonb, 'exchangeRate')::numeric(19,14) AS invoice_exchange_rate,
    jsonb_extract_path_text(il.jsonb, 'total')::numeric(19,4) AS invoice_line_total,
    jsonb_extract_path_text(ii.jsonb, 'currency') AS invoice_currency,
    jsonb_extract_path_text(il.jsonb, 'poLineId') AS po_line_id,
    jsonb_extract_path_text(ii.jsonb, 'vendorId')::uuid AS invoice_vendor_id,
    jsonb_extract_path_text(oo.jsonb, 'name') AS invoice_vendor_name   
FROM
    folio_finance.transaction AS ft
    LEFT JOIN folio_invoice.invoices AS ii ON jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceId')::uuid = ii.id
    LEFT JOIN folio_invoice.invoice_lines AS il ON jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceLineId')::uuid = il.id
    LEFT JOIN folio_finance.fund AS ff ON ft.fromfundid = ff.id
    LEFT JOIN folio_finance.fund AS tf ON ft.tofundid = tf.id
    LEFT JOIN folio_finance.budget AS fb ON ft.fromfundid = fb.fundid AND ft.fiscalyearid = fb.fiscalyearid
    LEFT JOIN folio_organizations. organizations AS oo ON jsonb_extract_path_text(ii.jsonb, 'vendorId')::uuid = oo.id
WHERE (jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Pending payment'
    OR jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Payment'
    OR jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Credit')
),
        
expense_class AS    
(
SELECT distinct      
	fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name AS expense_class_name,
        ffy.code AS expense_class_fiscal_year_code,
        sum(case when ft.transaction_type = 'Credit' THEN fti.transaction_amount*-1 ELSE fti.transaction_amount END) as amount_spent_in_expense_class
        
FROM fintraninv as fti --folio_derived.finance_transaction_invoices as fti  
        left join folio_finance.transaction__t as ft on fti.transaction_id = ft.id --LEFT JOIN finance_transactions AS ft ON fti.transaction_id = ft.id 
        left join folio_finance.expense_class__t as fec on fti.transaction_expense_class_id = fec.id --LEFT JOIN finance_expense_classes AS fec ON fti.transaction_expense_class_id = fec.id
        left join folio_finance.fiscal_year__t as ffy on ffy.id = fti.transaction_fiscal_year_id --LEFT JOIN finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id   

GROUP BY 
        fti.effective_fund_code,
        fti.effective_fund_name,
        fec.name,
        ffy.code
)

SELECT 
        current_date,
        fgffy.fiscal_year_id,
        ffy.code AS fiscal_year,
        fg.name AS team,
        fg.description AS fund_manager,
        fft.name AS fund_type,
        ff.code AS finance_funds_code,
        ff.name AS finance_funds_name,
        ff.description,
        COALESCE (fb.net_transfers,0) AS net_transfers,
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) AS total_funding,
	COALESCE (fb.expenditures,0) AS expenditures,
	COALESCE (fb.encumbered,0) AS encumbered,
	COALESCE (fb.awaiting_payment,0) AS awaiting_payment,
	(COALESCE (fb.encumbered,0)+COALESCE (fb.awaiting_payment,0)+COALESCE (fb.expenditures,0)) AS unavailable,-- Total of amount Encumbered, Awaiting Payment and Expended
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.expenditures,0) AS cash_balance,
	(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)-COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) - COALESCE (fb.encumbered,0) - COALESCE (fb.awaiting_payment,0) - COALESCE (fb.expenditures,0) AS available_balance,
        ec.expense_class_name,
        ec.amount_spent_in_expense_class, --This amount includes amount Expended and Awaiting Payment
        CASE WHEN 
        	fb.expenditures > 0                 
                THEN ec.amount_spent_in_expense_class/fb.expenditures
                ELSE 0 
                END AS percent_of_fund_spent_on_expense_class_to_date
FROM 
	folio_finance.fund__t as ff--finance_funds AS ff     
       left join folio_finance.budget__t as fb on fb.fund_id = ff.id --LEFT JOIN finance_budgets AS fb ON fb.fund_id = ff.id  
       left join folio_finance.fiscal_year__t as ffy on fb.fiscal_year_id = ffy.id --LEFT JOIN finance_fiscal_years AS ffy ON fb.fiscal_year_id = ffy.id
       left join folio_finance.group_fund_fiscal_year__t as fgffy on fgffy.budget_id = fb.id --LEFT JOIN finance_group_fund_fiscal_years AS fgffy  ON fgffy.budget_id = fb.id
       left join folio_finance.groups__t as fg on fg.id = fgffy.group_id --LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id
       left join folio_finance.fund_type__t as fft on ff.fund_type_id = fft.id --LEFT JOIN finance_fund_types AS fft ON ff.fund_type_id = fft.id
       left join expense_class as ec on ff.code = ec.effective_fund_code --LEFT JOIN expense_class AS ec ON ff.code = ec.effective_fund_code
       	and ec.expense_class_fiscal_year_code = ffy.code -- added 10-2-24    

WHERE 
	((ffy.code = (SELECT fiscal_year_code FROM parameters) or (select fiscal_year_code from parameters) = ''))
	and ((fg.name = (select team_filter from parameters) or (select team_filter from parameters) =''))
	
ORDER BY 
	team, finance_funds_code, finance_funds_name, expense_class_name
;
