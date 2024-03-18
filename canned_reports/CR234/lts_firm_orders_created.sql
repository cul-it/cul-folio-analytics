--CR234
--lts_firm_orderes_created
--Created by Natalya Pikulik
--Created on 03/18/24
--Used in LTS Acquisition Dashboard, Firm Orderes 
--This reports looks at new LTS Purchase orders created for new titles, print and electronic (Law titles are not included)

WITH pol_select AS (SELECT 
   DISTINCT ii.hrid,
   pi2.pol_instance_hrid,
   ppo.po_number,
   pl.po_line_number,
   ppo.approved,
   ppo.order_type,
   pi2.bill_to,
   pi2.created_by_username,
   pi2.vendor_code AS vendor,
   pi2.title,
   pi2.pol_location_name AS pol_location,
   pi2.created_date::DATE AS po_created_date,
   pl.metadata__created_date::date AS pol_created_date,
   ii.metadata__created_date::date AS instance_created_date,
   pi2.selector,
   pi2.requester,
   pl.order_format 
FROM folio_reporting.po_instance pi2
INNER JOIN inventory_instances ii   ON ii.id = pi2.pol_instance_id 
LEFT JOIN po_purchase_orders ppo ON ppo.po_number = pi2.po_number
LEFT JOIN po_lines pl ON pl.purchase_order_id = ppo.id 
WHERE pi2.vendor_code  IS NOT NULL
AND ii.metadata__created_date::date > '2021-07-04'
AND pi2.created_date::DATE > '2021-07-04'
AND pl.metadata__created_date::date > '2021-07-04'
AND pi2.bill_to NOT iLIKE '%law%'
ORDER BY   pi2.pol_instance_hrid,
   ppo.po_number,
   pl.po_line_number,
   ppo.approved,
   ppo.order_type,
   pi2.bill_to,
   pi2.created_by_username,
   pi2.vendor_code ,
   pi2.title,
   ii.hrid,
   pi2.pol_location_name ,
   pi2.created_date::DATE ,
   pl.metadata__created_date::date ,
   ii.metadata__created_date::date ,
   pi2.selector,
   pi2.requester,
   pl.order_format )
SELECT 
DISTINCT p.hrid,
   p.order_type,
   p.bill_to,
   p.created_by_username,
   p.vendor,
   p.title,
   p.instance_created_date,
   p.order_format 
FROM pol_select p
