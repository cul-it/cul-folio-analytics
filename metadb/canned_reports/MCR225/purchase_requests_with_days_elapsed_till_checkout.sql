--MCR225
--purchase requests with days elapsed till checkout
-- This query finds the number of days between when a firm-ordered (one-time) fully-received item was ordered (item record created), -- then received at LTS, then received at the unit library and then first checked out (Folio only). If item was not discharged at the unit library upon receipt, or item did not have an "In process" status prior to discharge, time elapsed will show null. Includes bibliographic info, order info and fund information and can be limited to just requested purchases (un-comment out lines 108-109).
--Updated on 09/03/26

WITH parameters AS 
(SELECT 
'2021-07-01'::DATE AS po_create_date_start
),

-- 1. Get bill_to information for purchase orders and invoices

billto AS -- extracts "name" from the configurarion_entries value field (used for invoice_invoices bill_to field)
       (SELECT
           cfge.id AS bill_to_id,
           SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS bill_to_name -- invoices bill-to
       FROM
           folio_configuration.config_data__t AS cfge 
       WHERE cfge.value LIKE '{"name"%'
),

billto2 AS -- extracts "name" from the configuration_entries value field (used for po_purchase_orders bill_to field)
       (SELECT
           cfge.id AS bill_to_id,
           SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS bill_to_name -- purchase orders bill-to
       FROM
           folio_configuration.config_data__t AS cfge 
       WHERE cfge.value LIKE '{"name"%'
),

-- 2. Get order information:

orders AS 
(
SELECT DISTINCT
   CASE 
	   WHEN DATE_PART ('month',ii.payment_date::DATE)< 7 
	   THEN CONCAT ('FY', DATE_PART ('year',ii.payment_date::DATE)) 
       ELSE CONCAT ('FY', DATE_PART ('year', ii.payment_date::DATE) + 1) 
       END AS fiscal_year,
   pi2.pol_instance_hrid AS inst_hrid,
   he.holdings_hrid,
   ie.item_hrid,
   ie.item_id::UUID,
   ie.created_date::DATE AS item_created_date,
   ie.barcode,
   pi2.title,
   pi2.requester,
   po_line.jsonb#>>'{details,receivingNote}' AS receiving_note,
   pi2.order_type,
   pi2.po_number AS po_no,
   pi2.po_line_number,
   pi2.vendor_code AS vendor,    
   ie.material_type_name,
   pi2.receipt_status,
   he.call_number AS call_no,
   pi2.pol_location_name,
   ll.library_name,  
   pi2.created_date::DATE AS po_created_date,
   pol.receipt_date::DATE AS pol_receipt_date, 
   ii.vendor_invoice_no,
   il.invoice_line_number,
   ii.invoice_date AS invoice_created_date,
   ii.status AS invoice_status,
   ii.payment_date::date AS invoice_payment_date,
   billto.bill_to_name AS inv_bill_to_name,
   billto2.bill_to_name AS po_bill_to_name,
   pi2.ship_to,
   ilfd.fund_code,
   ilfd.fund_name,
   CASE -- selects the correct finance group for funds based on invoice payment date
        WHEN ilfd.fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and ii.payment_date::date >='2023-07-01' THEN 'Area Studies'
        WHEN ilfd.fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and ii.payment_date::date <'2023-07-01' then '2CUL'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date <'2024-07-01' THEN 'Course Reserves'
        WHEN ilfd.fund_code = 'p2264' AND ii.payment_date::date >='2026-06-02' THEN 'Special Collections'
        WHEN ilfd.fund_code = 'p2264' AND ii.payment_date::date <'2026-06-02' THEN 'Humanities'
        WHEN ilfd.fund_code = 'p650' AND ii.payment_date::date >='2025-05-16' THEN 'Social Sciences'
        WHEN ilfd.fund_code = 'p650' AND ii.payment_date::date <'2025-05-16' THEN 'Interdisciplinary'
        WHEN ilfd.fund_code = 'p7353' AND ii.payment_date::date >='2026-07-07' THEN 'Social Sciences'
        WHEN ilfd.fund_code = 'p7353' AND ii.payment_date::date <'2026-07-07' THEN 'Humanities'
        WHEN ilfd.fund_code = 'p7368' AND ii.payment_date::date >='2025-07-09' THEN 'Social Sciences'
        WHEN ilfd.fund_code = 'p7368' AND ii.payment_date::date <'2025-07-09' THEN 'Humanities'
        ELSE fg.name
    	END AS fund_group_name,
   ilfd.fund_distribution_type,
   ilfd.fund_distribution_value,
   CASE 
       WHEN ilfd.fund_distribution_type = 'percentage' 
       THEN ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::numeric(12,2) 
       ELSE ilfd.fund_distribution_value 
       END AS cost

FROM folio_derived.po_instance AS pi2   
       LEFT JOIN folio_orders.po_line__t AS pol 
       ON pi2.po_line_number = pol.po_line_number
       
       LEFT JOIN folio_derived.po_lines_locations 
       ON pi2.po_line_id = po_lines_locations.pol_id
       
       LEFT JOIN folio_orders.po_line 
       ON pol.id = po_line.id
       
       LEFT JOIN folio_orders.purchase_order__t AS ppo 
       ON ppo.id = pol.purchase_order_id
       
       LEFT JOIN folio_derived.holdings_ext AS he 
       ON he.id::UUID = pi2.pol_holding_id::UUID
       	AND po_lines_locations.pol_location_id = he.permanent_location_id
       
       LEFT JOIN folio_derived.locations_libraries AS ll 
       on pi2.pol_location_name = ll.location_name
       
       LEFT JOIN folio_derived.item_ext AS ie 
       ON he.id = ie.holdings_record_id 
       
       LEFT JOIN folio_invoice.invoice_lines__t AS il 
       ON pol.id = il.po_line_id
       
       LEFT JOIN folio_derived.invoice_lines_fund_distributions AS ilfd
       ON il.id = ilfd.invoice_line_id::UUID
       
       LEFT JOIN folio_invoice.invoices__t AS ii 
       ON il.invoice_id = ii.id
       
       LEFT JOIN folio_finance.fund__t AS ff
       ON ilfd.fund_code = ff.code
       
       LEFT JOIN folio_finance.group_fund_fiscal_year__t AS fgffy 
       ON ff.id = fgffy.fund_id
       
       LEFT JOIN folio_finance.groups__t AS fg
       ON fgffy.group_id = fg.id
       
       LEFT JOIN billto 
       ON ii.bill_to = billto.bill_to_id
       
       LEFT JOIN billto2 
       ON ppo.bill_to = billto2.bill_to_id

WHERE 
       pi2.order_type = 'One-Time' 
       -- and pi2.ship_to != 'LTS Approvals'
       -- and pi2.created_location != 'LTS Approvals'
       -- and billto.bill_to_name !='LTS Approvals' -- invoice bill to
       -- and billto2.bill_to_name !='LTS Approvals' -- po bill to 
       AND pol.receipt_status = 'Fully Received'
       --AND pi2.pol_location_name != 'serv,remo'
       AND pi2.created_date::DATE >= (SELECT po_create_date_start FROM parameters) 
       AND ie.created_date::DATE >= (SELECT po_create_date_start FROM parameters)
       AND ii.vendor_invoice_no NOT LIKE '%problem%'
       AND he.call_number IS NOT null
       AND ii.payment_date IS NOT null
       AND (((pi2.requester IS NOT NULL AND pi2.requester NOT SIMILAR TO '%(no request|n/a|na|no req|No requestor|No requester|jacob)%')
       		OR (po_line.jsonb#>>'{details,receivingNote}' ILIKE '%req%' AND po_line.jsonb#>>'{details,receivingNote}' NOT ILIKE '%no request%'))
       		OR pi2.vendor_code IN ('AmazonBus','AMAZON-ILL'))
GROUP BY  
   CASE 
	   WHEN DATE_PART ('month',ii.payment_date::DATE)< 7 
	   THEN CONCAT ('FY', DATE_PART ('year',ii.payment_date::DATE)) 
       ELSE CONCAT ('FY', DATE_PART ('year', ii.payment_date::DATE) + 1) 
       END,
   pi2.pol_instance_hrid,
   he.holdings_hrid,
   ie.item_hrid,
   ie.item_id,
   ie.created_date::DATE,
   ie.barcode,
   pi2.title,
   pi2.requester,
   po_line.jsonb#>>'{details,receivingNote}',
   pi2.order_type, 
   pi2.po_number,
   pi2.po_line_number,
   pi2.vendor_code, 
   ie.material_type_name,
   pi2.receipt_status,
   he.call_number,
   pi2.pol_location_name,
   ll.library_name,
   pi2.created_date::DATE,
   pol.receipt_date::DATE,
   ii.vendor_invoice_no,
   il.invoice_line_number,
   ii.invoice_date,
   ii.status,
   ii.payment_date::date,
   billto.bill_to_name,
   billto2.bill_to_name,
   pi2.ship_to,
   ilfd.fund_code,
   ilfd.fund_name,
   CASE -- selects the correct finance group for funds based on invoice payment date
        WHEN ilfd.fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and ii.payment_date::date >='2023-07-01' THEN 'Area Studies'
        WHEN ilfd.fund_code in ('2616','2310','2342','2352','2410','2411','2440','p2350','p2450','p2452','p2658') and ii.payment_date::date <'2023-07-01' then '2CUL'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date <'2024-07-01' THEN 'Course Reserves'
        WHEN ilfd.fund_code = 'p2264' AND ii.payment_date::date >='2026-06-02' THEN 'Special Collections'
        WHEN ilfd.fund_code = 'p2264' AND ii.payment_date::date <'2026-06-02' THEN 'Humanities'
        WHEN ilfd.fund_code = 'p650' AND ii.payment_date::date >='2025-05-16' THEN 'Social Sciences'
        WHEN ilfd.fund_code = 'p650' AND ii.payment_date::date <'2025-05-16' THEN 'Interdisciplinary'
        WHEN ilfd.fund_code = 'p7353' AND ii.payment_date::date >='2026-07-07' THEN 'Social Sciences'
        WHEN ilfd.fund_code = 'p7353' AND ii.payment_date::date <'2026-07-07' THEN 'Humanities'
        WHEN ilfd.fund_code = 'p7368' AND ii.payment_date::date >='2025-07-09' THEN 'Social Sciences'
        WHEN ilfd.fund_code = 'p7368' AND ii.payment_date::date <'2025-07-09' THEN 'Humanities'
        ELSE fg.name
        END,
   ilfd.fund_distribution_type,
   ilfd.fund_distribution_value,
   CASE 
       WHEN ilfd.fund_distribution_type = 'percentage' 
       THEN ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::numeric(12,2) else ilfd.fund_distribution_value 
       END
),

-- 3. Get pub date (all instance records)

pubdate AS 
 (SELECT
      sm.instance_hrid,
      SUBSTRING (sm.content,8,4) AS pub_date

	FROM folio_source_record.marc__t AS sm 
	WHERE sm.field = '008'
),

-- 4. Get when the item was received at the unit library (= when item was discharged after having an 'In Process' status):

received AS 
 (SELECT 
       orders.fiscal_year,
       orders.inst_hrid,
       orders.holdings_hrid,
       orders.item_hrid,
       orders.barcode,
       orders.title,
       pubdate.pub_date,
       orders.requester,
       orders.receiving_note,
       orders.order_type,
       orders.ship_to,
       orders.po_no,
       orders.po_line_number,
       orders.vendor, 
       orders.material_type_name,
       orders.receipt_status,
       orders.call_no,
       orders.pol_location_name,
       orders.library_name,
       orders.item_id,
       orders.po_created_date::date,
       orders.pol_receipt_date::date,
       orders.item_created_date::date,
       orders.vendor_invoice_no,
       orders.invoice_line_number,
       orders.invoice_created_date::date,
       orders.invoice_status,
       orders.invoice_payment_date,
       orders.inv_bill_to_name,
       orders.po_bill_to_name,
       orders.fund_code,
       orders.fund_group_name,
       orders.fund_name,
       orders.fund_distribution_type,
   	   orders.fund_distribution_value,
       orders.cost,
       cci.item_id AS cci_item_id,
       cci.item_status_prior_to_check_in,
       cci.occurred_date_time::DATE AS item_discharged_at_unit_date,
       COUNT (DISTINCT loan__t.id) AS total_circs

FROM orders 
       LEFT JOIN folio_circulation.check_in__t  AS cci
       ON orders.item_id = cci.item_id 
               
       LEFT JOIN pubdate 
       ON orders.inst_hrid = pubdate.instance_hrid
       
       LEFT JOIN folio_circulation.loan__t 
       ON orders.item_id::UUID = loan__t.item_id

WHERE cci.item_status_prior_to_check_in = 'In process' OR cci.item_id IS null

group by orders.fiscal_year,
       orders.inst_hrid,
       orders.holdings_hrid,
       orders.item_hrid,
       orders.barcode,
       orders.title,
       pubdate.pub_date,
       orders.requester,
       orders.receiving_note,
       orders.order_type,
       orders.ship_to,
       orders.po_no,
       orders.po_line_number,
       orders.vendor, 
       orders.material_type_name,
       orders.receipt_status,
       orders.call_no,
       orders.pol_location_name,
       orders.library_name,
       orders.item_id,
       orders.po_created_date::date,
       orders.pol_receipt_date::date,
       orders.item_created_date::date,
       orders.vendor_invoice_no,
       orders.invoice_line_number,
       orders.invoice_created_date::date,
       orders.invoice_status,
       orders.invoice_payment_date,
       orders.inv_bill_to_name,
       orders.po_bill_to_name,
       orders.fund_code,
       orders.fund_group_name,
       orders.fund_name,
       orders.fund_distribution_type,
       orders.fund_distribution_value,
       orders.cost,
       cci.item_id,
       cci.item_status_prior_to_check_in,
       cci.occurred_date_time::DATE
)

-- 5. Get when the item was first circulated, and join all the data together:

SELECT 
      TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
       received.fiscal_year,
       received.inst_hrid,
       received.holdings_hrid,
       received.item_hrid,
       received.barcode,
       received.title,
       STRING_AGG (DISTINCT ip.publisher, ' | ') AS publisher,
       received.pub_date,
       lang.instance_language,
       received.material_type_name,
       received.call_no,
       SUBSTRING (received.call_no, '^([a-zA-Z]{1,3})') AS lc_class,
       TRIM (TRAILING '.' FROM SUBSTRING (received.call_no, '\d{1,}\.{0,}\d{0,}'))::NUMERIC AS lc_class_number,
       received.pol_location_name,
       received.library_name,
       received.requester,
       received.receiving_note,
       received.order_type,    
       received.po_no,
       received.po_line_number,
       received.receipt_status,
       received.vendor,
       received.vendor_invoice_no,
       received.invoice_line_number,
       received.invoice_created_date::date,
       received.invoice_status,
       received.invoice_payment_date,
       received.inv_bill_to_name,
       received.po_bill_to_name,
       received.ship_to,
       received.fund_code,
       received.fund_group_name,
       received.fund_name,
       received.fund_distribution_type,
       received.fund_distribution_value,
       received.cost,      
-- key dates:
       TO_CHAR (received.po_created_date::DATE,'mm/dd/yyyy') AS order_date,
       TO_CHAR (received.item_created_date::DATE,'mm/dd/yyyy') AS item_created_date,
       TO_CHAR (received.pol_receipt_date::DATE,'mm/dd/yyyy') AS recd_at_lts_date,
       TO_CHAR (received.item_discharged_at_unit_date::DATE,'mm/dd/yyyy') AS recd_at_unit_date,
       TO_CHAR (MIN (li.loan_date::DATE),'mm/dd/yyyy') AS first_checkout_date,        
-- number of days calculations:  
       received.pol_receipt_date - received.po_created_date AS days_til_recd_at_lts_from_order_date,  
       received.item_discharged_at_unit_date - received.pol_receipt_date AS days_til_recd_at_unit,
       MIN (li.loan_date::DATE) - received.item_discharged_at_unit_date::DATE AS days_til_first_checkout,
       received.total_circs

FROM received 
       LEFT JOIN folio_derived.loans_items AS li 
       ON received.item_id = li.item_id
      
       LEFT JOIN folio_derived.instance_publication AS ip 
       ON received.inst_hrid = ip.instance_hrid
      
       LEFT JOIN folio_derived.instance_languages AS lang 
       ON coalesce (received.inst_hrid,'') = lang.instance_hrid            

WHERE lang.language_ordinality = 1 OR lang.instance_hrid IS NULL

GROUP by
TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
       received.fiscal_year,
       received.inst_hrid,
       received.holdings_hrid,
       received.item_hrid,
       received.barcode,
       received.title,
       received.pub_date,
       lang.instance_language,
       received.material_type_name,
       received.call_no,
       SUBSTRING (received.call_no, '^([a-zA-Z]{1,3})'),
       TRIM (TRAILING '.' FROM SUBSTRING (received.call_no, '\d{1,}\.{0,}\d{0,}'))::NUMERIC,
       received.pol_location_name,
       received.library_name,
       received.requester,
       received.receiving_note,
       received.order_type,      
       received.po_no,
       received.po_line_number,
       received.receipt_status,
       received.vendor,
       received.vendor_invoice_no,
       received.invoice_line_number,
       received.invoice_created_date,
       received.invoice_status,
       received.invoice_payment_date,
       received.inv_bill_to_name,
       received.po_bill_to_name,
       received.ship_to,
       received.fund_code,
       received.fund_group_name,
       received.fund_name,
       received.fund_distribution_type,
       received.fund_distribution_value,
       received.cost,
       received.item_discharged_at_unit_date::DATE,
-- key dates:
       TO_CHAR (received.po_created_date::DATE,'mm/dd/yyyy'),
       TO_CHAR (received.item_created_date::DATE,'mm/dd/yyyy'),
       TO_CHAR (received.pol_receipt_date::DATE,'mm/dd/yyyy'),
       TO_CHAR (received.item_discharged_at_unit_date::DATE,'mm/dd/yyyy'),       
-- number of days calculations:  
       received.pol_receipt_date - received.po_created_date,      
       received.pol_receipt_date - received.item_created_date,
       received.item_discharged_at_unit_date::DATE - received.pol_receipt_date,
       received.total_circs
              
ORDER BY 
	fiscal_year, 
	UPPER (UNACCENT (REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (title, '.',''),',',''),';',''),': ',''),'''',''))) COLLATE "C",
	holdings_hrid, 
	item_hrid, 
	vendor_invoice_no, 
	invoice_line_number, 
	invoice_payment_date
;
