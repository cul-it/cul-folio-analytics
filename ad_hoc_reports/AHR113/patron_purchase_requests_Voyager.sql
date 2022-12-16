-AHR 113
--Patron Purchase Requests Voyager

-- This query finds all Voyager expenditures for a given Voyager fund number, purchase order type and range of fiscal years
-- Note that many Voyager funds were not migrated to Folio. This query pulls data by Voyager fund.


WITH parameters as 
(SELECT 
''::VARCHAR as fund_code_filter, -- Ex: 'p1166', '521', etc. 
''::VARCHAR AS po_type_description_filter, -- enter "Approval", “Firm Order”, “Continuation”, "Gift", "Exchange", "Depository" (or leave blank to get all)
'20' AS start_fiscal_year_id_filter -- enter the number that corresponds to the EARLIEST Fiscal year that you want. Ex: '19' will get FY19 through FY21. Leave blank to get everything.
),

recs as 
(SELECT DISTINCT
        fund.fund_name,
        fund.fund_code,
        ft.fund_type_name,
        pot.po_type_desc,
        pos.po_status_desc,
        bt.title,
        CASE WHEN ledger.ledger_name like 'Z%' THEN substring(ledger.ledger_name,2,8) ELSE ledger.ledger_name END AS ledger_name,
        invlif.amount/100 as inv_line_item_amount,
        li.bib_id::VARCHAR,
        lics.mfhd_id::VARCHAR,
        item.item_id::VARCHAR,
        item.historical_charges::integer,
        item.create_date::date,
        loc.location_name,
        mm.normalized_call_no,
        mm.display_call_no,
        SUBSTRING (mm.normalized_call_no,'^([a-zA-z]{1,3})') AS lc_class,
        SUBSTRING (mm.display_call_no,'\d{1,}\.{0,}\d{0,}') AS lc_class_number,
        bt.language,
        jllc."Language Name",
        bt.begin_pub_date,
        jlbfd.bib_format_display,
        instsubj.subject as primary_subject,
        concat(po.po_number,'-',li.line_item_number) as po_line_number,
        to_char(po.po_status_date::DATE,'mm/dd/yyyy') as po_status_date,
        lit.line_item_type_desc,
        lin.note as line_item_note,
        lin.print_note as line_item_print_note,
        inv.invoice_number,
        to_char(inv.invoice_date::DATE,'mm/dd/yyyy') as invoice_date,
        invstatus.invoice_status_desc,
        to_char(inv.invoice_status_date::DATE,'mm/dd/yyyy') as invoice_status_date,
        inv.invoice_status_date::date - inv.invoice_date::DATE as days_til_filled,
        li.requestor,
        invlif.split_fund_seq,
        vendor.vendor_name,
        (invlif.percentage/1000000)::NUMERIC(12,2) as pct,        
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
        
        left join vger.mfhd_item as mi 
        on mm.mfhd_id = mi.mfhd_id
        
        left join vger.item 
        on mi.item_id = item.item_id
        
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
        AND (((SELECT start_fiscal_year_id_filter FROM parameters) ='') OR (ledger.fiscal_year_id >= (SELECT start_fiscal_year_id_filter:: NUMERIC FROM parameters))) 
        and li.requestor >'' --and recs.requestor not ilike '%res%'
),

foo as 
(select distinct 
        to_char (current_date::date,'mm/dd/yyyy') as todays_date,
        recs.ledger_name, 
        recs.title,
        recs.bib_id,
        recs.mfhd_id,
        recs.item_id,
        recs.lc_class,
        recs.lc_class_number,
        recs.display_call_no,
        recs.primary_subject,
        recs.requestor,
        recs.invoice_date::date,
        recs.invoice_status_date::DATE,
        recs.invoice_status_desc,
        recs.days_til_filled,
        recs.fund_code,
        recs.inv_line_item_amount,
        case when recs.historical_charges is null then 0 else recs.historical_charges end as voyager_checkouts,
        count (li.loan_id) as folio_checkouts

from recs 

left join folio_reporting.loans_items as li 
on recs.item_id::varchar = li.hrid

where recs.requestor >'' and recs.requestor !='0'--not ilike '%res%'

group by 
        to_char (current_date::date,'mm/dd/yyyy'),
        recs.ledger_name, 
        recs.title,
        recs.bib_id,
        recs.mfhd_id,
        recs.item_id,
        recs.lc_class,
        recs.lc_class_number,
        recs.display_call_no,
        recs.primary_subject,
        recs.requestor,
        recs.invoice_date::date,
        recs.invoice_status_date::DATE,
        recs.invoice_status_desc,
        recs.days_til_filled,
        recs.fund_code,
        recs.inv_line_item_amount,
        recs.historical_charges
)

select 
foo.todays_date,
        foo.ledger_name, 
        foo.title,
        foo.bib_id,
        foo.requestor,
        foo.primary_subject,
        foo.lc_class,
        foo.lc_class_number,
        foo.display_call_no,
        to_char (foo.invoice_date::date,'mm/dd/yyyy') as date_requested,
        to_char (foo.invoice_status_date::DATE,'mm/dd/yyyy') as date_received,
        foo.invoice_status_desc,
        foo.days_til_filled,
        foo.fund_code,
        foo.inv_line_item_amount,
        sum (foo.voyager_checkouts + foo.folio_checkouts) as total_checkouts

from foo 

group by 
        foo.todays_date,
        foo.ledger_name, 
        foo.title,
        foo.bib_id,
        foo.requestor,
        foo.primary_subject,
        foo.lc_class,
        foo.lc_class_number,
        foo.display_call_no,
        to_char (foo.invoice_date::date,'mm/dd/yyyy'),
        to_char (foo.invoice_status_date::DATE,'mm/dd/yyyy'),
        foo.invoice_status_desc,
        foo.days_til_filled,
        foo.fund_code,
        foo.inv_line_item_amount
        
order by foo.ledger_name, foo.title, foo.fund_code
;
        
--ORDER BY title, ledger_name, po_line_number*/
