WITH parameters AS (
    SELECT
  /*Fill out the material type filter*/
    	'Laptop'::varchar AS material_type_filter,
  /*Fill out owning library filter or leave blank to include all libraries*/
        'Olin Library'::varchar AS owning_library_filter, -- 'Olin Library, Mann Library, etc.'
  /*Fill out the date range for the checkouts*/  
        '2021-07-01'::DATE AS start_date,
        '2022-11-01'::DATE AS end_date
 ),

loans AS (
SELECT 
        li.item_effective_location_name_at_check_out,
        li.hrid,
        li.loan_policy_name,
        li.material_type_name,
        ll.library_name,
        COUNT(li.loan_id) AS number_of_loans
        
        FROM folio_reporting.loans_items AS li
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON li.item_effective_location_id_at_check_out = ll.location_id
        
        WHERE 
        (li.material_type_name = (SELECT material_type_filter FROM parameters)
        OR (SELECT material_type_filter FROM parameters) = '')
        AND (ll.library_name = (SELECT owning_library_filter FROM parameters)
        OR (SELECT owning_library_filter FROM parameters) = '')
        AND (li.loan_date::date >= (SELECT start_date FROM parameters)) 
		AND (li.loan_date::date < (SELECT end_date FROM parameters))
		AND li.material_type_name IS NOT NULL
        
            
        GROUP BY li.loan_policy_name, li.material_type_name, ll.library_name, li.item_effective_location_name_at_check_out, li.hrid
        
        ORDER BY li.item_effective_location_name_at_check_out
        )
        
 
SELECT 
    	(SELECT start_date::varchar FROM parameters) || ' to '::varchar || (SELECT end_date::varchar FROM parameters) AS date_range,
       	loans.library_name,
        loans.material_type_name,
        loans.loan_policy_name,
        COUNT(loans.hrid) AS number_of_distinct_items,
        SUM(loans.number_of_loans) AS number_of_checkouts,
        (SUM(loans.number_of_loans) / COUNT(loans.hrid))::NUMERIC(12,2) AS loans_per_item
         

FROM loans

GROUP BY 
        loans.library_name,
        loans.material_type_name,
        loans.loan_policy_name

ORDER BY library_name, loan_policy_name, loans_per_item
;
