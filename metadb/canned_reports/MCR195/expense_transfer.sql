-- MCR195 - Expense transfer
-- last updated: 1-24-25
-- This query is a customization of CR-134 (paid invoices with bib data) for the purpose of identifying expenditures that can be transferred from unrestricted funds to restricted funds.
-- Last updated: 1-24-25
-- Query writer: Joanne Leary (jl41)
-- Query reviewer: Sharon Markus (slm5)
-- 11-18-24: excluded restricted funds and certain funds that Ann indicated would never be used to transfer funds out of (line 203 and 204)
-- 1-24-25: added instance UUId and replaced the derived tables with primary tables (added derivation code for po_lines_locations, finance_transaction_invoices and instance_languages; 
	-- used instance__t instead of instance_ext)
-- 1-16-26: revised to use derived tables and simplify query
-- replaced the aliases with full table names; coalesced instance title with po_lines__t.title or package to get "title"; used Collate "C" for title sorting
-- runs in under 2 minutes for FY2026 as of 1-16-26 


WITH parameters AS (

    SELECT
        '' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::varchar as order_type_filter, -- Ongoing or One-Time
        ''::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        '%%'::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        'FY2026'::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023, FY2024, etc.
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
       inner join folio_source_record.records_lb 
       on sm.matched_id = records_lb.matched_id
              WHERE sm.field = '050'
              AND sm.sf = 'a'
              and sm.ord = 1
              and records_lb.state = 'ACTUAL'
),

format_extract AS ( -- gets the format code from the marc leader and links to the local translation table
       SELECT
           sm.instance_id::uuid,
           substring(sm.content,7,2) AS bib_format_code,
           vs.folio_format_type as bib_format_display
 
       FROM
           folio_source_record.marc__t as sm --srs_marctab AS sm
           LEFT JOIN local_static.vs_folio_physical_material_formats as vs --local_core.vs_folio_physical_material_formats AS vs
           ON substring (sm.content,7,2) = vs.leader0607
           
           inner join folio_source_record.records_lb 
           on sm.matched_id = records_lb.matched_id
           
           WHERE sm.field = '000'
           and records_lb.state = 'ACTUAL'
),

subj1 as 
(select 
	inst_subj.instance_id,
	inst_subj.instance_hrid,
	inst_subj.subjects as primary_subject
	
	from folio_derived.instance_subjects as inst_subj 
	where inst_subj.subjects_ordinality = 1
),

subj2 as 
(select 
	inst_subj.instance_id,
	inst_subj.instance_hrid,
	string_agg (distinct inst_subj.subjects,' | ') as other_subjects 
	
	from folio_derived.instance_subjects as inst_subj 
	where inst_subj.subjects_ordinality > 1
	
	group by instance_id, instance_hrid
),

langs as 
(select 
	inst_lang.instance_id,
	inst_lang.instance_hrid,
	inst_lang.instance_language as primary_language
	
	from folio_derived.instance_languages as inst_lang 
	where inst_lang.language_ordinality = 1
),

ftie AS ( -- gets details of the finance transactions invoices table and converts Credits to negative values
       SELECT
        fti.transaction_id AS transaction_id,    
        fti.invoice_date::date,
        fti.invoice_payment_date::DATE AS invoice_payment_date,
        fti.transaction_fiscal_year_id,
        fiscal_year__t.code AS fiscal_year_code,
        fti.invoice_id,
        fti.invoice_line_id,
        fti.po_line_id,
        ledger__t.name AS finance_ledger_name,
        fti.transaction_expense_class_id AS expense_class,
        fti.invoice_vendor_name,
        fti.transaction_type,
        fti.transaction_amount,
        fti.invoice_line_total,
        fti.effective_fund_id AS effective_fund_id,
        fti.effective_fund_code AS effective_fund_code,
        fund__t.name as fund_name,
        fund_type__t.name AS fund_type_name,
        CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 
        	THEN fti.transaction_amount *-1 
        	ELSE fti.transaction_amount 
        	END AS effective_transaction_amount,
        fund__t.external_account_no AS external_account_no
      
        FROM
        folio_derived.finance_transaction_invoices as fti --folio_reporting.finance_transaction_invoices AS fti
                LEFT JOIN folio_finance.fund__t 
                on fund__t.code = fti.effective_fund_code  --finance_funds AS ff ON ff.code = fti.effective_fund_code
                
                LEFT JOIN folio_finance.fiscal_year__t 
                on fiscal_year__t.id = fti.transaction_fiscal_year_id --finance_fiscal_years AS ffy ON ffy.id = fti.transaction_fiscal_year_id
                
                LEFT JOIN folio_finance.fund_type__t 
                on fund_type__t.id = fund__t.fund_type_id --finance_fund_types AS fft ON fft.id = ff.fund_type_id
                
                LEFT JOIN folio_finance.ledger__t 
                on fund__t.ledger_id = ledger__t.id   --finance_ledgers AS fl ON ff.ledger_id = fl.id
       
        where fund_type__t.name like '%Unrestricted%'
	    and fund__t.code not in ('4','7','515','518','522','6920','6921','813','999') 
),

new_quantity AS --- this converts invoice line quantity values of zero to one; necessary for calculating price per unit ordered (line 296)
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
	        ((SELECT payment_date_start_date::varchar
	          FROM parameters)= '' OR
	         (SELECT payment_date_end_date::varchar
	          FROM parameters) ='')   
	    THEN 'Not Selected'
	    ELSE (SELECT payment_date_start_date::varchar
	          FROM parameters) || ' to ' ||
	         (SELECT payment_date_end_date::varchar
	          FROM parameters)
	          END AS payment_date_range, 
	
       ftie.fiscal_year_code AS transaction_fiscal_year_code,
       purchase_order__t.order_type,
       po_line__t.order_format,
       coalesce (REPLACE (REPLACE (instance__t.title, chr(13), ''),chr(10),''), REPLACE (REPLACE (po_line__t.title_or_package, chr(13), ''),chr(10),'')) AS title,
       instance__t.hrid as instance_hrid,
       instance__t.id as instance_uuid,
       CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and invoices__t.payment_date::date >='2023-07-01' THEN 'Area Studies'
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and invoices__t.payment_date::date <'2023-07-01' then '2CUL'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND invoices__t.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND invoices__t.payment_date::date <'2024-07-01' THEN 'Course Reserves'
	        ELSE groups__t.name end as finance_group_name,
       ftie.fund_name,
       ftie.effective_fund_code,
        ' ' AS transfer_to_fund,
       CASE WHEN ftie.invoice_line_total::decimal(12,2) > 0 
       		THEN ABS(ftie.transaction_amount::decimal(12,2)/ftie.invoice_line_total::decimal(12,2) *100)::decimal(3,0) 
       		ELSE 0 
       		END AS perc_spent,
       new_quantity.fixed_quantity AS quantity,
       ftie.transaction_type,
       ftie.effective_transaction_amount,
       ftie.fund_type_name,
       fund__t.description as fund_description,
       subj1.primary_subject,
       subj2.other_subjects,
       langs.primary_language,
       
       --concat (he.call_number_prefix,' ',he.call_number,' ',he.call_number_suffix) as holdings_call_number,
       
       --case when (he.call_number ilike '%On order%' or he.call_number ilike '%In process%')
	       --then null 
	       --else substring (he.call_number,'[A-Z]{1,3}') 
	       --end as holdings_lc_class,
	       
       --trim ('.' from substring (he.call_number,'\d{1,}\.{0,}\d{0,}')) as holdings_lc_class_number,
       
       string_agg (distinct field050.lc_classification,' | ') as field050_lc_classification,
       string_agg (distinct field050.lc_class,' | ') as field050_lc_class,
       string_agg (distinct field050.lc_class_number,' | ') as field050_lc_class_number,
       
       --coalesce (case when he.call_number ilike '%On order%' or he.call_number ilike '%In process%'
	       --then null 
	      -- else substring (he.call_number,'[A-Z]{1,3}') 
	       --end, 
	       --string_agg (distinct field050.lc_class,' | ')
	       --) as net_lc_class,
     
       --coalesce (trim ('.' from substring (he.call_number,'\d{1,}\.{0,}\d{0,}')), 
       			--string_agg (distinct field050.lc_class_number,' | ')
       			--) as net_lc_class_number,
              
       format_extract.bib_format_display AS format_name,
       STRING_AGG (DISTINCT po_lines_locations.pol_location_name, ' | ') as location_name, --locations.pol_location_name,' | ') AS location_name,
       purchase_order__t.po_number,
       po_line__t.po_line_number,
       
       REPLACE (REPLACE (po_line__t.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package,
       ftie.invoice_vendor_name,
       invoices__t.vendor_invoice_no,
       invoice_lines__t.invoice_line_number,
       invoices__t.folio_invoice_no,
       REPLACE (REPLACE (invoice_lines__t.description, chr(13), ''),chr(10),'') AS invoice_line_description,
       REPLACE (REPLACE (invoice_lines__t.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,
       ftie.invoice_date::date,
       invoices__t.status AS invoice_status,
       invoices__t.payment_date::timestamptz AS invoice_payment_date,
       ftie.finance_ledger_name,       
       expense_class__t.name AS expense_class,       
       ftie.external_account_no,       
       CASE WHEN ftie.transaction_type = 'Credit' AND ftie.transaction_amount >=0.01 
       		THEN ftie.transaction_amount *-1 
       		ELSE ftie.transaction_amount 
       		END AS transaction_amount,       
       ftie.effective_transaction_amount/new_quantity.fixed_quantity AS transaction_amount_per_qty 
                     
FROM
        ftie
        LEFT JOIN folio_invoice.invoice_lines__t 
        on invoice_lines__t.id = ftie.invoice_line_id --invoice_lines AS invoice_lines__t ON invoice_lines__t.id = ftie.invoice_line_id
        
        LEFT JOIN new_quantity
        ON invoice_lines__t.id = new_quantity.invoice_line_id
        
       	LEFT JOIN folio_invoice.invoices__t 
       	on ftie.invoice_id = invoices__t.id --invoice_invoices AS inv ON ftie.invoice_id = inv.id
       	
        LEFT JOIN folio_orders.po_line__t --as pol 
        on ftie.po_line_id::UUID = po_line__t.id::UUID --po_lines AS pol ON ftie.po_line_id = pol.id
        
        LEFT JOIN folio_orders.purchase_order__t --as po 
        on purchase_order__t.id::UUID = po_line__t.purchase_order_id::UUID --po_purchase_orders AS PO ON po.id = pol.purchase_order_id
        
        LEFT JOIN folio_inventory.instance__t --as instance__t 
        on instance__t.id = po_line__t.instance_id--LEFT JOIN folio_derived.instance_ext as instance__t on instance__t.instance_id = pol.instance_id --folio_reporting.instance_ext AS instance__t ON instance__t.instance_id = pol.instance_id
        
        LEFT JOIN langs --as lang 
        on langs.instance_id::UUID = po_line__t.instance_id::UUID --folio_derived.instance_languages as lang on lang.instance_id::UUID = pol.instance_id::UUID--folio_reporting.instance_languages AS lang ON lang.instance_id = pol.instance_id
        
        LEFT JOIN subj1 
        on instance__t.hrid = subj1.instance_hrid
        
        LEFT JOIN subj2 
        on instance__t.hrid = subj2.instance_hrid
        
        LEFT JOIN folio_finance.group_fund_fiscal_year__t --as group_fund_fiscal_year__t 
        on group_fund_fiscal_year__t.fund_id = ftie.effective_fund_id --fund_fiscal_year_group AS group_fund_fiscal_year__t ON group_fund_fiscal_year__t.fund_id = ftie.effective_fund_id
        
        left join folio_finance.groups__t 
        on groups__t.id = group_fund_fiscal_year__t.group_id
        
        left join folio_finance.fund__t 
        on group_fund_fiscal_year__t.fund_id = fund__t.id
        
        LEFT JOIN format_extract --AS format_extract 
        ON po_line__t.instance_id::UUID = format_extract.instance_id
        
        LEFT JOIN folio_derived.po_lines_locations -- as po_lines_locations 
        on ftie.po_line_id::UUID = po_lines_locations.pol_id ----folio_derived.po_lines_locations as locations on ftie.po_line_id::UUID = locations.pol_id::UUID --locations on ftie.po_line_id = locations.pol_id
        
        --left join folio_derived.po_instance 
		--on po_lines_locations.pol_id = po_instance.po_line_id 
		
		--left join folio_derived.holdings_ext as he 
		--on po_instance.pol_instance_id = he.instance_id
		
        LEFT JOIN folio_finance.expense_class__t --as fec 
        on expense_class__t.id = ftie.expense_class--finance_expense_classes AS fec ON fec.id = ftie.expense_class
        
        left join field050 
        ON instance__t.hrid = field050.instance_hrid
        
WHERE
        ((SELECT payment_date_start_date FROM parameters) ='' OR (invoices__t.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
		--inv.payment_date::timestamptz >= '2025-03-17 09:40:00.000 -0400'
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (invoices__t.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND invoices__t.status LIKE 'Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        AND ((ftie.fund_type_name = (SELECT fund_type FROM parameters)) OR ((SELECT fund_type FROM parameters) = ''))
        and ((CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and invoices__t.payment_date::date >='2023-07-01' THEN 'Area Studies'
	        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and invoices__t.payment_date::date <'2023-07-01' then '2CUL'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND invoices__t.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
	        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND invoices__t.payment_date::date <'2024-07-01' THEN 'Course Reserves'
	        ELSE groups__t.name end) = (select transaction_finance_group_name from parameters) or (SELECT transaction_finance_group_name FROM parameters) = '')
        AND ((ftie.finance_ledger_name ilike (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) ilike '%%'))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
        AND ((purchase_order__t.order_type = (SELECT order_type_filter FROM parameters)) OR ((SELECT order_type_filter FROM parameters) = ''))
        AND ((purchase_order__t.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((expense_class__t.name ilike (SELECT expense_class FROM parameters) or (SELECT expense_class FROM parameters) ilike '%%' or (SELECT expense_class FROM parameters) is null))
       -- AND (lang.language_ordinality = 1 OR lang.language_ordinality ISNULL)
        AND ((format_extract.bib_format_display ilike (SELECT format_name FROM parameters) OR (SELECT format_name FROM parameters) ilike '%%' or (SELECT format_name FROM parameters) is null))
        AND ((field050.lc_class ilike (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) ='' or (SELECT lc_class_filter FROM parameters) is null))

        
 GROUP BY
       instance__t.title,
       instance__t.hrid,
       instance__t.id,
       purchase_order__t.order_type,
       po_line__t.order_format,
       ftie.invoice_date::DATE,
       invoices__t.payment_date::timestamptz,
       ftie.effective_transaction_amount/new_quantity.fixed_quantity,
       ftie.effective_transaction_amount,
       ftie.transaction_type,
       ftie.invoice_vendor_name,
       invoices__t.vendor_invoice_no,
       invoice_lines__t.invoice_line_number,
       invoices__t.folio_invoice_no,
       invoice_lines__t.description,
       invoice_lines__t.comment,
       ftie.finance_ledger_name,
       ftie.fiscal_year_code,
       groups__t.name,
       fund__t.description,
       expense_class__t.name,
       ftie.effective_fund_code,
       ftie.fund_type_name,
       purchase_order__t.po_number,
       po_line__t.po_line_number,      
       format_extract.bib_format_display,        
       subj1.primary_subject,
       subj2.other_subjects,
       langs.primary_language,
      -- he.call_number_prefix,
       --he.call_number,
       --he.call_number_suffix,
       po_line__t.title_or_package,
       new_quantity.fixed_quantity,       
       ftie.external_account_no,
       invoices__t.status,
       REPLACE(REPLACE (invoice_lines__t.description, chr(13), ''),chr(10),''),
       REPLACE(REPLACE (invoice_lines__t.comment, chr(13), ''),chr(10),''),
       REPLACE(REPLACE (po_line__t.title_or_package, chr(13), ''),chr(10),''),
       REPLACE(REPLACE (instance__t.title, chr(13), ''),chr(10),''),
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
       main.title, --instance_title,
       main.instance_hrid,
       main.instance_uuid,
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
       main.primary_language,
       --trim (main.holdings_call_number) as call_number,
      -- main.holdings_lc_class,
       --main.holdings_lc_class_number,
      -- main.field050_lc_classification,
       split_part (main.field050_lc_class,'|',1) as lc_class,
       split_part (main.field050_lc_class_number,'|',1)::numeric as lc_class_number,
       --substring (main.field050_lc_class,'[A-Z]{1,3}') as field050_lc_class,
       --(substring (main.field050_lc_class_number,'\d{1,}\.{0,1}\d{0,}')) as field050_lc_class_number,
       --main.net_lc_class as lc_class,
       --split_part (main.net_lc_class_number,'|',1)::numeric as lc_class_number,
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
       main.invoice_payment_date::date,
       main.finance_ledger_name,       
       main.expense_class,       
       main.external_account_no
		
 FROM main
	
 ORDER BY 
    main.title collate "C", --main.instance_title collate "C",
	main.finance_ledger_name,
    main.finance_group_name,
    main.fund_type_name,
    main.invoice_vendor_name,
    main.vendor_invoice_no,
    main.invoice_line_number,
    main.po_number,
    main.po_line_number	
;
