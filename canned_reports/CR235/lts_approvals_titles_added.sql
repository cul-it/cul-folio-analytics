--CR235
--lts_approval_titles_added
--created by Natalya Pikulik
--created on 03/18/2024
--This report gets new titles that were received on approval plan via statistical code.

SELECT 
isc.instance_hrid,
isc.statistical_code,
isc.statistical_code_name,
isc.statistical_code_type_name,
ii.metadata__created_date::date
FROM 
folio_reporting.instance_statistical_codes isc 
LEFT JOIN inventory_instances ii ON isc.instance_id =ii.id 
WHERE isc.statistical_code_name IN ('Approval/Blanket order')
and ii.metadata__created_date::date>'2021-07-01'
