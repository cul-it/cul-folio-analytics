-- This query finds approval plan payments based on a "bill to" location of "LTS Approvals" in the purchase order or invoice. 
-- It also includes the purchase order location, workflow status, order type, order format, vendor name, fund, and fiscal year. 
-- 10-12-23: added po_instance to get location
-- written by Joanne Leary and Natalya Pikulik, reviewed by Sharon Beltaine

WITH parameters AS

(SELECT
	''::VARCHAR as fiscal_year_filter, -- Ex: FY2023
	'%%'::VARCHAR as vendor_name_filter, -- Ex: HARRASSOWITZ
	''::VARCHAR as fund_code_filter -- Ex: 310, 521, p6610
)

SELECT DISTINCT

il.description as title,
ii.vendor_invoice_no,
ppo.order_type,
pl.order_format,
ppo.workflow_status,
oo.name as vendor_name,
il.invoice_line_number,
pl.po_line_number,
poi.pol_location_name,
fti.effective_fund_name,
fti.effective_fund_code as fund_code,
fti.transaction_type,
ii.payment_date::date,
ffy.code AS fiscal_year,
il.total

FROM invoice_invoices ii

LEFT JOIN invoice_lines il ON ii.id=il.invoice_id
LEFT JOIN po_lines pl ON il.po_line_id = pl.id
LEFT JOIN folio_reporting.po_instance as poi on pl.id::uuid = poi.po_line_id::uuid
LEFT JOIN po_purchase_orders as ppo on pl.purchase_order_id = ppo.id
LEFT JOIN organization_organizations as oo on ii.vendor_id = oo.id
LEFT JOIN folio_reporting.finance_transaction_invoices as fti on il.id = fti.invoice_line_id
LEFT JOIN finance_fiscal_years ffy on fti.transaction_fiscal_year_id = ffy.id

WHERE (ii.bill_to = 'ca79f61a-1375-4e47-8d84-13c487b3ff38' OR ppo.bill_to = 'ca79f61a-1375-4e47-8d84-13c487b3ff38')
	AND ii.status = 'Paid'
	AND (ffy.code = (select fiscal_year_filter from parameters) or (select fiscal_year_filter from parameters) = '')
	AND (oo.name ilike (select vendor_name_filter from parameters) or (select vendor_name_filter from parameters) = '')
	AND (fti.effective_fund_code = (select fund_code_filter from parameters) or (select fund_code_filter from parameters) = '')

;

