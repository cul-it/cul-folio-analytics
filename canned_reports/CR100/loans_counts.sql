/* PURPOSE
This report produces a count of loans by loan policy, patron group, and material type. 

FILTERS FOR USER TO SELECT
start date, end date, permanent location name, owning library name.
*/
 
WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /* Fill one out, leave others blank to filter by location */
        ''::varchar AS item_location_filter, -- Examples: Olin, ILR, Africana, etc.
        ''::varchar AS library_filter -- Examples: Nestle Library', Library Annex, etc.
)
    --MAIN QUERY
    
SELECT (
    SELECT start_date::varchar FROM parameters) || ' to '::varchar || (SELECT end_date::varchar FROM parameters) AS date_range,
    ll.library_name,
    li.current_item_effective_location_name AS location_name,
    li.patron_group_name AS patron_group_name,
    li.material_type_name AS material_type_name,
    li.loan_policy_name AS loan_policy_name,
    count (li.loan_id) AS number_of_loans
   
FROM
    folio_reporting.loans_items AS li
    left join folio_reporting.locations_libraries as ll 
    on li.current_item_effective_location_id = ll.location_id

WHERE
    loan_date >= (SELECT start_date FROM parameters)
    AND loan_date < (SELECT end_date FROM parameters)
    AND (li.current_item_effective_location_name = (SELECT item_location_filter FROM parameters)
         OR '' = (SELECT item_location_filter FROM parameters))
     AND (ll.library_name = (SELECT library_filter FROM parameters)
         OR '' = (SELECT library_filter FROM parameters))
 GROUP BY 
    ll.library_name,
    li.current_item_effective_location_name,
    li.patron_group_name,
    li.material_type_name,
    li.loan_policy_name

 ORDER BY library_name, location_name, patron_group_name, loan_policy_name, material_type_name;

