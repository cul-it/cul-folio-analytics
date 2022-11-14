--CR194
--checkouts_and_checkins_by_date_range_and_service_point

-- This query finds checkouts and checkins by month for a given service point and date range. Item records that have been deleted will show
-- a material type name of "Unknown". Because most deleted records are equipment records, these items have been categorized 
-- as "Equipment" collection type as a best guess.
 
WITH parameters AS
(SELECT
        '2021-07-01'::date AS begin_date, -- enter date ranges in the format "yyyy-mm-dd"
        '2023-07-01'::date AS end_date, -- the end date will not be including in the results
        'Math Service Point'::VARCHAR AS service_point_name -- enter a service point name
),
 
actions AS
(SELECT
        to_char (current_date::date,'mm/dd/yyyy') AS todays_date,
        concat ((SELECT begin_date FROM parameters), ' - ',(SELECT end_date FROM parameters)) AS date_range,
        acl.date::DATE AS action_date,
        acl.id,
        acl.action,
        JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (acl.data, 'items')),'loanId') AS loan_id,
        JSON_EXTRACT_PATH_TEXT (JSON_ARRAY_ELEMENTS (JSON_EXTRACT_PATH (acl.data, 'items')),'itemId') AS item_id,
        isp.name AS service_point_name
       
FROM audit_circulation_logs AS acl
        LEFT JOIN inventory_service_points AS isp
        ON acl.service_point_id = isp.id
 
WHERE acl.date >= (SELECT begin_date FROM parameters) AND acl.date < (SELECT end_date FROM parameters)
        AND isp.name = (SELECT service_point_name FROM parameters)
        AND acl.action ILIKE 'Checked%'
        AND acl.source NOT ILIKE 'app%'
        AND acl.source NOT ILIKE 'admin%'
        AND acl.source NOT ILIKE 'fs%'
        AND acl.source NOT ILIKE 'system%'
)
 
SELECT
        actions.todays_date,
        actions.date_range,
        actions.action_date,
        DATE_PART ('Year',actions.action_date)::VARCHAR AS "year",
        TO_CHAR (actions.action_date,'Mon') AS "month",
        CASE
                WHEN actions.action ILIKE 'checked out%' THEN 'Checkout'
                ELSE 'Checkin'
                END AS action_type,
        actions.service_point_name,
        CASE WHEN ie.material_type_name IS NULL THEN 'Unknown' ELSE ie.material_type_name END AS material_type_name,
        CASE
                WHEN ie.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
                WHEN ie.material_type_name = 'Laptop' THEN 'Laptop'
                WHEN ie.material_type_name IS NULL THEN 'Equipment'
                WHEN ie.material_type_name ILIKE 'BD%' OR ie.material_type_name ILIKE 'ILL%' THEN 'ILLBD'
                ELSE 'Regular collection' END AS collection_type,
        COUNT (actions.id) AS number_of_actions
 
FROM actions
        LEFT JOIN folio_reporting.item_ext AS ie
        ON actions.item_id = ie.item_id
       
GROUP BY
        actions.todays_date,
        actions.date_range,
        actions.action_date,
        actions.action,
        actions.service_point_name,
        ie.material_type_name,
        collection_type,
        DATE_PART ('Year',actions.action_date)::VARCHAR,
        TO_CHAR (actions.action_date,'Mon')
       
ORDER BY
service_point_name, action_date, action_type
;

