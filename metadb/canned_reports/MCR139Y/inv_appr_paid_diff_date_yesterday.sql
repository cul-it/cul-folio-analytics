--MCR139Y
--inv_appr_paid_diff_date_yesterday.sql
--last updated: 1/28/25
--written by Nancy Boluc, revised to metadb by Ann Crowley and Sharon Markus
--This query provides a list of approved invoices that have been paid at a different date. 
--Sometimes Folio won't allow an invoice to get paid and the invoice will only be paid at a 
--later day, after changes have been made.
--The data range for this query is currently set to show data for FY2025.
--The data date column shows the date this data was last updated.

/*
Main Tables:
 	Invoice_invoices
 	Invoice_vouchers
 	Organization_organizations

Filters:
	Approval_date
*/
WITH parameters AS (
    SELECT
        /* enter invoice payment start date and end date in YYYY-MM-DD format */
        '2024-07-01' ::DATE AS approval_date_start_date,
        '2025-06-30' ::DATE AS approval_date_end_date -- Excludes the selected date
)
SELECT 
	--current_date,
     TO_CHAR(CURRENT_DATE - INTERVAL '1 day', 'MM-DD-YYYY') AS data_date,		
        (SELECT
			approval_date_start_date::varchar
     	FROM
        	parameters) || ' to '::varchar || (
     	SELECT
        	approval_date_end_date::varchar
     	FROM
        	parameters) AS approval_date_range,
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
WHERE 
	inv.approval_date::DATE != inv.payment_date::DATE
	AND (inv.approval_date::DATE >= (SELECT approval_date_start_date FROM parameters)) 
	AND (inv.approval_date::DATE < (SELECT approval_date_end_date FROM parameters));
	
