WITH receiving AS (
SELECT
   pp.received_date::DATE,
   ppo.bill_to AS bill_to_id,
   ppo.order_type,
   pp.format,
   pp.caption AS issues_received,
   pp.receiving_status AS status_received,
   ppo.po_number,
   ppo.po_number_prefix,
   pl.order_format,
   ppo.ship_to,
   poi.bill_to
FROM po_pieces pp
LEFT JOIN po_lines pl ON pp.po_line_id = pl.id
LEFT JOIN po_purchase_orders ppo ON ppo.id = pl.purchase_order_id
LEFT JOIN folio_reporting.po_instance poi ON ppo.id::uuid=poi.po_number_id::uuid
where ppo.order_type = 'Ongoing'
and pp.format = 'Physical'
and pp.receiving_status = 'Received'
AND pp.received_date > '2021-07-01'
AND poi.bill_to NOT iLIKE '%law%'
)
SELECT
   rc.received_date,
   rc.bill_to_id,
   rc.bill_to,
   rc.order_type,
   rc.format,
   rc.issues_received,
   rc.status_received,
   rc.po_number,
   rc.po_number_prefix,
   rc.order_format,
   rc.ship_to
   FROM receiving AS rc
  WHERE rc.bill_to not IN ('Law Technical Services')
;
