--CR134 Approved Invoices with bib data
--This query provides the list of approved invoices within a date range along with vendor name, finance group name, 
--vendor invoice number, fund details, purchase order details, language, instance subject, fund type, expense class and bibliographic format.
--In cases where the quantity was incorrectly entered as zero, this query replaces zero with 1 
WITH parameters AS (
    SELECT
        '' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::varchar as order_type_filter, -- Ongoing or One-Time
        ''::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        ''::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        ''::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023 etc.
        ''::VARCHAR AS po_number,
        ''::VARCHAR AS format_name, -- Ex: Book, Serial, Textual Resource, etc.
        ''::VARCHAR AS expense_class-- Ex:Physical Res - one-time perpetual, One time Electronic Res - Perpetual etc.
),   
format_extract as (
        SELECT 
         sm.instance_id::uuid,
         substring(sm.content,7,2) AS bib_format_code,
         jl.bib_format_display
        FROM
        srs_marctab as sm
        LEFT JOIN local.jl_bib_format_display_csv AS jl ON substring(sm.content,7,2) = jl.bib_format
        WHERE sm.field = '000' 
),
instance_subject_extract as (
        SELECT
        instances.id AS instance_id,
        instances.hrid AS instance_hrid,
        subjects.data #>> '{}' AS subject,
        subjects.ordinality AS subject_ordinality
        FROM
        inventory_instances AS instances
        CROSS JOIN LATERAL json_array_elements(json_extract_path(data, 'subjects'))
        WITH ORDINALITY AS subjects (data)
        WHERE subjects.ordinality = '1'
),
locations as 
(SELECT
    pol.id AS pol_id,
    json_extract_path_text(locations.data, 'quantity') AS pol_location_qty,
    json_extract_path_text(locations.data, 'quantityElectronic') AS pol_loc_qty_elec,
    json_extract_path_text(locations.data, 'quantityPhysical') AS pol_loc_qty_phys,      
    CASE WHEN json_extract_path_text(locations.data, 'locationId') IS NOT NULL THEN json_extract_path_text(locations.data, 'locationId') 
         ELSE ih.permanent_location_id
    END AS pol_location_id,      
    CASE WHEN il.name IS NOT NULL THEN il.name
         ELSE il2.name
    END AS pol_location_name,
    CASE WHEN il.name IS NOT NULL THEN 'pol_location'
         WHEN il2.name IS NOT NULL THEN 'pol_holding'
         ELSE 'no_source'
    END AS pol_location_source
FROM
    po_lines AS pol
    CROSS JOIN json_array_elements(json_extract_path(data, 'locations')) AS locations (data)
    LEFT JOIN inventory_holdings AS ih ON json_extract_path_text(locations.data, 'holdingId') = ih.id
    LEFT JOIN inventory_locations AS il ON json_extract_path_text(locations.data, 'locationId') = il.id
    LEFT JOIN inventory_locations AS il2 ON ih.permanent_location_id = il2.id
),
pol_holdings_id AS (
        SELECT
        pol.id AS pol_id,
        json_extract_path_text(locations.data, 'locationId') AS pol_loc_id,
        json_extract_path_text(locations.data, 'holdingId') AS pol_holding_id

                FROM
               po_lines AS pol
               CROSS JOIN json_array_elements(json_extract_path(data, 'locations')) AS locations (data)
),
  finance_transaction_invoices_ext AS (
        SELECT
        fti.transaction_id AS transaction_id,      
        fti.invoice_date::date,
                fti.invoice_payment_date::DATE AS invoice_payment_date,
                fti.transaction_fiscal_year_id,
                ffy.code AS fiscal_year_code,
                fti.invoice_id,
                fti.invoice_line_id,
                fti.po_line_id,
                fl.name AS finance_ledger_name,
                fti.transaction_expense_class_id AS expense_class,
                fti.invoice_vendor_name,
                fti.transaction_type,
                fti.transaction_amount,
                fti.effective_fund_id AS effective_fund_id,
                fti.effective_fund_code AS effective_fund_code,
                fft.name AS fund_type_name,
                CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS effective_transaction_amount,
                ff.external_account_no AS external_account_no
FROM
                folio_reporting.finance_transaction_invoices AS fti
                LEFT JOIN finance_funds AS ff ON ff.code = fti.effective_fund_code
                LEFT JOIN finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id
                LEFT JOIN finance_fund_types AS fft ON fft.id = ff.fund_type_id
                LEFT JOIN finance_ledgers AS fl ON ff.ledger_id = fl.id               
),
fund_fiscal_year_group AS (
SELECT
    FGFFY.id AS group_fund_fiscal_year_id,
    FG.name AS finance_group_name,
    ff.id AS fund_id,
    ff.code AS fund_code,
    fgffy.fiscal_year_id AS fund_fiscal_year_id,
    ffy.code AS fiscal_year_code
FROM
    finance_groups AS FG 
    LEFT JOIN finance_group_fund_fiscal_years AS FGFFY ON fg.id = fgffy.group_id
    LEFT JOIN finance_fiscal_years AS ffy ON ffy. id = fgffy.fiscal_year_id
    LEFT JOIN finance_funds AS FF ON FF.id = fgffy.fund_id
WHERE ((ffy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
ORDER BY ff.code

),
new_quantity AS 
        (SELECT 
        id AS invoice_line_id,
       CASE WHEN quantity = 0
                THEN 1
                ELSE quantity
                        END AS fixed_quantity
        FROM invoice_lines 
)
-- MAIN QUERY
SELECT distinct
        current_date AS current_date,           
       CASE WHEN 
                        ((SELECT
                        payment_date_start_date::varchar
                        FROM
                parameters)= ''
        OR      (SELECT
                payment_date_end_date::varchar
                        FROM
                parameters) ='')
                THEN 'Not Selected'
                ELSE
                        (SELECT payment_date_start_date::varchar
                FROM parameters) || ' to '::varchar || 
                (SELECT payment_date_end_date::varchar
                                FROM parameters)
                        END AS payment_date_range,       
       ftie.transaction_id AS transaction_id,
       --iext.title AS instance_title,
       replace(replace (iext.title, chr(13), ''),chr(10),'') AS instance_title,--updated code to get rid of carriage returns
       iext.instance_hrid,
       STRING_AGG (distinct locations.pol_location_name,' | ') as location_name,
       po.order_type,
       pol.order_format,
       ftie.invoice_date::date,
       inv.payment_date::DATE as invoice_payment_date,
       ftie.effective_transaction_amount/fq.fixed_quantity AS transaction_amount_per_qty,
       ftie.effective_transaction_amount,
       ftie.transaction_type,
       ftie.invoice_vendor_name,
       inv.vendor_invoice_no,
       --invl.description AS invoice_line_description,
       replace(replace (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,--updated code to get rid of carriage returns
       --invl.comment AS invoice_line_comment,
       replace(replace (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,--updated code to get rid of carriage returns
       ftie.finance_ledger_name,
       ftie.fiscal_year_code AS transaction_fiscal_year_code,
       ffyg.finance_group_name,
       fec.name AS expense_class,
       ftie.effective_fund_code,
       ftie.fund_type_name,
       po.po_number,
       pol.po_line_number,      
       formatt.bib_format_display AS format_name,        
       inssub.subject AS instance_subject, -- This IS the subject that is first on the list.
       lang.language AS LANGUAGE, -- This IS the language that is first on the list.
       --pol.title_or_package AS po_line_title_or_package,
       replace(replace (pol.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package,--updated code to get rid of carriage returns
       fq.fixed_quantity AS quantity,       
       ftie.external_account_no
FROM
        finance_transaction_invoices_ext AS ftie
        LEFT JOIN invoice_lines AS invl ON invl.id = ftie.invoice_line_id
        LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
       LEFT JOIN invoice_invoices AS inv ON ftie.invoice_id = inv.id
        LEFT JOIN po_lines AS pol ON ftie.po_line_id = pol.id
        LEFT JOIN po_purchase_orders AS PO ON po.id = pol.purchase_order_id
        LEFT JOIN folio_reporting.instance_ext AS iext ON iext.instance_id = pol.instance_id
        LEFT JOIN folio_reporting.instance_languages AS lang ON lang.instance_id = pol.instance_id
        LEFT JOIN instance_subject_extract AS inssub ON inssub.instance_hrid = iext.instance_hrid
        LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
        LEFT JOIN format_extract AS formatt ON pol.instance_id::UUID = formatt.instance_id
        left join locations on ftie.po_line_id = locations.pol_id
        --LEFT JOIN folio_reporting.po_lines_locations AS poll ON poll.pol_id = pol.id
        LEFT JOIN finance_expense_classes AS fec ON fec.id = ftie.expense_class
WHERE
        ((SELECT payment_date_start_date FROM parameters) ='' OR (inv.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (inv.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND inv.status LIKE 'Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        AND ((ftie.fund_type_name = (SELECT fund_type FROM parameters)) OR ((SELECT fund_type FROM parameters) = ''))
        AND ((ffyg.finance_group_name = (SELECT transaction_finance_group_name FROM parameters)) OR ((SELECT transaction_finance_group_name FROM parameters) = ''))
        AND ((ftie.finance_ledger_name = (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) = ''))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = '')) 
        AND ((po.order_type = (SELECT order_type_filter FROM parameters)) OR ((SELECT order_type_filter FROM parameters) = ''))
        AND ((po.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((fec.name = (SELECT expense_class FROM parameters)) OR ((SELECT expense_class FROM parameters) = ''))
        AND (lang.language_ordinality = '1' OR lang.language_ordinality ISNULL)
        AND ((formatt.bib_format_display= (SELECT format_name FROM parameters)) OR ((SELECT format_name FROM parameters) = ''))    
 GROUP BY
          ftie.transaction_id,
       iext.title,
       iext.instance_hrid,
       po.order_type,
       pol.order_format,
       ftie.invoice_date::DATE,
       inv.payment_date::DATE,
       ftie.effective_transaction_amount/fq.fixed_quantity,
       ftie.effective_transaction_amount,
       ftie.transaction_type,
       ftie.invoice_vendor_name,
       inv.vendor_invoice_no,
       invl.description,
       invl.comment,
       ftie.finance_ledger_name,
       ftie.fiscal_year_code,
       ffyg.finance_group_name,
       fec.name,
       ftie.effective_fund_code,
       ftie.fund_type_name,
       po.po_number,
       pol.po_line_number,      
       formatt.bib_format_display,        
       inssub.subject, 
       lang.language, 
       pol.title_or_package,
       fq.fixed_quantity,       
       ftie.external_account_no     
ORDER BY 
        instance_title,
        ftie.finance_ledger_name,
        ffyg.finance_group_name,
        fund_type_name,
        ftie.invoice_vendor_name,
        inv.vendor_invoice_no,
        po.po_number,
        pol.po_line_number 
        ;
