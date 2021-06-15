WITH parameters AS (
SELECT
    '2021-05-01'::DATE AS start_date,
    '2021-06-14'::DATE AS end_date
)
SELECT 
    poi.po_number AS po_number,
    poi.po_line_number,
    poi.vendor_code AS vendor_code,
    poi.created_date AS po_created_date,
    marc.bib_id,
    marc.tag,
    string_agg('$'::varchar || marc.sf || marc.content, '') AS series
FROM
    folio_reporting.po_instance AS poi
LEFT JOIN 
    inventory_instances AS ii ON poi.pol_instance_hrid = ii.hrid 
LEFT JOIN
    folio_source_record."__marc" AS marc ON ii.hrid = marc.bib_id 
WHERE
    marc.tag IN ('490','830') 
    AND poi.created_date::DATE >= (SELECT start_date FROM parameters)
    AND poi.created_date::DATE < (SELECT end_date FROM parameters)
GROUP BY
    marc.bib_id,
    marc.tag,
    poi.po_number,
    poi.po_line_number,
    poi.vendor_code,
    poi.created_date
;
