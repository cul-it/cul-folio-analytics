--MCR139Y
--inv_appr_paid_diff_date_yesterday.sql
--last updated: 4/17/25
--written by Nancy Boluc, revised to metadb by Ann Crowley and Sharon Markus
--This query provides a list of approved invoices that have been paid at a different date. 
--Sometimes Folio won't allow an invoice to get paid and the invoice will only be paid at a 
--later day, after changes have been made.
--*The results for this query currently show data for FY2025.
--The data date column shows the date this data was last updated.
--4-10-25: Added WHERE clause filter to restrict results to records year-to-date through yesterday using the invoice approval date.
--4-17-25: Added WHERE clause filter to restrict results to FY2025

SELECT 
	CURRENT_DATE as run_date,
    TO_CHAR(CURRENT_DATE - INTERVAL '1 day', 'MM-DD-YYYY') AS yesterday_date,		
	ffy.code as fiscal_year,
    org.name AS vendor_name,
	inv.vendor_invoice_no AS invoice_no,
	inv.export_to_accounting AS export_to_accounting,
	inv.status AS invoice_status,
	inv.approval_date :: DATE AS approval_date,
	inv.payment_date :: DATE AS payment_date,
	inv.voucher_number,
	invv.amount::DECIMAL(12,2) AS voucher_amount
FROM folio_invoice.invoices__t AS inv -- updated
	LEFT JOIN folio_organizations.organizations__t AS org ON org.id::UUID = inv.vendor_id::UUID -- updated
	LEFT JOIN folio_invoice.vouchers__t AS invv ON invv.invoice_id::UUID = inv.id::UUID --updated
	LEFT JOIN folio_finance.fiscal_year__t AS ffy on ffy.id::UUID = inv.fiscal_year_id::UUID
WHERE 
	inv.approval_date::DATE != inv.payment_date::DATE 
	AND inv.approval_date::DATE <= CURRENT_DATE - 1
	AND ffy.code = 'FY2025'
;


	
