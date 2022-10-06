--QUERY 1: LOANS ONLY
WITH PARAMETERS AS (
SELECT
       /* Choose a start and end date for the loans period */
       '2021-07-01'::date AS start_date,
       '2023-07-01'::date AS end_date)
   ,

loans AS 
(SELECT 
        ll.library_name,
        li.loan_id,
        li.patron_group_name,
                        
               CASE
                        WHEN li.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
                        WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
                        WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
                        WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
                        WHEN (li.material_type_name ilike 'BD%' or li.material_type_name ilike 'ILL*%' or li.item_effective_location_name_at_check_out ILIKE 'Borr%'
                        or li.item_effective_location_name_at_check_out ILIKE 'Inter%') then 'ILLBD'
                        WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'                                                                        
                        WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                        WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'                  
                        ELSE 'Regular' END AS collection_type,
                        
                 CASE WHEN
                date_part ('month',li.loan_date) >'6' 
                THEN concat ('FY ', date_part ('year',li.loan_date) + 1) 
                ELSE concat ('FY ', date_part ('year',li.loan_date))
                END as fiscal_year_of_checkout  

                
        FROM folio_reporting.loans_items AS li
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON li.item_effective_location_id_at_check_out = ll.location_id
        
        WHERE li.loan_date >=(SELECT start_date FROM parameters)  AND li.loan_date < (SELECT end_date FROM parameters)
      /*  and li.item_effective_location_name_at_check_out not ilike 'Borrow%'
        and li.item_effective_location_name_at_check_out not ilike 'Inter%'
        and li.patron_group_name not like 'SPEC%'*/
        )

SELECT 
        loans.library_name,
        loans.patron_group_name,
        loans.collection_type,
        count (loans.loan_id) AS total_loans, 
        loans.fiscal_year_of_checkout       
      

FROM loans 

GROUP BY 
        loans.library_name,
        loans.patron_group_name,
        loans.collection_type,
        loans.fiscal_year_of_checkout;  
        
  --QUERY 2: RENEWALS ONLY
  WITH PARAMETERS AS (
SELECT
       /* Choose a start and end date for the loans period */
       '2021-07-01'::date AS start_date,
       '2023-07-01'::date AS end_date)
   ,

renews as 
        (select 
                lrd.loan_id,
                cl.loan_date,
                lrd.loan_action_date,
                lrd.loan_action,
                lrd.loan_renewal_count::INT,
                  CASE WHEN
                date_part ('month',lrd.loan_action_date) >'6' 
                THEN concat ('FY ', date_part ('year',lrd.loan_action_date) + 1) 
                ELSE concat ('FY ', date_part ('year',lrd.loan_action_date))
                END as fiscal_year_of_renewal  
                
        
        from folio_reporting.loans_renewal_dates lrd 
                left join circulation_loans as cl 
        on lrd.loan_id = cl.id
        
        where lrd.loan_action_date >=(SELECT start_date FROM parameters) and lrd.loan_action_date < (SELECT end_date FROM parameters)
        ),

renews2 as 
        (select 
                renews.loan_id,
                CASE WHEN renews.loan_date <'2021-07-01' THEN max (renews.loan_renewal_count::INT) - min (renews.loan_renewal_count::INT) + 1 
                        ELSE max (renews.loan_renewal_count::INT) END as number_of_renewals,
                        renews.fiscal_year_of_renewal  
                    
                        
        from renews
        
        group by renews.loan_id, renews.loan_date,  renews.fiscal_year_of_renewal  
),

renews3 AS 
(SELECT 
        ll.library_name,
        li.patron_group_name,
                        
                CASE
                        WHEN li.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
                        WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
                        WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '3 hour%' then 'Equipment'
                        WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
                        WHEN (li.material_type_name ilike 'BD%' or li.material_type_name ilike 'ILL*%' or li.item_effective_location_name_at_check_out ILIKE 'Borr%'
                        or li.item_effective_location_name_at_check_out ILIKE 'Inter%') then 'ILLBD'
                        WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' then 'Reserve'                                                                        
                        WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                        WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve' 
                        ELSE 'Regular' END as collection_type,
                       
                                 
               
          renews2.fiscal_year_of_renewal,                
        renews2.loan_id,
        renews2.number_of_renewals
        

FROM folio_reporting.loans_items as li 
        LEFT JOIN renews2
        ON li.loan_id = renews2.loan_id
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON li.item_effective_location_id_at_check_out = ll.location_id
        
/*WHERE 
        li.item_effective_location_name_at_check_out not ilike 'Borrow%'
        and li.item_effective_location_name_at_check_out not ilike 'Inter%'
        and li.patron_group_name not like 'SPEC%'*/
        
GROUP BY renews2.loan_id, renews2.number_of_renewals, ll.library_name, 
li.patron_group_name, li.material_type_name, li.loan_policy_name, li.item_effective_location_name_at_check_out,  renews2.fiscal_year_of_renewal  
),

renews_final AS 
(SELECT 
        renews3.library_name,
        renews3.patron_group_name,
        renews3.collection_type,
        SUM (renews3.number_of_renewals) AS total_renewals,
        renews3.fiscal_year_of_renewal  
        

FROM renews3 

GROUP BY 
        renews3.library_name,
        renews3.patron_group_name,
        renews3.collection_type,
        renews3.fiscal_year_of_renewal  
        
ORDER BY library_name, patron_group_name, collection_type, renews3.fiscal_year_of_renewal  
)

SELECT 
        renews_final.library_name,
        renews_final.patron_group_name,
        renews_final.collection_type,
        coalesce (renews_final.total_renewals,0) as total_renewals,
        renews_final.fiscal_year_of_renewal  
        

FROM renews_final 

where renews_final.total_renewals > 0
;
