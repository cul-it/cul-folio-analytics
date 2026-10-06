--MCR427
--mann_laptop_checkin_checkout.sql
--last updated: 10/2/26 (10-3-26 JL)
--adapted from MCR108 by Sharon Markus
--This query captures laptop checkins and checkouts at Mann Library service points for the last 24 hours
--within specific time ranges, specifically from 7am to 3pm and from 3pm to 9pm
--The total_date_count is the sum of all counts for the date (all hours).
--The 7amto3pm_count is the sum for hours 9–14 (inclusive of 9, exclusive of 15).
--The 3pmto9pm_count is the sum for hours 15–24 (inclusive of 15, exclusive of 24).
--9/21/26: Added barcode
--10/2/26: updated time ranges for checkouts and restricted results to checkouts within the last 24 hours
--10/3/26: JL: re-wrote using primary tables to get up-to-the-moment data;
                -- re-named "action_type" to transction_type, "action_date" to transaction_date, "item_status" to "current_item_status" and "total_date_count" to "count_of_transactions_in_24_hours"
                -- resequenced fields to display in an easier to understand order
 
WITH
checkout_actions AS (
    SELECT
        service_point__t.name AS service_point_name,
        (loan__t.loan_date::timestamptz)::date AS transaction_date,--loans_items.loan_date::date AS action_date,
        to_char (loan__t.loan_date::timestamptz, 'FMDay') AS day_of_week, --to_char(loans_items.loan_date, 'FMDay') AS day_of_week,
        CAST (EXTRACT (hour FROM loan__t.loan_date::timestamptz) AS integer) AS hour_of_day,--CAST(extract(hour FROM loans_items.loan_date) AS integer) AS hour_of_day,
        material_type__t.name AS material_type_name,--loans_items.material_type_name,
        'Checkout' AS transaction_type,
        location__t.name AS item_effective_location_name_at_check_out,--loans_items.item_effective_location_name_at_check_out,
        item.jsonb#>>'{status,name}' AS item_status,--loans_items.item_status,
        COUNT (DISTINCT loan__t.id) AS ct --COUNT(DISTINCT loans_items.loan_id) AS ct
    FROM
        folio_circulation.loan__t
        LEFT JOIN folio_inventory.service_point__t
        ON loan__t.checkout_service_point_id = service_point__t.id --loans_items.checkout_service_point_id = service_point__t.id
               
        LEFT JOIN folio_inventory.item__t
                ON loan__t.item_id = item__t.id
               
                LEFT JOIN folio_inventory.item
                ON item__t.id = item.id
               
                LEFT JOIN folio_inventory.material_type__t
                ON item__t.material_type_id = material_type__t.id
               
                LEFT JOIN folio_inventory.location__t
                ON loan__t.item_effective_location_id_at_check_out = location__t.id
           
    WHERE
        loan__t.loan_date::timestamptz >= now() - interval '24 hours' --loans_items.loan_date >= NOW() - INTERVAL '24 hours'
    GROUP by
                service_point__t.name,
        (loan__t.loan_date::timestamptz)::date,--loans_items.loan_date::date AS action_date,
        to_char (loan__t.loan_date::timestamptz, 'FMDay'), --to_char(loans_items.loan_date, 'FMDay') AS day_of_week,
        CAST (EXTRACT (hour FROM loan__t.loan_date::timestamptz) AS integer),--CAST(extract(hour FROM loans_items.loan_date) AS integer) AS hour_of_day,
        material_type__t.name,--loans_items.material_type_name,
        location__t.name,--loans_items.item_effective_location_name_at_check_out,
        item.jsonb#>>'{status,name}'
),
simple_return_dates AS (
    SELECT
        service_point__t.name AS service_point_name,--loans_items.checkin_service_point_name AS service_point_name,
        COALESCE (
            loan__t.system_return_date::timestamptz AT TIME ZONE 'UTC',--loans_items.system_return_date::timestamptz AT TIME ZONE 'UTC',
            loan__t.return_date::timestamptz AT TIME ZONE 'UTC'--loans_items.loan_return_date::timestamptz AT TIME ZONE 'UTC'
        ) AS transaction_date,
        material_type__t.name AS material_type_name,--loans_items.material_type_name,
        'Checkin' AS transaction_type,
        location__t.name AS item_effective_location_name_at_check_out,--loans_items.item_effective_location_name_at_check_out,
        item.jsonb#>>'{status,name}' AS item_status,--loans_items.item_status,
        loan__t.id AS loan_id -- loans_items.loan_id
       
    FROM        
        folio_circulation.loan__t 
        LEFT JOIN folio_inventory.service_point__t
        ON loan__t.checkout_service_point_id = service_point__t.id --loans_items.checkout_service_point_id = service_point__t.id
               
        LEFT JOIN folio_inventory.item__t
                ON loan__t.item_id = item__t.id
               
                LEFT JOIN folio_inventory.item
                ON item__t.id = item.id
               
                LEFT JOIN folio_inventory.material_type__t
                ON item__t.material_type_id = material_type__t.id
               
                LEFT JOIN folio_inventory.location__t
                ON loan__t.item_effective_location_id_at_check_out = location__t.id
            
),
checkin_actions AS (
    SELECT
        simple_return_dates.service_point_name,
        simple_return_dates.transaction_date::date AS transaction_date,
        to_char(simple_return_dates.transaction_date, 'FMDay') AS day_of_week,
        CAST(extract(hour FROM simple_return_dates.transaction_date) AS integer) AS hour_of_day,
        simple_return_dates.material_type_name,
        simple_return_dates.transaction_type,
        simple_return_dates.item_effective_location_name_at_check_out,
        simple_return_dates.item_status,
        COUNT(DISTINCT simple_return_dates.loan_id) AS ct
    FROM simple_return_dates
    WHERE
        simple_return_dates.transaction_date >= NOW() - INTERVAL '24 hours'
    GROUP BY
        simple_return_dates.service_point_name,
        transaction_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        transaction_type,
        item_effective_location_name_at_check_out,
        item_status
),
combined AS (
    SELECT
        service_point_name,
        transaction_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        transaction_type,
        item_effective_location_name_at_check_out,
       item_status,
        ct
    FROM
        checkout_actions
    UNION ALL
    SELECT
        service_point_name,
        transaction_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        transaction_type,
        item_effective_location_name_at_check_out,
        item_status,
        ct
    FROM
        checkin_actions
)
SELECT
    to_char(NOW(), 'MM-DD-YYYY HH12:MI AM') AS "report generated",
    service_point_name,
    material_type_name,
    transaction_type,
    transaction_date,
    day_of_week,   
    item_effective_location_name_at_check_out,
    item_status as current_item_status, -- item_status
    SUM(ct) AS count_of_transactions_in_24_hours --total_date_count
FROM
    combined
WHERE
    service_point_name LIKE '%Mann%'
    AND
    material_type_name ILIKE 'Laptop'
GROUP BY
    service_point_name,
    material_type_name,
    transaction_type,
    transaction_date,
    day_of_week,
    item_effective_location_name_at_check_out,
    item_status
ORDER BY
    service_point_name,
    material_type_name,
    transaction_type,
    transaction_date,
    day_of_week,
    item_effective_location_name_at_check_out,
    item_status
    ;



