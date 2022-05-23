-- Lists title, patron group and department (where available) for items borrowed from other universities on Borrow Direct and Interlibrary Loan for FY22

SELECT 
	TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
	li.material_type_name,
	TO_CHAR (li.loan_date::DATE,'mm/dd/yyyy') AS loan_date,
	TO_CHAR (li.loan_return_date::DATE,'mm/dd/yyyy') AS return_date,
	CASE WHEN li.loan_return_date IS NOT NULL THEN DATE_PART('day', li.loan_return_date - li.loan_date) ELSE date_part('day', NOW() - li.loan_date) END AS days_on_loan,
	ie.title,
	ie.instance_hrid,
	he.holdings_hrid,
	li.hrid as item_hrid,
	li.barcode,
	itemext.effective_call_number,
	li.loan_policy_name,
	he.permanent_location_name,
	li.patron_group_name,
	udu.department_name,
	udu.department_code

FROM folio_reporting.loans_items AS li 
	LEFT JOIN folio_reporting.holdings_ext AS he 
	ON li.holdings_record_id = he.holdings_id
	
	LEFT JOIN folio_reporting.instance_ext AS ie 
	ON he.instance_id = ie.instance_id
	
	LEFT JOIN folio_reporting.item_ext AS itemext 
	ON li.item_id = itemext.item_id
	
	LEFT JOIN folio_reporting.users_departments_unpacked AS udu 
	ON li.user_id = udu.user_id

WHERE 
	li.loan_date >'2021-07-01'
	AND (li.material_type_name LIKE 'BD%' OR li.material_type_name LIKE 'ILL%')
	AND (li.current_item_permanent_location_name LIKE 'Borr%' OR li.current_item_permanent_location_name LIKE 'Int%')
	AND (udu.department_ordinality = 1 OR udu.department_ordinality IS NULL)
	
ORDER BY title, loan_date
;
