WITH PARAMETERS AS (
SELECT
       /* Choose a start and end date for the loans period */
       '2021-07-01'::date AS start_date,
       '2022-07-01'::date AS end_date)
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
                        ELSE 'Regular' END AS collection_type
                        
                            



                
        FROM folio_reporting.loans_items AS li
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON li.item_effective_location_id_at_check_out = ll.location_id
        
        WHERE li.loan_date >=(SELECT start_date FROM parameters)  AND li.loan_date < (SELECT end_date FROM parameters)
      /*  and li.item_effective_location_name_at_check_out not ilike 'Borrow%'
        and li.item_effective_location_name_at_check_out not ilike 'Inter%'
        and li.patron_group_name not like 'SPEC%'*/
        ),

loans_final AS 
(SELECT 
        loans.library_name,
        loans.patron_group_name,
        loans.collection_type,
        count (loans.loan_id) AS total_loans
        

FROM loans 

GROUP BY 
        loans.library_name,
        loans.patron_group_name,
        loans.collection_type
       
),

renews as 
        (select 
                lrd.loan_id,
                cl.loan_date,
                lrd.loan_action_date,
                lrd.loan_action,
                lrd.loan_renewal_count::INT
                
        
        from folio_reporting.loans_renewal_dates lrd 
                left join circulation_loans as cl 
        on lrd.loan_id = cl.id
        
        where lrd.loan_action_date >=(SELECT start_date FROM parameters) and lrd.loan_action_date < (SELECT end_date FROM parameters)
        ),

renews2 as 
        (select 
                renews.loan_id,
                CASE WHEN renews.loan_date <'2021-07-01' THEN max (renews.loan_renewal_count::INT) - min (renews.loan_renewal_count::INT) + 1 
                        ELSE max (renews.loan_renewal_count::INT) END as number_of_renewals
                      
                        
        from renews
        
        group by renews.loan_id, renews.loan_date
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
li.patron_group_name, li.material_type_name, li.loan_policy_name, li.item_effective_location_name_at_check_out
),

renews_final AS 
(SELECT 
        renews3.library_name,
        renews3.patron_group_name,
        renews3.collection_type,
        SUM (renews3.number_of_renewals) AS total_renewals
        

FROM renews3 

GROUP BY 
        renews3.library_name,
        renews3.patron_group_name,
        renews3.collection_type
        
ORDER BY library_name, patron_group_name, collection_type
)

SELECT 
        renews_final.library_name,
        renews_final.patron_group_name,
        renews_final.collection_type,
        coalesce (loans_final.total_loans,0) as total_loans,
        coalesce (renews_final.total_renewals,0) as total_renewals
        

FROM renews_final 
left JOIN loans_final
        ON loans_final.library_name = renews_final.library_name 
                AND loans_final.patron_group_name = renews_final.patron_group_name 
                AND loans_final.collection_type = renews_final.collection_type
where (loans_final.total_loans > 0  or renews_final.total_renewals > 0)
;
