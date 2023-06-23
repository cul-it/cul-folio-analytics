--CR123

/* This query provides a list of purchase orders with the workflow status "Open" showing the amount paid broken down by purchase order lines. 
Users can use multiple filters to narrow down their search by using parameters filters, located at the top of the query. It is important to note 
that the transaction amount will differ from the invoice line sub-total amount when an adjustment is made at the invoice level. 
The invoice line amount is capturing the payments made on deposit accounts where the transaction amount would be $0.

In addition, open orders without transactions are not associated with a fiscal year. If you select a fiscal year when you run this query, 
it will only show open orders with transactions. To show ALL open orders, do not enter a fiscal year in the fiscal year code parameter 
at the top of the query.

This report excludes any invoice line data not attached to a purchase order line and adjustments made at the invoice level.

This report does not show encumbrances on purchase orders. If you are looking for open/current encumbrances, please use CR213.
*/
	
/* NOTE: Choose a fiscal year filter */

WITH parameters AS (
    SELECT
        ''::VARCHAR AS order_type, -- select 'One-Time' or 'Ongoing' or leave blank for both
        ''::VARCHAR AS order_format, -- select 'Electronic Resource', 'Physical Resource', 'P/E Mix', 'Other' or leave blank for all
        ''::VARCHAR AS fund_group_name,  --Ex: Humanities, Social Sciences, Central etc. This is case SENSITIVE,
        ''::VARCHAR AS transaction_fiscal_year_code  --Ex: FY2022, FY2023
),
Instance_extract AS (
	SELECT 
		DISTINCT pol_instance_id,
		pol_instance_hrid,
		title AS instance_title
	FROM folio_reporting.po_instance AS poi 
	ORDER BY pol_instance_id
),
invoice_extract AS (
	SELECT
  		pol.id AS po_line_id, 
  		invl.id AS invl_id,
		ilfd.fund_distribution_id AS invoice_line_fund_distribution_id,
		ff.code AS fund_code,
		fti.effective_fund_code AS fti_fund_code,
		fti.effective_fund_id AS effective_fund_id,
		fti.transaction_type,
		fti.transaction_fiscal_year_id,
		ffy.code AS fiscal_year_code,
   		invl.invoice_line_status AS invl_status,
   		invl.sub_total AS invoice_sub_total,
   		inv.payment_date::date AS inv_payment_date,
   		inv.currency AS invoice_currency,
   		oo.name AS vendor_name,
   		inv.vendor_invoice_no,
   		CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >1 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS transaction_amount
   		
	FROM
   		invoice_invoices AS inv
   		LEFT JOIN invoice_lines AS invl ON invl.invoice_id = inv.id
   		LEFT JOIN po_lines AS pol ON pol.id = invl.po_line_id 
		LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd ON ilfd.invoice_line_id = invl.id 
		LEFT JOIN finance_funds AS ff ON ff.id = ilfd.fund_distribution_id
		LEFT JOIN folio_reporting.finance_transaction_invoices AS fti ON fti.invoice_line_id=invl.id AND ilfd.finance_fund_code=fti.effective_fund_code 
		LEFT JOIN organization_organizations AS oo ON oo.id = inv.vendor_id 
		LEFT JOIN finance_fiscal_years AS ffy ON ffy. id = fti.transaction_fiscal_year_id 
		WHERE (ffy.code = (SELECT transaction_fiscal_year_code FROM parameters) OR (SELECT transaction_fiscal_year_code FROM parameters) = '')
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
	WHERE (ffy.code = (SELECT transaction_fiscal_year_code FROM parameters) OR (SELECT transaction_fiscal_year_code FROM parameters) = '')
	ORDER BY ff.code
)
    ---MAIN QUERY
SELECT
   	CURRENT_DATE,
   	ffyg.finance_group_name AS fund_group_name,
   	invext.fund_code,
   	ppo.po_number AS po_number,
   	oo.name AS po_vendor_name,
   	pol.po_line_number,
   	pol.title_or_package AS pol_title_or_package,
   	inst.instance_title AS instance_title,
   	inst.pol_instance_hrid AS instance_hrid,
   	ppo.order_type AS po_order_type,
  	pol.order_format AS pol_order_format,
   	pol.payment_status,
   	pol.receipt_status AS pol_receipt_status,
  	pol_phys_type.pol_mat_type_name AS pol_phys_mat_type_name, -- This is the physical material type name
   	pol_er_type.pol_er_mat_type_name AS pol_er_mat_type_name, -- This is the electronic material type name
   	invext.invl_status AS invl_status,
   	invext.inv_payment_date::date AS inv_payment_date,
   	invext.vendor_invoice_no AS vendor_invoice_no,
   	invext.transaction_amount AS transaction_amount,
   	invext.fiscal_year_code AS transaction_fiscal_year,
  	 invext.invoice_sub_total AS invoice_line_sub_total,
  	invext.invoice_currency AS invoice_currency,
   	invext.transaction_type
FROM
	po_lines AS pol
	LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id 
	LEFT JOIN invoice_lines AS invl ON invl.po_line_id = pol.id
   	LEFT JOIN invoice_extract AS invext ON invext.invl_id = invl.id 
   	LEFT JOIN Instance_extract AS inst ON inst.pol_instance_id = pol.instance_id
	LEFT JOIN folio_reporting.po_lines_phys_mat_type AS pol_phys_type ON pol.id = pol_phys_type.pol_id
	LEFT JOIN folio_reporting.po_lines_er_mat_type AS pol_er_type ON pol.id = pol_er_type.pol_id
	LEFT JOIN folio_reporting.finance_transaction_purchase_order AS frftp ON frftp.pol_number = pol.po_line_number
	LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = invext.effective_fund_id
	LEFT JOIN organization_organizations AS oo ON oo.id = ppo.vendor
WHERE  
	ppo.workflow_status LIKE 'Open'
    	AND (ppo.order_type = (SELECT order_type FROM parameters) OR (SELECT order_type FROM parameters) = '')
    	AND (pol.order_format = (SELECT order_format FROM parameters) OR (SELECT order_format FROM parameters) = '')
    	AND (invext.fiscal_year_code = (SELECT transaction_fiscal_year_code FROM parameters) OR (SELECT transaction_fiscal_year_code FROM parameters) = '')
    	AND (ffyg.finance_group_name = (SELECT fund_group_name FROM parameters) OR (SELECT fund_group_name FROM parameters) = '')
GROUP BY
	ppo.order_type,
   	ffyg.finance_group_name,
   	ppo.po_number,
   	pol.po_line_number,
   	invext.vendor_name,
	pol.title_or_package,
	inst.instance_title,
	inst.pol_instance_hrid,
    	pol.order_format,
    	pol.payment_status,
   	pol.receipt_status,
   	pol_phys_type.pol_mat_type_name,
    	pol_er_type.pol_er_mat_type_name,
    	invext.invl_id,
   	invext.invl_status,
   	invext.inv_payment_date,
   	invext.vendor_invoice_no,
   	invext.transaction_amount,
   	invext.fiscal_year_code,
  	invext.invoice_sub_total,
  	invext.invoice_currency,
  	invext.fund_code,
  	invext.transaction_type,
  	ppo.vendor,
  	oo.name
ORDER BY 
	fund_group_name,
	fund_code ASC,
	vendor_name,
	po_number
;
	
