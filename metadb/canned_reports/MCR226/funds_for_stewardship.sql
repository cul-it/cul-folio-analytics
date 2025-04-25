--MCR226 funds_for_stewardship - Endowment funds only - revised 3-14-25
--This query provides the list of approved invoices within a date range along with primary contributor name, publisher name, publication date, publication place, vendor name, LC classification, LC class, LC class number, finance group name, vendor invoice number, fund details, purchase order details, language, instance subject, fund type, and expense class.
--Query writer: Joanne Leary (jl41)
--Posted on: 11/6/24
-- 2-28-25: added field 902 subquery (shows p-fund donor)
-- 3-3-25: replaced derived tables with source tables; replaced "locations" subquery with the derivation code for po_lines_locations
-- 3-13-25: revised to get just Endowment funds (fund_type like 'Endowment%') line 362
-- 3-14-25: added invoice_line_number; added contributor ordinality = 1; added field050 ordinality = 1
-- 4-25-25: updated local_shared to local_static

WITH parameters AS (
    SELECT
        '' AS payment_date_start_date, -- enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::varchar as order_type_filter, -- Ongoing or One-Time
        '%%'::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        '%%'::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        'FY2024'::VARCHAR AS fiscal_year_code, -- Ex: FY2022, FY2023, FY2024, etc.
        ''::VARCHAR AS po_number,
        '%%'::VARCHAR AS format_name, -- Ex: Book, Serial, Textual Resource, etc.
        '%%'::VARCHAR AS expense_class, -- Ex:Physical Res - one-time perpetual, One time Electronic Res - Perpetual etc. 
        ''::VARCHAR AS lc_class_filter -- Ex: NA, PE, QA, TX, S, KFN, etc.
),

field050 AS -- gets the LC classification
       (SELECT
              sm.instance_hrid,
              sm.content AS lc_classification,
              substring (sm.content,'[A-Za-z]{0,}') AS lc_class,
              trim (trailing '.' from SUBSTRING (sm.content, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number
      
       FROM folio_source_record.marc__t AS sm--srs_marctab AS sm
              WHERE sm.field = '050'
              AND sm.sf = 'a'
              and sm.ord = 1
),

format_extract AS ( -- gets the format code from the marc leader and links to the local translation table
       SELECT
           sm.instance_id::UUID,
           substring(sm.content,7,2) AS bib_format_code,
           vs.folio_format_type AS bib_format_display

       FROM
           folio_source_record.marc__t AS sm 
           LEFT JOIN local_static.vs_folio_physical_material_formats AS vs
           ON substring (sm.content,7,2) = vs.leader0607
           WHERE sm.field = '000'
),

instance_subject_extract AS ( -- gets the primary subject from the instance table
    SELECT 
	    i.id AS instance_id,
	    i.jsonb#>>'{hrid}' AS instance_hrid,
	    s.jsonb#>> '{value}' AS subjects,
	    s.ordinality AS subjects_ordinality
	FROM 
    folio_inventory.instance AS i
    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'subjects')) WITH ORDINALITY AS s (jsonb)
    
    WHERE s.ordinality = 1
),

-- publication update

publication_extract AS -- gets publication date, place, and publisher from the folio_inventory.instance table

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
    WHERE pub.ordinality = 1
),

-- primary contributor update

contrib AS (
    SELECT
        i.id AS instance_id,
        jsonb_extract_path_text(i.jsonb, 'hrid') AS instance_hrid,
        jsonb_extract_path_text(ctb.jsonb, 'name') AS contributor_name,
        jsonb_extract_path_text(ctb.jsonb, 'primary') ::boolean AS contributor_is_primary
    FROM
        folio_inventory.instance AS i
        CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'contributors')) WITH ORDINALITY AS ctb (jsonb)
     
    WHERE jsonb_extract_path_text(ctb.jsonb, 'primary')::boolean = true
    and ctb.ordinality = 1
),

po_lines_locations AS -- replaced the "locations" subquery with this, the derivation code for po_lines_locations
(with ploc AS (
    SELECT
        p.id::uuid AS pol_id,
        jsonb_extract_path_text(locations.data, 'locationId')::UUID AS pol_location_id,
        jsonb_extract_path_text(locations.data, 'holdingId')::UUID AS pol_holding_id,
        jsonb_extract_path_text(locations.data, 'quantity')::INT AS pol_loc_qty,
        jsonb_extract_path_text(locations.data, 'quantityElectronic')::INT AS pol_loc_qty_elec,
        jsonb_extract_path_text(locations.data, 'quantityPhysical')::INT AS pol_loc_qty_phys
    FROM
        folio_orders.po_line AS p
        CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(jsonb, 'locations')) AS locations (data)
		)
			SELECT
			    ploc.pol_id,
			    ploc.pol_loc_qty,
			    ploc.pol_loc_qty_elec,
			    ploc.pol_loc_qty_phys,
			CASE WHEN ploc.pol_location_id IS NOT NULL THEN ploc.pol_location_id  
			          ELSE hr.permanent_location_id
			END AS pol_location_id, 
			CASE WHEN pol_location.name IS NOT NULL THEN pol_location.name
			         ELSE holdings_location.name
			END AS pol_location_name,
			CASE WHEN pol_location.name IS NOT NULL THEN 'pol_location'
			         WHEN holdings_location.name IS NOT NULL THEN 'pol_holding'
			         ELSE 'no_source'
			END AS pol_location_source
		FROM
		    ploc
		    LEFT JOIN folio_inventory.holdings_record__t AS hr ON ploc.pol_holding_id::UUID = hr.id
		    LEFT JOIN folio_inventory.location__t AS pol_location ON pol_location.id = ploc.pol_location_id
		    LEFT JOIN folio_inventory.location__t AS holdings_location ON holdings_location.id::UUID = hr.permanent_location_id
),

finance_transaction_invoices as -- copied the code for the finance_transaction_invoices derived table
(SELECT
    ft.id AS transaction_id,
    jsonb_extract_path_text(ft.jsonb, 'amount')::numeric(19,4) AS transaction_amount,
    CASE WHEN jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Credit'
        THEN 
            jsonb_extract_path_text(ft.jsonb, 'amount') :: NUMERIC(19,4) * -1
        ELSE 
            jsonb_extract_path_text(ft.jsonb, 'amount') :: NUMERIC(19,4)
    END AS effective_transaction_amount,
    jsonb_extract_path_text(ft.jsonb, 'currency') AS transaction_currency,
    jsonb_extract_path_text(ft.jsonb, 'metadata', 'createdDate')::date AS transaction_created_date,
    jsonb_extract_path_text(ft.jsonb, 'metadata', 'updatedDate')::date AS transaction_updated_date,
	jsonb_extract_path_text(ft.jsonb, 'description') AS transaction_description,
    ft.expenseclassid AS transaction_expense_class_id,
    ft.fiscalyearid AS transaction_fiscal_year_id,
    ft.fromfundid AS transaction_from_fund_id,
    jsonb_extract_path_text(ff.jsonb, 'name') AS transaction_from_fund_name,
    jsonb_extract_path_text(ff.jsonb, 'code') AS transaction_from_fund_code,
    ft.tofundid AS transaction_to_fund_id,
    jsonb_extract_path_text(tf.jsonb, 'name') AS transaction_to_fund_name,
    jsonb_extract_path_text(tf.jsonb, 'code') AS transaction_to_fund_code,
    CASE WHEN ft.tofundid IS NULL THEN ft.fromfundid ELSE ft.tofundid END AS effective_fund_id,
    CASE WHEN jsonb_extract_path_text(ff.jsonb, 'name') IS NULL THEN jsonb_extract_path_text(tf.jsonb, 'name') ELSE jsonb_extract_path_text(ff.jsonb, 'name') END AS effective_fund_name,
    CASE WHEN jsonb_extract_path_text(ff.jsonb, 'code') IS NULL THEN jsonb_extract_path_text(tf.jsonb, 'code') ELSE jsonb_extract_path_text(ff.jsonb, 'code') END AS effective_fund_code,
    fb.id AS transaction_from_budget_id,
    jsonb_extract_path_text(fb.jsonb, 'name') AS transaction_from_budget_name,
    jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceId')::UUID AS invoice_id,
    jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceLineId')::UUID AS invoice_line_id,
    jsonb_extract_path_text(ft.jsonb, 'transactionType') AS transaction_type,
    jsonb_extract_path_text(ii.jsonb, 'invoiceDate') AS invoice_date,
    jsonb_extract_path_text(ii.jsonb, 'paymentDate') AS invoice_payment_date,
    jsonb_extract_path_text(ii.jsonb, 'exchangeRate')::numeric(19,14) AS invoice_exchange_rate,
    jsonb_extract_path_text(il.jsonb, 'total')::numeric(19,4) AS invoice_line_total,
    jsonb_extract_path_text(ii.jsonb, 'currency') AS invoice_currency,
    jsonb_extract_path_text(il.jsonb, 'poLineId')::UUID AS po_line_id,
    jsonb_extract_path_text(ii.jsonb, 'vendorId')::UUID AS invoice_vendor_id,
    jsonb_extract_path_text(oo.jsonb, 'name') AS invoice_vendor_name   
FROM
    folio_finance.transaction AS ft
    LEFT JOIN folio_invoice.invoices AS ii ON jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceId')::UUID = ii.id
    LEFT JOIN folio_invoice.invoice_lines AS il ON jsonb_extract_path_text(ft.jsonb, 'sourceInvoiceLineId')::UUID = il.id
    LEFT JOIN folio_finance.fund AS ff ON ft.fromfundid = ff.id
    LEFT JOIN folio_finance.fund AS tf ON ft.tofundid = tf.id
    LEFT JOIN folio_finance.budget AS fb ON ft.fromfundid = fb.fundid AND ft.fiscalyearid = fb.fiscalyearid
    LEFT JOIN folio_organizations. organizations AS oo ON jsonb_extract_path_text(ii.jsonb, 'vendorId')::UUID = oo.id
WHERE (jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Pending payment'
    OR jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Payment'
    OR jsonb_extract_path_text(ft.jsonb, 'transactionType') = 'Credit')
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
        finance_transaction_invoices AS fti
                LEFT JOIN folio_finance.fund__t as ff  
                ON ff.code = fti.effective_fund_code
                
                LEFT JOIN folio_finance.fiscal_year__t as ffy 
                ON ffy.id = fti.transaction_fiscal_year_id::UUID
                
                LEFT JOIN folio_finance.fund_type__t as fft 
                ON fft.id = ff.fund_type_id
                
                LEFT JOIN folio_finance.ledger__t as fl  
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
    LEFT JOIN folio_finance.group_fund_fiscal_year__t AS FGFFY ON fg.id = fgffy.group_id 
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
),

field_902 AS -- gets the donor entries (if any) in the 902 field
	(SELECT 
		marc__t.instance_id,
		marc__t.instance_hrid,
		string_agg (distinct trim (marc__t.content),' | ') AS p_fund_donor
	
	FROM folio_source_record.marc__t 
	
	WHERE 
		marc__t.field = '902'
		AND marc__t.sf ='b'
	
	GROUP BY instance_id, instance_hrid
),

instance_languages AS
(SELECT
    instances.id AS instance_id,
    jsonb_extract_path_text(instances.jsonb, 'hrid') AS instance_hrid,
    languages.jsonb #>> '{}' AS instance_language,
    languages.ordinality AS language_ordinality
FROM
    folio_inventory.instance AS instances
    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(jsonb, 'languages')) WITH ORDINALITY AS languages (jsonb)
WHERE languages.ordinality = 1
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
 
       REPLACE (REPLACE (instance__t.title, chr(13), ''),chr(10),'') AS instance_title,
       instance__t.hrid AS instance_hrid,
       STRING_AGG (distinct po_lines_locations.pol_location_name, ' | ') AS location_name,
       po.order_type,
       pol.order_format,
       ftie.invoice_date::date,
       inv.payment_date::DATE AS invoice_payment_date,
       ftie.effective_transaction_amount/fq.fixed_quantity AS transaction_amount_per_qty,
       ftie.effective_transaction_amount,
       ftie.transaction_type,
       ftie.invoice_vendor_name,
       inv.vendor_invoice_no,
       invl.invoice_line_number,
       REPLACE (REPLACE (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description, -- updated code to get rid of carriage returns
       REPLACE (REPLACE (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment, -- updated code to get rid of carriage returns
       ftie.finance_ledger_name,
       ftie.fiscal_year_code AS transaction_fiscal_year_code,
       
       CASE
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date <'2023-07-01' THEN '2CUL'
                 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        		 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
                 ELSE ffyg.finance_group_name end AS finance_group_name,

       fec.name AS expense_class,
       ftie.effective_fund_code,
       ftie.fund_name,
       ftie.fund_type_name,
       field_902.p_fund_donor,
       po.po_number,
       pol.po_line_number,    
       formatt.bib_format_display AS format_name,
       inssub.subjects AS instance_subject,
       contrib.contributor_name AS primary_contributor,
       SUBSTRING (pe.publication_date,'\d{4}') AS publication_date,
       pe.publication_place AS publication_place,
       pe.publisher AS publisher,
       lang.instance_language AS LANGUAGE, 
       STRING_AGG (distinct field050.lc_classification,' | ') AS lc_classification,
       STRING_AGG (distinct field050.lc_class,' | ') AS lc_class,
       STRING_AGG (distinct field050.lc_class_number,' | ') AS lc_class_number,
       REPLACE(REPLACE (pol.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package, -- updated code to get rid of carriage returns
       fq.fixed_quantity AS quantity,     
       ftie.external_account_no
              
 FROM
    finance_transaction_invoices_ext AS ftie
    LEFT JOIN folio_invoice.invoice_lines__t AS invl ON invl.id = ftie.invoice_line_id
    LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
    LEFT JOIN folio_invoice.invoices__t AS inv ON ftie.invoice_id = inv.id
    LEFT JOIN folio_orders.po_line__t AS pol ON ftie.po_line_id ::UUID = pol.id::UUID
    LEFT JOIN folio_orders.purchase_order__t AS PO ON po.id = pol.purchase_order_id
    LEFT JOIN folio_inventory.instance__t ON instance__t.id = pol.instance_id 
    LEFT JOIN field050 ON instance__t.hrid = field050.instance_hrid 
    LEFT JOIN instance_languages AS lang ON lang.instance_id = pol.instance_id 
    LEFT JOIN instance_subject_extract AS inssub ON inssub.instance_hrid = instance__t.hrid 
    LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
    LEFT JOIN format_extract AS formatt ON pol.instance_id::UUID = formatt.instance_id
    LEFT JOIN po_lines_locations ON ftie.po_line_id = po_lines_locations.pol_id
    LEFT JOIN folio_finance.expense_class__t AS fec ON fec.id = ftie.expense_class
    LEFT JOIN publication_extract AS pe ON pe.instance_id = instance__t.id
    LEFT JOIN contrib ON instance__t.id = contrib.instance_id 
    LEFT JOIN field_902 ON instance__t.id = field_902.instance_id 
        
WHERE
        ((SELECT payment_date_start_date FROM parameters) ='' OR (inv.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (inv.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND inv.status = 'Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        and ftie.fund_type_name ILIKE 'Endowment%'--(SELECT fund_type FROM parameters)) OR ((SELECT fund_type FROM parameters) = ''))
        AND ((CASE
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
                 WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') 
                    AND inv.payment_date::date <'2023-07-01' THEN '2CUL'
                 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        		 WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
                 ELSE ffyg.finance_group_name end) = (select transaction_finance_group_name from parameters) 
                    OR (SELECT transaction_finance_group_name FROM parameters) = '')
        AND ((ftie.finance_ledger_name ILIKE (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) ILIKE '%%'))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
        AND ((po.order_type = (SELECT order_type_filter FROM parameters)) OR ((SELECT order_type_filter FROM parameters) = ''))
        AND ((po.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((fec.name ILIKE (SELECT expense_class FROM parameters) or (SELECT expense_class FROM parameters) ILIKE '%%' OR (SELECT expense_class FROM parameters) IS NULL))
        AND ((formatt.bib_format_display ILIKE (SELECT format_name FROM parameters) OR (SELECT format_name FROM parameters) ILIKE '%%' OR (SELECT format_name FROM parameters) IS NULL))
        AND ((field050.lc_class ILIKE (SELECT lc_class_filter FROM parameters) OR (SELECT lc_class_filter FROM parameters) ='' OR (SELECT lc_class_filter FROM parameters) IS NULL))      
                
GROUP BY
       ftie.transaction_id,
       instance__t.title, 
       instance__t.hrid, 
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
       invl.description,
       invl.comment,
       ftie.finance_ledger_name,
       ftie.fiscal_year_code,
       ffyg.finance_group_name,
       fec.name,
       ftie.effective_fund_code,
       ftie.fund_name,
       field_902.p_fund_donor,
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

