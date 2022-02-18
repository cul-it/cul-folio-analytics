SELECT 
        to_char(current_date::DATE - 30,'mm/dd/yyyy') as start_date,
        to_char(current_date::DATE,'mm/dd/yyyy') AS end_date,
        
        ll.library_name AS owning_library,
        li.checkout_service_point_name,
        li.patron_group_name,
        li.material_type_name,
        --to_char(li.loan_date::DATE,'mm/dd/yyyy') as loan_date,
        li.loan_policy_name,
        count(li.loan_id)

FROM folio_reporting.loans_items as li 
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON li.current_item_effective_location_id = ll.location_id 

WHERE 
        li.loan_date > current_date - 30
        
GROUP BY 
        to_char(current_date::DATE -30,'mm/dd/yyyy'),
        to_char(current_date::DATE,'mm/dd/yyyy'),
        ll.library_name,
        li.checkout_service_point_name,
        --to_char(li.loan_date::DATE,'mm/dd/yyyy'),
        li.loan_policy_name,
        li.material_type_name,
        li.patron_group_name
ORDER BY 
        OWNING_LIBRARY, PATRON_GROUP_NAME, LOAN_POLICY_NAME;
