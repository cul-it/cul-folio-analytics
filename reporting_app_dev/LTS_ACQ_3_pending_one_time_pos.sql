--metadb:function LTS_ACQ_pending_orders

DROP FUNCTION IF EXISTS get_pending_one_time_orders;
CREATE FUNCTION get_pending_one_time_orders()
RETURNS TABLE (
               po_creation_date DATE,
               po_number TEXT,
               workflow_status TEXT,
               order_type TEXT
)
AS
$$
SELECT 
      po.creation_date::date AS po_creation_date,
      pot.po_number,
      pot.workflow_status,
      pot.order_type
FROM folio_orders.purchase_order po
LEFT JOIN folio_orders.purchase_order__t pot ON pot.id = po.id
WHERE pot.workflow_status = 'Pending'
AND pot.order_type NOT ILIKE 'Ongoing'
ORDER BY po.creation_date::date DESC;
$$
LANGUAGE SQL
STABLE
PARALLEL SAFE;
