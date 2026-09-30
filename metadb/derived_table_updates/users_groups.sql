-- 6-4-26: users_groups derived table re-write
-- This is a re-write of the users_groups derived table, without using the users_departments_unpacked derived table
-- Replaced the code for users_departments_unpacked with simpler code 
		
WITH user_depts AS 
	(SELECT
		    uu.id AS user_id,
		    departments.jsonb #>> '{}' AS department_id,
		    departments.ordinality AS department_ordinality,
		    ud.name AS department_name
		 FROM
		    folio_users.users AS uu
		    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(uu.jsonb, 'departments'))
		        WITH ORDINALITY AS departments (jsonb)
		        
		    LEFT JOIN folio_users.departments__t AS ud 
		    ON (departments.jsonb#>>'{}')::UUID = ud.id
)

SELECT
    users.id AS user_id,
    u.active,
    u.barcode,
    jsonb_extract_path_text(users.jsonb, 'metadata', 'createdDate')::timestamptz AS created_date,
    u.enrollment_date,
    u.expiration_date,
    u.external_system_id,
    u.patron_group,
    g.desc AS group_description,
    g.group AS group_name,
    user_depts.department_id,
    user_depts.department_name,
    jsonb_extract_path_text(users.jsonb, 'personal', 'lastName') AS user_last_name,
    jsonb_extract_path_text(users.jsonb, 'personal', 'firstName') AS user_first_name,
    jsonb_extract_path_text(users.jsonb, 'personal', 'middleName') AS user_middle_name,
    jsonb_extract_path_text(users.jsonb, 'personal', 'preferredFirstName') AS user_preferred_first_name,
    jsonb_extract_path_text(users.jsonb, 'personal', 'email') AS user_email,
    jsonb_extract_path_text(users.jsonb, 'personal', 'phone') AS user_phone,
    jsonb_extract_path_text(users.jsonb, 'personal', 'mobilePhone') AS user_mobile_phone,
    jsonb_extract_path_text(users.jsonb, 'personal', 'dateOfBirth')::date AS user_date_of_birth,
    jsonb_extract_path_text(users.jsonb, 'personal', 'preferredContactTypeId') AS user_preferred_contact_type_id,
    u.type AS user_type,
    jsonb_extract_path_text(users.jsonb, 'metadata', 'updatedDate')::timestamptz AS updated_date,
    u.username
FROM
    folio_users.users
    LEFT JOIN folio_users.users__t AS u ON users.id = u.id  
    LEFT JOIN folio_users.groups__t AS g ON u.patron_group = g.id
    LEFT JOIN user_depts ON users.id = user_depts.user_id
 ;

