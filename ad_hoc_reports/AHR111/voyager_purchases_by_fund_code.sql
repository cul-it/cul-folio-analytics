WITH parameters as 
(SELECT 
'p1166'::VARCHAR as fund_code_filter, -- Ex: 'p1166', '521', ‘6610’, etc. 
'Firm Order'::VARCHAR AS po_type_description_filter, -- enter "Approval", “Firm Order”, “Continuation”, "Gift", "Exchange", "Depository" (or leave blank to get all)
'15' AS start_fiscal_year_id_filter -- enter the number that corresponds to the EARLIEST Fiscal year that you want. Ex: '19' will get FY19 through FY21. Leave blank to get everything.
)

SELECT DISTINCT

        bt.title,
        CASE WHEN ledger.ledger_name like 'Z%' THEN substring(ledger.ledger_name,2,8) ELSE ledger.ledger_name END AS ledger_name,
        li.bib_id::VARCHAR,
        lics.mfhd_id::VARCHAR,
        loc.location_name,
        mm.normalized_call_no,
        mm.display_call_no,
        SUBSTRING (mm.normalized_call_no,'^([a-zA-z]{1,3})') AS lc_class,
        SUBSTRING (mm.display_call_no,'\d{1,}\.{0,}\d{0,}')::NUMERIC AS lc_class_number,
        bt.language,
        jllc."Language Name",
        bt.begin_pub_date,
        jlbfd.bib_format_display,
        instsubj.subject as primary_subject,
        concat(po.po_number,'-',li.line_item_number) as po_line_number,
        pot.po_type_desc,
        pos.po_status_desc,
        to_char(po.po_status_date::DATE,'mm/dd/yyyy') as po_status_date,
        lit.line_item_type_desc,
        lin.note as line_item_note,
        lin.print_note as line_item_print_note,
        inv.invoice_number,
        to_char(inv.invoice_date::DATE,'mm/dd/yyyy') as invoice_date,
        invstatus.invoice_status_desc,
        to_char(inv.invoice_status_date::DATE,'mm/dd/yyyy') as invoice_status_date,
        li.requestor,
        invlif.split_fund_seq,
        vendor.vendor_name,
        fund.fund_name,
        fund.fund_code,
        ft.fund_type_name,
        (invlif.percentage/1000000)::NUMERIC(12,2) as pct,
        invlif.amount/100 as inv_line_item_amount,
        inv.voucher_number
        
FROM 
        vger.purchase_order AS po 
        LEFT JOIN vger.po_type AS pot 
        ON po.po_type = pot.po_type
        
        LEFT JOIN vger.po_status AS pos 
        ON po.po_status = pos.po_status
        
        LEFT JOIN vger.line_item AS li 
        ON po.po_id = li.po_id
        
        LEFT JOIN vger.bib_text AS bt 
        ON li.bib_id = bt.bib_id
        
        LEFT JOIN folio_reporting.instance_subjects AS instsubj 
        ON bt.bib_id::VARCHAR = instsubj.instance_hrid
        
        LEFT JOIN local.jl_language_codes AS jllc 
        ON bt.language = jllc."Language Code"
        
        LEFT JOIN local.jl_bib_format_display_csv AS jlbfd 
        ON bt.bib_format = jlbfd.bib_format
        
        LEFT JOIN vger.line_item_type AS lit 
        ON li.line_item_type = lit.line_item_type 
        
        LEFT JOIN vger.line_item_copy AS lic 
        ON li.line_item_id = lic.line_item_id
        
        LEFT JOIN vger.line_item_notes AS lin 
        ON li.line_item_id = lin.line_item_id
        
        LEFT JOIN vger.line_item_copy_status AS lics 
        ON lic.line_item_id = lics.line_item_id
        
        LEFT JOIN vger.mfhd_master AS mm 
        ON lics.mfhd_id = mm.mfhd_id
        
        LEFT JOIN vger.location AS loc
        ON mm.location_id = loc.location_id
        
        LEFT JOIN vger.invoice_line_item_funds AS invlif 
        ON lics.copy_id = invlif.copy_id
        
        LEFT JOIN vger.fund 
        ON invlif.fund_id = fund.fund_id
                AND invlif.ledger_id = fund.ledger_id
        
        LEFT JOIN vger.fund_type AS ft 
        ON fund.fund_type = ft.fund_type_id
                
        LEFT JOIN vger.ledger 
        ON fund.ledger_id = ledger.ledger_id

        LEFT JOIN vger.invoice_line_item AS invli 
        ON invlif.inv_line_item_id = invli.inv_line_item_id
        
        LEFT JOIN vger.invoice AS inv 
        ON invli.invoice_id = inv.invoice_id
        
        LEFT JOIN vger.invoice_status AS invstatus 
        ON inv.invoice_status = invstatus.invoice_status
        
        LEFT JOIN vger.vendor 
        ON inv.vendor_id = vendor.vendor_id 
        
        
WHERE
        (fund.fund_code = (SELECT fund_code_filter FROM parameters) OR (SELECT fund_code_filter FROM parameters) = '')
        AND ((pot.po_type_desc = (SELECT po_type_description_filter FROM parameters)) OR ((SELECT po_type_description_filter FROM parameters)=''))
        AND ((instsubj.subject_ordinality = 1) OR (instsubj.subject_ordinality IS NULL))
        AND (((SELECT start_fiscal_year_id_filter FROM parameters) = '') OR (ledger.fiscal_year_id >= (SELECT start_fiscal_year_id_filter:: NUMERIC FROM parameters))) 

        
ORDER BY title, ledger_name, po_line_number
; 
