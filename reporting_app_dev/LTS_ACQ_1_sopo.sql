CREATE OR REPLACE FUNCTION LTS_ACQ_sopo(start_date date, end_date date)
 RETURNS TABLE(pol_instance_hrid text, po_number text, po_line_number text, vendor_code text, f_status text, po_created_date date, field text, series text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    poi.pol_instance_hrid,
    poi.po_number,
    poi.po_line_number,
    poi.vendor_code,
    poi.po_workflow_status,
    poi.created_date,
    marc.field,
    string_agg(DISTINCT marc.content, '') AS series
  FROM folio_derived.po_instance AS poi
  LEFT JOIN folio_inventory.instance__t__ AS ii 
    ON poi.pol_instance_hrid = ii.hrid 
  LEFT JOIN folio_source_record.marc__t AS marc 
    ON ii.hrid = marc.instance_hrid 
  WHERE marc.field IN ('490','830') 
    AND poi.created_date::DATE BETWEEN start_date AND end_date
  GROUP BY 
    poi.pol_instance_hrid,
    marc.instance_hrid,
    poi.po_number,
    poi.po_line_number,
    poi.vendor_code,
    poi.created_date,
    poi.po_workflow_status,
    marc.field;
END;
$function$
;
