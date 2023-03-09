WITH PARAMETERS AS (
SELECT
        /* Choose a start and end date for the requests period */
        '2022-07-01'::date AS start_date,
        '2023-06-30'::date AS end_date
),

recs AS 
(SELECT 
        TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy') AS todays_date,
        ll.library_name as owning_library,
        ri.item_effective_location_name AS item_location,
        --ri.request_date::DATE,
        DATE_PART ('month',ri.request_date::DATE) AS month_of_request,
        TO_CHAR (ri.request_date::DATE,'Month') AS month_name,
        DATE_PART ('year',ri.request_date::DATE)::VARCHAR AS year_of_request,
        ri.request_type,
        ri.request_status,
        ri.pickup_service_point_name,
        CASE WHEN ri.pickup_service_point_name LIKE '%Contactless%' THEN 'Contactless Pickup' ELSE 'Circ Desk Pickup' END AS pickup_type,
        ri.patron_group_name,
        ri.material_type_name,
        count(ri.request_id) as number_of_requests

FROM 
        folio_reporting.requests_items AS ri 
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON ri.item_effective_location_id = ll.location_id

WHERE
    ri.request_date::DATE >= (SELECT start_date FROM parameters)
    AND ri.request_date::DATE < (SELECT end_date FROM parameters)
    
GROUP BY
        TO_CHAR (CURRENT_DATE::DATE,'mm/dd/yyyy'),
        ll.library_name,
        ri.request_type,
        ri.request_date,
        DATE_PART ('month',ri.request_date::DATE),
        TO_CHAR (ri.request_date::DATE,'Month'),
        DATE_PART ('year',ri.request_date::DATE)::VARCHAR,
        ri.request_status,
        ri.pickup_service_point_name,
        CASE WHEN ri.pickup_service_point_name LIKE '%Contactless%' THEN 'Contactless Pickup' ELSE 'Circ Desk Pickup' END,
        ri.patron_group_name,
        ri.item_effective_location_name,
        ri.material_type_name
)

SELECT 
       recs.todays_date,
       recs.owning_library,
       recs.item_location,
       recs.month_of_request,
       recs.month_name,
       recs.year_of_request,
       recs.request_type,
       recs.request_status,
       recs.pickup_service_point_name,
       recs.pickup_type,
       recs.patron_group_name,
       recs.material_type_name,
       SUM (number_of_requests) AS total_requests

FROM recs 
GROUP BY 
       recs.todays_date,
       recs.owning_library,
       recs.item_location,
       recs.month_of_request,
       recs.month_name,
       recs.year_of_request,
       recs.request_type,
       recs.request_status,
       recs.pickup_service_point_name,
       recs.pickup_type,
       recs.patron_group_name,
       recs.material_type_name

ORDER BY year_of_request, month_of_request, owning_library, item_location, pickup_service_point_name
;

