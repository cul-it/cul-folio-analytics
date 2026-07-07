--MCR423
--Count of Loans by date range 

--This query provides counts of loans by date range specifically for annual data collection purposes. 
--It excludes ILL and BD counts, as well as some material types. See query for details of exclusions. 
--Query writer: Vandana Shah(vp25). Original query written by Joanne Leary (jl41)
--Date posted: 6/30/26
--Updated on 7/7/26 to include college financial group and to exclude loans with 3 hr policies (equipment) 

WITH PARAMETERS AS (
    SELECT
        '2025-07-01'::date AS start_date,
        '2026-07-01'::date AS end_date
)

SELECT 
    CURRENT_DATE AS todays_date,
    CONCAT((SELECT start_date FROM parameters), ' - ', (SELECT end_date FROM parameters)) AS date_range,
    
    -- Date fields
    DATE_PART('year', loans_items.loan_date::DATE) AS calendar_year,
    CASE 
        WHEN DATE_PART('month', loans_items.loan_date) > 6 
        THEN CONCAT('FY ', DATE_PART('year', loans_items.loan_date) + 1) 
        ELSE CONCAT('FY ', DATE_PART('year', loans_items.loan_date))
    END AS fiscal_year,
    
    -- Filter fields
    locations_libraries.library_name,
    loans_items.item_effective_location_name_at_check_out,
    loans_items.patron_group_name,
    loans_items.material_type_name,
    loans_items.loan_policy_name,
    loans_items.lost_item_policy_name,
   
    -- Count DISTINCT loan_ids
    COUNT(DISTINCT loans_items.loan_id) AS total_loans
                
FROM folio_derived.loans_items                  
LEFT JOIN folio_derived.locations_libraries  
    ON loans_items.item_effective_location_id_at_check_out = locations_libraries.location_id

WHERE loans_items.loan_date >= (SELECT start_date FROM parameters) 
  AND loans_items.loan_date < (SELECT end_date FROM parameters)
  
  -- Material type filter
  AND ((loans_items.material_type_name IN (
      'Book', 'Computfile', 'Map', 'Microform', 'Music (score)', 
      'Newspaper', 'Object', 'Periodical', 'Serial', 'Soundrec', 
      'Textual resource', 'Unbound', 'unspecified', 'Visual'
  ) OR loans_items.material_type_name IS NULL))
  
  -- Patron group filter  
  AND loans_items.patron_group_name IN (
      'Borrow Direct', 'Carrel', 'Faculty', 'Graduate', 'Interlibrary Loan', 
      'Library Card', 'Proxy Borrower', 'Staff', 'Undergraduate'
  )
  
  -- Exclude 3 hour loan policies so as to weed out equipment loans in the case of loans during the fiscal year whose item records have since been deleted (their material type will be NULL).
   AND loans_items.lost_item_policy_name IN ('General Collection repl (default)','Reserves replacement','No Replacement')

GROUP BY 
    calendar_year, 
    fiscal_year,
    library_name, 
    item_effective_location_name_at_check_out,
    patron_group_name, 
    material_type_name,
    loans_items.loan_policy_name,
    loans_items.lost_item_policy_name
        
ORDER BY 
    fiscal_year, 
    calendar_year, 
    library_name, 
    patron_group_name, 
    material_type_name,
    loans_items.loan_policy_name,
    loans_items.lost_item_policy_name
;
