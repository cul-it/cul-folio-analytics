-- MCR195
-- Expense transfer
-- This query is a customization of CR-134 (paid invoices with bib data) for the purpose of identifying expenditures that can be transferred from unrestricted funds to restricted funds.

--Query writer: Joanne Leary (jl41)
--Query reviewer: Sharon Marcus (slm5)

WITH parameters AS (

    SELECT
        '' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::VARCHAR AS order_type_filter, -- Ongoing or One-Time
        ''::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        '%%'::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        ''::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023, FY2024, etc.
        ''::VARCHAR AS po_number,
        '%%'::VARCHAR AS format_name, -- Ex: Book, Serial, Textual Resource, etc.
        '%%'::VARCHAR AS expense_class,-- Ex:Physical Res - one-time perpetual, One time Electronic Res - Perpetual etc.
        ''::VARCHAR AS lc_class_filter -- Ex: NA, PE, QA, TX, S, KFN, etc.
),

field050 AS ( -- gets the LC classification
       SELECT
              sm.instance_hrid,
              sm.content AS lc_classification,
              substring (sm.content,'[A-Za-z]{0,}') AS lc_class,
              TRIM (TRAILING '.' FROM SUBSTRING (sm.content, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number
      
       FROM srs_marctab AS sm
              WHERE sm.field = '050'
              AND sm.sf = 'a'
),
 
format_extract AS ( -- gets the format code from the marc leader and links to the local translation table
       SELECT
           sm.instance_id::UUID,
           SUBSTRING (sm.content,7,2) AS bib_format_code,
           vs.folio_format_type AS bib_format_display
 
       FROM
           srs_marctab AS sm
           LEFT JOIN local_core.vs_folio_physical_material_formats AS vs
           ON SUBSTRING (sm.content,7,2) = vs.leader0607
           WHERE sm.field = '000'
),

instance_subject_extract AS ( -- gets the primary subject from the instance_subjects derived table
       SELECT
              instsubj.instance_id,
              instsubj.instance_hrid,
              instsubj.subject AS primary_subject
             
       FROM folio_reporting.instance_subjects AS instsubj
       WHERE instsubj.subject_ordinality = 1
),

instance_subject_extract2 AS ( -- gets the secondary subjects from the instance_subjects derived table
       SELECT
              instsubj2.instance_id,
              instsubj2.instance_hrid,
              instsubj2.subject as other_subjects
             
       FROM folio_reporting.instance_subjects AS instsubj2
       WHERE instsubj2.subject_ordinality > 1
),

locations AS ( -- gets the location name using the po_lines table
       SELECT
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

finance_transaction_invoices_ext AS ( -- gets details of the finance transactions and converts Credits to negative values
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
          fti.invoice_line_total,
        fti.effective_fund_id AS effective_fund_id,
        fti.effective_fund_code AS effective_fund_code,
        ff.name AS fund_name,
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

fund_fiscal_year_group as  -- associates the fund with the finance group and fiscal year
	(SELECT
	    FGFFY.id AS group_fund_fiscal_year_id,
	    FG.name AS finance_group_name,
	    ff.id AS fund_id,
	    ff.code AS fund_code,
	    ff.name AS fund_name,
	    ff.description AS fund_description,
	    fgffy.fiscal_year_id AS fund_fiscal_year_id,
	    ffy.code AS fiscal_year_code
	FROM
	    finance_groups AS FG 
	    LEFT JOIN finance_group_fund_fiscal_years AS FGFFY ON fg.id = fgffy.group_id
	    LEFT JOIN finance_fiscal_years AS ffy ON ffy. id = fgffy.fiscal_year_id
	    LEFT JOIN finance_funds AS FF ON FF.id = fgffy.fund_id
	WHERE ((ffy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
),

new_quantity AS 
	(SELECT 
		id AS invoice_line_id,
	       CASE WHEN quantity = 0
	       THEN 1
	       ELSE quantity
	    END AS fixed_quantity
		FROM invoice_lines 
),

main as 
(SELECT DISTINCT
    current_date AS current_date,           
    CASE WHEN 
       	((SELECT payment_date_start_date::varchar FROM parameters)= '' OR (SELECT payment_date_end_date::VARCHAR FROM parameters) ='')		
       		THEN 'Not Selected'
       	ELSE
       		(SELECT payment_date_start_date::VARCHAR FROM parameters) || ' to '::VARCHAR || 
        	(SELECT payment_date_end_date::VARCHAR FROM parameters)
		END AS payment_date_range,	
       ftie.fiscal_year_code AS transaction_fiscal_year_code,
       po.order_type,
       pol.order_format,
       REPLACE (REPLACE (iext.title, chr(13), ''),chr(10),'') AS instance_title,
       iext.instance_hrid,
       
       CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date <'2023-07-01' then '2CUL'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
	        ELSE ffyg.finance_group_name END AS finance_group_name,

       ftie.fund_name,
       ftie.effective_fund_code,
        ' ' AS transfer_to_fund,
       CASE WHEN ftie.invoice_line_total::DECIMAL(12,2) > 0 
       		THEN ABS(ftie.transaction_amount::DECIMAL(12,2)/ftie.invoice_line_total::DECIMAL(12,2) *100)::DECIMAL(3,0) 
       		ELSE 0 
       		END AS perc_spent,
       fq.fixed_quantity AS quantity,
       ftie.transaction_type,
       ftie.effective_transaction_amount,
       ftie.fund_type_name,
       ffyg.fund_description,
       ise.primary_subject,
       STRING_AGG (DISTINCT ise2.other_subjects,' | ') AS  other_subjects,
       lang.language,
       STRING_AGG (DISTINCT field050.lc_classification,' | ') AS lc_classification,
       STRING_AGG (DISTINCT field050.lc_class,' | ') AS lc_class,
       STRING_AGG (DISTINCT field050.lc_class_number,' | ') AS lc_class_number,
       formatt.bib_format_display AS format_name,
       STRING_AGG (DISTINCT locations.pol_location_name,' | ') AS location_name,
       po.po_number,
       pol.po_line_number,
       REPLACE (REPLACE (pol.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package,
       ftie.invoice_vendor_name,
       inv.vendor_invoice_no,
       invl.invoice_line_number,
       inv.folio_invoice_no,
       REPLACE (REPLACE (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,
       REPLACE (REPLACE (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,
       ftie.invoice_date::date,
       inv.status AS invoice_status,
       inv.payment_date::DATE AS invoice_payment_date,
       ftie.finance_ledger_name,       
       fec.name AS expense_class,       
       ftie.external_account_no,       
       CASE WHEN ftie.transaction_type = 'Credit' AND ftie.transaction_amount >=0.01 
       		THEN ftie.transaction_amount *-1 
       		ELSE ftie.transaction_amount 
       		END AS transaction_amount,       
       ftie.effective_transaction_amount/fq.fixed_quantity AS transaction_amount_per_qty
                   
FROM
        finance_transaction_invoices_ext AS ftie
        LEFT JOIN invoice_lines AS invl ON invl.id = ftie.invoice_line_id
        LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
       	LEFT JOIN invoice_invoices AS inv ON ftie.invoice_id = inv.id
        LEFT JOIN po_lines AS pol ON ftie.po_line_id = pol.id
        LEFT JOIN po_purchase_orders AS PO ON po.id = pol.purchase_order_id
        LEFT JOIN folio_reporting.instance_ext AS iext ON iext.instance_id = pol.instance_id
        LEFT JOIN folio_reporting.instance_languages AS lang ON lang.instance_id = pol.instance_id
        LEFT JOIN instance_subject_extract AS ise on iext.instance_hrid = ise.instance_hrid
        LEFT JOIN instance_subject_extract2 AS ise2 ON iext.instance_hrid = ise2.instance_hrid
        LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
        LEFT JOIN format_extract AS formatt ON pol.instance_id::UUID = formatt.instance_id
        LEFT JOIN locations ON ftie.po_line_id = locations.pol_id
        LEFT JOIN finance_expense_classes AS fec ON fec.id = ftie.expense_class
        LEFT JOIN field050 ON iext.instance_hrid = field050.instance_hrid
        
WHERE
        ((SELECT payment_date_start_date FROM parameters) ='' OR (inv.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (inv.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND inv.status LIKE 'Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        AND ((ftie.fund_type_name = (SELECT fund_type FROM parameters)) OR ((SELECT fund_type FROM parameters) = ''))
        
        and ((CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date <'2023-07-01' then '2CUL'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
	        ELSE ffyg.finance_group_name end) = (SELECT transaction_finance_group_name FROM parameters) OR (SELECT transaction_finance_group_name FROM parameters) = '')
                 
        AND ((ftie.finance_ledger_name ILIKE (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) ILIKE '%%'))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
        AND ((po.order_type = (SELECT order_type_filter FROM parameters)) OR ((SELECT order_type_filter FROM parameters) = ''))
        AND ((po.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((fec.name ILIKE (SELECT expense_class FROM parameters) OR (SELECT expense_class FROM parameters) ILIKE '%%' OR (SELECT expense_class FROM parameters) IS NULL))
        AND (lang.language_ordinality = '1' OR lang.language_ordinality ISNULL)
        AND ((formatt.bib_format_display ILIKE (SELECT format_name FROM parameters) OR (SELECT format_name FROM parameters) ILIKE '%%' OR (SELECT format_name FROM parameters) IS NULL))
        AND ((field050.lc_class ILIKE (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) ='' OR (SELECT lc_class_filter FROM parameters) IS NULL))

        
 GROUP BY
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
       invl.invoice_line_number,
       inv.folio_invoice_no,
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
       ise.primary_subject,
       lang.language, 
       pol.title_or_package,
       fq.fixed_quantity,       
       ftie.external_account_no,
       inv.status,
       REPLACE(REPLACE (invl.description, chr(13), ''),chr(10),''),
       REPLACE(REPLACE (invl.comment, chr(13), ''),chr(10),''),
       REPLACE(REPLACE (pol.title_or_package, chr(13), ''),chr(10),''),
       REPLACE(REPLACE (iext.title, chr(13), ''),chr(10),''),
       ftie.transaction_type,
       ftie.transaction_amount,
       ftie.invoice_line_total,
       ftie.fund_name,
       ffyg.fund_description       
)

SELECT -- (this is to select fields from the preceding subquery and order them as requested by the selectors)
	   TO_CHAR (current_date::date,'mm/dd/yyyy') as todays_date,
	   main.payment_date_range,	
       main.transaction_fiscal_year_code as fiscal_year,
       main.order_type,
       main.order_format,
       main.instance_title,
       main.instance_hrid,
       main.finance_group_name,
       main.fund_name,
       main.effective_fund_code,
       main.transfer_to_fund,
       main.perc_spent,
       main.quantity,
       main.transaction_type,
       main.effective_transaction_amount,
       main.fund_type_name,
       main.fund_description,
       main.primary_subject,
       main.other_subjects,
       main.language, 
       main.lc_classification,
       main.lc_class,
       main.lc_class_number,
       main.format_name,
       main.location_name,
       main.po_number,
       main.po_line_number,
       main.po_line_title_or_package,
       main.invoice_vendor_name,
       main.vendor_invoice_no,
       main.invoice_line_number,
       main.folio_invoice_no,
       main.invoice_line_description,
       main.invoice_line_comment,
       main.invoice_date::date,
       main.invoice_status,
       main.invoice_payment_date,
       main.finance_ledger_name,       
       main.expense_class,       
       main.external_account_no
		
 FROM main
	
 ORDER BY 
    main.instance_title,
    main.transaction_fiscal_year_code,
	main.finance_ledger_name,
    main.finance_group_name,
    main.fund_type_name,
    main.invoice_vendor_name,    
    main.vendor_invoice_no,
    main.invoice_line_number,
    main.po_number,
    main.po_line_number	
;
