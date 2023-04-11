--CR205
--libraries_locations_service_points_owners


WITH parameters AS 
(
SELECT
	'45'::varchar AS age_of_bill,
	-- enter minimum number of days old (required). For all open fines, enter zero.
'%%'::varchar AS feefine_owner
	-- enter an owning library (optional). For all libraries, leave blank.
)
SELECT
	concat ((
	SELECT
		age_of_bill
	FROM
		parameters)::varchar,
	' days and older') AS fine_group,
	to_char (current_date::date,
	'mm/dd/yyyy') AS todays_date,
	ffo.owner AS fee_fine_owner,
	uu.personal__last_name AS patron_last_name,
	uu.personal__first_name AS patron_first_name,
	uu.external_system_id,
	uu.username AS netid,
	ug.GROUP AS patron_group,
	CASE
		WHEN uu.active = 'True' THEN 'Active'
		ELSE 'Expired'
	END AS patron_status,
	ffa.id AS fee_fine_id,
	current_date::date - ffa.metadata__created_date::date AS age_of_fine,
	to_char (ffa.metadata__created_date::timestamp,
	'mm/dd/yyyy hh:mi am') AS fine_create_date,
	ffa.fee_fine_type,
	ffa.amount AS original_amount,
	ffa.remaining AS amount_remaining,
	ffa.title,
	ffa.call_number,
	ffa.barcode,
	ffa.material_type,
	to_char (ffa.due_date::timestamp,
	'mm/dd/yyyy hh:mi am') AS due_date,
	to_char (ffa.returned_date::timestamp,
	'mm/dd/yyyy hh:mi am') AS return_date,
	ffa.status__name AS fee_fine_status
FROM
	feesfines_accounts AS ffa
LEFT JOIN user_users AS uu 
ON
	ffa.user_id = uu.id
LEFT JOIN feesfines_owners AS ffo 
ON
	ffa.owner_id = ffo.id
LEFT JOIN user_groups AS ug 
ON
	uu.patron_group = ug.id
WHERE
	ffa.metadata__created_date <= current_date::date - (
	SELECT
		age_of_bill
	FROM
		parameters)::integer
	AND ffa.status__name = 'Open'
	AND (ffo.OWNER ILIKE (
	SELECT
		feefine_owner
	FROM
		parameters)
	OR (
	SELECT
		feefine_owner
	FROM
		parameters) = '')
ORDER BY
	uu.personal__last_name,
	uu.personal__first_name,
	ffa.metadata__created_date
;
