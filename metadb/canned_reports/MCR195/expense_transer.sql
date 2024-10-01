-- MCR195
-- Expense transfer
-- This query is a customization of CR-134 (paid invoices with bib data) for the purpose of identifying expenditures that can be transferred from unrestricted funds to restricted funds.
-- Last updated: 7-29-24
--Query writer: Joanne Leary (jl41)
--Query reviewer: Sharon Markus (slm5)

WITH parameters AS (

    SELECT
        '' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::varchar as order_type_filter, -- Ongoing or One-Time
        ''::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        '%%'::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        'FY2025'::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023, FY2024, etc.
        ''::VARCHAR AS po_number,
        '%%'::VARCHAR AS format_name, -- Ex: Book, Serial, Textual Resource, etc.
        '%%'::VARCHAR AS expense_class,-- Ex:Physical Res - one-time perpetual, One time Electronic Res - Perpetual etc.
        ''::VARCHAR AS lc_class_filter -- Ex: NA, PE, QA, TX, S, KFN, etc.
),

field050 AS -- gets the LC classification
       (SELECT
              sm.instance_hrid,
              sm.content AS lc_classification,
              substring (sm.content,'[A-Za-z]{0,}') as lc_class,
              trim (trailing '.' from SUBSTRING (sm.content, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number
      
       FROM folio_source_record.marc__t as sm--srs_marctab AS sm
              WHERE sm.field = '050'
              AND sm.sf = 'a'
),
 
format_extract AS ( -- gets the format code from the marc leader and links to the local translation table
       SELECT
           sm.instance_id::uuid,
           substring(sm.content,7,2) AS bib_format_code,
           vs.folio_format_type as bib_format_display
 
       FROM
           folio_source_record.marc__t as sm --srs_marctab AS sm
           LEFT JOIN local_shared.vs_folio_physical_material_formats as vs --local_core.vs_folio_physical_material_formats AS vs
           ON substring (sm.content,7,2) = vs.leader0607
           WHERE sm.field = '000'
),

subj1 as -- gets the primary subject from the instance_subjects derived table
(SELECT 
	    i.id AS instance_id,
	    jsonb_extract_path_text(i.jsonb, 'hrid') AS instance_hrid,
	    s.jsonb #>> '{value}' AS primary_subject,
	    s.ordinality AS subjects_ordinality
	FROM 
	    folio_inventory.instance AS i
	    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'subjects')) WITH ORDINALITY AS s (jsonb)
	WHERE s.ordinality = 1
), 

subj2 as -- gets the secondary subjects from the instance_subjects derived table
(SELECT 
	    i.id AS instance_id,
	    jsonb_extract_path_text(i.jsonb, 'hrid') AS instance_hrid,
	    s.jsonb #>> '{value}' AS other_subjects,
	    s.ordinality AS subjects_ordinality
	FROM 
	    folio_inventory.instance AS i
	    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'subjects')) WITH ORDINALITY AS s (jsonb)
	WHERE s.ordinality > 1
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
        ff.name as fund_name,
        fft.name AS fund_type_name,
        CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS effective_transaction_amount,
        ff.external_account_no AS external_account_no
       FROM
        folio_derived.finance_transaction_invoices fti --folio_reporting.finance_transaction_invoices AS fti
                LEFT JOIN folio_finance.fund__t as ff on ff.code = fti.effective_fund_code  --finance_funds AS ff ON ff.code = fti.effective_fund_code
                LEFT JOIN folio_finance.fiscal_year__t as ffy on ffy.id = fti.transaction_fiscal_year_id --finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id
                LEFT JOIN folio_finance.fund_type__t as fft on fft.id = ff.fund_type_id --finance_fund_types AS fft ON fft.id = ff.fund_type_id
                LEFT JOIN folio_finance.ledger__t as fl on ff.ledger_id = fl.id   --finance_ledgers AS fl ON ff.ledger_id = fl.id
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
	    folio_finance.groups__t as fg --finance_groups AS FG 
	    LEFT JOIN folio_finance.group_fund_fiscal_year__t as fgffy on fg.id = fgffy.group_id --finance_group_fund_fiscal_years AS FGFFY ON fg.id = fgffy.group_id
	    LEFT JOIN folio_finance.fiscal_year__t as ffy on ffy.id = fgffy.fiscal_year_id --finance_fiscal_years AS ffy ON ffy. id = fgffy.fiscal_year_id
	    LEFT JOIN folio_finance.fund__t as ff on ff.id = fgffy.fund_id --finance_funds AS FF ON FF.id = fgffy.fund_id
),

new_quantity AS 
	(SELECT 
		id AS invoice_line_id,
	       CASE WHEN quantity = 0
	       THEN 1
	       ELSE quantity
	    END AS fixed_quantity
		FROM folio_invoice.invoice_lines__t 
),

main AS 
(SELECT DISTINCT
    current_date AS current_date,           
    CASE WHEN 
       	((SELECT payment_date_start_date::varchar FROM parameters)= '' OR (SELECT payment_date_end_date::varchar from parameters) ='')		
       		THEN 'Not Selected'
       	ELSE
       		(SELECT payment_date_start_date::varchar FROM parameters) || ' to '::varchar || 
        	(SELECT payment_date_end_date::varchar FROM parameters)
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
	        ELSE groups__t.name end as finance_group_name,
       ftie.fund_name,
       ftie.effective_fund_code,
        ' ' AS transfer_to_fund,
       CASE WHEN ftie.invoice_line_total::decimal(12,2) > 0 
       		THEN ABS(ftie.transaction_amount::decimal(12,2)/ftie.invoice_line_total::decimal(12,2) *100)::decimal(3,0) 
       		ELSE 0 
       		END AS perc_spent,
       fq.fixed_quantity AS quantity,
       ftie.transaction_type,
       ftie.effective_transaction_amount,
       ftie.fund_type_name,
       fund__t.description as fund_description,
       subj1.primary_subject,
       string_agg (distinct subj2.other_subjects,' | ') as other_subjects,
       lang.instance_language,
       string_agg (distinct field050.lc_classification,' | ') as lc_classification,
       string_agg (distinct field050.lc_class,' | ') as lc_class,
       string_agg (distinct field050.lc_class_number,' | ') as lc_class_number,
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
        LEFT JOIN folio_invoice.invoice_lines__t as invl on invl.id = ftie.invoice_line_id --invoice_lines AS invl ON invl.id = ftie.invoice_line_id
        LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
       	LEFT JOIN folio_invoice.invoices__t as inv on ftie.invoice_id = inv.id --invoice_invoices AS inv ON ftie.invoice_id = inv.id
        LEFT JOIN folio_orders.po_line__t as pol on ftie.po_line_id::UUID = pol.id::UUID --po_lines AS pol ON ftie.po_line_id = pol.id
        LEFT JOIN folio_orders.purchase_order__t as po on po.id::UUID = pol.purchase_order_id::UUID --po_purchase_orders AS PO ON po.id = pol.purchase_order_id
        LEFT JOIN folio_derived.instance_ext as iext on iext.instance_id = pol.instance_id --folio_reporting.instance_ext AS iext ON iext.instance_id = pol.instance_id
        LEFT JOIN folio_derived.instance_languages as lang on lang.instance_id::UUID = pol.instance_id::UUID--folio_reporting.instance_languages AS lang ON lang.instance_id = pol.instance_id
        LEFT JOIN subj1 on iext.instance_hrid = subj1.instance_hrid
        LEFT JOIN subj2 on iext.instance_hrid = subj2.instance_hrid       
        LEFT JOIN folio_finance.group_fund_fiscal_year__t as ffyg on ffyg.fund_id = ftie.effective_fund_id --fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
        left join folio_finance.groups__t on groups__t.id = ffyg.group_id
        left join folio_finance.fund__t on ffyg.fund_id = fund__t.id
        LEFT JOIN format_extract AS formatt ON pol.instance_id::UUID = formatt.instance_id
        LEFT JOIN folio_derived.po_lines_locations as locations on ftie.po_line_id::UUID = locations.pol_id::UUID --locations on ftie.po_line_id = locations.pol_id
        LEFT JOIN folio_finance.expense_class__t as fec on fec.id = ftie.expense_class--finance_expense_classes AS fec ON fec.id = ftie.expense_class
        left join field050 ON iext.instance_hrid = field050.instance_hrid
        
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
	        ELSE groups__t.name end) = (select transaction_finance_group_name from parameters) or (SELECT transaction_finance_group_name FROM parameters) = '')
        AND ((ftie.finance_ledger_name ilike (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) ilike '%%'))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
        AND ((po.order_type = (SELECT order_type_filter FROM parameters)) OR ((SELECT order_type_filter FROM parameters) = ''))
        AND ((po.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((fec.name ilike (SELECT expense_class FROM parameters) or (SELECT expense_class FROM parameters) ilike '%%' or (SELECT expense_class FROM parameters) is null))
        AND (lang.language_ordinality = 1 OR lang.language_ordinality ISNULL)
        AND ((formatt.bib_format_display ilike (SELECT format_name FROM parameters) OR (SELECT format_name FROM parameters) ilike '%%' or (SELECT format_name FROM parameters) is null))
        AND ((field050.lc_class ilike (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) ='' or (SELECT lc_class_filter FROM parameters) is null))

        
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
       groups__t.name,
       fund__t.description,
       fec.name,
       ftie.effective_fund_code,
       ftie.fund_type_name,
       po.po_number,
       pol.po_line_number,      
       formatt.bib_format_display,        
       subj1.primary_subject,
       lang.instance_language, 
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
       ftie.fund_name      
)

SELECT 
	TO_CHAR (current_date::date,'mm/dd/yyyy') as todays_date,	
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
       main.instance_language, 
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
	main.finance_ledger_name,
    main.finance_group_name,
    main.fund_type_name,
    main.invoice_vendor_name,
    main.vendor_invoice_no,
    main.invoice_line_number,
    main.po_number,
    main.po_line_number	
;
