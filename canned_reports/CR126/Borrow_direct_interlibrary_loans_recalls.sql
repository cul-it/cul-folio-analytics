WITH BDILL AS 
(
SELECT
	uu.id,
	json_extract_path_text(uu.data,
	'personal',
	'lastName') AS patron_last_name,
	json_extract_path_text(uu.data,
	'personal',
	'firstName') AS patron_first_name,
	ug.desc AS patron_group_name,
	uu.barcode,
	uu.active
FROM
	user_users AS uu
LEFT JOIN user_groups AS ug 
        ON
	uu.patron_group = ug.id
WHERE
	ug.desc LIKE 'Borrow Direct%'
	OR ug.desc LIKE 'Inter%'
ORDER BY
	patron_last_name,
	patron_first_name
),
days AS (
SELECT
	item_id,
	DATE_PART('day', NOW() - due_date) AS days_overdue
FROM
	public.circulation_loans
),
main AS (
SELECT
	to_char(current_date::DATE, 'mm/dd/yyyy') AS todays_date,
	BDILL.patron_last_name,
	BDILL.patron_first_name,
	BDILL.barcode AS borrower_barcode,
	iext.title,
	he.permanent_location_name,
	he.call_number,
	ii.enumeration,
	ii.chronology,
	ii.copy_number,
	ii.barcode AS item_barcode,
	to_char(cl.loan_date::DATE, 'mm/dd/yyyy') AS loan_date,
	to_char(ri.request_date::DATE, 'mm/dd/yyyy') AS recall_request_date,
	to_char(cl.due_date::DATE, 'mm/dd/yyyy') AS due_date,
	days.days_overdue,
	cl.system_return_date,
	json_extract_path_text(ii.data,
	'status',
	'name') AS current_item_status,
	to_char(json_extract_path_text(ii.data, 'status', 'date')::DATE, 'mm/dd/yyyy') AS current_item_status_date,
	cl.due_date_changed_by_recall,
	ri.request_type,
	ri.request_status,
	json_extract_path_text(uu2.data,'personal', 'lastName') AS requester_last_name,
	json_extract_path_text(uu2.data, 'personal', 'firstName') AS requester_first_name,
	json_extract_path_text(uu2.data, 'personal', 'email') AS requester_email,
	uu2.barcode AS requester_barcode,
	ri.patron_group_name AS requester_patron_group
FROM
	circulation_loans AS cl
INNER JOIN BDILL ON
	BDILL.id = cl.user_id
LEFT JOIN inventory_items AS ii 
        ON
	cl.item_id = ii.id
LEFT JOIN folio_reporting.requests_items AS ri 
        ON
	ii.id = ri.item_id
LEFT JOIN user_users AS uu2 
        ON
	ri.requester_id = uu2.id
LEFT JOIN folio_reporting.holdings_ext AS he 
        ON
	ii.holdings_record_id = he.holdings_id
LEFT JOIN folio_reporting.instance_ext AS iext 
        ON
	he.instance_id = iext.instance_id
LEFT JOIN days ON
	days.item_id = cl.item_id

	WHERE
	cl.due_date_changed_by_recall = 'true'
	AND cl.system_return_date IS NULL
	AND cl.due_date < current_date
	AND json_extract_path_text(ii.data, 'status', 'name') = 'Checked out'
	)
	
	SELECT 
		recall_request_date,
		request_status,
		item_barcode,
		borrower_barcode,
		call_number,
		permanent_location_name,
		title,
		requester_patron_group,
		requester_email
	FROM main
		
	ORDER BY
	recall_request_date ASC
        ;
