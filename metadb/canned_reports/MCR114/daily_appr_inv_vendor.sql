-- MCR114
-- daily_appr_inv_vendor.sql
-- written by Nancy Bolduc, revised by Sharon Markus, reviewed and tested by 
-- Last updated 2/19/24

-- This query provides the list of invoices paid by vendor along with voucher lines details.

WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
    	'2021-07-01' :: DATE AS voucher_date_start_date,
        '2022-06-30' :: DATE AS voucher_date_end_date -- Excludes the selected date
)
SELECT 
	(SELECT
		voucher_date_start_date::VARCHAR
     FROM
        parameters) || ' to '::VARCHAR || (
     SELECT
        voucher_date_end_date::VARCHAR
     FROM
        parameters) AS date_range,	
    org.erp_code AS vendor_erp_code,
    org.name AS vendor_name,
    inv.vendor_invoice_no,
    invv.voucher_number,
    invvl.external_account_number,
    invv.export_to_accounting AS export_to_accounting,
    SUM(invvl.amount) AS total_amount
FROM 
    folio_invoice.voucher_lines__t AS invvl 
    LEFT JOIN folio_derived.invoice_voucher_lines_fund_distributions AS invvlfd ON invvlfd.invoice_voucher_line_id = invvl.id
    LEFT JOIN folio_invoice.invoice_lines__t AS invl ON invl.id = invvlfd.fund_distribution_invl_id
    LEFT JOIN folio_invoice.vouchers__t AS invv ON invv.id = invvl.voucher_id
    LEFT JOIN folio_invoice.invoices__t AS inv ON inv.id = invv.invoice_id
    LEFT JOIN folio_orders.po_line__t AS pol ON pol.id = invl.po_line_id
    LEFT JOIN folio_derived.po_instance AS poins ON poins.po_line_number = pol.PO_LINE_NUMBER 
    LEFT JOIN folio_organizations.organizations__t AS org ON org.id = invv.vendor_id
WHERE
    (invv.voucher_date::DATE >= (SELECT voucher_date_start_date FROM parameters)) 
    AND (invv.voucher_date::DATE < (SELECT voucher_date_end_date FROM parameters))
    AND inv.status LIKE 'Paid'
GROUP BY 
    vendor_invoice_no,
    org.erp_code,
    org.name,
    invvl.external_account_number,
    invv.voucher_number,
    invv.export_to_accounting
ORDER BY vendor_name
;

