WITH parameters AS (
    SELECT
        
        ''::VARCHAR AS invoice_line_status,-- Ex: Approved, Open, Reviewed,Paid
        ''::VARCHAR AS finance_fund_code
        
),

circs AS 
(SELECT 
        li.item_id,
        COUNT(li.loan_id) AS total_circs_in_folio
        
        FROM folio_reporting.loans_items AS li 
        GROUP BY li.item_id 
)

SELECT DISTINCT ON (po_instance.pol_instance_hrid)
        po_instance.pol_instance_hrid,
        po_instance.pol_location_name,
        he.holdings_hrid,
        itemext.item_hrid,
        po_instance.title,
        "is".subject,
        to_char(po_instance.created_date::DATE,'mm/dd/yyyy') AS request_create_date,
        to_char(po_lines.receipt_date::DATE,'mm/dd/yyyy') AS receipt_date,
        po_instance.pol_location_name,
        he.permanent_location_name AS holdings_location,
        he.call_number as holdings_call_number,
        CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.enumeration,' ',itemext.chronology, 
        CASE WHEN itemext.copy_number >'1' THEN concat ('c.',itemext.copy_number) ELSE '' END,' ',itemext.effective_call_number_suffix) AS whole_call_number,
        CASE WHEN he.call_number_type_name ILIKE '%Library of Congress%' THEN SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') ELSE ' - ' END AS lc_class,
        SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}') AS lc_class_number,
        itemext.material_type_name,
        po_lines.requester,
        po_lines.order_format,
        po_lines.po_line_number,
        CASE WHEN po_lines.rush = 'True' THEN 'Rush' ELSE '' END AS rush,
        invoice_lines.quantity,
        CASE WHEN invoice_lines.invoice_line_status IS NULL THEN 'No current status' ELSE invoice_lines.invoice_line_status END,
        invoice_invoices.vendor_invoice_no,
        ilfd.fund_name,
        ilfd.finance_fund_code,
        ilfd.fund_distribution_value,
        ilfd.invoice_line_total,
       CASE WHEN circs.total_circs_in_folio IS NULL THEN 0 ELSE circs.total_circs_in_folio END

FROM po_lines
        LEFT JOIN folio_reporting.po_instance 
        ON po_lines.po_line_number = po_instance.po_line_number
        
        LEFT JOIN folio_reporting.instance_subjects AS "is" 
        ON po_instance.pol_instance_id = "is".instance_id
        
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON po_instance.pol_instance_id = he.instance_id
        
        LEFT JOIN invoice_lines 
        on po_lines.id = invoice_lines.po_line_id
        
        LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd
        ON invoice_lines.id = ilfd.invoice_line_id
        
        LEFT JOIN invoice_invoices 
        ON invoice_lines.invoice_id = invoice_invoices.id
        
        LEFT JOIN folio_reporting.item_ext AS itemext 
        on he.holdings_id = itemext.holdings_record_id 
        
        LEFT JOIN circs 
        ON  itemext.item_id = circs.item_id

WHERE
 (invoice_lines.invoice_line_status = (SELECT invoice_line_status FROM parameters) OR (SELECT invoice_line_status FROM parameters) = '')
		AND (ilfd.finance_fund_code  = (SELECT finance_fund_code FROM parameters) OR (SELECT finance_fund_code FROM parameters) = '')
		AND po_lines.requester >''
        AND po_lines.requester not ilike '%Current issues in periodical room%'
      --  AND invoice_lines.invoice_line_status = 'Paid'
      --  AND ilfd.fund_name LIKE '521 %'
        AND ("is".subject_ordinality = 1  OR "is".subject_ordinality IS NULL)
        
GROUP BY
        po_instance.pol_instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        po_instance.title,
        po_instance.pol_location_name,
        ilfd.finance_fund_code,
        "is".subject,
        to_char(po_instance.created_date::DATE,'mm/dd/yyyy'),
        to_char(po_lines.receipt_date::DATE,'mm/dd/yyyy'),
        po_instance.pol_location_name,
        he.permanent_location_name,
        he.call_number,
        CONCAT(itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.enumeration,' ',itemext.chronology, 
        CASE WHEN itemext.copy_number >'1' THEN concat ('c.',itemext.copy_number) ELSE '' END,' ',itemext.effective_call_number_suffix),
        CASE WHEN he.call_number_type_name ILIKE '%Library of Congress%' THEN SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') ELSE ' - ' END,
        SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}'),
        itemext.material_type_name,
        po_lines.requester,
        po_lines.order_format,
        po_lines.po_line_number,
        CASE WHEN po_lines.rush = 'True' THEN 'Rush' ELSE '' END,
        invoice_lines.quantity,
        invoice_lines.invoice_line_status,
        invoice_invoices.vendor_invoice_no,
        ilfd.fund_name,
        ilfd.fund_distribution_value,
        ilfd.invoice_line_total,
        CASE WHEN circs.total_circs_in_folio IS NULL THEN 0 ELSE circs.total_circs_in_folio END

ORDER BY po_instance.pol_instance_hrid,
po_instance.title
;
