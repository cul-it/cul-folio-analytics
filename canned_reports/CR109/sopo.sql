WITH parameters AS (
    SELECT
           current_date - integer '2' AS start_date -- get all orders created XX days from today
    )
SELECT 
    poi.po_number AS po_number,
    poi.po_line_number,
    poi.vendor_code AS vendor_code,
    poi.po_wf_status,
    poi.created_date AS po_created_date,
    m.instance_hrid,
    m.field,
    string_agg('$'::varchar || m.sf || m.content, '') AS series
FROM
    folio_reporting.po_instance AS poi
LEFT JOIN 
    inventory_instances AS ii ON poi.pol_instance_hrid = ii.hrid 
LEFT JOIN
    srs_marctab AS m ON ii.hrid = m.instance_hrid
WHERE
    m.field IN ('490','830') 
    AND poi.created_date::DATE >=(SELECT start_date FROM parameters)
GROUP BY
    m.instance_hrid,
    m.field,
    poi.po_number,
    poi.po_line_number,
    poi.vendor_code,
    poi.created_date,
    poi.po_wf_status
;
