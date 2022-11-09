-- CR184A: physical collections use
-- This query counts loans and renewals by date range, owning library, patron group, material type and collection type.
 
WITH PARAMETERS AS
(SELECT
       /* Choose a start and end date in the format "yyyy-mm-dd" */
       '2022-07-01'::date AS start_date,
       '2023-07-01'::date AS end_date
),
 
loans AS
(SELECT
        concat ((SELECT start_date FROM parameters),' - ', (SELECT end_date FROM parameters)) AS date_range,
        ll.library_name,
        li.loan_id,
        li.patron_group_name,
        li.material_type_name,
                       
        CASE
            WHEN li.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
            WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
            WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
            WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
            WHEN (li.material_type_name ilike 'BD%' or li.material_type_name ilike 'ILL%' or li.item_effective_location_name_at_check_out ILIKE 'Borr%'
                OR li.item_effective_location_name_at_check_out ILIKE 'Inter%') then 'ILLBD'
            WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'                                                                        
            WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
            WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'                 
            ELSE 'Regular'
            END AS collection_type,
                       
         CASE
                WHEN date_part ('month',li.loan_date) >'6' THEN concat ('FY ', date_part ('year',li.loan_date) + 1)
            ELSE concat ('FY ', date_part ('year',li.loan_date))
            END AS fiscal_year_of_checkout 
                
        FROM folio_reporting.loans_items AS li
                LEFT JOIN folio_reporting.locations_libraries AS ll
                ON li.item_effective_location_id_at_check_out = ll.location_id
       
        WHERE li.loan_date >= (SELECT start_date FROM parameters) AND li.loan_date < (SELECT end_date FROM parameters)
),
 
loans2 as
(SELECT
        loans.date_range,
        loans.fiscal_year_of_checkout,
        loans.library_name,      
        loans.patron_group_name,
        loans.material_type_name,
        loans.collection_type,
        count (loans.loan_id) AS total_loans
                     
FROM loans
 
GROUP BY
        loans.date_range,
        loans.library_name,
        loans.fiscal_year_of_checkout,
        loans.patron_group_name,
        loans.material_type_name,
        loans.collection_type
       
ORDER BY library_name, patron_group_name, material_type_name, collection_type
),
 
renews AS
 
(SELECT
        lrd.loan_id,
        cl.loan_date::date,
        lrd.loan_action_date::date,
        CASE
                WHEN date_part ('month', lrd.loan_action_date::date) >'6' THEN concat ('FY ', date_part ('year',lrd.loan_action_date::date) + 1)
                ELSE concat ('FY ',date_part ('year',lrd.loan_action_date::date))
                END AS fiscal_year_of_renewal
        FROM
                folio_reporting.loans_renewal_dates lrd
                LEFT JOIN circulation_loans AS cl
                ON cl.id = lrd.loan_id
       
        WHERE
                lrd.loan_action_date::date >= (SELECT start_date FROM parameters)::date
                AND lrd.loan_action_date::date < (SELECT end_date FROM parameters)::date
       
        GROUP BY
                lrd.loan_id,
                lrd.loan_action_date::date,
                cl.loan_date::date
),
 
renews2 AS
 
(SELECT distinct
        renews.loan_id,
        renews.fiscal_year_of_renewal,
        count (renews.loan_action_date::date) AS renewal_count
FROM
        renews
GROUP BY
        renews.loan_id,
        renews.fiscal_year_of_renewal
ORDER BY
        renews.loan_id
),
 
renews3 AS
(SELECT
        concat ((SELECT start_date FROM parameters),' - ', (SELECT end_date FROM parameters)) AS date_range,
        renews2.fiscal_year_of_renewal,
        ll.library_name,
        li.patron_group_name,
        li.material_type_name,
        CASE
                WHEN li.material_type_name IN ('Peripherals', 'Supplies', 'Umbrella', 'Locker Keys', 'Carrel Keys', 'Room Keys', 'Equipment') THEN 'Equipment'
                WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
                WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
                WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
                WHEN (li.material_type_name ILIKE 'BD%' OR li.material_type_name ILIKE 'ILL*%') THEN 'ILLBD'
                WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'
                WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'
                ELSE 'Regular'
                END AS collection_type,
        renews2.renewal_count
       
        FROM renews2
        LEFT JOIN folio_reporting.loans_items AS li
        ON renews2.loan_id = li.loan_id
           
        LEFT JOIN folio_reporting.locations_libraries AS ll
        ON li.item_effective_location_id_at_check_out = ll.location_id
),
 
renews4 as
(SELECT
        renews3.date_range,
        renews3.fiscal_year_of_renewal,
        renews3.library_name,
        renews3.patron_group_name,
        renews3.material_type_name,
        renews3.collection_type,
        SUM (renews3.renewal_count) AS total_renewals
       
FROM renews3
       
GROUP BY
        renews3.date_range,
        renews3.fiscal_year_of_renewal,
        renews3.library_name,
        renews3.patron_group_name,
        renews3.material_type_name,
        renews3.collection_type
 
ORDER BY
        library_name, patron_group_name, material_type_name, collection_type
)
 
select
        loans2.date_range,
        loans2.fiscal_year_of_checkout as fiscal_year,
        loans2.library_name,      
        loans2.patron_group_name,
        loans2.material_type_name,
        loans2.collection_type,
        loans2.total_loans,
        CASE WHEN renews4.total_renewals IS NULL THEN 0 ELSE renews4.total_renewals END as total_renewals
       
from loans2
        full outer join renews4
        on loans2.library_name = renews4.library_name
                and loans2.patron_group_name = renews4.patron_group_name
                and loans2.material_type_name = renews4.material_type_name
                and loans2.collection_type = renews4.collection_type
 
order by loans2.library_name, loans2.patron_group_name, loans2.material_type_name, loans2.collection_type
;
 
