WITH parameters AS (
    SELECT
        /* Enter an invoice payment date range, OR enter a fiscal year (NOT BOTH) */ 
    
                 /* For invoice payment date range, enter the start date and end date in YYYY-MM-DD format */
    
                ''AS start_date,
                ''AS end_date,
        
                 /* For Fiscal Year, enter the fiscal year in the following format: 'FY2023' */
                        
                 (:fiscal_year)::VARCHAR AS fiscal_year_filter,
        
        /* Enter a fund group name: 'Central', 'Humanities', 'Area Studies', 'Rare & Distinctive', 'Law', 'Sciences', etc. 
         * see complete list at https://confluence.cornell.edu/display/folioreporting/Fund+Groups */
        ''::VARCHAR AS fund_group_filter,
        
        /* Enter the fund type, such as 'Endowment - Unrestricted', 'Income - Restricted' etc. (Case sensitive) 
         * See complete list at https://confluence.cornell.edu/display/folioreporting/Fund+Types */
        ''::VARCHAR AS fund_type_filter,
        
        /* Enter an order format: 'Physical Resource', 'Electronic Resource', 'P/E Mix', or 'Other' */
        ''::VARCHAR AS order_format_filter,
        
        /* Enter the Expense Class name (case-sensitive) -- see complete list at https://confluence.cornell.edu/display/folioreporting/Expense+Classes */
        ''::VARCHAR AS expense_class_filter,
        
        /* Enter transaction type 'Credit' or 'Payment' */
        ''::VARCHAR AS  transaction_type_filter,
        
        /* Enter the fund code - Example: p2754, 2030, 410, etc. */
        ''::VARCHAR AS transaction_fund_code_filter
),

fitrin_wrap AS (
    -- wrapping transactions to_fund and from_fund to one fund_id
        SELECT
                fitrin.transaction_id,
                fitrin.invoice_payment_date,
                fitrin.transaction_type,
                fitrin.transaction_expense_class_id,
                fitrin.transaction_fiscal_year_id,
                fitrin.po_line_id,
                ii.vendor_invoice_no,
                
                CASE 
                        WHEN fitrin.transaction_from_fund_id  IS NOT NULL AND fitrin.transaction_to_fund_id IS NULL THEN 'TRANSACTION FROM FUND'
                        WHEN fitrin.transaction_from_fund_id IS NULL AND fitrin.transaction_to_fund_id IS NOT NULL THEN 'TRANSACTION TO FUND'
                        ELSE 'TRANSACTION WITH FROM AND TO FUND' END AS transaction_fund_from_to,
                CASE 
                        WHEN fitrin.transaction_from_fund_id IS NOT NULL AND fitrin.transaction_to_fund_id IS NULL THEN fitrin.transaction_from_fund_id
                        WHEN fitrin.transaction_from_fund_id IS NULL AND fitrin.transaction_to_fund_id IS NOT NULL THEN fitrin.transaction_to_fund_id
                        ELSE 'has from and to fund' END AS fund_id,
                CASE 
                        WHEN fitrin.transaction_from_fund_code IS NOT NULL AND fitrin.transaction_to_fund_code IS NULL THEN fitrin.transaction_from_fund_code
                        WHEN fitrin.transaction_from_fund_code IS NULL AND fitrin.transaction_to_fund_code IS NOT NULL THEN fitrin.transaction_to_fund_code
                        ELSE 'has from and to fund' END AS fund_code,   
                CASE WHEN fitrin.transaction_type = 'Credit' AND fitrin.transaction_amount >.0001 THEN fitrin.transaction_amount *-1 
                        ELSE fitrin.transaction_amount END AS transaction_amount,    
                        fitrin.transaction_amount AS transaction_amount_source           
 FROM
        folio_reporting.finance_transaction_invoices AS fitrin
        left join invoice_invoices as ii 
         on fitrin.invoice_id = ii.id
        
)

SELECT
        CURRENT_DATE,
        ffy.code AS fiscal_year,
        TO_CHAR (fitrin.invoice_payment_date::TIMESTAMP,'mm/dd/yyyy HH:MI am') as inv_pymt_date,
        pol.po_line_number AS po_line_number,
        fitrin.vendor_invoice_no,
        pol.order_format,
        fingrp.name AS fund_group,
        finfun.name AS fund_name,
        finfuntyp.name AS fund_type,
        finfun.code AS fund_code,
        finfun.description AS fund_description,
        fitrin.transaction_type AS transaction_type,
        finexpclass.name AS expense_class,
        fitrin.fund_code AS transaction_fund_code,
        fitrin.transaction_fund_from_to AS fund_transaction_source,
        fitrin.transaction_amount AS po_line_transaction_amount
        --fitrin.transaction_amount_source AS transaction_amount_source

FROM finance_funds AS finfun
LEFT JOIN fitrin_wrap AS fitrin ON finfun.id = fitrin.fund_id
LEFT JOIN finance_fund_types AS finfuntyp ON finfuntyp.id = finfun.fund_type_id
LEFT JOIN finance_expense_classes AS finexpclass ON finexpclass.id = fitrin.transaction_expense_class_id
LEFT JOIN po_lines AS pol ON pol.id = fitrin.po_line_id
LEFT JOIN finance_group_fund_fiscal_years AS fingrpfund ON fingrpfund.fund_id = finfun.id
LEFT JOIN finance_groups AS fingrp ON fingrp.id = fingrpfund.group_id
LEFT JOIN finance_fiscal_years AS ffy ON fitrin.transaction_fiscal_year_id = ffy.id

WHERE   
        ((fitrin.transaction_type = 'Credit') OR (fitrin.transaction_type = 'Payment'))
        AND ((ffy.code = (SELECT fiscal_year_filter FROM parameters)) OR ((SELECT fiscal_year_filter FROM parameters) = ''))
        AND ((SELECT start_date FROM parameters) ='' OR (fitrin.invoice_payment_date::date >= (SELECT start_date FROM parameters)::DATE))
        AND ((SELECT end_date FROM parameters) ='' OR (fitrin.invoice_payment_date::date < (SELECT end_date FROM parameters)::DATE)) 
        AND ((finfuntyp.name ILIKE (SELECT fund_type_filter FROM parameters)) OR 
                ((SELECT fund_type_filter FROM parameters) = ''))        
        AND ((fingrp.name = (SELECT fund_group_filter FROM parameters)) OR 
                ((SELECT fund_group_filter FROM parameters) = ''))                               
        AND ((finexpclass.name = (SELECT expense_class_filter FROM parameters)) OR 
                ((SELECT expense_class_filter FROM parameters) = ''))
        AND ((fitrin.transaction_type = (SELECT transaction_type_filter FROM parameters)) OR 
                ((SELECT transaction_type_filter FROM parameters) = ''))
        AND ((fitrin.fund_code = (SELECT transaction_fund_code_filter FROM parameters)) OR 
                ((SELECT transaction_fund_code_filter FROM parameters) = ''))
        AND (((SELECT order_format_filter FROM parameters) = '') OR (pol.order_format = (SELECT order_format_filter FROM parameters)))
     
GROUP BY
        ffy.code,
        fitrin.invoice_payment_date,
        pol.po_line_number,
        pol.order_format,
        fitrin.vendor_invoice_no,
        fund_group,
        fund_name,
        fund_type,
        finfun.code,
        fund_description,
        fitrin.transaction_type,
        expense_class,
        fitrin.transaction_id,
        fitrin.fund_code,
        fitrin.transaction_fund_from_to,
        fitrin.transaction_amount,
        fitrin.transaction_amount_source
        ;

