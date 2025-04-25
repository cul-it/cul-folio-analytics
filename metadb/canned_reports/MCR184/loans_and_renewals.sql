--MCR184
-- loans and renewals by fiscal year
--NOTE: 6/24/24: This query uses the loans_renewal_dates from local_static. Change to folio_derived once the derived table is fixed.
-- 4-25-25: updated to use the regular derived table (folio_derived.loans_renewal_dates) since that is now fixed in the Apr. 10 tag 

WITH PARAMETERS AS 
(SELECT
       /* Choose a start and end date in the format "yyyy-mm-dd" */
       '2024-07-01'::date AS start_date,
       '2025-07-01'::date AS end_date
),

loans AS 
(SELECT 
        concat ((SELECT start_date FROM parameters),' - ', (SELECT end_date FROM parameters)) AS date_range,
        locations_libraries.library_name,
        loans_items.loan_id,
        loans_items.patron_group_name,
        loans_items.material_type_name,
                        
        CASE
            WHEN loans_items.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
            WHEN loans_items.material_type_name = 'Laptop' THEN 'Laptop'
            WHEN loans_items.material_type_name IS NULL AND loans_items.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
            WHEN loans_items.material_type_name IS NULL AND loans_items.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
            WHEN loans_items.material_type_name ilike 'BD%' OR loans_items.item_effective_location_name_at_check_out ILIKE 'Borr%' THEN 'Borrow Direct'
            WHEN loans_items.material_type_name ilike 'ILL%' OR loans_items.item_effective_location_name_at_check_out ILIKE 'Inter%' THEN 'Interlibrary Loan'            
            WHEN loans_items.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'                                                                        
            WHEN loans_items.loan_policy_name LIKE '%hour%' THEN 'Reserve'
            WHEN loans_items.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'                  
            ELSE 'Regular' 
            END AS collection_type,
                        
         CASE 
                WHEN date_part ('month',loans_items.loan_date) > 6 THEN concat ('FY ', date_part ('year',loans_items.loan_date) + 1) 
            ELSE concat ('FY ', date_part ('year',loans_items.loan_date))
            END AS fiscal_year_of_checkout, 
            
        date_part ('month',loans_items.loan_date::DATE) as month_num_of_checkout,
        to_char (loans_items.loan_date::DATE,'Mon') as month_name_of_checkout,
        date_part ('year', loans_items.loan_date::DATE) as calendar_year_of_checkout
                
        FROM folio_derived.loans_items                  
                LEFT JOIN folio_derived.locations_libraries  
                ON folio_derived.loans_items.item_effective_location_id_at_check_out = folio_derived.locations_libraries.location_id
        
        WHERE loans_items.loan_date >= (SELECT start_date FROM parameters) AND loans_items.loan_date < (SELECT end_date FROM parameters)
),

loans2 as 
(SELECT 
        loans.date_range,
        loans.fiscal_year_of_checkout,
        loans.month_num_of_checkout,
        loans.month_name_of_checkout,
        loans.calendar_year_of_checkout,
        loans.library_name,       
        loans.patron_group_name,
        loans.material_type_name,
        loans.collection_type,
        count (loans.loan_id) AS total_loans 
               
      
FROM loans 

GROUP BY 
        loans.date_range,
        loans.month_num_of_checkout,
        loans.month_name_of_checkout,
        loans.calendar_year_of_checkout,
        loans.library_name,
        loans.fiscal_year_of_checkout,
        loans.patron_group_name,
        loans.material_type_name,
        loans.collection_type
        
ORDER BY library_name, patron_group_name, material_type_name, collection_type
), 

renews AS

(SELECT distinct
        loans_renewal_dates.loan_id::uuid,
        folio_circulation.loan__t.loan_date::date,
        to_char (loans_renewal_dates.renewal_date::timestamptz,'mm/dd/yyyy hh:mi am') as renewal_date,
        date_part ('month',loans_renewal_dates.renewal_date::DATE) as month_num_of_renewal,
    	to_char (loans_renewal_dates.renewal_date::DATE,'Mon') as month_name_of_renewal,
    	date_part ('year', loans_renewal_dates.renewal_date::DATE) as calendar_year_of_renewal,
        CASE
                WHEN date_part ('month', loans_renewal_dates.renewal_date::date) > 6 THEN concat ('FY ', date_part ('year', loans_renewal_dates.renewal_date::date) + 1)
                ELSE concat ('FY ',date_part ('year',loans_renewal_dates.renewal_date::date))
                END AS fiscal_year_of_renewal
                
FROM
       local_derived.loans_renewal_dates
       LEFT JOIN folio_circulation.loan__t  
       --the loan_id in the derived table needs to be cast as uuid
       ON folio_circulation.loan__t.id = loans_renewal_dates.loan_id::uuid
        
WHERE
     	loans_renewal_dates.renewal_date::date >= (SELECT start_date FROM parameters)::date
      	AND loans_renewal_dates.renewal_date::date < (SELECT end_date FROM parameters)::date

        
GROUP BY
      loans_renewal_dates.loan_id,
      loans_renewal_dates.renewal_date,
      folio_circulation.loan__t.loan_date::date
),

renews2 AS 

(SELECT distinct
        renews.loan_id,
        renews.fiscal_year_of_renewal,
        renews.month_num_of_renewal,
        renews.month_name_of_renewal,
        renews.calendar_year_of_renewal,
        count (renews.renewal_date::date) AS renewal_count
FROM
        renews
GROUP BY
        renews.loan_id,
        renews.fiscal_year_of_renewal,
        renews.month_num_of_renewal,
        renews.month_name_of_renewal,
        renews.calendar_year_of_renewal
ORDER BY
        renews.loan_id
),

renews3 AS 
(SELECT 
        concat ((SELECT start_date FROM parameters),' - ', (SELECT end_date FROM parameters)) AS date_range,
        renews2.fiscal_year_of_renewal,
        renews2.month_num_of_renewal,
        renews2.month_name_of_renewal,
        renews2.calendar_year_of_renewal,
        renews2.renewal_count,
        locations_libraries.library_name, 
        loans_items.patron_group_name,
        loans_items.material_type_name,
        CASE
                WHEN loans_items.material_type_name IN ('Peripherals', 'Supplies', 'Umbrella', 'Locker Keys', 'Carrel Keys', 'Room Keys', 'Equipment') THEN 'Equipment'
                WHEN loans_items.material_type_name = 'Laptop' THEN 'Laptop'
                WHEN loans_items.material_type_name IS NULL AND loans_items.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
                WHEN loans_items.material_type_name IS NULL AND loans_items.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
                WHEN loans_items.material_type_name ilike 'BD%' OR loans_items.item_effective_location_name_at_check_out ILIKE 'Borr%' THEN 'Borrow Direct'
                WHEN loans_items.material_type_name ilike 'ILL%' OR loans_items.item_effective_location_name_at_check_out ILIKE 'Inter%' THEN 'Interlibrary Loan'
                WHEN loans_items.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'
                WHEN loans_items.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                WHEN loans_items.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'
                ELSE 'Regular'
                END AS collection_type        
        
        FROM renews2
                LEFT JOIN folio_derived.loans_items 
            ON renews2.loan_id = folio_derived.loans_items.loan_id            
                LEFT JOIN folio_derived.locations_libraries 
            ON loans_items.item_effective_location_id_at_check_out = folio_derived.locations_libraries.location_id
),

renews4 as 
(SELECT
        renews3.date_range,
        renews3.fiscal_year_of_renewal,
        renews3.month_num_of_renewal,
        renews3.month_name_of_renewal,
        renews3.calendar_year_of_renewal,
        renews3.library_name,
        renews3.patron_group_name,
        renews3.material_type_name,
        renews3.collection_type,
        SUM (renews3.renewal_count) AS total_renewals
        
FROM renews3
        
GROUP BY
        renews3.date_range,
        renews3.fiscal_year_of_renewal,
        renews3.month_num_of_renewal,
        renews3.month_name_of_renewal,
        renews3.calendar_year_of_renewal,
        renews3.library_name,
        renews3.patron_group_name,
        renews3.material_type_name,
        renews3.collection_type

ORDER BY
        library_name, patron_group_name, material_type_name, collection_type
)

select 
        Current_date AS todays_date,
        case when loans2.date_range is null then renews4.date_range else loans2.date_range end as date_range,        
        case when loans2.month_name_of_checkout is null then renews4.month_name_of_renewal else loans2.month_name_of_checkout end as month_name,
        case when loans2.month_num_of_checkout is null then renews4.month_num_of_renewal else loans2.month_num_of_checkout end as month_num,
        case when loans2.calendar_year_of_checkout::VARCHAR is null then renews4.calendar_year_of_renewal::varchar else 	loans2.calendar_year_of_checkout::varchar end as calendar_year,
        case when loans2.fiscal_year_of_checkout is null then renews4.fiscal_year_of_renewal else loans2.fiscal_year_of_checkout end as fiscal_year,
        case when loans2.library_name is null then renews4.library_name else loans2.library_name end as library_name,       
        case when loans2.patron_group_name is null then renews4.patron_group_name else loans2.patron_group_name end as patron_group_name,
        case when loans2.material_type_name is null then renews4.material_type_name else loans2.material_type_name end as material_type_name,
        case when loans2.collection_type is null then renews4.collection_type else loans2.collection_type end as collection_type,
        case when loans2.total_loans is null then 0 else loans2.total_loans end as total_loans,
        CASE WHEN renews4.total_renewals IS NULL THEN 0 ELSE renews4.total_renewals END as total_renewals
        
from loans2
        full outer join renews4
        on loans2.library_name = renews4.library_name
                and loans2.patron_group_name = renews4.patron_group_name
                and loans2.material_type_name = renews4.material_type_name
                and loans2.collection_type = renews4.collection_type
                and loans2.fiscal_year_of_checkout = renews4.fiscal_year_of_renewal
                and loans2.month_num_of_checkout = renews4.month_num_of_renewal
                and loans2.month_name_of_checkout = renews4.month_name_of_renewal
                and loans2.calendar_year_of_checkout = renews4.calendar_year_of_renewal

order by fiscal_year, calendar_year, month_num, library_name, patron_group_name, material_type_name, collection_type
; 
