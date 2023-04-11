--CR205
--libraries_locations_service_points_owners


WITH fine_owner AS 
(SELECT 
ffo.id AS owner_id,
ffo.OWNER AS fee_fine_owner,
JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (ffo.data, 'servicePointOwner')),'label') AS service_point_name,
JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (ffo.data, 'servicePointOwner')),'value') AS service_point_id
FROM feesfines_owners AS ffo
)

SELECT
to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
invlib.name AS library_name,
invloc.name AS location_name,
invsp.name AS service_point_name,
invlib.code AS library_code,
invloc.code AS location_code,
invsp.code AS service_point_code,
CASE 
WHEN invloc IS NULL THEN ' - ' 
WHEN invloc.is_active = 'True' THEN 'Active' 
ELSE 'Inactive' END AS location_status,
CASE WHEN invsp.pickup_location = 'True' THEN 'Yes' else 'No' END AS pickup_service_point,
fine_owner.fee_fine_owner

FROM inventory_libraries AS invlib
FULL OUTER JOIN inventory_locations AS invloc 
ON invlib.id = invloc.library_id 

FULL OUTER JOIN inventory_service_points AS invsp 
ON invloc.primary_service_point = invsp.id

FULL OUTER JOIN fine_owner 
ON invsp.id = fine_owner.service_point_id


ORDER BY library_name,
location_name,
service_point_name
;
