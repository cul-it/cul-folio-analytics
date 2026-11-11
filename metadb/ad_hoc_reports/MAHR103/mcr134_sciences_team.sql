--MCR134_sciences_team
--Approved Invoices with bib data - modified for just Sciences and Cornell Medical (Science Team version)
--Last updated: 11-11-26

--This query provides the list of approved invoices within a date range along with vendor name, finance group name,
--vendor invoice number, fund details, purchase order details, language, instance subject, fund type, expense class
--LC classification, LC class, LC class number, and bibliographic format.
--In cases where the quantity was incorrectly entered as zero, this query replaces zero with 1.
-- 7-29-25: used coalesce function to provide a title in cases where index_title is null
-- 8-5-26: updated finance groups for p2264, p650, p7353, p7368
-- 8-11-26: corrected fund/finance case when statement; changed to local_derived.marc__t
-- 8-19-26: removed instance_subjects_extract subquery and substituted instance_subjects derived table; updated regular expression for LC class from (0,} to {1,3})
-- corrected WHERE section for parameters values: transaction ledger name, format name, expense class, LC class, language
-- 8-20-26: updated WHERE section again to allow for null values
-- 9-29-26: updated to include publisher
-- 10-22-26: sargability fixes: removed redundant ::uuid casts from the indexed side of joins
--           (pol.id, pol.instance_id, po_lines_locations.pol_id) so Postgres can use their indexes;
--           removed unnecessary ORDER BY inside fund_fiscal_year_group CTE. Results are unchanged.
-- 11-11-26: incorporated Science Team changes from previous MCR134 query for science team
-- 11-11-26: removed the payment_date_range column from the output

WITH parameters AS (
    SELECT
    -- NOTE: do not use Fiscal Year Code parameter ALONG WITH payment start and end date parameters; they could be in conflict. Use one or the other.
        '' AS payment_date_start_date,-- NOTE: enter invoice payment start date and end date in YYYY-MM-DD format
        '' AS payment_date_end_date, -- NOTE: Excludes the selected date
        ''::VARCHAR AS transaction_fund_code, -- NOTE: Ex: 999, 521, p1162 etc.
        ''::varchar AS order_type_filter, -- NOTE: Ongoing or One-Time
        ''::VARCHAR AS fund_type, -- NOTE: Ex: Endowment - Restricted, Appropriated - Unrestricted etc.
        ''::VARCHAR AS transaction_finance_group_name,
    -- NOTE: parameter not used in this version; finance group is hard coded to ('Sciences','Cornell Medical') in the WHERE clause
        '%%'::VARCHAR AS transaction_ledger_name, -- NOTE: Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O
        'FY2027'::VARCHAR AS fiscal_year_code,-- NOTE: Ex: FY2022, FY2023, FY2024, etc.
        ''::VARCHAR AS po_number,
        '%%'::VARCHAR AS format_name, -- NOTE: Ex: Book, Serial, Textual Resource, etc.
        '%%'::VARCHAR AS expense_class,-- NOTE: Ex: Physical Res - one-time perpetual, One time Electronic Res - Perpetual etc.
        ''::VARCHAR AS lc_class_filter -- NOTE: Ex: NA, PE, QA, TX, S, KFN, etc.
),
field050 AS (     -- NOTE: gets the LC classification
    SELECT
        sm.instance_hrid,
        sm.content AS lc_classification,
        substring (sm.content,'[A-Za-z]{1,3}') as lc_class,
        trim (trailing '.' from SUBSTRING (sm.content, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number
    FROM 
    local_derived.marc__t AS sm
    --folio_source_record.marc__t AS sm
    WHERE sm.field = '050' AND sm.sf = 'a'
),
format_extract AS (         -- NOTE: gets the format code from the marc leader and links to the local translation table
    SELECT
        sm.instance_id::uuid,
        substring(sm.content,7,2) AS bib_format_code,
        vs.folio_format_type as bib_format_display
    FROM
        local_derived.marc__t AS sm --
        --folio_source_record.marc__t AS sm
        LEFT JOIN local_static.vs_folio_physical_material_formats AS vs
        ON substring (sm.content,7,2) = vs.leader0607
    WHERE sm.field = '000'
),
finance_transaction_invoices_ext AS (          -- NOTE: gets details of the finance transactions and converts Credits to negative values
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
        CASE WHEN fti.transaction_type = 'Credit' AND fti.transaction_amount >0.01
             THEN fti.transaction_amount *-1
             ELSE fti.transaction_amount
        END AS effective_transaction_amount,
        ff.external_account_no AS external_account_no
    FROM
        folio_derived.finance_transaction_invoices AS fti
        LEFT JOIN folio_finance.fund__t AS ff ON ff.code = fti.effective_fund_code
        LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy.id = fti.transaction_fiscal_year_id
        LEFT JOIN folio_finance.fund_type__t AS fft ON fft.id = ff.fund_type_id
        LEFT JOIN folio_finance.ledger__t AS fl ON ff.ledger_id = fl.id
),
fund_fiscal_year_group AS ( 
    -- NOTE: associates the fund with the finance group and fiscal year
    -- NOTE: 10-22-26: removed ORDER BY ff.code; sorting inside a CTE has no effect on final output and forces an unnecessary sort
    SELECT
        FGFFY.id AS group_fund_fiscal_year_id,
        FG.name AS finance_group_name,
        ff.id AS fund_id,
        ff.code AS fund_code,
        fgffy.fiscal_year_id AS fund_fiscal_year_id,
        ffy.code AS fiscal_year_code
    FROM
        folio_finance.groups__t AS FG
        LEFT JOIN folio_finance.group_fund_fiscal_year__t AS FGFFY ON fg.id = fgffy.group_id -- NOTE: OLD group_id
        LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy. id = fgffy.fiscal_year_id
        LEFT JOIN folio_finance.fund__t AS FF ON FF.id = fgffy.fund_id
),
new_quantity AS (
    -- NOTE: converts invoice line quantities showing "0" to "1" for use in a price-per-unit calculation
    SELECT
        id AS invoice_line_id,
        CASE WHEN quantity = 0
             THEN 1
             ELSE quantity
        END AS fixed_quantity
    FROM folio_invoice.invoice_lines__t
)

SELECT
-- NOTE: combines all the information from above subqueries and refers to the values entered in the parameters
DISTINCT current_date AS current_date,
    -- NOTE: payment_date_range column removed 11-11-26
    -- NOTE: columns below reordered to match the HWWS column order from the Science Team version
    ftie.fiscal_year_code AS transaction_fiscal_year_code,
    iext.instance_hrid,
    -- NOTE: renamed from index_title to instance_title to match the Science Team version; keeps the coalesce logic
    coalesce (replace(replace (iext.index_title, chr(13), ''),chr(10),''), replace(replace (iext.title, chr(13), ''),chr(10),''),' - ') AS instance_title,
    ftie.effective_fund_code,
    ftie.effective_transaction_amount,
    string_agg (distinct po_lines_locations.pol_location_name,' | ') as location_name,
    ftie.invoice_vendor_name,
    invl.invoice_line_number,
    inv.payment_date::DATE as invoice_payment_date,
    inssub.subjects AS instance_subject,
    po.po_number,
    pol.po_line_number,
    fec.name AS expense_class,
    po.order_type,
    pol.order_format,
    ftie.invoice_date::date,
    ftie.effective_transaction_amount/fq.fixed_quantity AS transaction_amount_per_qty,
    ftie.transaction_type,
    -- NOTE: publisher column retained from the main MCR134 query (added 9-29-26; not present in the earlier Science Team version)
    ip.publisher,
    inv.vendor_invoice_no,
    -- NOTE: invoice_status column retained from the main MCR134 query (not present in the earlier Science Team version)
    inv.status AS invoice_status,
    replace(replace (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,
    replace(replace (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,
    ftie.finance_ledger_name,
    CASE         -- NOTE: selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date <'2023-07-01' then '2CUL'
        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
        WHEN ftie.effective_fund_code = 'p2264' AND inv.payment_date::date >='2026-06-02' THEN 'Special Collections'
        WHEN ftie.effective_fund_code = 'p2264' AND inv.payment_date::date <'2026-06-02' THEN 'Humanities'
        WHEN ftie.effective_fund_code = 'p650' AND inv.payment_date::date >='2025-05-16' THEN 'Social Sciences'
        WHEN ftie.effective_fund_code = 'p650' AND inv.payment_date::date <'2025-05-16' THEN 'Interdisciplinary'
        WHEN ftie.effective_fund_code = 'p7353' AND inv.payment_date::date >='2026-07-07' THEN 'Social Sciences'
        WHEN ftie.effective_fund_code = 'p7353' AND inv.payment_date::date <'2026-07-07' THEN 'Humanities'
        WHEN ftie.effective_fund_code = 'p7368' AND inv.payment_date::date >='2025-07-09' THEN 'Social Sciences'
        WHEN ftie.effective_fund_code = 'p7368' AND inv.payment_date::date <'2025-07-09' THEN 'Humanities'
        ELSE ffyg.finance_group_name
    END AS finance_group_name,
    ftie.fund_name,
    ftie.fund_type_name,
    formatt.bib_format_display AS format_name,
    lang.instance_language AS LANGUAGE,
    string_agg (distinct field050.lc_classification,' | ') as lc_classification,
    string_agg (distinct field050.lc_class,' | ') as lc_class,
    string_agg (distinct field050.lc_class_number,' | ') as lc_class_number,
    replace(replace (pol.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package,
    fq.fixed_quantity AS quantity,
    ftie.external_account_no
FROM
    finance_transaction_invoices_ext AS ftie
    LEFT JOIN folio_invoice.invoice_lines__t AS invl ON invl.id = ftie.invoice_line_id
    LEFT JOIN new_quantity AS fq ON invl.id = fq.invoice_line_id
    LEFT JOIN folio_invoice.invoices__t AS inv ON ftie.invoice_id = inv.id
    -- NOTE: 10-22-26: cast only the CTE side; pol.id is already uuid, and casting it blocked the index on po_line__t.id
    LEFT JOIN folio_orders.po_line__t AS pol ON ftie.po_line_id::uuid = pol.id
    LEFT JOIN folio_orders.purchase_order__t AS PO ON po.id = pol.purchase_order_id
    LEFT JOIN folio_derived.instance_ext AS iext ON iext.instance_id = pol.instance_id
    LEFT JOIN field050 ON iext.instance_hrid = field050.instance_hrid
    LEFT JOIN folio_derived.instance_languages AS lang ON lang.instance_id = pol.instance_id
    LEFT JOIN folio_derived.instance_subjects as inssub on iext.instance_id = inssub.instance_id
    left join folio_derived.instance_publication as ip on iext.instance_id = ip.instance_id
    LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
    -- NOTE: 10-22-26: pol.instance_id is already uuid; removed cast so the join column stays sargable
    LEFT JOIN format_extract AS formatt ON pol.instance_id = formatt.instance_id
    -- NOTE: 10-22-26: cast only the CTE side; casting po_lines_locations.pol_id blocked the index on the derived table
    LEFT JOIN folio_derived.po_lines_locations on ftie.po_line_id::uuid = po_lines_locations.pol_id
    LEFT JOIN folio_finance.expense_class__t AS fec ON fec.id = ftie.expense_class

    CROSS JOIN parameters AS p
WHERE
    ((p.payment_date_start_date = '' or inv.payment_date::date >= p.payment_date_start_date::date)
    AND (p.payment_date_end_date = '' or inv.payment_date::date <= p.payment_date_end_date::date))
    AND inv.status in ('Paid','Approved')
    AND (inssub.subjects_ordinality = 1 or inssub.instance_id is null)
    AND (p.transaction_fund_code = '' or ftie.effective_fund_code = p.transaction_fund_code)
    AND (p.fund_type = '' or ftie.fund_type_name = p.fund_type)

    -- NOTE: finance group hard coded to ('Sciences','Cornell Medical') for the Science Team;
    -- replaces the transaction_finance_group_name parameter filter;
    -- keeps the updated CASE statement (including p2264, p650, p7353, p7368 fund changes)
    AND (CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date <'2023-07-01' then '2CUL'
        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
        WHEN ftie.effective_fund_code = 'p2264' AND inv.payment_date::date >='2026-06-02' THEN 'Special Collections'
        WHEN ftie.effective_fund_code = 'p2264' AND inv.payment_date::date <'2026-06-02' THEN 'Humanities'
        WHEN ftie.effective_fund_code = 'p650' AND inv.payment_date::date >='2025-05-16' THEN 'Social Sciences'
        WHEN ftie.effective_fund_code = 'p650' AND inv.payment_date::date <'2025-05-16' THEN 'Interdisciplinary'
        WHEN ftie.effective_fund_code = 'p7353' AND inv.payment_date::date >='2026-07-07' THEN 'Social Sciences'
        WHEN ftie.effective_fund_code = 'p7353' AND inv.payment_date::date <'2026-07-07' THEN 'Humanities'
        WHEN ftie.effective_fund_code = 'p7368' AND inv.payment_date::date >='2025-07-09' THEN 'Social Sciences'
        WHEN ftie.effective_fund_code = 'p7368' AND inv.payment_date::date <'2025-07-09' THEN 'Humanities'
        ELSE ffyg.finance_group_name
    END) in ('Sciences','Cornell Medical')

    AND (p.transaction_ledger_name = '' or ftie.finance_ledger_name ilike p.transaction_ledger_name)
    AND (p.fiscal_year_code = '' or ftie.fiscal_year_code = p.fiscal_year_code)
    AND (p.order_type_filter = '' or po.order_type = p.order_type_filter or po.order_type is null)
    AND (p.po_number = '' or po.po_number = p.po_number or po.po_number is null)
    AND (p.expense_class = '' or fec.name ilike p.expense_class or fec.name is null)
    AND (lang.language_ordinality = 1 OR lang.instance_id is null or language_ordinality ISNULL)
    AND (p.format_name = '' or formatt.bib_format_display ilike p.format_name or formatt.bib_format_display is null)
    AND (p.lc_class_filter = '' or field050.lc_class = p.lc_class_filter or field050.lc_class is null)
    AND (ip.publication_ordinality = 1 or ip.instance_id is null)
GROUP BY
    ftie.transaction_id,
    coalesce (replace(replace (iext.index_title, chr(13), ''),chr(10),''), replace(replace (iext.title, chr(13), ''),chr(10),''),' - '),
    iext.instance_hrid,
    po.order_type,
    pol.order_format,
    ftie.invoice_date::DATE,
    inv.payment_date::DATE,
    ftie.effective_transaction_amount/fq.fixed_quantity,
    ftie.effective_transaction_amount,
    ftie.transaction_type,
    ip.publisher,
    ftie.invoice_vendor_name,
    inv.vendor_invoice_no,
    invl.invoice_line_number,
    inv.status,
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
    lang.instance_language,
    pol.title_or_package,
    fq.fixed_quantity,
    ftie.external_account_no
-- NOTE: ORDER BY first column renamed to instance_title to match the Science Team version
ORDER BY 
    instance_title,
    ftie.finance_ledger_name,
    fund_type_name,
    ftie.invoice_vendor_name,
    inv.vendor_invoice_no,
    po.po_number,
    pol.po_line_number
;
