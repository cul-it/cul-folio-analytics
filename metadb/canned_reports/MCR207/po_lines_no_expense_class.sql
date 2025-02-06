--MCR207 
---po_lines_no_expense_class
--2/6/25: revised for Metadb by Sharon Markus
--2/4/25: updated for LDP 2.1.0
--written by Ann Crowley, Nancy Bolduc, and Sharon Markus

--This query is used to get a listing of purchase order lines with no expense class selected when the PO was created.
--It includes fund code, purchase order line number,workflow status, order type, order format and Title.
--This is pulling purchase order line information not tied to a transaction.

SELECT
  current_date AS current_date,
  PO_line_number AS po_line_number,
  ff.code AS fund_code,
  ppo.workflow_status AS workflow_status,
  ppo.order_type AS order_type,
  order_format AS order_format,
  title_or_package AS title_or_package

FROM folio_orders.po_line AS pol
  CROSS JOIN jsonb_array_elements(jsonb_extract_path(jsonb, 'fundDistribution')) AS dist(data)
  LEFT JOIN folio_orders.po_line__t AS pol2 ON pol.id::UUID = pol2.id::UUID
  LEFT JOIN folio_finance.expense_class__t AS fec ON jsonb_extract_path_text(dist.data, 'expenseClassId')::UUID = fec.id::UUID
  LEFT JOIN folio_finance.fund__t AS ff ON ff.id::UUID = jsonb_extract_path_text(dist.data, 'fundId')::UUID
  LEFT JOIN folio_orders.purchase_order__t AS ppo ON ppo.id::UUID = pol2.purchase_order_id::UUID

WHERE fec.name IS NULL
AND ff.code != '522'
AND ff.code != '999'
AND ff.code != '9'
AND ff.code != '7'
AND ff.code != '3'
AND ff.code != '4'
AND ff.code != '70'
AND ff.code != '6920'
AND ff.code != '6921'
AND ff.code != 'Look'
AND ff.code != '515'
AND ff.code != '518'
AND ppo.workflow_status != 'Closed'

ORDER BY
pol2.PO_line_number,
ff.code;

