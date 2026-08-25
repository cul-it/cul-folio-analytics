-- 8-21-26: Get firm ordered e-books (combination Natalya and JL coding)
-- 8-24-26: updated to include LC class and LC class number

WITH recs AS 
    (WITH get_ebk_fo_orders AS
        (SELECT  *
         FROM folio_derived.po_instance
         WHERE ((bill_to IS NULL AND created_by_username = 'fs00001034')
                OR bill_to IN ('LTS E-Resources & Serials'))
         AND created_date>'2021-06-30'
        ),
    classifications AS 
    (SELECT 
           instance.id AS instance_id,
           instance.jsonb#>>'{hrid}' AS instance_hrid,
           class.jsonb#>>'{classificationNumber}' AS LC_call_number,
           SUBSTRING (class.jsonb#>>'{classificationNumber}','(?i)[A-Z]{1,3}') AS lc_class_from_instance,
           TRIM ('.' from REPLACE (SUBSTRING (class.jsonb#>>'{classificationNumber}','\d{1,}\.{0,}\d{0,}'),'..','.'))::numeric AS lc_class_number_from_instance
     FROM folio_inventory.instance 
     CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (instance.jsonb,'classifications')) WITH ordinality AS class (jsonb)
     WHERE class.ordinality = 1
    )
SELECT DISTINCT 
ge.pol_instance_hrid,
ii.id AS instance_id,
fiscal_year__t.code AS invoice_fiscal_year,
DATE_PART ('year',ge.created_date::date) AS calendar_year_added_to_collection,
COALESCE (ii.jsonb#>>'{title}',ge.title) AS title,
ic.contributor_name AS author,
COALESCE (ip.publisher,ge.publisher) AS publisher,
ge.vendor_code,
fti.invoice_vendor_name,
COALESCE (ip.date_of_publication,ge.publication_date) AS publication_date,
he.permanent_location_name,
MAX (TRIM (he.call_number)) AS call_number,
COALESCE (MAX (CASE WHEN he.call_number ILIKE '%In process%' THEN NULL ELSE SUBSTRING (he.call_number,'(?i)[A-Z]{1,3}') end), classifications.lc_class_from_instance) AS lc_class,
COALESCE (MAX (TRIM ('.' FROM REPLACE (SUBSTRING (he.call_number,'\d{1,}\.{0,}\d{0,}'),'..','.'))::numeric), classifications.lc_class_number_from_instance) AS lc_class_number,
ge.po_line_number,
invoices__t.vendor_invoice_no,
invoice_lines__t.invoice_line_number,
invoice_lines__t.comment AS invoice_line_comment,
fti.effective_transaction_amount,
fti.effective_fund_code,
ge.created_date::date AS purchase_order_create_date,
invoices__t.payment_date::date AS invoice_payment_date,
mode_of_issuance__t.name AS mode_of_issuance_name
FROM get_ebk_fo_orders AS ge
LEFT JOIN folio_inventory.instance AS ii ON ii.id = ge.pol_instance_id
LEFT JOIN classifications ON ii.id = classifications.instance_id
LEFT JOIN folio_orders.po_line ON po_line.purchaseorderid = ge.po_number_id 
LEFT JOIN folio_derived.holdings_ext AS he ON pol_instance_id =he.instance_id
LEFT JOIN folio_derived.instance_publication AS ip ON ii.id = ip.instance_id
LEFT JOIN folio_inventory.mode_of_issuance__t ON (ii.jsonb#>>'{modeOfIssuanceId}')::UUID = mode_of_issuance__t.id
LEFT JOIN folio_derived.instance_contributors AS ic ON ii.id = ic.instance_id
LEFT JOIN folio_orders.po_line__t ON ge.po_line_number = po_line__t.po_line_number
LEFT JOIN folio_derived.finance_transaction_invoices AS fti ON ge.po_line_id::UUID = fti.po_line_id::UUID
LEFT JOIN folio_invoice.invoice_lines__t ON fti.invoice_line_id = invoice_lines__t.id
LEFT JOIN folio_invoice.invoices__t ON invoice_lines__t.invoice_id = invoices__t.id
LEFT JOIN folio_finance.fiscal_year__t ON fti.transaction_fiscal_year_id = fiscal_year__t.id
WHERE ii.creation_date::DATE > '2021-07-04' --from instance
AND ge.created_date::DATE > '2021-07-04' ---from po_instance
AND po_line.creation_date::DATE > '2021-07-04' --from po_line
AND ge.created_date >'2021-07-01' 
AND he.permanent_location_name = 'serv,remo'
AND ge.receipt_status NOT IN  ('Ongoing', 'Cancelled')
AND ((ii.jsonb#>>'{discoverySuppress}')::boolean = false OR (ii.jsonb#>>'{discoverySuppress}')::boolean IS NULL)
AND (he.discovery_suppress = FALSE OR he.discovery_suppress IS NULL)
AND mode_of_issuance__t.name NOT IN ('integrating resource', 'serial')
AND (ic.contributor_ordinality = 1 OR ic.instance_id IS NULL)
AND (ip.publication_ordinality = 1 OR ip.instance_id IS NULL)               
GROUP BY ge.pol_instance_hrid, ii.id, fiscal_year__t.code, DATE_PART ('year',ge.created_date::date),
      COALESCE (ii.jsonb#>>'{title}',ge.title), ic.contributor_name,COALESCE (ip.publisher,ge.publisher),
      ge.vendor_code, fti.invoice_vendor_name, COALESCE (ip.date_of_publication,ge.publication_date),
      he.permanent_location_name, ge.po_line_number, invoices__t.vendor_invoice_no, invoice_lines__t.invoice_line_number,
      invoice_lines__t.comment, fti.effective_transaction_amount, fti.effective_fund_code,ge.created_date::date, 
      invoices__t.payment_date::date, mode_of_issuance__t.name, classifications.lc_class_from_instance,
      classifications.lc_class_number_from_instance
  )
SELECT recs.*
FROM recs 
ORDER BY invoice_fiscal_year, 
UPPER (UNACCENT (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (title, '.',''),',',''),';',''),': ',''),'''',''))) COLLATE "C", 
po_line_number,vendor_invoice_no,invoice_line_number
;
