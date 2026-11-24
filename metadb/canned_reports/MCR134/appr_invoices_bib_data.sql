--MCR134

--Approved Invoices with bib data

--Last updated: 11-24-26

--This query provides the list of approved invoices within a date range along with vendor name, finance group name,

--vendor invoice number, fund details, purchase order details, language, instance subject, fund type, expense class

--LC classification, LC class, LC class number, AND bibliographic format.

--In cases WHERE the quantity was incorrectly entered as zero, this query replaces zero with 1.

-- 7-29-25: used coalesce function to provide a title in cases where index_title is null

-- 8-5-26: updated finance groups for p2264, p650, p7353, p7368

-- 8-11-26: corrected fund/finance case when statement; changed to local_derived.marc__t

-- 8-19-26: removed instance_subjects_extract subquery AND substituted instance_subjects derived table; updated regular expression for LC class from (0,} to {1,3})

-- corrected WHERE section for parameters values: transaction ledger name, format name, expense class, LC class, language

-- 8-20-26: updated WHERE section again to allow for null values

-- 9-29-26: updated to include publisher (lines 131, 181, 217, 229)

-- 10-22-26: sargability fixes: removed redundant ::uuid casts from the indexed side of joins

--           (pol.id, pol.instance_id, po_lines_locations.pol_id) so Postgres can use their indexes;

--           removed unnecessary ORDER BY inside fund_fiscal_year_group CTE. Results are unchanged.

-- 11-5-26: AI suggested using a CROSS JOIN to parameters values; re-wrote the WHERE clause;

                -- ran in 59 seconds (with regular marc__t), 7 minutes 14 sec using derived marc__t

-- 11-11-26: updated with suggestions from Claude. With local_derived.marc__t, runs in 4 min 46 sec; gets correct results

                -- Using regular marc__t, runs in 1 min 35 secs, gets correct results

-- 11-24-26: Summary of changes (Claude):

                -- Overall, the re-write minimizes the work needed to retrieve data in each step, and minimizes the number of records each subsequent step has to process

                -- new subquery "marc_bib" combines content extract from 000 field and 050 field (one-stop shopping)

                -- field050 subquery finds LC Class, Class Number and Classification; aggregates distinct values and puts the LC Class values in an array

                                -- Lc_class_array is accessed by the main query with an "ANY" function

                -- format_extract subquery references the new marc_bib result to extract the 2-character code from the 000 field

                -- finance_invoice_transactions_ext subquery uses a cross join to parameters to select only the records specified in the parameters

                -- fund_fiscal_year_group subquery does not need to bother joining multiple tables because joining to the FTIE records in the main query will take care of the work

                -- pol_locations subquery aggregates all locations (making one row per po_line_id)

                -- main query uses a cross join to parameters; WHERE statement updated to agree with references to the parameter values;

                                -- string_agg fields for call number components are no longer needed, so "Group By" clause is no longer needed

                                -- in general, cross joins put all values in a single row that is referenced by the query in the Where clause

                                                -- Otherwise, the query has to go back and evaluate each parameter value against each row for a true/false result

-- 11-24-26: cast invl.invoice_line_number to INT for sorting; removed "field050.lc_class is null or field050.instance_hrid is null" from the lc_class Where condition 

 

WITH parameters AS (

    select

    -- NOTE: do not use Fiscal Year Code parameter ALONG WITH payment start AND end date parameters; they could be in conflict. Use one or the other.

        '' AS payment_date_start_date,--enter invoice payment start date AND end date in YYYY-MM-DD format

        '' AS payment_date_end_date, -- Excludes the selected date

        ''::VARCHAR AS transaction_fund_code, -- Ex: 999, 521, p1162 etc.

        ''::varchar AS order_type_filter, -- Ongoing or One-Time

        ''::VARCHAR AS fund_type, -- Ex: Endowment - Restricted, Appropriated - Unrestricted etc.

        ''::VARCHAR AS transaction_finance_group_name, -- Ex: Sciences, Central, Rare & Distinctive, Law, Cornell Medical, Course Reserves etc.

        ''::VARCHAR AS transaction_ledger_name, -- Ex: CUL - Contract College, CUL - Endowed, CU Medical, Lab OF O

        'FY2026'::VARCHAR AS fiscal_year_code,-- Ex: FY2022, FY2023, FY2024, etc.

        ''::VARCHAR AS po_number,

        ''::VARCHAR AS format_name, -- Ex: Book, Serial, Textual Resource, etc.

        ''::VARCHAR AS expense_class,-- Ex:Physical Res - one-time perpetual, One time Electronic Res - Perpetual etc.

        ''::VARCHAR AS lc_class_filter -- Ex: NA, PE, QA, TX, S, KFN, etc.

),

 

marc_bib AS ( -- single scan of marc__t serving both field050 AND format_extract

    SELECT

        sm.instance_id,

        sm.instance_hrid,

        sm.field,

        sm.content

    FROM --local_derived.marc__t as sm

    folio_source_record.marc__t AS sm

    WHERE sm.field = '000' OR (sm.field = '050' AND sm.sf = 'a')

),

 

field050 AS (-- gets the LC classification, pre-aggregated to one row per instance

    SELECT

        instance_hrid,

        string_agg (DISTINCT content, ' | ') AS lc_classification,

        string_agg (DISTINCT substring (content,'[A-Za-z]{1,3}'), ' | ') AS lc_class,

        string_agg (DISTINCT trim (trailing '.' from SUBSTRING (content, '\d{1,}\.{0,}\d{0,}')), ' | ') AS lc_class_number,

        array_agg (DISTINCT substring (content,'[A-Za-z]{1,3}')) AS lc_class_array -- used by the lc_class_filter parameter

    FROM marc_bib

    WHERE field = '050'

    GROUP BY instance_hrid

),

 

format_extract AS ( -- gets the format code from the marc leader AND links to the local translation table

    -- DISTINCT preserves the dedup previously done by the outer GROUP BY when an instance has more than one source record

    SELECT DISTINCT

        mb.instance_id,

        mb.bib_format_code,

        vs.folio_format_type AS bib_format_display

    FROM (

                        SELECT instance_id, substring (content,7,2) AS bib_format_code

                        FROM marc_bib

                        WHERE field = '000'

                 ) AS mb

    LEFT JOIN local_static.vs_folio_physical_material_formats AS vs

        ON mb.bib_format_code = vs.leader0607

),

 

finance_transaction_invoices_ext AS ( -- gets details of the finance transactions AND converts Credits to negative values

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

    CROSS JOIN parameters AS p

        LEFT JOIN folio_finance.fund__t AS ff ON ff.id = fti.effective_fund_id -- joined on uuid id instead of text code

        LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy.id = fti.transaction_fiscal_year_id

        LEFT JOIN folio_finance.fund_type__t AS fft ON fft.id = ff.fund_type_id

        LEFT JOIN folio_finance.ledger__t AS fl ON ff.ledger_id = fl.id

    WHERE -- selective parameters applied early so downstream joins see fewer rows

        (p.fiscal_year_code = '' OR ffy.code = p.fiscal_year_code)

        AND (p.transaction_fund_code = '' OR fti.effective_fund_code = p.transaction_fund_code)

        AND (p.transaction_ledger_name = '' OR fl.name ILIKE p.transaction_ledger_name)

),

 

fund_fiscal_year_group AS ( -- associates the fund with the finance group AND fiscal year

    -- 10-22-26: removed ORDER BY ff.code; sorting inside a CTE has no effect on final output AND forces an unnecessary sort       

        SELECT DISTINCT

        fgffy.fund_id AS fund_id,

        fg.name AS finance_group_name

    FROM

        folio_finance.groups__t AS fg

        JOIN folio_finance.group_fund_fiscal_year__t AS fgffy ON fg.id = fgffy.group_id              

),

 

pol_locations AS ( -- pre-aggregates locations to one row per PO line

    SELECT

        pol_id,

        string_agg (DISTINCT pol_location_name, ' | ') AS location_name

    FROM folio_derived.po_lines_locations

    GROUP BY pol_id

)

 

SELECT               -- combines all the information from above subqueries AND refers to the values entered in the parameters

    DISTINCT current_date AS current_date,

    CASE WHEN

        ((SELECT payment_date_start_date::varchar

          FROM parameters)= '' OR

         (SELECT payment_date_end_date::varchar

          FROM parameters) ='')

        THEN 'Not Selected'

        ELSE (SELECT payment_date_start_date::varchar

              FROM parameters) || ' to '::varchar ||

             (SELECT payment_date_end_date::varchar

              FROM parameters)

    END AS payment_date_range,

    coalesce (replace(replace (iext.index_title, chr(13), ''),chr(10),''), replace(replace (iext.title, chr(13), ''),chr(10),''),' - ') AS index_title,

    iext.instance_hrid,

    polloc.location_name,

    po.order_type,

    pol.order_format,

    ftie.invoice_date::date,

    inv.payment_date::DATE as invoice_payment_date,

    ftie.effective_transaction_amount / CASE WHEN invl.quantity = 0 THEN 1 ELSE invl.quantity END AS transaction_amount_per_qty,

    ftie.effective_transaction_amount,

    ftie.transaction_type,

    ip.publisher,

    ftie.invoice_vendor_name,

    inv.vendor_invoice_no,

    invl.invoice_line_number::INT,

    inv.status as invoice_status,

    replace(replace (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,

    replace(replace (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,

    ftie.finance_ledger_name,

    ftie.fiscal_year_code AS transaction_fiscal_year_code,

    CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, AND Course Reserves merged into Interdisciplinary in FY2025

        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') AND inv.payment_date::date >='2023-07-01' THEN 'Area Studies'

        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') AND inv.payment_date::date <'2023-07-01' then '2CUL'

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

    fec.name AS expense_class,

    ftie.effective_fund_code,

    ftie.fund_name,

    ftie.fund_type_name,

    po.po_number,

    pol.po_line_number,

    formatt.bib_format_display AS format_name,

    inssub.subjects AS instance_subject,

    lang.instance_language AS LANGUAGE,

    field050.lc_classification,

    field050.lc_class,

    field050.lc_class_number,

    replace(replace (pol.title_or_package, chr(13), ''),chr(10),'') AS po_line_title_or_package,

    CASE WHEN invl.quantity = 0 THEN 1 ELSE invl.quantity END AS quantity, -- converts quantities showing "0" to "1" for the price-per-unit calculation

    ftie.external_account_no

FROM

    finance_transaction_invoices_ext AS ftie

    LEFT JOIN folio_invoice.invoice_lines__t AS invl ON invl.id = ftie.invoice_line_id

    LEFT JOIN folio_invoice.invoices__t AS inv ON ftie.invoice_id = inv.id

    LEFT JOIN folio_orders.po_line__t AS pol ON ftie.po_line_id::uuid = pol.id

    LEFT JOIN folio_orders.purchase_order__t AS PO ON po.id = pol.purchase_order_id

    LEFT JOIN folio_derived.instance_ext AS iext ON iext.instance_id = pol.instance_id

    LEFT JOIN field050 ON iext.instance_hrid = field050.instance_hrid

    LEFT JOIN folio_derived.instance_languages AS lang ON lang.instance_id = pol.instance_id

    LEFT JOIN folio_derived.instance_subjects as inssub on iext.instance_id = inssub.instance_id

    LEFT JOIN folio_derived.instance_publication as ip on iext.instance_id = ip.instance_id

    LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id

    LEFT JOIN format_extract AS formatt ON pol.instance_id = formatt.instance_id

    LEFT JOIN pol_locations AS polloc ON ftie.po_line_id::uuid = polloc.pol_id

    LEFT JOIN folio_finance.expense_class__t AS fec ON fec.id = ftie.expense_class

   

CROSS JOIN parameters as p

 

WHERE  

    ((p.payment_date_start_date = '' or inv.payment_date::date >= p.payment_date_start_date::date)

                AND (p.payment_date_end_date = '' or inv.payment_date::date <= p.payment_date_end_date::date))  

    AND inv.status in ('Paid','Approved')

    AND (inssub.subjects_ordinality = 1 or inssub.instance_id is null)

    AND (p.transaction_fund_code = '' or ftie.effective_fund_code = p.transaction_fund_code)

    AND (p.fund_type = '' or ftie.fund_type_name = p.fund_type)

    AND (p.transaction_finance_group_name = '' or

    (CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, AND Course Reserves merged into Interdisciplinary in FY2025

        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') AND inv.payment_date::date >='2023-07-01' THEN 'Area Studies'

        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') AND inv.payment_date::date <'2023-07-01' then '2CUL'

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

                END) = p.transaction_finance_group_name)

    AND (p.transaction_ledger_name = '' or ftie.finance_ledger_name ilike p.transaction_ledger_name)

    AND (p.fiscal_year_code = '' or ftie.fiscal_year_code = p.fiscal_year_code)

    AND (p.order_type_filter = '' or po.order_type = p.order_type_filter or po.order_type is null)

    AND (p.po_number = '' or po.po_number = p.po_number or po.po_number is null)

    AND (p.expense_class = '' or fec.name ilike p.expense_class or fec.name is null)

    AND (lang.language_ordinality = 1 OR lang.instance_id is null or language_ordinality ISNULL)

    AND (p.format_name = '' or formatt.bib_format_display ilike p.format_name or formatt.bib_format_display is null)

                -- matches if ANY 050 class that equals the filter; instances with no 050 (or no extractable class) are kept, as before

    AND (p.lc_class_filter = '' or p.lc_class_filter = ANY (field050.lc_class_array)) -- or field050.lc_class is null or field050.instance_hrid is null)

    AND (ip.publication_ordinality = 1 or ip.instance_id is null)

ORDER BY index_title,

    ftie.finance_ledger_name,

    fund_type_name,

    ftie.invoice_vendor_name,

    inv.vendor_invoice_no,

    invl.invoice_line_number::INT,

    po.po_number,

    pol.po_line_number

                ;
