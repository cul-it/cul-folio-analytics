--MCR226 funds_for_stewardship 
--This query provides the list of approved invoices within a date range along with primary contributor name, publisher name, publication date, publication place, vendor name, LC classification, LC class, LC class number, finance group name, vendor invoice number, fund details, purchase order details, language, instance subject, fund type, and expense class.
--Query writer: Joanne Leary (jl41)
--Posted on: 11/6/24

WITH parameters AS (
    SELECT
        '' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::varchar as order_type_filter, -- Ongoing or One-Time
        '%%'::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        '%%'::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        ''::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023, FY2024, etc.
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
           LEFT JOIN local_shared.vs_folio_physical_material_formats AS vs
           ON substring (sm.content,7,2) = vs.leader0607
           WHERE sm.field = '000'
),

instance_subject_extract AS ( -- gets the primary subject from the instance_subjects derived table
       SELECT
              instsubj.instance_id,
              instsubj.instance_hrid,
              instsubj.subjects
             
       FROM folio_derived.instance_subjects AS instsubj
       WHERE instsubj.subjects_ordinality = 1
),

--publication update

publication_extract as -- gets publication date, place, and publisher from the folio_inventory.instance table
(SELECT 
    i.id AS instance_id,
    jsonb_extract_path_text(i.jsonb, 'hrid') AS instance_hrid,
    jsonb_extract_path_text(pub.jsonb, 'place') AS publication_place,
    jsonb_extract_path_text(pub.jsonb, 'publisher') AS publisher,
    jsonb_extract_path_text(pub.jsonb, 'dateOfPublication') AS publication_date,
    pub.ordinality AS publication_ordinality
FROM 
    folio_inventory.instance AS i
    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'publication')) WITH ORDINALITY AS pub (jsonb)
    where pub.ordinality = 1
),

--primary contributor update
contrib AS (
    SELECT
        i.id AS instance_id,
        jsonb_extract_path_text(i.jsonb, 'hrid') AS instance_hrid,
        jsonb_extract_path_text(ctb.jsonb, 'name') AS contributor_name,
        jsonb_extract_path_text(ctb.jsonb, 'primary') ::boolean AS contributor_is_primary
    FROM
        folio_inventory.instance AS i
        CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'contributors')) WITH ORDINALITY AS ctb (jsonb)
        
        LEFT JOIN folio_inventory.contributor_type__t AS ctt ON jsonb_extract_path_text(ctb.jsonb, 'contributorTypeId') ::uuid = ctt.id
        LEFT JOIN folio_inventory.contributor_name_type__t AS cntt ON jsonb_extract_path_text(ctb.jsonb, 'contributorNameTypeId') ::uuid = cntt.id
        
    where jsonb_extract_path_text(ctb.jsonb, 'primary') ::boolean = 'true'
),

locations AS ( -- gets the location name using the po_lines table
       SELECT
           pol.id AS pol_id,
           jsonb_extract_path_text(locations.data, 'quantity') AS pol_location_qty,
           jsonb_extract_path_text(locations.data, 'quantityElectronic') AS pol_loc_qty_elec,
           jsonb_extract_path_text(locations.data, 'quantityPhysical') AS pol_loc_qty_phys,    
           CASE WHEN jsonb_extract_path_text(locations.data, 'locationId')::UUID IS NOT NULL THEN jsonb_extract_path_text(locations.data, 'locationId')::UUID
               ELSE ih.permanent_location_id::UUID
              END AS pol_location_id,
             
           CASE WHEN il.name IS NOT NULL THEN il.name
               ELSE il2.name
              END AS pol_location_name,
             
           CASE WHEN il.name IS NOT NULL THEN 'pol_location'
                WHEN il2.name IS NOT NULL THEN 'pol_holding'
                ELSE 'no_source'
           END AS pol_location_source
          
       FROM
           folio_orders.po_line as pol --po_lines AS pol
           CROSS JOIN jsonb_array_elements(jsonb_extract_path(pol.jsonb, 'locations')) AS locations (data)
           
           LEFT JOIN folio_inventory.holdings_record__t as ih --inventory_holdings AS ih 
           ON jsonb_extract_path_text(locations.data, 'holdingId')::UUID = ih.id
           
           LEFT JOIN folio_inventory.location__t as il --inventory_locations AS il 
           ON jsonb_extract_path_text(locations.data, 'locationId')::UUID = il.id
           
           LEFT JOIN folio_inventory.location__t as il2 -- inventory_locations AS il2 
           ON ih.permanent_location_id = il2.id
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
        fti.effective_fund_id AS effective_fund_id,
        fti.effective_fund_code AS effective_fund_code,
        ff.name as fund_name,
        fft.name AS fund_type_name,
        CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS effective_transaction_amount,
        ff.external_account_no AS external_account_no
		
       FROM
        folio_derived.finance_transaction_invoices AS fti
                LEFT JOIN folio_finance.fund__t as ff --finance_funds AS ff 
                ON ff.code = fti.effective_fund_code
                
                LEFT JOIN folio_finance.fiscal_year__t as ffy --finance_fiscal_years AS ffy 
                ON ffy.id = fti.transaction_fiscal_year_id::UUID
                
                LEFT JOIN folio_finance.fund_type__t as fft --finance_fund_types AS fft 
                ON fft.id = ff.fund_type_id
                
                LEFT JOIN folio_finance.ledger__t as fl --finance_ledgers AS fl 
                ON ff.ledger_id = fl.id
                	
),

fund_fiscal_year_group AS ( -- associates the fund with the finance group and fiscal year
    SELECT
       FGFFY.id AS group_fund_fiscal_year_id,
       FG.name AS finance_group_name,
       ff.id AS fund_id,
       ff.code AS fund_code,
       fgffy.fiscal_year_id AS fund_fiscal_year_id,
       ffy.code AS fiscal_year_code
    FROM
       folio_finance.groups__t AS FG
    LEFT JOIN folio_finance.group_fund_fiscal_year__t AS FGFFY ON fg.id = fgffy.group_id --OLD group_id
    LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy. id = fgffy.fiscal_year_id
    LEFT JOIN folio_finance.fund__t AS FF ON FF.id = fgffy.fund_id
    
    WHERE ((ffy.code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
),

new_quantity AS ( -- converts invoice line quantities showing "0" to "1" for use in a price-per-unit calculation
SELECT
     id AS invoice_line_id,
     CASE WHEN quantity = 0
          THEN 1
          ELSE quantity
          END AS fixed_quantity
     FROM folio_invoice.invoice_lines__t
)

SELECT DISTINCT
       current_date AS current_date,         
       CASE WHEN
               ((SELECT
                 payment_date_start_date::varchar
                 FROM parameters)= ''
                    OR
                    (SELECT
                 payment_date_end_date::varchar
                 FROM parameters) ='')              
             THEN 'Not Selected'
             ELSE
                (SELECT payment_date_start_date::varchar
                FROM parameters) || ' to '::varchar ||
                (SELECT payment_date_end_date::varchar
                FROM parameters)
            END AS payment_date_range,     
 
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
       replace(replace (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,--updated code to get rid of carriage returns
       replace(replace (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,--updated code to get rid of carriage returns
       ftie.finance_ledger_name,
       ftie.fiscal_year_code AS transaction_fiscal_year_code,
       
       CASE
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date <'2023-07-01' THEN '2CUL'
                 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        		 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
                 ELSE ffyg.finance_group_name end as finance_group_name,

       fec.name AS expense_class,
       ftie.effective_fund_code,
       ftie.fund_name,
       ftie.fund_type_name,
       po.po_number,
       pol.po_line_number,    
       formatt.bib_format_display AS format_name,      
       inssub.subjects AS instance_subject, -- This IS the subject that is first on the list.
       contrib.contributor_name as primary_contributor,
       SUBSTRING (pe.publication_date,'\d{4}') AS publication_date,
       pe.publication_place AS publication_place,
       pe.publisher AS publisher,
       lang.instance_language AS LANGUAGE, -- This IS the language that is first on the list.
       string_agg (distinct field050.lc_classification,' | ') as lc_classification,
       string_agg (distinct field050.lc_class,' | ') as lc_class,
       string_agg (distinct field050.lc_class_number,' | ') as lc_class_number,
       replace(replace (pol.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package,--updated code to get rid of carriage returns
       fq.fixed_quantity AS quantity,     
       ftie.external_account_no
              
 FROM
    finance_transaction_invoices_ext AS ftie
    LEFT JOIN folio_invoice.invoice_lines__t AS invl ON invl.id = ftie.invoice_line_id
    LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
    LEFT JOIN folio_invoice.invoices__t AS inv ON ftie.invoice_id = inv.id
    LEFT JOIN folio_orders.po_line__t AS pol ON ftie.po_line_id ::uuid= pol.id::uuid
    LEFT JOIN folio_orders.purchase_order__t AS PO ON po.id = pol.purchase_order_id
    LEFT JOIN folio_derived.instance_ext AS iext ON iext.instance_id = pol.instance_id
    LEFT JOIN field050 ON iext.instance_hrid = field050.instance_hrid
    LEFT JOIN folio_derived.instance_languages AS lang ON lang.instance_id = pol.instance_id
    LEFT JOIN instance_subject_extract AS inssub ON inssub.instance_hrid = iext.instance_hrid
    LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
    LEFT JOIN format_extract AS formatt ON pol.instance_id::UUID = formatt.instance_id
    LEFT JOIN folio_derived.po_lines_locations on ftie.po_line_id::UUID = po_lines_locations.pol_id::UUID --locations on ftie.po_line_id ::uuid = locations.pol_id::uuid
    LEFT JOIN folio_finance.expense_class__t AS fec ON fec.id = ftie.expense_class
    LEFT JOIN publication_extract AS pe ON pe.instance_id = iext.instance_id
    LEFT JOIN contrib on iext.instance_id = contrib.instance_id
    LEFT JOIN locations on ftie.po_line_id::UUID = locations.pol_id    
        
WHERE
        ((SELECT payment_date_start_date FROM parameters) ='' OR (inv.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (inv.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND inv.status ='Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        AND ((ftie.fund_type_name ilike (SELECT fund_type FROM parameters)) OR ((SELECT fund_type FROM parameters) = ''))
        AND ((CASE
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date <'2023-07-01' THEN '2CUL'
                 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        		 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
                 ELSE ffyg.finance_group_name end) = (select transaction_finance_group_name from parameters) 
                    OR (SELECT transaction_finance_group_name FROM parameters) = '')
        AND ((ftie.finance_ledger_name ilike (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) ilike '%%'))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
        AND ((po.order_type = (SELECT order_type_filter FROM parameters)) OR ((SELECT order_type_filter FROM parameters) = ''))
        AND ((po.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((fec.name ilike (SELECT expense_class FROM parameters) or (SELECT expense_class FROM parameters) ilike '%%' or (SELECT expense_class FROM parameters) is null))
        AND (lang.language_ordinality = 1 OR lang.language_ordinality ISNULL)
        AND ((formatt.bib_format_display ilike (SELECT format_name FROM parameters) OR (SELECT format_name FROM parameters) ilike '%%' or (SELECT format_name FROM parameters) is null))
        AND ((field050.lc_class ilike (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) ='' or (SELECT lc_class_filter FROM parameters) is null))
        
                
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
       ftie.fund_name,
       ftie.fund_type_name,
       po.po_number,
       pol.po_line_number,    
       formatt.bib_format_display,      
       inssub.subjects,
       pe.publication_date,
       pe.publication_place,
       pe.publisher,
       lang.instance_language,
       pol.title_or_package,
       fq.fixed_quantity,     
       ftie.external_account_no,
       contrib.contributor_name
       
ORDER BY
        ftie.fiscal_year_code,
        instance_title,
        ftie.finance_ledger_name,
        fund_type_name,
        ftie.invoice_vendor_name,
        inv.vendor_invoice_no,
        po.po_number,
        pol.po_line_number
;
