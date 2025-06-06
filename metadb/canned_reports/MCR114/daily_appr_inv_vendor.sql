--MCR114
--daily_appr_inv_vendor
--This query provide the list of invoices paid by vendor along with voucher lines details.
--written by Nancy Bolduc, revised for Metadb by Sharon Markus, and tested by Ann Crowley
--last updated 1/20/25
--The date range for records in results is set for FY2025.

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2024-07-01' :: DATE AS voucher_date_start_date,
        '2025-06-30' :: DATE AS voucher_date_end_date -- Excludes the selected date
)
SELECT 
		(SELECT
			voucher_date_start_date::varchar
     	FROM
        	parameters) || ' to '::varchar || (
     	SELECT
        	voucher_date_end_date::varchar
     	FROM
        	parameters) AS date_range,	
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
	LEFT JOIN local_static.vs_po_instance AS poins ON poins.po_line_number = pol.po_line_number 
	LEFT JOIN folio_organizations.organizations__t AS org ON org.id = invv.vendor_id
WHERE
	(invv.voucher_date::date >= (SELECT voucher_date_start_date FROM parameters)) 
	AND (invv.voucher_date::date < (SELECT voucher_date_end_date FROM parameters))
	AND inv.status LIKE 'Paid'
GROUP BY 
	vendor_invoice_no,
    org.erp_code,
	org.name,
	invvl.amount,
	invv.export_to_accounting,
	invvl.external_account_number,
	invv.voucher_number
ORDER BY vendor_name;

