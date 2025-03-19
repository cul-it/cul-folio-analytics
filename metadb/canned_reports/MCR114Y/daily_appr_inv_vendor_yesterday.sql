-- MCR114Y
-- daily_appr_inv_vendor_yesterday.sql
-- This query provide the list of invoices paid by vendor along with voucher lines details.
-- written by Nancy Bolduc, revised for Metadb by Sharon Markus, and tested by Ann Crowley
-- last updated: 3/18/25
-- The invoice status is hardcoded as 'Paid'.
-- 3-18-25: adjusted date parameters to restrict results to records from the previous day only

WITH parameters AS (
    SELECT
           current_date - integer '1' AS start_date -- get all orders created XX days from today
)
SELECT 
	invv.voucher_date::date AS voucher_date,    	
    org.erp_code AS vendor_erp_code,
	org.name AS vendor_name,
	inv.vendor_invoice_no,
	invv.voucher_number,
	invvl.external_account_number,
	invv.export_to_accounting AS export_to_accounting,
	invvl.amount
FROM 
	folio_invoice.voucher_lines__t AS invvl 
	LEFT JOIN folio_derived.invoice_voucher_lines_fund_distributions AS invvlfd
	  ON invvlfd.invoice_voucher_line_id = invvl.id
	LEFT JOIN folio_invoice.invoice_lines__t AS invl ON invl.id = invvlfd.fund_distribution_invl_id
	LEFT JOIN folio_invoice.vouchers__t AS invv ON invv.id = invvl.voucher_id
	LEFT JOIN folio_invoice.invoices__t AS inv ON inv.id = invv.invoice_id
	LEFT JOIN folio_orders.po_line__t AS pol ON pol.id = invl.po_line_id
	LEFT JOIN local_shared.vs_po_instance AS poins ON poins.po_line_number = pol.po_line_number 
	LEFT JOIN folio_organizations.organizations__t AS org ON org.id = invv.vendor_id
WHERE
	invv.voucher_date::date = (SELECT start_date FROM parameters) 
	AND inv.status LIKE 'Paid'
GROUP BY 
	invv.voucher_date,
	vendor_invoice_no,
    org.erp_code,
	org.name,
	invvl.amount,
	invv.export_to_accounting,
	invvl.external_account_number,
	invv.voucher_number
ORDER BY vendor_name;

