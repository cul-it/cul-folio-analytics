/*
PURPOSE
This report shows a list of exceptions, which are actions taken by an operator (staff member) and are recorded in the circulation log. 
An example is when an item has been manually discharged or discharged by an operator.


List of actions currently listed are: "Age to lost", "Anonymize", "Billed", "Cancelled", "Cancelled as error", "Changed due date", "Check in", 
"Check out", "Checked in", "Checked out", "Checked out through override", "Claimed returned", "Closed loan", "Created", "Created through override", "
Credited fully", "Declared lost", "Deleted", "Edited", "Expired", "Marked as missing", "Modified", "Moved", "Paid fully", "Paid partially", 
"Patron blocked from requesting", "Pickup expired", "Queue position reordered", "Recall requested", "Refunded fully", "Refunded partially", "
Renewed", "Renewed through override", "Request status changed", "Send", "Staff information only added", "Transferred fully", "Transferred partially", 
"Waived fully", "Waived partially".

MAIN TABLES INCLUDED
audit_circulation_log, locations_service_points (derived table), users_groups

FILTERS FOR USERS TO SELECT 
start and end dates, actions. 

*/
WITH parameters AS (
    SELECT
        /* Choose a start and end date for the request period */
       '2021-07-01'::date AS start_date,
       '2022-06-30'::date AS end_date, 
       ''::varchar AS action_service_point_name_filter, --Fill in a service point name, or leave blank */
        /* Fill in 1-4 action names, or leave all blank for all actions */
        ''::varchar AS action_filter1, -- see list of actions in README documentation 
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
     --   library_name 
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
    ac.object AS action_result,
    ac.source AS action_source,
    json_extract_path_text(ac.data, 'linkToIds', 'userId') AS user_id,
    json_extract_path_text(ac.data, 'linkToIds', 'feeFineId') AS fee_fine_id,
    ia.item_id,
    ia.loan_id,
    ia.item_barcode,
    ug.group_description AS patron_group_name,
    ug.user_last_name AS patron_last_name,
    ug.user_first_name AS patron_first_name,
    ug.user_middle_name AS patron_middle_name,
    ug.user_email AS patron_email,
    ac.service_point_id AS service_point_id,
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
