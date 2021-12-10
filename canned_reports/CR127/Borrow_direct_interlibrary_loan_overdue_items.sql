WITH parameters AS (
SELECT
	/* replace the placeholder number with the number of days overdue that is needed for this report */
	'30'::integer AS days_overdue_filter
	-- doesn't work if empty
       ),
days AS (
SELECT
	loan_id,
	item_id,
	DATE_PART('day', NOW() - loan_due_date) AS days_overdue
FROM
	folio_reporting.loans_items
),
BDILL AS 
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
	uu.barcode
FROM
	user_users AS uu
LEFT JOIN user_groups AS ug 
        ON
	uu.patron_group = ug.id
WHERE
	ug.desc LIKE 'Borrow Direct%'
	OR ug.desc LIKE 'Inter%'
)

SELECT
	to_char(current_date::DATE, 'mm/dd/yyyy') AS todays_date,
	days.days_overdue,
	--  DATE_PART('day', NOW() - li.loan_due_date) AS days_overdue,
	li.loan_policy_name,
	BDILL.patron_last_name,
	BDILL.patron_first_name,
	BDILL.barcode AS patron_barcode,
	ie.title,
	he.permanent_location_name,
	he.call_number,
	li.enumeration,
	li.chronology,
	li.copy_number,
	li.barcode AS item_barcode,
	max(li.loan_date)AS latest_loan_date,
	to_char(li.loan_due_date::DATE, 'mm/dd/yyyy') AS loan_due_date,
	ite.status_name,
	to_char(ite.status_date::DATE, 'mm/dd/yyyy') AS item_status_date
FROM
	folio_reporting.loans_items AS li
LEFT JOIN BDILL 
        ON
	li.user_id = BDILL.id
LEFT JOIN days ON
	days.loan_id = li.loan_id
LEFT JOIN folio_reporting.holdings_ext AS he 
        ON
	li.holdings_record_id = he.holdings_id
LEFT JOIN folio_reporting.instance_ext AS ie 
        ON
	he.instance_id = ie.instance_id
LEFT JOIN folio_reporting.item_ext AS ite 
        ON
	li.item_id = ite.item_id
WHERE
	(days.days_overdue > 0
		AND days.days_overdue <= (
		SELECT
			days_overdue_filter
		FROM
			parameters))
	AND li.loan_policy_name IN ('20 weeks (ILL)', '20 weeks (BD)')
	AND li.loan_return_date IS NULL
GROUP BY
	to_char(current_date::DATE, 'mm/dd/yyyy'),
	li.loan_policy_name,
	li.loan_date,
	BDILL.patron_last_name,
	BDILL.patron_first_name,
	BDILL.barcode,
	ie.title,
	he.permanent_location_name,
	he.call_number,
	li.enumeration,
	li.chronology,
	li.copy_number,
	li.barcode,
	days.days_overdue,
	to_char(li.loan_date::DATE, 'mm/dd/yyyy'),
	to_char(li.loan_due_date::DATE, 'mm/dd/yyyy'),
	ite.status_name,
	to_char(ite.status_date::DATE, 'mm/dd/yyyy')
ORDER BY
	patron_last_name,
	patron_first_name,
	loan_date,
	title,
	enumeration,
	chronology;

