-- CR175A: this is a revision of the orders split funds query (CR175). This query finds invoices where multiple funds were used,  
-- either belonging to the same fund group or to different fund groups. (Ex: Law/Social Sciences; Sciences/Medical; Social Sciences/Humanities/Central, etc.)
 
WITH parameters AS (
    SELECT
        
        ''::VARCHAR AS finance_group_name,-- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        ''::VARCHAR AS transaction_fund_code,-- Ex: 999, 521, p1162 etc.
        ''::VARCHAR AS transaction_fiscal_year--Ex: FY2022, FY2023
),
invl_count AS ( -- This is to get the fund associated with each purchase order line to later in the main query identify only those that have more than one distinct fund per purchase order line.
            WITH invl_funds_distr AS (
    SELECT
        id AS invoice_line_id,
        json_extract_path_text(dist.data, 'code') AS fund_distribution_code,
        json_extract_path_text(dist.DATA,'encumbrance') AS fund_encumbrance,
        json_extract_path_text(dist.data, 'fundId') AS fund_distribution_id,
        json_extract_path_text(dist.data, 'expenseClassId') AS fund_expense_class_id,
        json_extract_path_text(dist.data, 'distributionType') AS fund_distribution_type,
        json_extract_path_text(dist.data, 'value')::numeric AS fund_distribution_value
    FROM
        invoice_lines AS il
        CROSS JOIN json_array_elements(json_extract_path(data, 'fundDistributions')) WITH ORDINALITY AS dist(data)
)
            SELECT 
                        ppo.po_number,
                        po_line_number,
                        fdist.invoice_line_Id,
                        COUNT (invoice_line_id) AS invoice_line_count,
                        COUNT (DISTINCT fund_distribution_id) AS fund_id_count
            FROM 
                        invoice_lines AS invl
                        
                        LEFT JOIN po_lines AS pol ON pol.id = invl.po_line_id 
                        LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id 
                        LEFT JOIN invl_funds_distr AS fdist ON fdist.invoice_line_id = invl.id
            GROUP BY 
                        ppo.po_number,
                        pol.po_line_number,
                        fdist.invoice_line_Id
),
pol_hrid_extract AS ( --This is to get the hrid for each instance id
            SELECT 
                        id, 
                        hrid 
            FROM inventory_instances
),
 
main as 
(SELECT 
            CURRENT_DATE,
            fy.code AS transaction_fiscal_year_code,
            pol.title_or_package AS po_line_title_or_package,
            hridext.hrid AS pol_hrid,
            fti.invoice_vendor_name,
            inv.vendor_invoice_no,
        CASE WHEN inv.note ISNULL THEN 'N/A' ELSE inv.note END AS invoice_note,
            pol.po_line_number,
            inv.status AS invoice_status,
            inv.payment_date::date AS payment_date,
            fti.effective_fund_code,
            fg.name AS fund_group_name,
            fec.name AS expense_class,
            fti.transaction_type,
            CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS transaction_amount,
            ROUND ((fti.transaction_amount::numeric/fti.invoice_line_total::numeric *100), 2)  AS perc_spent            
FROM folio_reporting.finance_transaction_invoices AS fti 
            LEFT JOIN invoice_lines AS invl ON invl.id = fti.invoice_line_id 
            LEFT JOIN invoice_invoices AS inv ON inv.id = fti.invoice_id 
            LEFT JOIN po_lines AS pol ON pol.id = invl.po_line_id 
            LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id 
            LEFT JOIN invl_count AS invlc ON invlc.invoice_line_id = invl.id
            LEFT JOIN pol_hrid_extract AS hridext ON hridext.id = pol.instance_id
            LEFT JOIN finance_funds AS ff ON ff.code = fti.effective_fund_code
            LEFT JOIN finance_fiscal_years AS fy ON fy.id = fti.transaction_fiscal_year_id
            LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = ff.id AND fti.transaction_fiscal_year_id = fgffy.fiscal_year_id
            LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id 
            LEFT JOIN finance_expense_classes AS fec ON fec.id = fti.transaction_expense_class_id
WHERE 
            invoice_line_count >1
            AND fund_id_count >1
            AND ((fti.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
            AND ((fy.code  = (SELECT transaction_fiscal_year FROM parameters)) OR ((SELECT transaction_fiscal_year FROM parameters) = ''))
            AND ((fg.name  = (SELECT finance_group_name FROM parameters)) OR ((SELECT finance_group_name FROM parameters) = '')) 
)
 
-- This subquery finds just the split fund invoice payments where one of the funds was the fund specified in the parameters
select distinct
                        CURRENT_DATE,
            fy.code AS transaction_fiscal_year_code,
            pol.title_or_package AS po_line_title_or_package,
            hridext.hrid AS pol_hrid,
            fti.invoice_vendor_name,
            inv.vendor_invoice_no,
        CASE WHEN inv.note ISNULL THEN 'N/A' ELSE inv.note END AS invoice_note,
            pol.po_line_number,
            inv.status AS invoice_status,
            inv.payment_date::date AS payment_date,
            fti.effective_fund_code,
            fg.name AS fund_group_name,
            fec.name AS expense_class,
            fti.transaction_type,
            CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS transaction_amount,
            ROUND ((fti.transaction_amount::numeric/fti.invoice_line_total::numeric *100), 2)  AS perc_spent            
FROM folio_reporting.finance_transaction_invoices AS fti 
            LEFT JOIN invoice_lines AS invl ON invl.id = fti.invoice_line_id 
            LEFT JOIN invoice_invoices AS inv ON inv.id = fti.invoice_id 
            LEFT JOIN po_lines AS pol ON pol.id = invl.po_line_id 
            LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id 
            LEFT JOIN invl_count AS invlc ON invlc.invoice_line_id = invl.id
            LEFT JOIN pol_hrid_extract AS hridext ON hridext.id = pol.instance_id
            LEFT JOIN finance_funds AS ff ON ff.code = fti.effective_fund_code
            LEFT JOIN finance_fiscal_years AS fy ON fy.id = fti.transaction_fiscal_year_id
            LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = ff.id AND fti.transaction_fiscal_year_id = fgffy.fiscal_year_id
            LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id 
            LEFT JOIN finance_expense_classes AS fec ON fec.id = fti.transaction_expense_class_id
            inner join main on pol.po_line_number = main.po_line_number
                and main.vendor_invoice_no = inv.vendor_invoice_no
                and main.payment_date::DATE = inv.payment_date::DATE
WHERE 
            invoice_line_count >1
            AND fund_id_count >1            
            AND ((fy.code  = (SELECT transaction_fiscal_year FROM parameters)) OR ((SELECT transaction_fiscal_year FROM parameters) = ''))
;                                   
