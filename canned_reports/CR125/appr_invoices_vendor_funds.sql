--This query provides the list of approved invoices within a date range along with vendor name, invoice number, fund group and fund used.

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2021-07-01' :: DATE AS payment_date_start_date,
        '2022-06-30' :: DATE AS payment_date_end_date, -- Excludes the selected date
        '':: VARCHAR AS invoice_no, --Ex: 12345, CUL01 etc.
        '':: VARCHAR AS from_fund_code, --Ex: 999, p2853. PLEASE SELECT FROM_FUND_CODE OR TO_FUND_CODE, NOT BOTH AT THE SAME TIME
        '':: VARCHAR AS to_fund_code, --Ex: 999, p2853. PLEASE SELECT FROM_FUND_CODE OR TO_FUND_CODE, NOT BOTH AT THE SAME TIME
        '':: VARCHAR AS finance_group_name,--Ex: Central, Sciences, Humanities... It is case sensitive, it has to match Folio
        '':: VARCHAR AS vendor_name -- Ex:  Proquest, YANKEE/EBK, HARRASSOWITZ... It is case sensitive, it has to match Folio
),
ledger_fund AS (
	SELECT 
		fl.name AS ledger_name,
		ff.external_account_no,
		ff.code AS fund_code
	FROM 
		finance_ledgers fl 
		LEFT JOIN finance_funds AS ff ON FF.ledger_id = fl.id
	GROUP BY 
		external_account_no,
		fl.name,
		ff.code
)
SELECT 
		(SELECT
			payment_date_start_date::varchar
     	FROM
        	parameters) || ' to '::varchar || (
     	SELECT
        	payment_date_end_date::varchar
     	FROM
        	parameters) AS date_range,	
	CASE WHEN lf.ledger_name IS NULL THEN lf2.ledger_name ELSE lf.ledger_name END,
	CASE WHEN fg.name IS NULL THEN fg2.name ELSE fg.name END AS finance_group_name,
	org.erp_code AS vendor_code,
	fti.invoice_vendor_name AS vendor_name,
	inv.vendor_invoice_no AS invoice_no,
	inv.export_to_accounting AS export_to_accounting,
	inv.invoice_date::date AS invoice_date,
	inv.payment_date::date AS payment_date,
	inv.voucher_number,
	fti.transaction_from_fund_code AS from_fund_code,
	fti.transaction_to_fund_code AS to_fund_code,
	CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >1 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS transaction_amount,
	CASE WHEN fti.transaction_from_fund_code IS NOT NULL THEN lf.external_account_no ELSE lf2.external_account_no END
FROM 
	folio_reporting.finance_transaction_invoices AS fti 
	LEFT JOIN invoice_lines AS invl ON invl.id = fti.invoice_line_id 
	LEFT JOIN invoice_invoices AS inv ON fti.invoice_id = inv.id
	LEFT JOIN organization_organizations AS org ON org.id = inv.vendor_id
	LEFT JOIN finance_budgets AS fb ON fti.transaction_from_fund_id = fb.fund_id AND fti.transaction_fiscal_year_id = fb.fiscal_year_id
	LEFT JOIN finance_budgets AS fb2 ON fti.transaction_to_fund_id = fb2.fund_id AND fti.transaction_fiscal_year_id = fb2.fiscal_year_id
	LEFT JOIN ledger_fund AS lf ON lf.fund_code = fti.transaction_from_fund_code 
	LEFT JOIN ledger_fund AS lf2 ON lf2.fund_code = fti.transaction_to_fund_code
	LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = fti.transaction_from_fund_id 
	LEFT JOIN finance_group_fund_fiscal_years AS fgffy2 ON fgffy2.fund_id = fti.transaction_to_fund_id 
	LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id
	LEFT JOIN finance_groups AS fg2 ON fg2.id = fgffy2.group_id
WHERE
	(inv.payment_date::date >= (SELECT payment_date_start_date FROM parameters)) 
	AND (inv.payment_date::date < (SELECT payment_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
	AND ((inv.vendor_invoice_no = (SELECT invoice_no  FROM parameters)) OR ((SELECT invoice_no  FROM parameters) = ''))
	AND ((fti.transaction_from_fund_code = (SELECT from_fund_code FROM parameters)) OR ((SELECT from_fund_code FROM parameters) = '')) 
	AND ((fti.transaction_to_fund_code = (SELECT to_fund_code FROM parameters)) OR ((SELECT to_fund_code FROM parameters) = ''))
	AND ((fti.invoice_vendor_name = (SELECT vendor_name FROM parameters)) OR ((SELECT vendor_name FROM parameters) = ''))
	AND ((CASE WHEN fg.name IS NULL THEN fg2.name ELSE fg.name END =(SELECT finance_group_name FROM parameters)) OR ((SELECT finance_group_name FROM parameters) = ''))
ORDER BY 
	lf.ledger_name, 
	fti.invoice_vendor_name,
	inv.vendor_invoice_no;