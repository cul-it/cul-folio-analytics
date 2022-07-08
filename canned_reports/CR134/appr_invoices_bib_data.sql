--This query provides the list of approved invoices within a date range along with vendor name, finance group name, 
--vendor invoice number, fund details, purchase order details, language, instance subject, and bibliographic format.

WITH parameters AS (

    SELECT
        '2022-07-01' AS payment_date_start_date,--enter invoice payment start date and end date in YYYY-MM-DD format
        '2023-07-01' AS payment_date_end_date, -- Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.
        ''::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.
        ''::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        'FY2023'::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023 etc.
        ''::VARCHAR AS po_number,
        ''::VARCHAR AS bib_format_display -- Ex: Book, Serial, Textual Resource, etc.
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

language_extract AS (
        SELECT
        sm.instance_id AS instance_id,
        substring(sm.content, 36,3) AS LANGUAGE,
        sr.state,
        sr.id

    FROM
        srs_marctab AS sm
        LEFT JOIN srs_records AS sr on sr.id = sm.srs_id
        WHERE sm.field = '008' AND sr.state = 'ACTUAL'
),

format_extract as (

	SELECT
        sm.instance_id AS instance_id,
        substring(sm.content,7,2) AS bib_format_code,
        jl.bib_format_display,
        sr.state,
        sr.id

    FROM
        srs_marctab AS sm
        LEFT JOIN srs_records AS sr ON sr.id = sm.srs_id
        LEFT JOIN local.jl_bib_format_display_csv AS jl ON substring(sm.content,7,2) = jl.bib_format

        WHERE sm.field = '000' AND sr.state = 'ACTUAL'
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

finance_transaction_invoices_ext AS (

        SELECT
                fti.invoice_payment_date::DATE AS invoice_payment_date,
                fti.transaction_fiscal_year_id,
                ffy.code AS fiscal_year_code,
                fti.invoice_id,
                fti.invoice_line_id,
                fti.po_line_id,
                fl.name AS finance_ledger_name,
                fti.invoice_vendor_name,
                fti.transaction_type,
                fti.transaction_amount,
                fti.effective_fund_id AS effective_fund_id,
                fti.effective_fund_code AS effective_fund_code,
               	fft.name AS fund_type_name,
                CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >1 THEN fti.transaction_amount *-1 ELSE fti.transaction_amount END AS effective_transaction_amount,
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
WHERE (ffy.code = (SELECT fiscal_year_code FROM parameters))
ORDER BY ff.code

)
-- MAIN QUERY
SELECT
        current_date AS current_date,           
        (    
        SELECT payment_date_start_date::varchar
            
        FROM
        parameters) || ' to '::varchar || (
       
        SELECT
        payment_date_end_date::varchar

        FROM
        parameters) AS payment_date_range,
        inv.payment_date::DATE,
        ftie.finance_ledger_name,
        ftie.fiscal_year_code AS transaction_fiscal_year_code,
        ffyg.finance_group_name,
        ftie.effective_fund_code,
        ftie.fund_type_name,
        po.po_number,
        pol.po_line_number,
        pol.order_format,
        po.order_type,
        lang.language AS language,
        format_extract.bib_format_display,
        ftie.invoice_vendor_name,
        inv.vendor_invoice_no,
        inssub.subject AS instance_subject, -- This IS the subject that is first on the list.
        pol.title_or_package AS po_line_title_or_package,
        iext.title AS instance_title,
        --------frh.call_number -- Will de added after the Kiwi release
        iext.instance_hrid,
        ------polholdid.pol_holding_id AS holdings_id, -- Will be addded after the Kiwi release
        ------frh.holdings_hrid AS holdings_hrid, -- Will be addded after the Kiwi release
        invl.description AS invoice_line_description,
        invl.comment AS invoice_line_comment,
        ftie.effective_transaction_amount AS transaction_amount,
        ftie.transaction_type,
        ftie.external_account_no
FROM
        finance_transaction_invoices_ext AS ftie
        LEFT JOIN invoice_lines AS invl ON invl.id = ftie.invoice_line_id
       LEFT JOIN invoice_invoices AS inv ON ftie.invoice_id = inv.id
        LEFT JOIN po_lines AS pol ON ftie.po_line_id = pol.id
        LEFT JOIN po_purchase_orders AS PO ON po.id = pol.purchase_order_id
        LEFT JOIN folio_reporting.instance_ext AS iext ON iext.instance_id = pol.instance_id
        LEFT JOIN folio_reporting.po_lines_locations AS poll ON poll.pol_id = pol.id
        LEFT JOIN pol_holdings_id AS polholdid ON polholdid.pol_id = pol.id
        --------LEFT JOIN folio_reporting.holdings_ext AS frh ON frh.holdings_id = polholdid.pol_holding_id  -- Will add after the Kiwi release
        LEFT JOIN language_extract AS lang ON lang.instance_id = pol.instance_id
        LEFT JOIN instance_subject_extract AS inssub ON inssub.instance_hrid = iext.instance_hrid
        LEFT JOIN format_extract on pol.instance_id = format_extract.instance_id
        LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
       
WHERE
		((SELECT payment_date_start_date FROM parameters) ='' OR (inv.payment_date >= (SELECT payment_date_start_date FROM parameters)::DATE))
        AND ((SELECT payment_date_end_date FROM parameters) ='' OR (inv.payment_date <= (SELECT payment_date_end_date FROM parameters)::DATE))
        AND inv.status LIKE 'Paid'
        AND ((ftie.effective_fund_code = (SELECT transaction_fund_code FROM parameters)) OR ((SELECT transaction_fund_code FROM parameters) = ''))
        AND ((ftie.fund_type_name = (SELECT fund_type FROM parameters)) OR ((SELECT fund_type FROM parameters) = ''))
        AND ((ffyg.finance_group_name = (SELECT transaction_finance_group_name FROM parameters)) OR ((SELECT transaction_finance_group_name FROM parameters) = ''))
        AND ((ftie.finance_ledger_name = (SELECT transaction_ledger_name FROM parameters)) OR ((SELECT transaction_ledger_name FROM parameters) = ''))
        AND ((ftie.fiscal_year_code = (SELECT fiscal_year_code FROM parameters)) OR ((SELECT fiscal_year_code FROM parameters) = ''))
        AND ((po.po_number = (SELECT po_number FROM parameters)) OR ((SELECT po_number FROM parameters) = ''))
        AND ((format_extract.bib_format_display = (SELECT bib_format_display FROM parameters)) OR ((SELECT bib_format_display FROM parameters) = ''))
ORDER BY
        ftie.finance_ledger_name,
        ffyg.finance_group_name,
        fund_type_name,
        ftie.invoice_vendor_name,
        inv.vendor_invoice_no,
        po.po_number 
        ;
        
