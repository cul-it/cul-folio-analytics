-- MCR223
-- approvals_and_firm_orders

-- This query finds all orders (not just approvals) showing the "bill to" and "ship to" locations in the purchase order or invoice. 
-- It also includes the purchase order location, workflow status, order type, order format, vendor name, fund, and fiscal year. 
-- 10-12-23: added po_instance to get location
-- 1-4-24: revised to get call number, LC class and class numbers, holdings hrids, holdings locations, holdings type name, mode of issuance name, 
--   instance and holdings suppress, finance group; commented out order type at Kizer's request 
-- 1-5-24: added publisher, publication_date, language, primary subject
-- 1-9-24: put "order type" back in; added bill-to and ship-to for purchase orders and invoices
-- 1-10-24: aggregated the results in a final query at the end to get rid of combinatorial duplicates
-- 1-11-24: added filters for po_bill_to, inv_bill_to, po_ship_to and order type
-- 1-16-24: added sorting for Firm orders and Approvals, with categories for print and electronic books and serials
-- 1-23-24: added format translation from the Header (folio_format_type)
-- 1-24-24: resequences the fields in the order preferred by Kizer
-- 1-29-24: per Natalya, changed the sorting algorithm to include 'LTS Standing Orders','LTS Documents' in Ongoing with 'Serials' result

WITH parameters as 
(SELECT
    ''::VARCHAR AS fiscal_year_filter, -- Ex: FY2023
    '%%'::VARCHAR AS vendor_name_filter, -- Ex: HARRASSOWITZ
    ''::VARCHAR AS fund_code_filter, -- Ex: 310, 521, p6610
    ''::VARCHAR as order_type_filter, -- Ex: Ongoing or One-time
    ''::VARCHAR as po_bill_to_filter,-- Ex: LTS Approvals, LTS Acquisitions, LTS E-Resources & Serials, Law Technical Services, RMC Acquisitions
    ''::VARCHAR as inv_bill_to_filter,-- Ex: LTS Approvals, LTS Acquisitions, LTS E-Resources & Serials, Law Technical Services, RMC Acquisitions
    ''::VARCHAR as po_ship_to_filter -- Ex: LTS Approvals, LTS Acquisitions, LTS E-Resources & Serials, Law Technical Services, RMC Acquisitions
),
field050 AS -- gets the LC classification from the 050
(SELECT 
        sm.instance_hrid,
        sm.content AS lc_classification,
        SUBSTRING (sm.content,'[A-Za-z]{0,}') AS lc_class,
        TRIM (trailing '.' FROM SUBSTRING (sm.content, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number
FROM folio_source_record.marc__t AS sm 
        WHERE sm.field = '050' AND sm.sf = 'a'
),
field090 AS -- gets the LC classification from the 090
(SELECT 
        sm.instance_hrid,
        sm.content AS lc_classification,
        SUBSTRING (sm.content,'[A-Za-z]{0,}') AS lc_class,
        TRIM (trailing '.' FROM SUBSTRING (sm.content, '\d{1,}\.{0,}\d{0,}')) AS lc_class_number
FROM folio_source_record.marc__t AS sm 
        WHERE sm.field = '090' AND sm.sf = 'a'
),
folio_format as 
(SELECT 
        sm.instance_hrid,
        substring (sm.content,7,2) as leader_code,
        vs.folio_format_type
FROM folio_source_record.marc__t as sm 
LEFT JOIN local_shared.vs_folio_physical_material_formats as vs on trim (substring (sm.content,7,2)) = trim (vs.leader0607)
    WHERE sm.field = '000'
),
invbillto AS -- extracts "name" from the value field (used for invoice_invoices bill_to field)
(SELECT
        cfge.id AS inv_bill_to_id,
        SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS inv_bill_to_name
FROM folio_configuration.config_data__t AS cfge
    WHERE cfge.value LIKE '{"name"%'
),
pobillto AS -- extracts "name" from the value field (used for po_purchase_orders bill_to field)
(SELECT
        cfge.id AS po_bill_to_id,
        SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS po_bill_to_name
FROM folio_configuration.config_data__t AS cfge
    WHERE cfge.value LIKE '{"name"%'
),
poshipto AS -- extracts "name" from the value field (used for po_purchase_orders ship_to field)
(SELECT
        cfge.id AS po_ship_to_id,
        SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS po_ship_to_name
FROM folio_configuration.config_data__t AS cfge
    WHERE cfge.value LIKE '{"name"%'
),
fund_fiscal_year_group AS -- translates the ids for fund, fund group AND fiscal year for linking to the main subquery 
(SELECT
        fgffy.id AS group_fund_fiscal_year_id,
        fg.name AS finance_group_name,
        ff.id AS fund_id,
        ff.code AS fund_code,
        fgffy.fiscal_year_id AS fund_fiscal_year_id,
        ffy.code AS fiscal_year_code
FROM folio_finance.groups__t AS fg
        LEFT JOIN folio_finance.group_fund_fiscal_year__t AS fgffy ON fg.id = fgffy.group_id
        LEFT JOIN folio_finance.fiscal_year__t AS ffy ON ffy. id = fgffy.fiscal_year_id
        LEFT JOIN folio_finance.fund__t AS ff ON ff.id = fgffy.fund_id
    WHERE ((ffy.code = (SELECT fiscal_year_filter FROM parameters)) OR ((SELECT fiscal_year_filter FROM parameters) = ''))
),
lang AS -- gets primary language
(SELECT 
    instlang.instance_id,
    instlang.instance_hrid,
    instlang.instance_language
FROM folio_derived.instance_languages AS instlang 
    WHERE instlang.language_ordinality = 1
),
subj AS -- get primary subject
    (SELECT 
    instsub.instance_id,
    instsub.subjects 
FROM folio_derived.instance_subjects AS instsub
    WHERE instsub.subjects_ordinality = 1
),
finall AS -- join up all the preceding subqueries
(SELECT DISTINCT
    ffyg.fiscal_year_code,
    poi.pol_instance_hrid,
    STRING_AGG (DISTINCT he.holdings_hrid,' | ') AS holdings_hrid,
    invinst.title as instance_title,
    il.description AS invoice_lines_description,
    TRIM (LEADING ' | ' FROM STRING_AGG (DISTINCT he.call_number,' | ')) AS call_number,
    STRING_AGG (DISTINCT coalesce (SUBSTRING (he.call_number,'[A-Za-z]{1,}'), field050.lc_class, field090.lc_class),' | ') AS lc_class,
    TRIM (trailing '.' FROM coalesce (SUBSTRING (he.call_number, '\d{1,}\.{0,}\d{0,}'), field050.lc_class_number, field090.lc_class_number))::NUMERIC AS lc_class_number,
    ppo.order_type,
    subj.subjects AS primary_subject,
    string_agg (distinct iser.series,' | ') as series,
    moi.name AS instance_mode_of_issuance,
    folio_format.folio_format_type,
    STRING_AGG (DISTINCT he.type_name,' | ') AS holdings_type_name,
    CASE WHEN invinst.discovery_suppress = 'True' THEN 'True' ELSE 'False' END AS instance_suppress,
    STRING_AGG (DISTINCT (CASE WHEN he.discovery_suppress = 'True' THEN 'True' ELSE 'False' END),' | ') AS holdings_suppress,
    pl.order_format,
    ppo.workflow_status,
    oo.name AS vendor_name,
    pl.publisher,
    SUBSTRING (pl.publication_date,'\d{4}') AS publication_date,
    lang.instance_language,
    il.comment AS invoice_line_comment,
    ii.vendor_invoice_no,
    il.invoice_line_number::NUMERIC,
    ii.invoice_date::DATE,
    ii.payment_date::DATE AS invoice_payment_date,  
    pl.po_line_number,
    poll.pol_location_name AS poll_location_name,
    invbillto.inv_bill_to_name,
    pobillto.po_bill_to_name,
    poshipto.po_ship_to_name,
    ilfd.fund_name,
    ilfd.fund_code,
    CASE
        WHEN ilfd.fund_code IN ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') AND ii.payment_date::DATE >='2023-07-01' THEN 'Area Studies' 
        WHEN ilfd.fund_code IN ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') AND ii.payment_date::DATE <'2023-07-01' THEN '2CUL'
        ELSE ffyg.finance_group_name END AS finance_group_name,
    fti.transaction_type,
    ii.payment_date::DATE,
    ilfd.fund_distribution_type,
    ilfd.fund_distribution_value,
    CASE WHEN ilfd.fund_distribution_type = 'percentage' 
    THEN ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::NUMERIC(12,2) ELSE ilfd.fund_distribution_value END AS cost
FROM folio_invoice.invoices__t ii
    LEFT JOIN folio_invoice.invoice_lines__t as il ON ii.id=il.invoice_id
    LEFT JOIN folio_derived.invoice_lines_fund_distributions AS ilfd on il.id = ilfd.invoice_line_id
    LEFT JOIN folio_orders.po_line__t AS pl ON il.po_line_id = pl.id
    LEFT JOIN folio_derived.po_lines_locations AS poll on il.po_line_id = poll.pol_id
    LEFT JOIN folio_derived.po_instance AS poi on pl.id::uuid = poi.po_line_id::uuid
    LEFT JOIN folio_derived.holdings_ext AS he on poi.pol_instance_id = he.instance_id
    LEFT JOIN folio_inventory.instance__t AS invinst on he.instance_id = invinst.id
    LEFT join folio_format on invinst.hrid = folio_format.instance_hrid
    LEFT join folio_derived.instance_series AS iser on invinst.hrid = iser.instance_hrid
    LEFT JOIN folio_inventory.mode_of_issuance__t AS moi on invinst.mode_of_issuance_id = moi.id
    LEFT JOIN folio_orders.purchase_order__t AS ppo on pl.purchase_order_id = ppo.id
    LEFT JOIN folio_organizations.organizations__t AS oo on ii.vendor_id = oo.id
    LEFT JOIN folio_derived.finance_transaction_invoices AS fti on il.id = fti.invoice_line_id
         AND ilfd.invoice_line_id = fti.invoice_line_id
         AND ilfd.fund_name = fti.effective_fund_name
    LEFT JOIN fund_fiscal_year_group as ffyg on fti.transaction_fiscal_year_id = ffyg.fund_fiscal_year_id
         AND  ffyg.fund_id = ilfd.fund_distribution_id
    LEFT JOIN field050 on poi.pol_instance_hrid = field050.instance_hrid
    LEFT JOIN field090 on poi.pol_instance_hrid = field090.instance_hrid
    LEFT JOIN lang on invinst.id = lang.instance_id
    LEFT JOIN subj on invinst.id = subj.instance_id
    LEFT JOIN invbillto on ii.bill_to = invbillto.inv_bill_to_id
    LEFT JOIN pobillto on ppo.bill_to = pobillto.po_bill_to_id
    LEFT JOIN poshipto on ppo.ship_to = poshipto.po_ship_to_id
WHERE
    ii.status = 'Paid'
    AND ii.payment_date::DATE IS NOT NULL
    AND (ffyg.fiscal_year_code = (SELECT fiscal_year_filter FROM parameters) or (SELECT fiscal_year_filter FROM parameters) = '')
    AND (oo.name ilike (SELECT vendor_name_filter FROM parameters) or (SELECT vendor_name_filter FROM parameters) = '')
    AND (fti.effective_fund_code = (SELECT fund_code_filter FROM parameters) or (SELECT fund_code_filter FROM parameters) = '')
    AND (ppo.order_type = (select order_type_filter from parameters) or (select order_type_filter from parameters) = '')
    AND (pobillto.po_bill_to_name = (select po_bill_to_filter from parameters) or (select po_bill_to_filter from parameters) = '')
    AND (poshipto.po_ship_to_name = (select po_ship_to_filter from parameters) or (select po_ship_to_filter from parameters) = '')
    AND (invbillto.inv_bill_to_name = (select inv_bill_to_filter from parameters) or (select inv_bill_to_filter from parameters) = '')
GROUP BY 
    ffyg.fiscal_year_code, poi.pol_instance_hrid, invinst.title, il.description, field050.lc_class_number, field090.lc_class_number,
    he.call_number, subj.subjects, ii.vendor_invoice_no, ii.invoice_date::DATE, ii.payment_date::DATE, ppo.order_type,
    folio_format.folio_format_type, pl.order_format, lang.instance_language,
    CASE WHEN invinst.discovery_suppress = 'True' THEN 'True' ELSE 'False' END, moi.name, ppo.workflow_status, oo.name, pl.publisher,
    SUBSTRING (pl.publication_date,'\d{4}'), il.comment, il.invoice_line_number::NUMERIC, pl.po_line_number, invbillto.inv_bill_to_name,
    pobillto.po_bill_to_name, poshipto.po_ship_to_name, poll.pol_location_name, ilfd.fund_name, ilfd.fund_code, 
    CASE
        WHEN ilfd.fund_code IN ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') AND ii.payment_date::DATE >='2023-07-01' THEN 'Area Studies' 
        WHEN ilfd.fund_code IN ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') AND ii.payment_date::DATE <'2023-07-01' THEN '2CUL'
        ELSE ffyg.finance_group_name END,
    fti.transaction_type, ilfd.fund_distribution_type, ilfd.fund_distribution_value,
    CASE WHEN ilfd.fund_distribution_type = 'percentage' 
    THEN ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::NUMERIC(12,2) ELSE ilfd.fund_distribution_value END
)
SELECT -- aggregate certain fields to eliminate combinatorial duplicate, apply sorting algorithm to find acquisitions type, order format and material type
    finall.fiscal_year_code,
    CASE  WHEN (finall.inv_bill_to_name = 'LTS Approvals' or finall.po_bill_to_name = 'LTS Approvals' 
                OR finall.po_ship_to_name = 'LTS Approvals') then 'Approvals'
         WHEN (finall.inv_bill_to_name in ('LTS Acquisitions','LTS E-Resources & Serials', 'RMC Acquisitions','Law Technical Services') 
                OR finall.po_bill_to_name in ('LTS Acquisitions','LTS E-Resources & Serials', 'RMC Acquisitions','Law Technical Services') 
                OR finall.po_ship_to_name in ('LTS Acquisitions','LTS E-Resources & Serials', 'RMC Acquisitions','Law Technical Services')) 
                AND finall.order_type = 'One-Time' then 'Firm orders'
         WHEN (finall.inv_bill_to_name in ('LTS E-Resources & Serials','Law Technical Services','RMC Acquisitions','LTS Standing Orders','LTS Documents')
                OR finall.po_bill_to_name in  ('LTS E-Resources & Serials','Law Technical Services', 'RMC Acquisitions','LTS Standing Orders','LTS Documents') 
                OR finall.po_ship_to_name in ('LTS E-Resources & Serials','Law Technical Services','RMC Acquisitions','LTS Standing Orders','LTS Documents')) 
                AND finall.order_type = 'Ongoing' THEN 'Serials'
         ELSE 'Undetermined' END AS acquisition_type,
    finall.order_format,
    CASE WHEN coalesce (finall.folio_format_type, finall.holdings_type_name, finall.instance_mode_of_issuance) is null then 'Unspecified'
         WHEN coalesce (finall.folio_format_type, finall.holdings_type_name, finall.instance_mode_of_issuance) ilike '%serial%' then 'Serial'
         WHEN coalesce (finall.folio_format_type, finall.holdings_type_name, finall.instance_mode_of_issuance) ilike '%book%' then 'Book'
         ELSE 'Other material format' end as material_format,
    finall.fund_name,
    finall.fund_code,
    finall.finance_group_name,
    finall.cost,   
    finall.vendor_name,   
    finall.instance_title,
    finall.series,
    finall.publisher,
    STRING_AGG (DISTINCT finall.publication_date,' | ') AS publication_date,
    STRING_AGG (DISTINCT finall.lc_class,' | ') AS lc_class,
    finall.lc_class_number,
    TRIM (LEADING ' | ' FROM STRING_AGG (DISTINCT finall.call_number,' | ')) AS call_number,
    STRING_AGG (DISTINCT finall.primary_subject,' | ') AS primary_subject,
    STRING_AGG (DISTINCT finall.instance_language,' | ') AS language,
    finall.pol_instance_hrid,
    STRING_AGG (DISTINCT finall.holdings_hrid,' | ') AS holdings_id,
    STRING_AGG (DISTINCT finall.order_type,' | ') AS order_type,
    STRING_AGG (DISTINCT finall.instance_mode_of_issuance,' | ') AS mode_of_issuance,
    STRING_AGG (DISTINCT finall.holdings_type_name,' | ') AS holdings_type_name,
    finall.folio_format_type,
    STRING_AGG (DISTINCT finall.instance_suppress,' | ') AS instance_suppress,
    STRING_AGG (DISTINCT finall.holdings_suppress,' | ') AS holdings_suppress,
    finall.workflow_status,
    STRING_AGG (DISTINCT finall.invoice_line_comment,' | ') AS invoice_line_comment,
    STRING_AGG (DISTINCT finall.vendor_invoice_no,' | ') AS vendor_invoice_number,
    finall.invoice_line_number::NUMERIC,
    finall.invoice_date::DATE,
    finall.invoice_payment_date,    
    finall.po_line_number,
    finall.poll_location_name,
    finall.inv_bill_to_name,
    finall.po_bill_to_name,
    finall.po_ship_to_name,
    finall.transaction_type,
    finall.payment_date::DATE,
    finall.fund_distribution_type,
    finall.fund_distribution_value
FROM finall 
GROUP BY finall.fiscal_year_code,
     CASE WHEN  (finall.inv_bill_to_name = 'LTS Approvals' OR finall.po_bill_to_name = 'LTS Approvals' 
                OR finall.po_ship_to_name = 'LTS Approvals') THEN 'Approvals'
          WHEN (finall.inv_bill_to_name in ('LTS Acquisitions','LTS E-Resources & Serials', 'RMC Acquisitions','Law Technical Services') 
                OR finall.po_bill_to_name in ('LTS Acquisitions','LTS E-Resources & Serials', 'RMC Acquisitions','Law Technical Services') 
                OR finall.po_ship_to_name in ('LTS Acquisitions','LTS E-Resources & Serials', 'RMC Acquisitions','Law Technical Services')) 
                AND  finall.order_type = 'One-Time' THEN 'Firm orders'
          WHEN (finall.inv_bill_to_name in ('LTS E-Resources & Serials','Law Technical Services','RMC Acquisitions','LTS Standing Orders','LTS Documents')
                OR finall.po_bill_to_name in  ('LTS E-Resources & Serials','Law Technical Services', 'RMC Acquisitions','LTS Standing Orders','LTS Documents') 
                OR finall.po_ship_to_name in ('LTS E-Resources & Serials','Law Technical Services','RMC Acquisitions','LTS Standing Orders','LTS Documents')) 
                AND finall.order_type = 'Ongoing' THEN  'Serials'
          ELSE 'Undetermined' end,
     finall.order_format,
    CASE  WHEN coalesce (finall.folio_format_type, finall.holdings_type_name, finall.instance_mode_of_issuance) is null then 'Unspecified'
          WHEN coalesce (finall.folio_format_type, finall.holdings_type_name, finall.instance_mode_of_issuance) ilike '%serial%' then 'Serial'
          WHEN coalesce (finall.folio_format_type, finall.holdings_type_name, finall.instance_mode_of_issuance) ilike '%book%' then 'Book'
          ELSE  'Other material format' end,
    finall.pol_instance_hrid, finall.instance_title, finall.series, finall.invoice_lines_description, finall.lc_class_number,
    finall.order_type, finall.folio_format_type, finall.workflow_status, finall.vendor_name, finall.publisher,
    finall.invoice_line_number::NUMERIC, finall.invoice_date::DATE, finall.invoice_payment_date, finall.po_line_number,
    finall.poll_location_name, finall.inv_bill_to_name, finall.po_bill_to_name, finall.po_ship_to_name, finall.fund_name,
    finall.fund_code, finall.finance_group_name, finall.transaction_type, finall.payment_date::DATE, finall.fund_distribution_type,
    finall.fund_distribution_value, finall.cost
ORDER BY  fiscal_year_Code, instance_title
;
