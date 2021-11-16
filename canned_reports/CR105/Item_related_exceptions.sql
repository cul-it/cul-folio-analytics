FILTERS FOR USERS TO SELECT 
start and end dates, actions. */

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the request period */
       '2021-10-01'::date AS start_date,
       '2021-11-01'::date AS end_date, 
       ''::varchar AS action_service_point_name_filter, --Fill in a service point name, or leave blank */
        /* Fill in 1-4 action names, or leave all blank for all actions */
        'Claimed returned'::varchar AS action_filter1, -- see list of actions in README documentation 
        ''::varchar AS action_filter2, -- other action to also include
        ''::varchar AS action_filter3, -- other action to also include
        ''::varchar AS action_filter4 -- other action to also include
),
service_points AS (
    SELECT
        service_point_id,
        service_point_name
           FROM folio_reporting.locations_service_points
   GROUP BY
        service_point_id,
       service_point_name
    ),
items_array AS (
    SELECT
        ac.id AS log_id,
        json_extract_path_text(items.data, 'itemId') AS item_id,
        json_extract_path_text(items.data, 'loanId') AS loan_id,
        json_extract_path_text(items.data, 'itemBarcode') AS item_barcode
    FROM
        public.audit_circulation_logs AS ac
        CROSS JOIN json_array_elements(json_extract_path(data, 'items')) AS items (data)
)
SELECT
    (SELECT start_date::varchar FROM parameters) || 
        ' to ' || 
        (SELECT end_date::varchar FROM parameters) AS date_range,
    ac.date AS action_date,
    ac.action AS action,
    ac.description AS action_description,
    ac.source AS action_source,
    ia.item_barcode,
    ug.group_description AS patron_group_name,
    ug.user_last_name AS patron_last_name,
    ug.user_first_name AS patron_first_name,
    ug.user_email AS patron_email,
    sp.service_point_name
FROM
    public.audit_circulation_logs AS ac
    LEFT JOIN items_array AS ia ON ac.id = ia.log_id
    LEFT JOIN folio_reporting.users_groups AS ug ON json_extract_path_text(ac.data, 'linkToIds', 'userId') = ug.user_id
    LEFT JOIN service_points AS sp ON ac.service_point_id = sp.service_point_id
WHERE
    ac.date >= (SELECT start_date FROM parameters)
    AND ac.date < (SELECT end_date FROM parameters)
    AND (
        sp.service_point_name = (SELECT action_service_point_name_filter FROM parameters)
        OR '' = (SELECT action_service_point_name_filter FROM parameters)
    )
    AND (
        ac.action IN ((SELECT action_filter1 FROM parameters), 
                      (SELECT action_filter2 FROM parameters), 
                      (SELECT action_filter3 FROM parameters), 
                      (SELECT action_filter4 FROM parameters)
                      )
        OR (
            '' = (SELECT action_filter1 FROM parameters) AND 
            '' = (SELECT action_filter2 FROM parameters) AND 
            '' = (SELECT action_filter3 FROM parameters) AND 
            '' = (SELECT action_filter4 FROM parameters)
        )
    )
;
