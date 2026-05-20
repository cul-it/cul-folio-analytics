-- 12-1-25: finance_invoice_transactions derived table re-write

--metadb:table finance_invoice_transactions
--metadb:require folio_finance.expense_class__t.id uuid
--metadb:require folio_finance.expense_class__t.code text
--metadb:require folio_finance.expense_class__t.name text
--metadb:require folio_finance.expense_class__t.external_account_number_ext text

-- Create a derived table of fund distribution in invoices.
-- The derived table contains the information on the fund distribution
-- from the invoices app as well as from the transactions system
-- table.
-- 11-14-25: external account number is no longer in the expense class table; now comes in the fund__t table. Made that change. 
-- 11-19-25: Added invoice_id and invoice_line_number to the first subquery
-- 11-25-25: added finance group to "finance" subquery 
	-- added invoice_lines__t.description, purchase_order_id, po_line_id, po_line_number, transaction_type, and invoice_payment_date to main query
-- 12-1-25: resequenced fields to group record ids together, then report elements that make sense to selectors

--DROP TABLE IF EXISTS finance_invoice_transactions;

--CREATE TABLE finance_invoice_transactions AS
WITH invoice_lines_fund_distribution AS (
    select
    	(invoice_lines.jsonb#>>'{invoiceId}')::UUID as invoice_id, -- added
        invoice_lines.id AS invoice_line_id,
        (invoice_lines.jsonb#>>'{poLineId}')::UUID as po_line_id, -- added
        invoice_lines.jsonb#>>'{invoiceLineNumber}' as invoice_line_number, -- added
        jsonb_extract_path_text(invoice_lines.jsonb, 'total')::numeric(19,4) AS invoice_line_total,
        jsonb_extract_path_text(jsonb_array_elements(jsonb_extract_path(invoice_lines.jsonb, 'fundDistributions')), 'fundId')::uuid AS invoice_line_fund_id,
        jsonb_extract_path_text(jsonb_array_elements(jsonb_extract_path(invoice_lines.jsonb, 'fundDistributions')), 'value')::numeric(19,4) AS invoice_line_distribution_value,
        jsonb_extract_path_text(jsonb_array_elements(jsonb_extract_path(invoice_lines.jsonb, 'fundDistributions')), 'distributionType') AS invoice_line_distribution_type,
        jsonb_extract_path_text(jsonb_array_elements(jsonb_extract_path(invoice_lines.jsonb, 'fundDistributions')), 'expenseClassId') :: UUID AS invoice_line_distribution_expense_class_id
    FROM 
        folio_invoice.invoice_lines
),
invoice_vendors AS (
    SELECT
        invoices__t.id AS invoice_id,
        organizations__t.name AS invoice_vendor_name
    FROM 
        folio_invoice.invoices__t
        INNER JOIN folio_organizations.organizations__t ON organizations__t.id = invoices__t.vendor_id 
),
finance AS (
    SELECT
        fiscal_year__t.id AS fiscal_year_id,
        fiscal_year__t.code AS fiscal_year,
        ledger__t.id AS ledger_id,
        ledger__t.name AS ledger_name,
        budget__t.id AS budget_id,
        budget__t.name AS budget_name,
        fund__t.id AS fund_id,
        fund__t.code AS fund_code,
        groups__t.name as finance_group_name -- added
    FROM            
        folio_finance.fiscal_year__t
        LEFT JOIN folio_finance.budget__t ON budget__t.fiscal_year_id = fiscal_year__t.id
        LEFT JOIN folio_finance.fund__t ON fund__t.id = budget__t.fund_id
        LEFT JOIN folio_finance.ledger__t ON ledger__t.id = fund__t.ledger_id
        
        -- joined to group_fund_fiscal_year__t and groups__t tables to get finance group
        
        left join folio_finance.group_fund_fiscal_year__t as gffyt 
	        on fiscal_year__t.id = gffyt.fiscal_year_id 
	        	and fund__t.id = gffyt.fund_id 
	       		and budget__t.id = gffyt.budget_id
       	left join folio_finance.groups__t 
       		on gffyt.group_id = groups__t.id
),
transactions AS (
    SELECT
        transaction__t.id AS transaction_id,
        transaction__t.transaction_type, -- added
        CASE WHEN transaction__t.transaction_type = 'Credit'
            THEN transaction__t.to_fund_id
            ELSE transaction__t.from_fund_id
        	END AS effective_fund_id,
        transaction__t.amount AS transaction_amount,
        CASE WHEN transaction__t.transaction_type = 'Credit'
            THEN transaction__t.amount :: NUMERIC(19,2) * -1
            ELSE transaction__t.amount :: NUMERIC(19,2)
        	END AS effective_transaction_amount,
        transaction__t.currency AS transaction_currency,
        transaction__t.fiscal_year_id,
        transaction__t.source_invoice_line_id,
        transaction__t.expense_class_id AS transaction_expense_class_id,
        expense_class__t.code AS expense_class_code,
        expense_class__t.name AS expense_class_name
        --expense_class__t.external_account_number_ext -- removed
    FROM
        folio_finance.transaction__t
        LEFT JOIN folio_finance.expense_class__t ON expense_class__t.id = transaction__t.expense_class_id
)
select
    invoices__t.id AS invoice_id,
    invoice_lines__t.id AS invoice_line_id,
    invoice_lines_fund_distribution.invoice_line_fund_id,
    inv_line_expense_class.id AS invoice_line_expense_class_id,
    po_line__t.purchase_order_id, -- added
    invoice_lines_fund_distribution.po_line_id, -- added
    transactions.transaction_id,
    transactions.effective_fund_id AS transaction_fund_id,
    finance.fiscal_year_id,
    finance.ledger_id,
    finance.budget_id,
    transactions.transaction_expense_class_id,
    invoices__t.vendor_id,
    finance.fiscal_year,
    finance.finance_group_name, -- added
    transactions.expense_class_name AS transactions_expense_class_name,
    invoice_vendors.invoice_vendor_name AS vendor_name,
    invoice_lines__t.description as invoice_line_description, -- added   
    inv_line_fund.code AS invoice_line_fund_code,
    finance.fund_code AS transaction_fund_code,
    po_line__t.po_line_number, -- added
    invoices__t.vendor_invoice_no AS vendor_invoice_number,  
    invoice_lines_fund_distribution.invoice_line_number, -- added
    invoices__t.invoice_date::date,
    invoices__t.payment_date::date as invoice_payment_date, -- added
    invoice_lines_fund_distribution.invoice_line_distribution_value,
    invoice_lines_fund_distribution.invoice_line_distribution_type,
    transactions.transaction_type, -- added 
    transactions.transaction_amount,
    transactions.effective_transaction_amount,
    invoice_lines__t.total AS invoice_line_total,
    inv_line_expense_class.code AS invoice_line_expense_class_code,
    inv_line_expense_class.name AS invoice_line_expense_class_name,
    invoices__t.folio_invoice_no AS folio_invoice_number,     
    invoices__t.status AS invoice_status,
    inv_line_fund.external_account_no, -- added
    transactions.expense_class_code AS transactions_expense_class_code,    
    invoices__t.exchange_rate,  
    invoices__t.currency AS invoice_currency,
    transactions.transaction_currency,           
    finance.ledger_name,   
    finance.budget_name 
    --inv_line_expense_class.external_account_number_ext, -- removed
    --transactions.external_account_number_ext AS transactions_external_account_number_ext -- removed
    
FROM
    folio_invoice.invoices__t
    LEFT JOIN folio_invoice.invoice_lines__t ON invoice_lines__t.invoice_id = invoices__t.id
    LEFT JOIN invoice_lines_fund_distribution ON invoice_lines_fund_distribution.invoice_line_id = invoice_lines__t.id
    LEFT JOIN folio_finance.expense_class__t AS inv_line_expense_class ON inv_line_expense_class.id = invoice_lines_fund_distribution.invoice_line_distribution_expense_class_id
    LEFT JOIN folio_finance.fund__t AS inv_line_fund ON inv_line_fund.id = invoice_lines_fund_distribution.invoice_line_fund_id
    LEFT JOIN invoice_vendors ON invoice_vendors.invoice_id = invoices__t.id    
    LEFT JOIN transactions ON transactions.source_invoice_line_id = invoice_lines__t.id
        AND transactions.effective_fund_id = invoice_lines_fund_distribution.invoice_line_fund_id
    LEFT JOIN finance ON finance.fund_id = transactions.effective_fund_id
        AND finance.fiscal_year_id = transactions.fiscal_year_id
    left join folio_orders.po_line__t -- added
    	on invoice_lines_fund_distribution.po_line_id = po_line__t.id -- added
WHERE 
    invoice_lines_fund_distribution.invoice_line_distribution_expense_class_id IS null
    and finance.fund_code = 'p6993'
    
UNION

select
    invoices__t.id AS invoice_id,
    invoice_lines__t.id AS invoice_line_id,
    invoice_lines_fund_distribution.invoice_line_fund_id,
    inv_line_expense_class.id AS invoice_line_expense_class_id,
    po_line__t.purchase_order_id, -- added
    invoice_lines_fund_distribution.po_line_id, -- added
    transactions.transaction_id,
    transactions.effective_fund_id AS transaction_fund_id,
    finance.fiscal_year_id,
    finance.ledger_id,
    finance.budget_id,
    transactions.transaction_expense_class_id,
    invoices__t.vendor_id,
    finance.fiscal_year,
    finance.finance_group_name, -- added
    transactions.expense_class_name AS transactions_expense_class_name,
    invoice_vendors.invoice_vendor_name AS vendor_name,
    invoice_lines__t.description as invoice_line_description, -- added   
    inv_line_fund.code AS invoice_line_fund_code,
    finance.fund_code AS transaction_fund_code,
    po_line__t.po_line_number, -- added
    invoices__t.vendor_invoice_no AS vendor_invoice_number,  
    invoice_lines_fund_distribution.invoice_line_number, -- added
    invoices__t.invoice_date::date,
    invoices__t.payment_date::date as invoice_payment_date, -- added
    invoice_lines_fund_distribution.invoice_line_distribution_value,
    invoice_lines_fund_distribution.invoice_line_distribution_type,
    transactions.transaction_type, -- added 
    transactions.transaction_amount,
    transactions.effective_transaction_amount,
    invoice_lines__t.total AS invoice_line_total,
    inv_line_expense_class.code AS invoice_line_expense_class_code,
    inv_line_expense_class.name AS invoice_line_expense_class_name,
    invoices__t.folio_invoice_no AS folio_invoice_number,     
    invoices__t.status AS invoice_status,
    inv_line_fund.external_account_no, -- added
    transactions.expense_class_code AS transactions_expense_class_code,    
    invoices__t.exchange_rate,  
    invoices__t.currency AS invoice_currency,
    transactions.transaction_currency,           
    finance.ledger_name,   
    finance.budget_name 
    --inv_line_expense_class.external_account_number_ext, -- removed
    --transactions.external_account_number_ext AS transactions_external_account_number_ext -- removed
FROM
    folio_invoice.invoices__t
    LEFT JOIN folio_invoice.invoice_lines__t ON invoice_lines__t.invoice_id = invoices__t.id
    LEFT JOIN invoice_lines_fund_distribution ON invoice_lines_fund_distribution.invoice_line_id = invoice_lines__t.id
    LEFT JOIN folio_finance.expense_class__t AS inv_line_expense_class ON inv_line_expense_class.id = invoice_lines_fund_distribution.invoice_line_distribution_expense_class_id
    LEFT JOIN folio_finance.fund__t AS inv_line_fund ON inv_line_fund.id = invoice_lines_fund_distribution.invoice_line_fund_id
    LEFT JOIN invoice_vendors ON invoice_vendors.invoice_id = invoices__t.id    
    LEFT JOIN transactions ON transactions.source_invoice_line_id = invoice_lines__t.id
        AND transactions.effective_fund_id = invoice_lines_fund_distribution.invoice_line_fund_id
        AND transactions.transaction_expense_class_id = invoice_lines_fund_distribution.invoice_line_distribution_expense_class_id
    LEFT JOIN finance ON finance.fund_id = transactions.effective_fund_id
        AND finance.fiscal_year_id = transactions.fiscal_year_id
    left join folio_orders.po_line__t -- added
    	on invoice_lines_fund_distribution.po_line_id = po_line__t.id -- added
WHERE 
    invoice_lines_fund_distribution.invoice_line_distribution_expense_class_id IS NOT null
    and finance.fund_code = 'p6993'
;

