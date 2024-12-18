--MCR206
-- open_fines_older_than_x_days
--This query lists all open fines that are older than a specified number of days. Includes fee owner and patron details. 

--Query writer: Joanne Leary (jl41)
--posted on: 12/18/24

WITH parameters AS 
(
SELECT
	'45'::varchar AS age_of_bill, -- enter minimum number of days old (required). For all open fines, enter zero.
	'%%'::varchar AS feefine_owner -- enter an owning library (optional). For all libraries, leave blank.
)
SELECT
	concat ((select age_of_bill from parameters)::varchar,' days and older') AS fine_group,
	to_char (current_date::date,
	'mm/dd/yyyy') AS todays_date,
	ffo.owner AS fee_fine_owner,
	jsonb_extract_path_text (users.jsonb,'personal','lastName') as patron_last_name,
	jsonb_extract_path_text (users.jsonb,'personal','firstName') as patron_first_name,
	uu.external_system_id,
	uu.username AS netid,
	ug.group AS patron_group,
	CASE
		WHEN uu.active = TRUE THEN 'Active'
		ELSE 'Expired'
	END AS patron_status,
	ffa.id AS fee_fine_id,
	current_date::date - jsonb_extract_path_text (accounts.jsonb,'metadata','createdDate')::date as age_of_fine,
	jsonb_extract_path_text (accounts.jsonb,'metadata','createdDate')::date as fine_create_date,
	ffa.fee_fine_type,
	ffa.amount AS original_amount,
	ffa.remaining AS amount_remaining,
	ffa.title,
	ffa.call_number,
	ffa.barcode,
	ffa.material_type,
	to_char (ffa.due_date::timestamp,'mm/dd/yyyy hh:mi am') AS due_date,
	to_char (ffa.returned_date::timestamp,'mm/dd/yyyy hh:mi am') AS return_date,
	jsonb_extract_path_text (accounts.jsonb,'status','name') as fee_fine_status 
FROM
	folio_feesfines.accounts__t as ffa 
		LEFT JOIN folio_users.users__t as uu  
		on ffa.user_id = uu.id
		
		left join folio_feesfines.accounts 
		on ffa.id = accounts.id
		
		left join folio_users.users 
		on uu.id = users.id
		
		LEFT JOIN folio_feesfines.owners__t as ffo 
		on ffa.owner_id = ffo.id
		
		LEFT JOIN folio_users.groups__t as ug 
		on uu.patron_group = ug.id
	
WHERE
	jsonb_extract_path_text (accounts.jsonb,'metadata','createdDate')::date <= current_date::date - (select age_of_bill from parameters)::integer
		AND jsonb_extract_path_text (accounts.jsonb,'status','name') = 'Open'
		AND (ffo.owner ILIKE (select feefine_owner from parameters) OR (select feefine_owner from parameters) = '')
ORDER BY
	patron_last_name,
	patron_first_name, 
	created_date 
;
