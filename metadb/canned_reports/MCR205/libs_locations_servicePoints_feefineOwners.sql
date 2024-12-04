--MCR205
--libraries_locations_service_points_feefine_owners

--This query finds libraries, locations, service points and fine owners associated with the service points.

--Query writer: Joanne Leary (jl41)
--Posted on: 12/4/24

WITH fine_owner AS 
(SELECT 
	ffo.id as owner_id,
	jsonb_extract_path_text (ffo.jsonb,'owner') AS fee_fine_owner,
	jsonb_extract_path_text (sp.data,'label') AS service_point_name,
	jsonb_extract_path_text (sp.data,'value')::UUID AS service_point_id,
	sp.ordinality AS service_point_ordinality
	
FROM folio_feesfines.owners__ AS ffo
	CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (ffo.jsonb, 'servicePointOwner')) WITH ORDINALITY 
	AS sp (data)
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
		WHEN invloc.is_active = 'True' 
		THEN 'Active' 
		ELSE 'Inactive' 
		END AS location_status,
	CASE 
		WHEN invsp.pickup_location = 'True' 
		THEN 'Yes' 
		ELSE 'No' 
		END AS pickup_service_point,
	fine_owner.fee_fine_owner

FROM folio_inventory.loclibrary__t as invlib --inventory_libraries AS invlib
	FULL OUTER JOIN folio_inventory.location__t as invloc --inventory_locations AS invloc 
	ON invlib.id = invloc.library_id 
	
	FULL OUTER JOIN folio_inventory.service_point__t as invsp --inventory_service_points AS invsp 
	ON invloc.primary_service_point = invsp.id
	
	FULL OUTER JOIN fine_owner 
	ON invsp.id::UUID = fine_owner.service_point_id

ORDER BY 
	library_name,
	location_name,
	service_point_name
;
