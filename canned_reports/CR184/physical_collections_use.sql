WITH PARAMETERS AS (
SELECT
       /* Choose a start and end date for the loans period */
       '2021-07-01'::date AS start_date,
       '2022-07-01'::date AS end_date)
   ,

loans AS 
(
SELECT
       ll.library_name,
       li.loan_id,
       li.patron_group_name,
       CASE
              WHEN li.material_type_name IN ('Peripherals', 'Supplies', 'Umbrella', 'Locker Keys', 'Carrel Keys', 'Room Keys', 'Equipment') THEN 'Equipment'
              WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
              WHEN li.material_type_name IS NULL
              AND li.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
              WHEN li.material_type_name IS NULL
              AND li.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
              WHEN (li.material_type_name ILIKE 'BD%'
              OR li.material_type_name ILIKE 'ILL*%') THEN 'ILLBD'
              WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'
              WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
              WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'
              ELSE 'Regular'
       END AS collection_type
FROM
       folio_reporting.loans_items AS li
LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON
       li.item_effective_location_id_at_check_out = ll.location_id
WHERE
       li.loan_date >= (
       SELECT
              start_date
       FROM
              parameters)
       AND li.loan_date < (
       SELECT
              end_date
       FROM
              parameters)
        ),

loans_final AS 
(
SELECT
       loans.library_name,
       loans.patron_group_name,
       loans.collection_type,
       count (loans.loan_id) AS total_loans
FROM
       loans
GROUP BY
       loans.library_name,
       loans.patron_group_name,
       loans.collection_type
),

renews AS 
        (
SELECT
       lrd.loan_id,
       cl.loan_date,
       lrd.loan_action_date,
       lrd.loan_action,
       lrd.loan_renewal_count::INT
FROM
       folio_reporting.loans_renewal_dates lrd
LEFT JOIN circulation_loans AS cl 
        ON
       lrd.loan_id = cl.id
WHERE
       lrd.loan_action_date >= (
       SELECT
              start_date
       FROM
              parameters)
       AND lrd.loan_action_date < (
       SELECT
              end_date
       FROM
              parameters)
        ),

renews2 AS 
        (
SELECT
       renews.loan_id,
       CASE
              WHEN renews.loan_date <'2021-07-01' THEN max (renews.loan_renewal_count::INT) - min (renews.loan_renewal_count::INT) + 1
              ELSE max (renews.loan_renewal_count::INT)
       END AS total_number_of_renewals
FROM
       renews
GROUP BY
       renews.loan_id,
       renews.loan_date
),


renews3 AS 
(
SELECT
       ll.library_name,
       li.patron_group_name,
       CASE
              WHEN li.material_type_name IN ('Peripherals', 'Supplies', 'Umbrella', 'Locker Keys', 'Carrel Keys', 'Room Keys', 'Equipment') THEN 'Equipment'
              WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
              WHEN li.material_type_name IS NULL
                     AND li.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
                     WHEN li.material_type_name IS NULL
                     AND li.loan_policy_name LIKE '2 hour%' THEN 'Reserve'
                     WHEN (li.material_type_name ILIKE 'BD%'
                           OR li.material_type_name ILIKE 'ILL*%') THEN 'ILLBD'
                     WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'
                     WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                     WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'
                     ELSE 'Regular'
              END AS collection_type,
              renews2.loan_id,
              renews2.total_number_of_renewals
       FROM
              folio_reporting.loans_items AS li
       LEFT JOIN renews2
        ON
              li.loan_id = renews2.loan_id
       LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON
              li.item_effective_location_id_at_check_out = ll.location_id
       GROUP BY
              renews2.loan_id,
              renews2.total_number_of_renewals,
              ll.library_name,
              li.patron_group_name,
              li.material_type_name,
              li.loan_policy_name,
              li.item_effective_location_name_at_check_out  
),

renews_final AS 
(
SELECT
       renews3.library_name,
       renews3.patron_group_name,
       renews3.collection_type,
       SUM (renews3.total_number_of_renewals) AS total_renewals
FROM
       renews3
GROUP BY
       renews3.library_name,
       renews3.patron_group_name,
       renews3.collection_type
ORDER BY
       library_name,
       patron_group_name,
       collection_type
)

SELECT
       renews_final.library_name,
       renews_final.patron_group_name,
       renews_final.collection_type,
       COALESCE (loans_final.total_loans,
       0) AS total_loans,
       COALESCE (renews_final.total_renewals,
       0) AS total_renewals
FROM
       renews_final
LEFT JOIN loans_final
        ON
       loans_final.library_name = renews_final.library_name
       AND loans_final.patron_group_name = renews_final.patron_group_name
       AND loans_final.collection_type = renews_final.collection_type
WHERE
       (loans_final.total_loans > 0
              OR renews_final.total_renewals > 0)
	      ;
