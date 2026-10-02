--MCR427
--mann_laptop_checkin_checkout.sql
--last updated: 10/2/26
--adapted from MCR108 by Sharon Markus
--This query captures laptop checkins and checkouts at Mann Library service points for the last 24 hours 
--within specific time ranges, specifically from 7am to 3pm and from 3pm to 9pm
--The total_date_count is the sum of all counts for the date (all hours).
--The 7amto3pm_count is the sum for hours 9–14 (inclusive of 9, exclusive of 15).
--The 3pmto9pm_count is the sum for hours 15–24 (inclusive of 15, exclusive of 24).
--9/21/26: Added barcode
--10/2/26: updated time ranges for checkouts and restricted results to checkouts within the last 24 hours

WITH
checkout_actions AS (
    SELECT
        service_point__t.name AS service_point_name,
        loans_items.loan_date::date AS action_date,
        to_char(loans_items.loan_date, 'FMDay') AS day_of_week,
        CAST(extract(hour FROM loans_items.loan_date) AS integer) AS hour_of_day,
        loans_items.material_type_name,
        'Checkout' AS action_type,
        loans_items.item_effective_location_name_at_check_out,
        loans_items.item_status,
        count(DISTINCT loans_items.loan_id) AS ct 
    FROM
        folio_derived.loans_items 
        LEFT JOIN folio_inventory.service_point__t 
            ON loans_items.checkout_service_point_id = service_point__t.id
    WHERE
        loans_items.loan_date >= NOW() - INTERVAL '24 hours'
    GROUP BY
        service_point_name,
        action_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        item_effective_location_name_at_check_out,
        item_status
),
simple_return_dates AS (
    SELECT
        loans_items.checkin_service_point_name AS service_point_name,
        coalesce(
            loans_items.system_return_date::timestamptz AT TIME ZONE 'UTC', 
            loans_items.loan_return_date::timestamptz AT TIME ZONE 'UTC'
        ) AS action_date,
        loans_items.material_type_name,
        'Checkin' AS action_type,
        loans_items.item_effective_location_name_at_check_out,
        loans_items.item_status,
        loans_items.loan_id
    FROM
        folio_derived.loans_items  
),
checkin_actions AS (
    SELECT
        simple_return_dates.service_point_name,
        simple_return_dates.action_date::date AS action_date,
        to_char(simple_return_dates.action_date, 'FMDay') AS day_of_week,
        CAST(extract(hour FROM simple_return_dates.action_date) AS integer) AS hour_of_day,
        simple_return_dates.material_type_name,
        simple_return_dates.action_type,
        simple_return_dates.item_effective_location_name_at_check_out,
        simple_return_dates.item_status,
        count(DISTINCT simple_return_dates.loan_id) AS ct 
    FROM simple_return_dates
    WHERE
        simple_return_dates.action_date >= NOW() - INTERVAL '24 hours'
    GROUP BY
        simple_return_dates.service_point_name,
        action_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        action_type,
        item_effective_location_name_at_check_out,
        item_status
),
combined AS (
    SELECT
        service_point_name,
        action_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        action_type,
        item_effective_location_name_at_check_out,
        item_status,
        ct
    FROM
        checkout_actions
    UNION ALL
    SELECT
        service_point_name,
        action_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        action_type,
        item_effective_location_name_at_check_out,
        item_status,
        ct
    FROM
        checkin_actions
)
SELECT
    service_point_name,
    action_date,
    day_of_week,
    material_type_name,
    action_type,
    item_effective_location_name_at_check_out,
    item_status,
    SUM(ct) AS total_date_count,
    SUM(CASE WHEN hour_of_day >= 7 AND hour_of_day < 15 THEN ct ELSE 0 END) AS "7amto3pm_count",
    SUM(CASE WHEN hour_of_day >= 15 AND hour_of_day < 24 THEN ct ELSE 0 END) AS "3pmto12am_count"
FROM
    combined
WHERE
    service_point_name LIKE '%Mann%'
    AND material_type_name ILIKE 'Laptop'
GROUP BY
    service_point_name,
    action_date,
    day_of_week,
    material_type_name,
    action_type,
    item_effective_location_name_at_check_out,
    item_status
ORDER BY
    service_point_name,
    action_date,
    day_of_week,
    material_type_name,
    action_type,
    item_effective_location_name_at_check_out,
    item_status;

