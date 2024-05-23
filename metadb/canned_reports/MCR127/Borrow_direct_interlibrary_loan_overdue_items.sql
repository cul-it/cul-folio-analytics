--MCR127
--Borrow_direct_interlibrary_loan_overdue_items
--Provides a list of items owned by CUL and borrowed by BD/ILL patrons, that are overdue.
--Original query written by Joanne Leary (jl41)
--This query ported to Metadb by Vandana Shah (vp25)
--Reviewed by Joanne Leary (jl41) and Linda Miller (lm15)
--Posted on 5/23/24


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
	folio_derived.loans_items 
),
BDILL AS 
(
SELECT
	users.id,
	jsonb_extract_path_text(users.jsonb, 'personal', 'lastName') AS patron_last_name,
	jsonb_extract_path_text(users.jsonb, 'personal', 'firstName') AS patron_first_name,
	groups__t."desc" AS patron_group_name,
	jsonb_extract_path_text(users.jsonb, 'barcode') AS barcode
FROM
	folio_users.users 
LEFT JOIN folio_users.groups__t  
        ON
	folio_users.users.patrongroup = folio_users.groups__t.id
WHERE
	folio_users.groups__t.desc LIKE 'Borrow Direct%'
	OR folio_users.groups__t.desc LIKE 'Inter%'
)

SELECT
	to_char(current_date::DATE, 'mm/dd/yyyy') AS todays_date,
	days.days_overdue,
	loans_items.loan_policy_name,
	BDILL.patron_last_name,
	BDILL.patron_first_name,
	BDILL.barcode AS patron_barcode,
	instance_ext.title,
	holdings_ext.permanent_location_name,
	holdings_ext.call_number,
	loans_items.enumeration,
	loans_items.chronology,
	loans_items.copy_number,
	loans_items.barcode AS item_barcode,
	max(loans_items.loan_date)AS latest_loan_date,
	to_char(loans_items.loan_due_date::DATE, 'mm/dd/yyyy') AS loan_due_date,
	item_ext.status_name,
	to_char(item_ext.status_date::DATE, 'mm/dd/yyyy') AS item_status_date
FROM
	folio_derived.loans_items 
LEFT JOIN BDILL 
        ON
	folio_derived.loans_items.user_id = BDILL.id
LEFT JOIN days ON
	days.loan_id = folio_derived.loans_items.loan_id
LEFT JOIN folio_derived.holdings_ext 
        ON
	folio_derived.loans_items.holdings_record_id = folio_derived.holdings_ext.holdings_id
LEFT JOIN folio_derived.instance_ext 
        ON
	folio_derived.holdings_ext.instance_id = folio_derived.instance_ext.instance_id
LEFT JOIN folio_derived.item_ext 
        ON
	folio_derived.loans_items.item_id = folio_derived.item_ext.item_id
WHERE
	(days.days_overdue > 0
		AND days.days_overdue <= (
		SELECT
			days_overdue_filter
		FROM
			parameters))
	AND folio_derived.loans_items.loan_policy_name IN ('20 weeks (ILL)', '20 weeks (BD)')
	AND folio_derived.loans_items.loan_return_date IS NULL
GROUP BY
	to_char(current_date::DATE, 'mm/dd/yyyy'),
	folio_derived.loans_items.loan_policy_name,
	folio_derived.loans_items.loan_date,
	BDILL.patron_last_name,
	BDILL.patron_first_name,
	BDILL.barcode,
	instance_ext.title,
	holdings_ext.permanent_location_name,
	holdings_ext.call_number,
	loans_items.enumeration,
	loans_items.chronology,
	loans_items.copy_number,
	loans_items.barcode,
	days.days_overdue,
	to_char(folio_derived.loans_items.loan_date::DATE, 'mm/dd/yyyy'),
	to_char(folio_derived.loans_items.loan_due_date::DATE, 'mm/dd/yyyy'),
	item_ext.status_name,
	to_char(item_ext.status_date::DATE, 'mm/dd/yyyy')
ORDER BY
	patron_last_name,
	patron_first_name,
	loan_date,
	title,
	enumeration,
	chronology;
