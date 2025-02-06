--CR207 
--2/6/25: updated for LDP 2.1.0

--po_lines_no_expense_class
--To get a listing of purchase order lines with no expense class selected when the PO was created
--Includes fund code, purchase order line #,workflow status, order type, order format and Title
--This is pulling purchase order line information not tied to a transaction

SELECT
  current_date AS current_date,
  PO_line_number AS po_line_number,
  ff.code AS fund_code,
  ppo.workflow_status AS workflow_status,
  ppo.order_type AS order_type,
  order_format AS order_format,
  title_or_package AS title_or_package

FROM po_lines AS pol
  CROSS JOIN jsonb_array_elements(jsonb_extract_path(data, 'fundDistribution')) AS dist(data)
  LEFT JOIN finance_expense_classes AS fec ON jsonb_extract_path_text(dist.DATA, 'expenseClassId')::UUID = fec.id::UUID
  LEFT JOIN finance_funds AS ff ON ff.id::UUID = jsonb_extract_path_text(dist.data, 'fundId')::UUID
  LEFT JOIN po_purchase_orders AS ppo ON ppo.id::UUID = pol.purchase_order_id::UUID

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
pol.PO_line_number,
ff.code;
