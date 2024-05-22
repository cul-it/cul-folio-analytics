--MCR 108
--Services_Usage
--This query provides the number of circulation transactions by service-point and transaction type, with time aggregated to date, day of week, and hour of day.
--Ported by Linda Miller (lm15)
--Query reviewers: Joanne Leary (jl41), Vandana Shah (vp25)
--Query posted on 5/22/24

WITH parameters AS (
    SELECT
        '2023-07-01'::date AS start_date, 
        '2024-07-01'::date AS end_date
),

checkout_actions AS (
    SELECT
    loans_items.checkout_service_point_name AS service_point_name,
    loans_items.loan_date::date AS action_date,
    to_char(loans_items.loan_date, 'Day') AS day_of_week,
    extract(hours FROM loans_items.loan_date) AS hour_of_day,
    loans_items.material_type_name,
    'Checkout'::varchar AS action_type,
    loans_items.item_effective_location_name_at_check_out,
    loans_items.item_status,
    count(DISTINCT loans_items.loan_id) AS ct 
FROM
    folio_derived.loans_items 
    WHERE
        loans_items.loan_date >= (
            SELECT
                start_date
            FROM
                parameters)
            AND loans_items.loan_date < (
                SELECT
                    end_date
                FROM
                    parameters)
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
        coalesce(loans_items.system_return_date::timestamptz at time zone 'UTC', loans_items.loan_return_date::timestamptz at time zone 'UTC') AS action_date,
        loans_items.material_type_name,
        'Checkin'::varchar AS action_type,
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
    to_char(action_date, 'Day') AS day_of_week,
    extract(hours FROM simple_return_dates.action_date) AS hour_of_day,
    simple_return_dates.material_type_name,
    simple_return_dates.action_type,
    simple_return_dates.item_effective_location_name_at_check_out,
    simple_return_dates.item_status,
    count(DISTINCT simple_return_dates.loan_id) AS ct 
       
    FROM simple_return_dates
    WHERE
        simple_return_dates.action_date >= (
            SELECT
                start_date
            FROM
                parameters)
            AND simple_return_dates.action_date < (
                SELECT
                    end_date
                FROM
                    parameters)
            GROUP BY
                simple_return_dates.service_point_name,
                action_date,
                day_of_week,
                hour_of_day,
                material_type_name,
                action_type,
                item_effective_location_name_at_check_out,
                item_status
)

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
    ORDER BY
        service_point_name,
        action_date,
        day_of_week,
        hour_of_day,
        material_type_name,
        action_type,
        item_effective_location_name_at_check_out,
        item_status;
