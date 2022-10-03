WITH 
parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2021-07-01'::date AS start_date,
        '2022-07-01'::date AS end_date,
        
        /* Choose a library or leave blank to include all libraries */
        'Mann Library'::varchar AS library_filter -- Examples: Nestle Library, Library Annex, Olin Library, etc.
),

laptops AS 
(SELECT 
        ii.hrid AS instance_hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        ll.library_name,
        li.item_effective_location_name_at_check_out,
       ii.title,
        he.call_number AS holdings_call_number,
        CASE WHEN he.call_number ILIKE '%mac%' THEN 'Mac' ELSE 'Dell' END AS laptop_type,
        CONCAT (iecc.effective_call_number_prefix,' ', iecc.effective_call_number,' ',iecc.effective_call_number_suffix, 
                ' ',itemext.enumeration,' ',itemext.chronology) AS item_call_number,
        itemext.barcode,
        li.loan_policy_name,
        date_part ('year',li.loan_date) as "year",
        date_part ('month',li.loan_date) as month_number,
        date_part ('day',li.loan_date) as day_number,
        TO_CHAR (li.loan_date::TIMESTAMP,'mm/dd/yyyy') AS loan_date,
        TO_CHAR (li.loan_date::TIMESTAMP, 'Month') AS month_name,
        TO_CHAR (li.loan_date::TIMESTAMP, 'Day') AS day_name,      
        
                li.loan_id as li_loan_id,
                lrd.loan_id as lrd_loan_id,      
                max (lrd.loan_renewal_count::INT) as renewal_count,
                li.material_type_name

FROM folio_reporting.item_ext AS itemext 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON itemext.holdings_record_id = he.holdings_id
        
        LEFT JOIN inventory_instances AS ii 
        ON he.instance_id = ii.id

        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 
        
        LEFT JOIN folio_reporting.loans_items AS li 
        ON itemext.item_id = li.item_id 
        
        LEFT JOIN folio_reporting.item_effective_callno_components AS iecc 
        ON itemext.item_id = iecc.item_id
        
        LEFT JOIN folio_reporting.loans_renewal_dates lrd 
        ON li.loan_id = lrd.loan_id      
        
        
where li.loan_date >= (SELECT start_date FROM parameters) and li.loan_date < (SELECT end_date FROM parameters)--'2022-07-01'
        and ((lrd.loan_action_date >= (SELECT start_date FROm parameters) and lrd.loan_action_date < (SELECT end_date FROM parameters)) OR lrd.loan_action_date IS NULL)-- 2022-07-01') OR lrd.loan_action_date IS NULL)
        and li.material_type_name = 'Laptop'
        AND (ll.library_name = (SELECT library_filter FROM parameters) OR (SELECT library_filter FROM parameters)= '')

group by 

        ii.hrid,
    he.holdings_hrid,
    itemext.item_hrid,
    ll.library_name,
    li.item_effective_location_name_at_check_out,
    ii.title,
    he.call_number,
        iecc.effective_call_number_prefix,
        iecc.effective_call_number,
        iecc.effective_call_number_suffix, 
        itemext.enumeration,
        itemext.chronology,
        itemext.barcode,
        li.loan_policy_name,
        li.loan_date,
        li.loan_id,
        lrd.loan_id,
        li.material_type_name                
 ),
        
loans AS 
        (SELECT 
        laptops.loan_date,
        laptops."year",
        laptops.month_name,
        laptops.month_number,
        laptops.day_number,
        laptops.day_name,        
                laptops.library_name,
        laptops.title,
        laptops.item_call_number,
        laptops.loan_policy_name,
        laptops.item_hrid,
        laptops.laptop_type,
        CASE WHEN laptops.loan_policy_name ILIKE '%week%' THEN 'Extended loan' 
                WHEN laptops.loan_policy_name IS NULL THEN 'Did not circulate in Folio'
                ELSE 'Hourly loan' END AS loan_type,
        count (laptops.li_loan_id) AS total_charges,
        SUM (laptops.renewal_count) AS total_renews

FROM laptops 

GROUP BY 
        laptops.loan_date,
        laptops."year",
        laptops.month_name,
        laptops.month_number,
        laptops.day_number,
        laptops.day_name,        
                laptops.library_name,
        laptops.title,
        laptops.item_call_number,
        laptops.loan_policy_name,
        laptops.item_hrid,
        laptops.laptop_type
)
        
 SELECT 
        (SELECT start_date::date FROM parameters)::varchar || ' to ' || (SELECT end_date::date FROM parameters)::varchar AS date_range,
        loans.library_name,
        loans."year"::varchar,
        loans.month_name,
        loans.month_number,
        loans.day_number,
        loans.day_name,        
        loans.laptop_type,
        loans.loan_type,
        COUNT (distinct loans.item_hrid) AS number_of_laptops_loaned,
        SUM (loans.total_charges) AS total_checkouts,
        coalesce (SUM (loans.total_renews),0) AS total_renews

FROM loans 

GROUP BY 
                loans."year",
                loans.month_number,
                loans.month_name,
                loans.day_number,
                loans.day_name,
        loans.library_name,
        loans.laptop_type,
        loans.loan_type

ORDER BY  library_name, "year", month_number, day_number, laptop_type, loan_type
;
