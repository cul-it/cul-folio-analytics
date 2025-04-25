-- MCR171 
--Borrow Direct and ILL loans to Cornell patrons - selectors report. 
-- Finds the items borrowed through ILL and BD, shows the patron group and dept when available, and shows the number of days on loan.
-- Lists title, patron group and department (where available) for items borrowed from other universities on Borrow Direct and Interlibrary Loan. Parameters include date range for the loans. 
--Query writer: Joanne Leary (jl41)
--Posted omn: 7/15/24

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2023-07-01'::date AS start_date,
        '2024-07-01'::date AS end_date
        )
SELECT 
       TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
       li.material_type_name,
       TO_CHAR (li.loan_date::DATE,'mm/dd/yyyy') AS loan_date,
       TO_CHAR (li.loan_return_date::DATE,'mm/dd/yyyy') AS return_date,
       CASE WHEN li.loan_return_date IS NOT NULL THEN (li.loan_return_date::DATE - li.loan_date::DATE) ELSE (NOW()::DATE - li.loan_date::DATE) END AS days_on_loan,
       ie.title,
       ie.instance_hrid,
       he.holdings_hrid,
       li.hrid as item_hrid,
       li.barcode,
       itemext.effective_call_number,
       li.loan_policy_name,
       he.permanent_location_name,
       li.patron_group_name,
       COALESCE (udu.department_name, cs.custom_fields__department) AS department_name,
       COALESCE (udu.department_code, cs.department_code) AS department_code

FROM folio_derived.loans_items as li --folio_reporting.loans_items AS li 
       left join folio_derived.holdings_ext as he --LEFT JOIN folio_reporting.holdings_ext AS he 
       ON li.holdings_record_id = he.id
       
       LEFT JOIN folio_derived.instance_ext AS ie 
       ON he.instance_id = ie.instance_id
       
       LEFT JOIN folio_derived.item_ext AS itemext 
       ON li.item_id = itemext.item_id
       
       LEFT JOIN folio_derived.users_departments_unpacked AS udu 
       ON li.user_id = udu.user_id
       
       left join local_static.sm_circ_snapshot4 as cs 
       on li.loan_id = cs.loan_id::UUID

WHERE
	li.loan_date >= (SELECT start_date FROM parameters)
    	AND li.loan_date < (SELECT end_date FROM parameters)
       	AND (li.material_type_name like 'BD%' OR li.material_type_name like 'ILL%')
       	AND he.permanent_location_name similar to '(Borr|Int)%'
       	AND (udu.department_ordinality = 1 OR udu.department_ordinality IS NULL)
       
ORDER BY title, loan_date
;
