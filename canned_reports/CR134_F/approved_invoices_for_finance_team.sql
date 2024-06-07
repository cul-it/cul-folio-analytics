--CR134_F Approved Invoices for FBO 
--This query provides the list of approved invoices within a date range along with ledger name, external account no, vendor name, 
--vendor invoice no, invoice line description, invoice date, invoice payment date, order format, format name, purchase order line no,fund code, transaction type, transaction amount.
--In cases where the quantity was incorrectly entered as zero, this query replaces zero with 1 
--06-06-24 Added invoice_line_number to SELECT to distinguish invoice line payments that would otherwise be combined by DISTINCT as identical, 
--which was reducing expenditure totals compared to the total expenditures shown in the ledger.


WITH parameters AS (
    SELECT
        '' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        ''::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023 etc.
        ''::VARCHAR AS format_name -- Ex: Book, Serial, Textual Resource, etc.      
),   
format_extract as (
        SELECT 
         sm.instance_id::uuid,
         substring(sm.content,7,2) AS bib_format_code,
         jl.bib_format_display
        FROM
        srs_marctab as sm
        LEFT JOIN local.jl_bib_format_display_csv AS jl ON substring(sm.content,7,2) = jl.bib_format
        WHERE sm.field = '000' 
),
  finance_transaction_invoices_ext AS (
        SELECT
        fti.transaction_id AS transaction_id,      
        fti.invoice_date::date,
                fti.invoice_payment_date::DATE AS invoice_payment_date,
                fti.transaction_fiscal_year_id,
                ffy.code AS fiscal_year_code,
                fti.invoice_id,
                fti.invoice_line_id,
                fti.po_line_id,
                fl.name AS finance_ledger_name,
                fti.transaction_expense_class_id AS expense_class,
                fti.invoice_vendor_name,
                fti.transaction_type,
                fti.transaction_amount,
                fti.effective_fund_id AS effective_fund_id,
                fti.effective_fund_code AS effective_fund_code,
                fft.name AS fund_type_name,
                CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS effective_transaction_amount,
                ff.external_account_no AS external_account_no
FROM
                folio_reporting.finance_transaction_invoices AS fti
                LEFT JOIN finance_funds AS ff ON ff.code = fti.effective_fund_code
                LEFT JOIN finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id
                LEFT JOIN finance_fund_types AS fft ON fft.id = ff.fund_type_id
                LEFT JOIN finance_ledgers AS fl ON ff.ledger_id = fl.id               
),
fund_fiscal_year_group AS (
SELECT
    FGFFY.id AS group_fund_fiscal_year_id,
    FG.name AS finance_group_name,
    ff.id AS fund_id,
    ff.code AS fund_code,
    fgffy.fiscal_year_id AS fund_fiscal_year_id,
    ffy.code AS fiscal_year_code
FROM
    finance_groups AS FG 
    LEFT JOIN finance_group_fund_fiscal_years AS FGFFY ON fg.id = fgffy.group_id
    LEFT JOIN finance_fiscal_years AS ffy ON ffy. id = fgffy.fiscal_year_id
    LEFT JOIN finance_funds AS FF ON FF.id = fgffy.fund_id
WHERE ((ffy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
ORDER BY ff.code

),
new_quantity AS 
        (SELECT 
        id AS invoice_line_id,
       CASE WHEN quantity = 0
                THEN 1
                ELSE quantity
                        END AS fixed_quantity
        FROM invoice_lines 
)
-- MAIN QUERY
SELECT distinct
        current_date AS current_date,           
       CASE WHEN 
                        ((SELECT
                        payment_date_start_date::varchar
                        FROM
                parameters)= ''
        OR      (SELECT
                payment_date_end_date::varchar
                        FROM
                parameters) ='')
                THEN 'Not Selected'
                ELSE
                        (SELECT payment_date_start_date::varchar
                FROM parameters) || ' to '::varchar || 
                (SELECT payment_date_end_date::varchar
                                FROM parameters)
                        END AS payment_date_range,       
       pol.order_format,
       ftie.invoice_date::date,
       invl.invoice_line_number,
       inv.payment_date::DATE as invoice_payment_date,
       ftie.effective_transaction_amount,
       ftie.transaction_type,
       ftie.invoice_vendor_name,
       inv.vendor_invoice_no,
       replace(replace (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,--updated code to get rid of carriage returns
       ftie.finance_ledger_name,
       ftie.fiscal_year_code AS transaction_fiscal_year_code,
       ftie.effective_fund_code,
       pol.po_line_number,      
       formatt.bib_format_display AS format_name,        
       fq.fixed_quantity AS quantity,       
       ftie.external_account_no
FROM
        finance_transaction_invoices_ext AS ftie
        LEFT JOIN invoice_lines AS invl ON invl.id = ftie.invoice_line_id
        LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
       LEFT JOIN invoice_invoices AS inv ON ftie.invoice_id = inv.id
        LEFT JOIN po_lines AS pol ON ftie.po_line_id = pol.id
        LEFT JOIN po_purchase_orders AS PO ON po.id = pol.purchase_order_id
        LEFT JOIN folio_reporting.instance_ext AS iext ON iext.instance_id = pol.instance_id
        LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
        LEFT JOIN format_extract AS formatt ON pol.instance_id::UUID = formatt.instance_id
WHERE
        ((SELECT payment_date_start_date FROM parameters) ='' OR (inv.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (inv.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND inv.status LIKE 'Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        AND ((ftie.finance_ledger_name = (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) = ''))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = '')) 
        AND ((formatt.bib_format_display= (SELECT format_name FROM parameters)) OR ((SELECT format_name FROM parameters) = ''))    
 
GROUP BY
       ftie.transaction_id,
       pol.order_format,
       ftie.invoice_date::DATE,
       invl.invoice_line_number,
       inv.payment_date::DATE,
       ftie.effective_transaction_amount,
       ftie.transaction_type,
       ftie.invoice_vendor_name,
       inv.vendor_invoice_no,
       invl.description,
       ftie.finance_ledger_name,
       ftie.fiscal_year_code,
       ftie.effective_fund_code,
       pol.po_line_number,      
       formatt.bib_format_display,        
       fq.fixed_quantity,       
       ftie.external_account_no  
    
ORDER BY 
        ftie.finance_ledger_name,
        ftie.effective_fund_code,
        ftie.invoice_vendor_name,
        inv.vendor_invoice_no,
        pol.po_line_number 
        ;
