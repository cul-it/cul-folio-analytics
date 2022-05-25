--QUERY 1
--BD/ILL loans and renewals counts from CUL to other universities

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */ 
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date
        ),
loans AS 
(SELECT 
    li.loan_id,
    CASE WHEN li.renewal_count IS NULL THEN 0 ELSE li.renewal_count END AS renew_count
    FROM folio_reporting.loans_items AS li
    )

SELECT
       TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
       li.patron_group_name,
       ll.library_name,    
       COUNT (lns.loan_id) AS number_of_checkouts, 
       SUM (lns.renew_count) AS number_of_renewals, 
       COUNT (lns.loan_id) + SUM (lns.renew_count) AS total_charges_and_renewals 

FROM folio_reporting.loans_items AS li
    LEFT JOIN loans lns ON li.loan_id = lns.loan_id
    
    left join folio_reporting.locations_libraries ll 
    on li.item_effective_location_id_at_check_out = ll.location_id

WHERE
	li.loan_date >= (SELECT start_date FROM parameters)
    and li.loan_date < (SELECT end_date FROM parameters)
    and (li.material_type_name not like 'BD%' and li.material_type_name not like '%ILL%')
    and (li.patron_group_name like 'B%' or li.patron_group_name like 'I%')

GROUP BY
    TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
    ll.library_name,
    li.patron_group_name

        
ORDER BY
    li.patron_group_name ASC

;


--QUERY 2
--BD/ILL – count of items borrowed from other universities

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */ 
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date
        )
SELECT
        TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
        li.current_item_permanent_location_name,
        li.patron_group_name,
        COUNT (li.loan_id) AS total_circs

FROM folio_reporting.loans_items AS li
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON li.current_item_permanent_location_id = ll.location_id

WHERE 
		li.loan_date >= (SELECT start_date FROM parameters)
    	AND li.loan_date < (SELECT end_date FROM parameters) 
        AND (li.current_item_permanent_location_name LIKE 'Borrow%' OR li.current_item_permanent_location_name LIKE 'Inter%')

GROUP BY
        TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
        li.current_item_permanent_location_name,
        li.patron_group_name
        
ORDER BY
        li.current_item_permanent_location_name ASC,
        li.patron_group_name ASC
        ;
