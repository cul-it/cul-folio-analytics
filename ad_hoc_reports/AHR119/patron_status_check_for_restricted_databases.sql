--AHR119
--patron_status_check_for_restricted_databases

SELECT
	TO_CHAR (CURRENT_DATE::DATE,
	'mm/dd/yyyy') AS todays_date,
	pu.*,
	json_extract_path_text (uu.data,
	'personal',
	'lastName') AS patron_last_name,
	json_extract_path_text (uu.data,
	'personal',
	'firstName') AS patron_first_name,
	uu.barcode AS patron_barcode,
	uu.username AS net_id,
	json_extract_path_text (uu.data,
	'personal',
	'email') AS email_address,
	CASE
		WHEN uu.active = 'True' THEN 'Active'
		WHEN uu.active = 'False' THEN 'Expired'
		ELSE 'Not found'
	END AS patron_status,
	ug.group_name,
	udu.department_name,
	udu.department_code
FROM
	local.pitchbook_users pu
LEFT JOIN user_users AS uu 
        ON
	pu.netid = uu.username
LEFT JOIN folio_reporting.users_groups AS ug 
        ON
	uu.id = ug.user_id
LEFT JOIN folio_reporting.users_departments_unpacked udu 
        ON
	uu.id = udu.user_id
ORDER BY
	pu.seq_number
;
