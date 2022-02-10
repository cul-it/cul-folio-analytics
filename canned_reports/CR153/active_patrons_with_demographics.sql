SELECT 
        json_extract_path_text(uu.data,'personal','lastName') AS last_name,
        json_extract_path_text(uu.data,'personal','firstName') AS first_name,
        uu.username AS net_id,
        uu.active,
        json_extract_path_text(uu.data,'customFields','college') AS college,
        udu.department_name,
        udu.department_code,
        ug.group AS patron_group,
        uu.barcode AS patron_barcode,
        json_extract_path_text(uu.data,'externalSystemId') AS external_system_id

FROM user_users AS uu 
        LEFT JOIN folio_reporting.users_departments_unpacked AS udu 
        ON uu.id = udu.user_id 
        
        LEFT JOIN user_groups AS ug 
        ON uu.patron_group = ug.id

WHERE uu.active = 'True'
        AND uu.barcode IS NOT NULL 

ORDER BY college, department_name, last_name, first_name
;
