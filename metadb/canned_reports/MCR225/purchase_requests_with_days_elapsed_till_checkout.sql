--MCR225
--purchase requests with days elapsed till checkout
-- This query finds the number of days between when a firm-ordered (one-time) fully-received item was ordered (item record created), -- then received at LTS, then received at the unit library and then first checked out (Folio only). If item was not discharged at the unit library upon receipt, or item did not have an "In process" status prior to discharge, time elapsed will show null. Includes bibliographic info, order info and fund information and can be limited to just requested purchases (un-comment out lines 108-109).


WITH parameters AS 
(SELECT 
'2024-07-01'::DATE AS po_create_date_start
),

-- 1. Get bill_to information for purchase orders and invoices

billto AS -- extracts "name" from the configurarion_entries value field (used for invoice_invoices bill_to field)
       (SELECT
           cfge.id AS bill_to_id,
           SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS bill_to_name
       FROM
           folio_configuration.config_data__t as cfge --configuration_entries AS cfge
       WHERE cfge.value LIKE '{"name"%'
),

billto2 AS -- extracts "name" from the configuration_entries value field (used for po_purchase_orders bill_to field)
       (SELECT
           cfge.id AS bill_to_id,
           SUBSTRING (cfge.value, '([A-Z].+)(",".+)') AS bill_to_name
       FROM
           folio_configuration.config_data__t as cfge --configuration_entries AS cfge
       WHERE cfge.value LIKE '{"name"%'
),

-- 2. Get order information:

orders AS 
(
SELECT distinct
   CASE WHEN DATE_PART ('month',ii.payment_date::DATE)< 7 THEN CONCAT ('FY', DATE_PART ('year',ii.payment_date::DATE)) 
              ELSE CONCAT ('FY', DATE_PART ('year', ii.payment_date::DATE) + 1) END AS fiscal_year,
   pi2.pol_instance_hrid AS inst_hrid,
   he.holdings_hrid,
   ie.item_hrid,
   ie.item_id::UUID,
   ie.created_date::DATE AS item_created_date,
   ie.barcode,
   pi2.title,
   pi2.requester,
   pi2.order_type,--ppo.order_type,
   pi2.po_number AS po_no,
   pi2.po_line_number,-- AS pol_no,
   pi2.vendor_code AS vendor,    
   ie.material_type_name,
   pi2.receipt_status, --pol.receipt_status,
   he.call_number AS call_no,
   pi2.location_name, --pi2.pol_location_name AS pol_location,  
   pi2.po_created_date::DATE AS po_created_date,
   pol.receipt_date::DATE AS pol_receipt_date, 
   ii.vendor_invoice_no,
   ii.invoice_date as invoice_created_date, --(jsonb_extract_path_text (ii.jsonb, 'metadata', 'createdDate'))::DATE AS invoice_created_date,
   billto.bill_to_name AS inv_bill_to_name,
   billto2.bill_to_name AS po_bill_to_name,
   pi2.ship_to,
   ilfd.fund_code,
   ilfd.fund_name,
   CASE -- selects the correct finance group for funds that were merged into Area Studies from 2CUL in FY2024, based on invoice payment date
        WHEN ilfd.fund_code in ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') and ii.payment_date::DATE >='2023-07-01' THEN 'Area Studies'
        WHEN ilfd.fund_code in ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') and ii.payment_date::DATE <'2023-07-01' THEN '2CUL'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date <'2024-07-01' THEN 'Course Reserves'
          
        ELSE fg.name 
        END AS fund_group_name,
   
   CASE 
       WHEN ilfd.fund_distribution_type = 'percentage' 
       THEN ((ilfd.invoice_line_total*ilfd.fund_distribution_value)/100)::numeric(12,2) else ilfd.fund_distribution_value 
       END AS cost

FROM local_static.vs_po_instance as pi2 --folio_reporting.po_instance pi2  
       LEFT JOIN folio_orders.po_line__t as pol --po_lines pol 
       ON pi2.po_line_number = pol.po_line_number 
       
       LEFT JOIN folio_orders.purchase_order__t as ppo --po_purchase_orders ppo 
       ON ppo.id = pol.purchase_order_id
       
       LEFT JOIN folio_derived.holdings_ext as he --folio_reporting.holdings_ext he 
       ON he.holdings_id::UUID = pi2.pol_holding_id::UUID
       
       LEFT JOIN folio_derived.item_ext as ie --folio_reporting.item_ext ie 
       ON he.holdings_id = ie.holdings_record_id 
       
       LEFT JOIN folio_invoice.invoice_lines__t as il --invoice_lines il 
       ON pol.id = il.po_line_id
       
       LEFT JOIN folio_derived.invoice_lines_fund_distributions as ilfd --folio_reporting.invoice_lines_fund_distributions ilfd 
       ON il.id = ilfd.invoice_line_id::UUID
       
       LEFT JOIN folio_invoice.invoices__t as ii --invoice_invoices ii 
       ON il.invoice_id = ii.id
       
       LEFT JOIN folio_finance.fund__t as ff --finance_funds AS ff 
       ON ilfd.fund_code = ff.code
       
       LEFT JOIN folio_finance.group_fund_fiscal_year__t as fgffy --finance_group_fund_fiscal_years fgffy 
       ON ff.id = fgffy.fund_id
       
       LEFT JOIN folio_finance.groups__t as fg --finance_groups AS fg 
       ON fgffy.group_id = fg.id
       
       LEFT JOIN billto ON ii.bill_to = billto.bill_to_id
       LEFT JOIN billto2 ON ppo.bill_to = billto2.bill_to_id

WHERE 
       pi2.order_type = 'One-Time' --ppo.order_type  = 'One-Time' 
       -- and pi2.ship_to != 'LTS Approvals'
       -- and pi2.created_location != 'LTS Approvals'
       -- and billto.bill_to_name !='LTS Approvals' -- invoice bill to
       -- and billto2.bill_to_name !='LTS Approvals' -- po bill to 
       AND pol.receipt_status = 'Fully Received'
       --AND pi2.pol_location_name != 'serv,remo'
       AND pi2.po_created_date::DATE >= (SELECT po_create_date_start FROM parameters) 
       AND ie.created_date::DATE >= (SELECT po_create_date_start FROM parameters)
       AND ii.vendor_invoice_no NOT LIKE '%problem%'
       AND he.call_number IS NOT null
       AND ii.payment_date IS NOT NULL
       and pi2.requester is not null
       and pi2.requester NOT SIMILAR TO '%(no request|n/a|na|no req|No requestor|No requester)%'
       
GROUP BY  
   CASE WHEN DATE_PART ('month',ii.payment_date::DATE)< 7 THEN CONCAT ('FY', DATE_PART ('year',ii.payment_date::DATE)) 
              ELSE CONCAT ('FY', DATE_PART ('year', ii.payment_date::DATE) + 1) END,
   pi2.pol_instance_hrid,
   he.holdings_hrid,
   ie.item_hrid,
   ie.item_id,
   ie.created_date::DATE,
   ie.barcode,
   pi2.title,
   pi2.requester,
   pi2.order_type, --ppo.order_type, 
   pi2.po_number,
   pi2.po_line_number,
   pi2.vendor_code, 
   ie.material_type_name,
   pi2.receipt_status,--pol.receipt_status,
   he.call_number,
   pi2.location_name,  
   pi2.po_created_date::DATE,
   pol.receipt_date::DATE,
   ii.vendor_invoice_no,
   ii.invoice_date,--(jsonb_extract_path_text (ii.jsonb, 'metadata', 'createdDate'))::DATE,
   billto.bill_to_name,
   billto2.bill_to_name,
   pi2.ship_to,
   ilfd.fund_code,
   ilfd.fund_name,
   CASE -- selects the correct finance group for funds that were merged into Area Studies from 2CUL in FY2024, based on invoice payment date
        WHEN ilfd.fund_code in ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') and ii.payment_date::DATE >='2023-07-01' THEN 'Area Studies'
        WHEN ilfd.fund_code in ('2616','2310','2342','2410','2411','2440','p2350','p2450','p2452','p2658','2352') and ii.payment_date::DATE <'2023-07-01' THEN '2CUL'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date >='2024-07-01' THEN 'Interdisciplinary'
        WHEN ilfd.fund_code in ('7311','7342','7370','p7358') AND ii.payment_date::date <'2024-07-01' THEN 'Course Reserves' 
        ELSE fg.name 
        END,
   
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

	FROM folio_source_record.marc__t as sm --srs_marctab AS sm 
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
       orders.order_type,
       orders.ship_to,
       orders.po_no,
       orders.po_line_number,
       orders.vendor, 
       orders.material_type_name,
       orders.receipt_status,
       orders.call_no,
       orders.location_name,
       orders.item_id,
       orders.po_created_date::date,
       orders.pol_receipt_date::date,
       orders.item_created_date::date,
       orders.vendor_invoice_no,
       orders.invoice_created_date::date,
       orders.inv_bill_to_name,
       orders.po_bill_to_name,
       orders.fund_code,
       orders.fund_group_name,
       orders.fund_name,
       orders.cost,
       cci.item_id AS cci_item_id,
       cci.item_status_prior_to_check_in,
       cci.occurred_date_time::DATE AS item_discharged_at_unit_date

FROM orders 
       LEFT JOIN folio_circulation.check_in__t  as cci --circulation_check_ins AS cci 
       ON orders.item_id = cci.item_id 
               
       LEFT JOIN pubdate 
       ON orders.inst_hrid = pubdate.instance_hrid

WHERE cci.item_status_prior_to_check_in = 'In process' OR cci.item_id IS NULL
)

-- 5. Get when the item was first circulated, and join all the data together:

SELECT DISTINCT
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
       received.location_name,    
       received.requester,
       received.order_type,    
       received.po_no,
       received.po_line_number,
       received.receipt_status,
       received.vendor,
       received.vendor_invoice_no,
       received.invoice_created_date::date,
       received.inv_bill_to_name,
       received.po_bill_to_name,
       received.ship_to,
       received.fund_code,
       received.fund_group_name,
       received.fund_name,
       received.cost,
       received.item_status_prior_to_check_in,
       
-- key dates:
       TO_CHAR (received.po_created_date::DATE,'mm/dd/yyyy') AS order_date,
       TO_CHAR (received.item_created_date::DATE,'mm/dd/yyyy') AS item_created_date,
       TO_CHAR (received.pol_receipt_date::DATE,'mm/dd/yyyy') AS recd_at_lts_date,
       TO_CHAR (received.item_discharged_at_unit_date::DATE,'mm/dd/yyyy') AS recd_at_unit_date,
       TO_CHAR (MIN (li.loan_date::DATE),'mm/dd/yyyy') AS first_checkout_date,
         
-- number of days calculations:  
       received.pol_receipt_date - received.po_created_date AS days_til_recd_at_lts_from_order_date,  
       --received.pol_receipt_date - received.item_created_date AS days_til_recd_at_lts,
       received.item_discharged_at_unit_date - received.pol_receipt_date AS days_til_recd_at_unit,
       MIN (li.loan_date::DATE) - received.item_discharged_at_unit_date::DATE AS days_til_first_checkout

FROM received 
       LEFT JOIN folio_derived.loans_items AS li 
       ON received.item_id = li.item_id
      
       LEFT JOIN folio_derived.instance_publication AS ip 
       ON received.inst_hrid = ip.instance_hrid
      
       LEFT JOIN folio_derived.instance_languages AS lang 
       ON received.inst_hrid = lang.instance_hrid

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
       received.location_name,    
       received.requester,
       received.order_type,      
       received.po_no,
       received.po_line_number,
       received.receipt_status,
       received.vendor,
       received.vendor_invoice_no,
       received.invoice_created_date,
       received.inv_bill_to_name,
       received.po_bill_to_name,
       received.ship_to,
       received.fund_code,
       received.fund_group_name,
       received.fund_name,
       received.cost,
       received.item_status_prior_to_check_in,
       received.item_discharged_at_unit_date::DATE,
-- key dates:
       TO_CHAR (received.po_created_date::DATE,'mm/dd/yyyy'),
       TO_CHAR (received.item_created_date::DATE,'mm/dd/yyyy'),
       TO_CHAR (received.pol_receipt_date::DATE,'mm/dd/yyyy'),
       TO_CHAR (received.item_discharged_at_unit_date::DATE,'mm/dd/yyyy'),       
-- number of days calculations:  
       received.pol_receipt_date - received.po_created_date,      
       received.pol_receipt_date - received.item_created_date,
       received.item_discharged_at_unit_date::DATE - received.pol_receipt_date
              
ORDER BY fiscal_year, title
;


