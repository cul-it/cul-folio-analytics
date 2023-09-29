--CR174A
--QUERY 1
--BD/ILL loans and renewals counts of items loaned BY CUL to others (CUL is LENDER)

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */ 
        '2021-07-01'::date AS start_date,
        '2025-07-01'::date AS end_date
        ),
loans AS 
(SELECT 
    li.loan_id,
    CASE WHEN li.renewal_count IS NULL THEN 0 ELSE li.renewal_count END AS renew_count,
    
    CASE 
	    WHEN date_part ('month',li.loan_date ::DATE) >'6' 
        THEN concat ('FY ', date_part ('year',li.loan_date::DATE) + 1) 
        ELSE concat ('FY ', date_part ('year',li.loan_date::DATE))
        END as fiscal_year_of_loan
     
        FROM folio_reporting.loans_items AS li
    )

SELECT
       TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
       li.patron_group_name,
       ll.library_name,  
       lns.fiscal_year_of_loan,
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
    and (li.patron_group_name like 'Borrow%' or li.patron_group_name like 'Inter%') 
   

GROUP BY
    TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
    ll.library_name,
    li.patron_group_name,
    lns.fiscal_year_of_loan

        
ORDER BY
    li.patron_group_name ASC

;
