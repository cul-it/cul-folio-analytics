--AHR131
--Folio patrons matched to Lexis users
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 7/25/23
/*this query finds Folio patrons matched by first and last name to a file of Lexis users. (requested by Suzanne Cohen, ILR). 
  Custom field elements for College and Department are included in the results in order to help identify the correct user in the case of multiple matches in Folio.*/

SELECT
	lx.seq_no,
	lx.firstname AS lexis_first_name,
	lx.lastname AS lexis_last_name,
	to_char (uu.created_date::date,
	'mm/dd/yyyy') AS folio_patron_record_create_date,
	CASE
		WHEN uu.personal__first_name IS NULL
		AND uu.personal__last_name IS NULL THEN 'Not found'
		WHEN uu.active = 'True' THEN 'Active'
		ELSE 'Inactive'
	END AS folio_patron_status,
	uu.personal__first_name AS folio_first_name,
	uu.personal__last_name AS folio_last_name,
	uu.personal__middle_name AS folio_middle_name,
	uu.username AS folio_net_id,
	uu.personal__email AS folio_email,
	ug.desc AS patron_group,
	uu.custom_fields__college,
	uu.custom_fields__department
FROM
	local.lexisilr AS lx
LEFT JOIN user_users AS uu
       ON
	upper (lx.firstname) = upper (uu.personal__first_name)
	AND upper (lx.lastname) = upper (uu.personal__last_name)
LEFT JOIN user_groups AS ug 
       ON
	uu.patron_group = ug.id
ORDER BY
	lx.seq_no
;

