--MCR174A (QUERY 1) 
--BD/ILL loans and renewals counts of items loaned BY CUL to others (CUL is LENDER)
--Query writer: Joanne Leary (jl41)
--Date posted: 6/24/24

WITH parameters AS (
    SELECT 
        /* Choose a start and end date for the loans period */ 
        '2023-07-01'::date AS start_date,
        '2024-07-01'::date AS end_date
        ),

loans AS 
(SELECT DISTINCT
    loans_items.loan_id,
    CASE WHEN SUM (lrd.folio_renewal_count) is null then 0 else sum (lrd.folio_renewal_count) end AS renew_count,   
    CASE 
        WHEN date_part ('month',loans_items.loan_date ::DATE) > 6 
        THEN concat ('FY ', date_part ('year',loans_items.loan_date::DATE) + 1) 
        ELSE concat ('FY ', date_part ('year',loans_items.loan_date::DATE))
        END AS fiscal_year_of_loan
     
 FROM folio_derived.loans_items 
	 LEFT JOIN local_shared.loans_renewal_dates AS lrd 
	 ON loans_items.loan_id::UUID = lrd.loan_id::UUID
        
 GROUP BY loans_items.loan_id,loans_items.loan_date
)

SELECT
       TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
       loans_items.patron_group_name,
       locations_libraries.library_name,  
       loans.fiscal_year_of_loan,
       COUNT (loans.loan_id) AS number_of_checkouts, 
       SUM (loans.renew_count) AS number_of_renewals, 
       COUNT (loans.loan_id) + SUM (loans.renew_count) AS total_charges_and_renewals 

FROM folio_derived.loans_items 
    LEFT JOIN loans
    ON loans_items.loan_id = loans.loan_id
    
    LEFT JOIN folio_derived.locations_libraries  
    ON loans_items.item_effective_location_id_at_check_out = locations_libraries.location_id

WHERE
    loans_items.loan_date >= (SELECT start_date FROM parameters)
    AND loans_items.loan_date < (SELECT end_date FROM parameters)
    AND (loans_items.material_type_name NOT LIKE 'BD%' AND loans_items.material_type_name NOT LIKE '%ILL%')
    AND (loans_items.patron_group_name LIKE 'Borrow%' OR loans_items.patron_group_name LIKE 'Inter%') 
   

GROUP BY
    TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
    locations_libraries.library_name,
    loans_items.patron_group_name,
    loans.fiscal_year_of_loan

        
ORDER BY
    loans_items.patron_group_name ASC
;
