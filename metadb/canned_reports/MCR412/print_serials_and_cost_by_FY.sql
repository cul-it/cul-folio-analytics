--MCR412
--Print serials and cost by FY based on an input list of PO numbers 
-- This query gets the payments for print serials (based on an input list of PO numbers) and shows finance group, fund, LC class, location
--Query writer: Joanne Leary (jl41)
  --Posted on: 10/8/25

WITH finance_transaction_invoices_ext AS ( -- gets details of the finance transactions and converts Credits to negative values
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
    
    ORDER BY ff.code
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

-- next two queries get the LC class from the 050 field and the holdings call number

lc_marc AS 
	(SELECT DISTINCT
		sm.instance_hrid,
		SUBSTRING (STRING_AGG (SUBSTRING (sm.content,'[A-Z]{1,3}'),' | ' ORDER BY sm.ord),'[A-Z]{1,3}') AS lc_class
	
	FROM folio_source_record.marc__t AS sm 
		
	WHERE sm.field = '050'
		AND  sm.sf = 'a'
		AND  sm.ord = 1
	GROUP BY sm.instance_hrid
),

lc_final AS 
(
	SELECT
		instance__t.hrid AS instance_hrid,
		CASE WHEN STRING_AGG (DISTINCT call_number_type__t.name,' | ') like '%Library of Congress%' THEN 'LC' ELSE 'Other' END AS call_number_type,
		lc_marc.lc_class AS lc_class_050,
		
		CASE WHEN 
			call_number_type__t.name !='Library of Congress classification' 
			THEN NULL 
			ELSE SUBSTRING (STRING_AGG (DISTINCT SUBSTRING (holdings_record__t.call_number,'[A-Z]{1,3}'),' | '),'[A-Z]{1,3}') 
			END AS lc_class_holdings,
			
		CASE WHEN 
			lc_marc.lc_class IS NULL AND SUBSTRING (STRING_AGG (DISTINCT SUBSTRING (holdings_record__t.call_number,'[A-Z]{1,3}'),' | '),'[A-Z]{1,3}') IS NULL 
			THEN NULL
			ELSE 
				COALESCE (lc_marc.lc_class, 
					CASE WHEN call_number_type__t.name !='Library of Congress classification' 
						THEN NULL 
						ELSE SUBSTRING (STRING_AGG (DISTINCT SUBSTRING (holdings_record__t.call_number,'[A-Z]{1,3}'),' | '),'[A-Z]{1,3}') 
						END) 
			END AS lc_class_final
			
	FROM folio_inventory.instance__t
		LEFT JOIN folio_inventory.holdings_record__t 
		ON instance__t.id = holdings_record__t.instance_id
		
		LEFT JOIN folio_inventory.call_number_type__t 
		ON holdings_record__t.call_number_type_id = call_number_type__t.id
		
		LEFT JOIN folio_inventory.location__t 
		ON holdings_record__t.permanent_location_id = location__t.id
		
		LEFT JOIN lc_marc 
		ON instance__t.hrid = lc_marc.instance_hrid
	
	WHERE (instance__t.discovery_suppress = false OR instance__t.discovery_suppress IS NULL)
		AND (holdings_record__t.discovery_suppress = false OR holdings_record__t.discovery_suppress IS NULL)
		AND holdings_record__t.call_number NOT SIMILAR TO '%(n%rder|n%rocess|ON ORDER|IN PROCESS|vailable|elector|No call number)%' --- exclude records with non-standard OR temporary call numbers
		
	GROUP BY instance__t.hrid, lc_marc.lc_class, call_number_type__t.name--, formats.folio_format_type
),

main as 
(SELECT
  DISTINCT 
    current_date::date AS current_date,                 
    trim (coalesce (replace(replace (iext.index_title, chr(13), ''),chr(10),''), replace(replace (pol.title_or_package, chr(13), ''),chr(10),''),' - ')) AS index_title,
    iext.instance_hrid,
    lc_final.lc_class_final,
    string_agg (distinct instance_languages.instance_language,' | ') as language,
    string_agg (distinct po_lines_locations.pol_location_name,' | ') as location_name,
    po.order_type,
    pol.order_format,
    ftie.invoice_date::date,
    inv.payment_date::DATE as invoice_payment_date,
    ftie.effective_transaction_amount/fq.fixed_quantity AS transaction_amount_per_qty,
    ftie.effective_transaction_amount,
    ftie.transaction_type,
    ftie.invoice_vendor_name,
    inv.vendor_invoice_no,
    invl.invoice_line_number,
    inv.status as invoice_status,
    replace(replace (invl.description, chr(13), ''),chr(10),'') AS invoice_line_description,
    replace(replace (invl.comment, chr(13), ''),chr(10),'') AS invoice_line_comment,
    ftie.finance_ledger_name,
    ftie.fiscal_year_code AS transaction_fiscal_year_code,
    CASE -- selects the correct finance group for funds merged into Area Studies from 2CUL in FY2024, and Course Reserves merged into Interdisciplinary in FY2025
        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date >='2023-07-01' THEN 'Area Studies'
        WHEN ftie.effective_fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and inv.payment_date::date <'2023-07-01' then '2CUL'
        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ftie.effective_fund_code in ('7311','7342','7370','p7358') AND inv.payment_date::date <'2024-07-01' THEN 'Course Reserves'
        ELSE ffyg.finance_group_name END AS finance_group_name,
    fec.name AS expense_class,
    ftie.effective_fund_code,
    ftie.fund_name,
    ftie.fund_type_name,
    po.po_number,
    pol.po_line_number,    
    trim (replace(replace (pol.title_or_package, chr(13), ''),chr(10),'')) AS po_line_title_or_package,
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
    left join lc_final on iext.instance_hrid = lc_final.instance_hrid
    LEFT JOIN folio_derived.instance_languages AS lang ON lang.instance_id = pol.instance_id
    LEFT JOIN fund_fiscal_year_group AS ffyg ON ffyg.fund_id = ftie.effective_fund_id
    LEFT JOIN folio_derived.po_lines_locations on ftie.po_line_id::UUID = po_lines_locations.pol_id::UUID --locations on ftie.po_line_id ::uuid = locations.pol_id::uuid
    LEFT JOIN folio_finance.expense_class__t AS fec ON fec.id = ftie.expense_class
    left join folio_derived.instance_languages on iext.instance_id = instance_languages.instance_id
 
WHERE
        inv.status in ('Paid','Approved')

GROUP BY
       ftie.transaction_id,
       trim(coalesce (replace(replace (iext.index_title, chr(13), ''),chr(10),''), replace(replace (pol.title_or_package, chr(13), ''),chr(10),''),' - ')),
       iext.instance_hrid,
       lc_final.lc_class_final,
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
       trim (replace(replace (pol.title_or_package, chr(13), ''),chr(10),'')),
       fq.fixed_quantity,     
       ftie.external_account_no  
)

select distinct
	current_date::date AS current_date,
	jpi.po_number as input_po_number,
	po_line__t.po_line_number,	
	main.po_line_title_or_package,                 
    main.index_title,
    main.instance_hrid,
    main.lc_class_final,
    main.language,
    main.location_name,
    main.order_type,
    main.order_format,
    main.invoice_date::date,
    main.invoice_payment_date,
    main.transaction_amount_per_qty,
    main.effective_transaction_amount,
    main.transaction_type,
    main.invoice_vendor_name,
    main.vendor_invoice_no,
    main.invoice_line_number,
    main.invoice_status,
    main.invoice_line_description,
    main.invoice_line_comment,
    main.finance_ledger_name,
    main.transaction_fiscal_year_code,
    main.finance_group_name,
    main.expense_class,
    main.effective_fund_code,
    main.fund_name,
    main.fund_type_name,    
    main.quantity,     
    main.external_account_no
	

from local_open.jl_poids_9_29_25 jpi

	left join main
	on jpi.po_number = main.po_number
	
	left join folio_orders.po_line__t 
	on jpi.po_number = split_part (po_line__t.po_line_number,'-',1)

order by 
	main.po_line_title_or_package,
	main.index_title, 
	main.transaction_fiscal_year_code, 
	main.finance_group_name, 
	main.vendor_invoice_no, 
	main.invoice_line_number,
	main.instance_hrid,
    main.lc_class_final,
    main.language,
    main.location_name,
    main.order_type,
    main.order_format,
    main.invoice_date::date,
    main.invoice_payment_date,
    main.transaction_amount_per_qty,
    main.effective_transaction_amount,
    main.transaction_type,
    main.invoice_vendor_name,
    main.invoice_status,
    main.invoice_line_description,
    main.invoice_line_comment,
    main.finance_ledger_name,
    main.expense_class,
    main.effective_fund_code,
    main.fund_name,
    main.fund_type_name,
    main.quantity,     
    main.external_account_no
        ;
