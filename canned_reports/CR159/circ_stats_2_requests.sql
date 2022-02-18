WITH PARAMETERS AS (
SELECT
        /* Choose a start and end date for the requests period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date
)

select 
        to_char(current_date::DATE,'mm/dd/yyyy') as todays_date,
        ll.library_name as owning_library,
        ri.item_effective_location_name as item_location,
        --ri.request_date::DATE,
        date_part('month',ri.request_date::DATE) as month_of_request,
        to_char(ri.request_date::DATE,'Month') as month_name,
        date_part('year',ri.request_date::DATE)::VARCHAR as year_of_request,
        ri.request_type,
        ri.request_status,
        ri.pickup_service_point_name,
        case when ri.pickup_service_point_name like '%Contactless%' then 'Contactless Pickup' else 'Circ Desk Pickup' end as pickup_type,
        ri.patron_group_name,
        ri.material_type_name,
        count(ri.request_id) as number_of_requests

from 
        folio_reporting.requests_items as ri 
        left join folio_reporting.locations_libraries as ll 
        on ri.item_effective_location_id = ll.location_id

WHERE
    ri.request_date::DATE >= (SELECT start_date FROM parameters)
    AND ri.request_date::DATE < (SELECT end_date FROM parameters)
    
GROUP BY
        to_char(current_date::DATE,'mm/dd/yyyy'),
        ll.library_name,
        ri.request_type,
        ri.request_date,
        date_part('month',ri.request_date::DATE),
        to_char(ri.request_date::DATE,'Month'),
        date_part('year',ri.request_date::DATE)::VARCHAR,
        ri.request_status,
        ri.pickup_service_point_name,
        case when ri.pickup_service_point_name like '%Contactless%' then 'Contactless Pickup' else 'Circ Desk Pickup' end,
        ri.patron_group_name,
        ri.item_effective_location_name,
        ri.material_type_name

order by year_of_request, month_of_request, owning_library,item_effective_location_name, pickup_service_point_name 
;
