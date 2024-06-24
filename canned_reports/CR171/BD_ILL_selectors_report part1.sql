-- Lists title, patron group and department (where available) for items borrowed from other universities on Borrow Direct and Interlibrary Loan. Parameters include date range for the loans. 
-- 6-7-24: updated to incorporate circ snapshot data
-- 6-24-24: replaced criteria using item locations (permanent or effective) with holdings permanent location name

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loan period */
        '2023-07-01'::date AS start_date,
        '2024-06-30'::date AS end_date
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

FROM folio_reporting.loans_items AS li 
       LEFT JOIN folio_reporting.holdings_ext AS he 
       ON li.holdings_record_id = he.holdings_id
       
       LEFT JOIN folio_reporting.instance_ext AS ie 
       ON he.instance_id = ie.instance_id
       
       LEFT JOIN folio_reporting.item_ext AS itemext 
       ON li.item_id = itemext.item_id
       
       LEFT JOIN folio_reporting.users_departments_unpacked AS udu 
       ON li.user_id = udu.user_id
       
       LEFT JOIN local_core.circ_snapshot4 cs 
       ON li.loan_id = cs.loan_id

WHERE
        li.loan_date >= (SELECT start_date FROM parameters)
        AND li.loan_date < (SELECT end_date FROM parameters)
       AND (li.material_type_name LIKE 'BD%' OR li.material_type_name LIKE 'ILL%')
       AND he.permanent_location_name SIMILAR TO '(Borr|Int)%'
       AND (udu.department_ordinality = 1 OR udu.department_ordinality IS NULL)
       
ORDER BY title, loan_date
;

