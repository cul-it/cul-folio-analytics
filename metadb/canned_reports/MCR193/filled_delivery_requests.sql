--MCR 193
--Filled Delivery Requests
--This query provides a count of all contactless delivery and circulation desk pickup requests, by fiscal year. Patron group, material type, request type, and location details are included. 
--Original LDP query writer: Joanne Leary (JL41). Current version ported to Metadb: Vandana Shah (vp25)
--Reviewed by: Linda Miller (lm15), Joanne Leary (jl41)
--Query posted on: 5/8/24

WITH PARAMETERS AS (
SELECT
     /* Choose a start and end date for the requests period */
     '2023-07-01'::date AS start_date,
     '2024-07-01'::date AS end_date)  ,
   
users AS 
(
SELECT DISTINCT
     folio_users.users.id,
     jsonb_extract_path_text (jsonb,  'personal', 'lastName') AS requestor_last_name,
     jsonb_extract_path_text (jsonb, 'personal', 'firstName') AS requestor_first_name
FROM
     folio_users.users  
)

SELECT DISTINCT
     to_char(current_date::DATE, 'mm/dd/yyyy') AS todays_date,
     requests_items.request_type,
     locations_libraries.library_name AS owning_library,
     requests_items.item_effective_location_name AS item_location,
     requests_items.patron_group_name,
     requests_items.pickup_service_point_name,
     CASE
           WHEN requests_items.pickup_service_point_name LIKE '%Contactless%' THEN 'Contactless Pickup'
           ELSE 'Circ Desk Pickup'
     END AS pickup_type,
     
     CASE WHEN
    date_part ('month',folio_derived.requests_items.request_date ::DATE) >'6' 
        THEN concat ('FY ', date_part ('year',folio_derived.requests_items.request_date::DATE) + 1) 
        ELSE concat ('FY ', date_part ('year',folio_derived.requests_items.request_date::DATE))
        END as fiscal_year_of_request,
     count (distinct requests_items.request_id) AS number_of_requests
                
    
     
FROM
     folio_derived.requests_items 
LEFT JOIN folio_derived.locations_libraries 
                ON
     folio_derived.requests_items.item_effective_location_id = folio_derived.locations_libraries.location_id
     
LEFT JOIN users 
                ON
     folio_derived.requests_items.requester_id = users.id
WHERE
           requests_items.request_date::DATE >= (SELECT start_date FROM Parameters)
     AND requests_items.request_date::DATE <(SELECT end_date FROM Parameters)
     AND requests_items.request_status IN ('Closed - Filled', 'Closed - Pickup expired', 'Open - In transit', 'Open - Awaiting pickup')
     AND requests_items.material_type_name NOT IN ('BD MATERIAL', 'ILL MATERIAL')
     AND requests_items.item_effective_location_name !~~* 'Borrow%'
     AND requests_items.item_effective_location_name !~~* 'Interlibrary%'
     AND ((users.requestor_last_name !~~* '%reserve%'
     AND users.requestor_first_name !~~* '%reserve%'
     AND users.requestor_last_name !~~* 'Collection'
     AND users.requestor_last_name !~~* '%Bindery%'
     AND users.requestor_last_name !~~* '%Conservation%'
     AND users.requestor_last_name !~~* '%heine%'
     AND users.requestor_last_name !~~* '%DMG%'
     AND users.requestor_last_name !~~* '%New books%'
     AND users.requestor_last_name !~~* '%project%')
     OR users.requestor_last_name IS NULL
     OR users.requestor_first_name IS NULL)
     
GROUP BY
     to_char(current_date::DATE, 'mm/dd/yyyy'),
     locations_libraries.library_name,
     requests_items.request_type,
     requests_items.request_status,
     requests_items.pickup_service_point_name,
     requests_items.patron_group_name,
     requests_items.item_effective_location_name,
     requests_items.material_type_name,
     fiscal_year_of_request
ORDER BY
     owning_library,
     item_effective_location_name,
     patron_group_name,
     pickup_service_point_name 
;
