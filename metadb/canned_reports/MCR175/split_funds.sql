--MCR175
--Split funds
--This query shows split fund payments for all finance groups. 
--Query writer: Joanne Leary (jl41)
--Posted on: 7/25/24

WITH parameters AS (
    SELECT
        
        ''::VARCHAR AS finance_group_name,-- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        ''::VARCHAR AS transaction_fund_code,-- Ex: 999, 521, p1162 etc.
        ''::VARCHAR AS transaction_fiscal_year--Ex: FY2022, FY2023
),

main as 
(
SELECT distinct
            CURRENT_DATE,
            fy.code AS transaction_fiscal_year_code,
            pol.title_or_package AS po_line_title_or_package,
            ii.hrid as pol_hrid,
            ii.id as instance_id,
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
            count (ilfd.invoice_line_id) as count_of_invl_ids,
    		count (distinct ilfd.fund_distribution_id) as count_of_fund_dist_ids,
            CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS transaction_amount,
           -- ROUND ((fti.transaction_amount::numeric / fti.invoice_line_total::numeric *100), 2)  AS perc_spent
            ROUND ((fti.transaction_amount / fti.invoice_line_total::numeric) *100, 2) AS perc_spent
            
FROM folio_derived.finance_transaction_invoices fti --folio_reporting.finance_transaction_invoices AS fti 
            left join folio_invoice.invoice_lines__t as invl on fti.invoice_line_id = invl.id --LEFT JOIN invoice_lines AS invl ON invl.id = fti.invoice_line_id 
            left join folio_invoice.invoices__t as inv on inv.id = fti.invoice_id -- LEFT JOIN invoice_invoices AS inv ON inv.id = fti.invoice_id 
            left join folio_orders.po_line__t as pol on pol.id = invl.po_line_id --LEFT JOIN po_lines AS pol ON pol.id = invl.po_line_id 
            left join folio_orders.purchase_order__t as ppo on ppo.id = pol.purchase_order_id --LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id 
            left join folio_derived.invoice_lines_fund_distributions ilfd on invl.id = ilfd.invoice_line_id --left join folio_reporting.invoice_lines_fund_distributions as ilfd on invl.id = ilfd.invoice_line_id
            left join folio_inventory.instance__t as ii on pol.instance_id::UUID = ii.id::UUID --left join inventory_instances as ii on pol.instance_id = ii.id
            left join folio_finance.fund__t as ff on ff.code = fti.effective_fund_code --LEFT JOIN finance_funds AS ff ON ff.code = fti.effective_fund_code
            left join folio_finance.fiscal_year__t as fy on fy.id = fti.transaction_fiscal_year_id --LEFT JOIN finance_fiscal_years AS fy ON fy.id = fti.transaction_fiscal_year_id
            left join folio_finance.group_fund_fiscal_year__t as fgffy on fgffy.fund_id = ff.id and fti.transaction_fiscal_year_id = fgffy.fiscal_year_id --LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = ff.id AND fti.transaction_fiscal_year_id = fgffy.fiscal_year_id
            left join folio_finance.groups__t as fg on fg.id = fgffy.group_id --LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id 
            left join folio_finance.expense_class__t as fec on fec.id = fti.transaction_expense_class_id --LEFT JOIN finance_expense_classes AS fec ON fec.id = fti.transaction_expense_class_id
WHERE 

			(fti.invoice_line_total::numeric > 0 or fti.invoice_line_total::numeric < 0) 
            AND ((fti.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
            AND ((fy.code  = (SELECT transaction_fiscal_year FROM parameters)) OR ((SELECT transaction_fiscal_year FROM parameters) = ''))
            AND ((fg.name  = (SELECT finance_group_name FROM parameters)) OR ((SELECT finance_group_name FROM parameters) = ''))
			--and ROUND ((fti.transaction_amount / fti.invoice_line_total::numeric) *100, 2) < 100
			--and ROUND ((fti.transaction_amount / fti.invoice_line_total::numeric) *100, 2) != -100
			
GROUP BY 
			CURRENT_DATE,
            fy.code,
            pol.title_or_package,
            ii.id,
            ii.hrid,
            fti.invoice_vendor_name,
            inv.vendor_invoice_no,
        	CASE WHEN inv.note ISNULL THEN 'N/A' ELSE inv.note END,
            pol.po_line_number,
            inv.status,
            inv.payment_date::date,
            fti.effective_fund_code,
            fg.name,
            fec.name,
            fti.transaction_type,
            CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END,
            ROUND ((fti.transaction_amount/fti.invoice_line_total::numeric *100), 2) 
                        
HAVING 	 
        count (distinct ilfd.fund_distribution_id) > 1
) 

-- This subquery finds just the split fund invoice payments where one of the funds was the fund specified in the parameters
select distinct
            CURRENT_DATE,
            fy.code AS transaction_fiscal_year_code,
            pol.title_or_package AS po_line_title_or_package,
            main.pol_hrid,
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
            ROUND ((fti.transaction_amount/fti.invoice_line_total::numeric *100), 2)  AS perc_spent 
            
FROM folio_derived.finance_transaction_invoices fti --folio_reporting.finance_transaction_invoices AS fti 
            left join folio_invoice.invoice_lines__t as invl on invl.id = fti.invoice_line_id --LEFT JOIN invoice_lines AS invl ON invl.id = fti.invoice_line_id 
            left join folio_invoice.invoices__t as inv on inv.id = fti.invoice_id -- LEFT JOIN invoice_invoices AS inv ON inv.id = fti.invoice_id 
            left join folio_orders.po_line__t as pol on pol.id = invl.po_line_id --LEFT JOIN po_lines AS pol ON pol.id = invl.po_line_id 
            left join folio_orders.purchase_order__t as ppo on ppo.id = pol.purchase_order_id --LEFT JOIN po_purchase_orders AS ppo ON ppo.id = pol.purchase_order_id 
            left join folio_finance.fund__t as ff on ff.code = fti.effective_fund_code --LEFT JOIN finance_funds AS ff ON ff.code = fti.effective_fund_code
            
            left join folio_finance.fiscal_year__t as fy on fy.id = fti.transaction_fiscal_year_id --LEFT JOIN finance_fiscal_years AS fy ON fy.id = fti.transaction_fiscal_year_id
            left join folio_finance.group_fund_fiscal_year__t as fgffy on fgffy.fund_id = ff.id and fti.transaction_fiscal_year_id = fgffy.fiscal_year_id --LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = ff.id AND fti.transaction_fiscal_year_id = fgffy.fiscal_year_id
            left join folio_finance.groups__t as fg on fg.id = fgffy.group_id --LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id 
            left join folio_finance.expense_class__t as fec on fec.id = fti.transaction_expense_class_id --LEFT JOIN finance_expense_classes AS fec ON fec.id = fti.transaction_expense_class_id
			left join folio_derived.invoice_lines_fund_distributions ilfd on invl.id = ilfd.invoice_line_id           
            --LEFT JOIN finance_fiscal_years AS fy ON fy.id = fti.transaction_fiscal_year_id
            --LEFT JOIN finance_group_fund_fiscal_years AS fgffy ON fgffy.fund_id = ff.id AND fti.transaction_fiscal_year_id = fgffy.fiscal_year_id
            --LEFT JOIN finance_groups AS fg ON fg.id = fgffy.group_id 
           -- LEFT JOIN finance_expense_classes AS fec ON fec.id = fti.transaction_expense_class_id
            --LEFT JOIN folio_reporting.invoice_lines_fund_distributions AS ilfd ON invl.id = ilfd.invoice_line_id
            INNER JOIN main ON pol.po_line_number = main.po_line_number
                AND main.vendor_invoice_no = inv.vendor_invoice_no
                AND main.payment_date::DATE = inv.payment_date::DATE
                --and main.instance_id = pol.instance_id
                
WHERE 
			(fti.invoice_line_total::numeric > 0 OR fti.invoice_line_total::numeric < 0) 
			AND ROUND ((fti.transaction_amount/fti.invoice_line_total::numeric *100), 2) < 100
			AND ROUND ((fti.transaction_amount / fti.invoice_line_total::numeric) *100, 2) != -100
            AND ((fy.code  = (SELECT transaction_fiscal_year FROM parameters)) OR ((SELECT transaction_fiscal_year FROM parameters) = ''))
;
