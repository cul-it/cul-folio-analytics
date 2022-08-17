WITH 
parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /* Choose a library or leave blank to include all */
        'Olin Library'::varchar AS library_filter -- Examples: Nestle Library', Library Annex, etc.
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
        TO_CHAR (li.loan_date::TIMESTAMP,'mm/dd/yyyy') AS loan_date,
        TO_CHAR (li.loan_date::TIMESTAMP, 'Month') AS loan_month,
        TO_CHAR (li.loan_date::TIMESTAMP, 'YYYY') AS loan_year,
        COUNT(li.loan_id) AS count_of_charges,
        COUNT (lrd.loan_action_date) AS count_of_renews

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

WHERE itemext.material_type_name = 'Laptop'
        AND (li.loan_date >=(SELECT start_date FROM parameters) AND li.loan_date < (SELECT end_date FROM parameters) OR li.loan_date IS NULL)       
        AND ((lrd.loan_action_date >=(SELECT start_date FROM parameters) AND lrd.loan_action_date <(SELECT end_date FROM parameters) AND lrd.loan_action like 'renew%') OR lrd.loan_id IS NULL)
        AND (ll.library_name = (SELECT library_filter FROM parameters) OR '' = (SELECT library_filter FROM parameters))

GROUP BY 
        ii.hrid,
        he.holdings_hrid,
        itemext.item_hrid,
        ii.title,
        ll.library_name,
        he.call_number,
        li.item_effective_location_name_at_check_out,
        iecc.effective_call_number_prefix, 
        iecc.effective_call_number, 
        iecc.effective_call_number_suffix,
        itemext.enumeration,
        itemext.chronology,
        itemext.barcode,
        li.loan_date,
        loan_month,
        loan_year,
        li.loan_policy_name
),

loans AS 
(SELECT 
        laptops.loan_date,
        laptops.loan_month,
        laptops.loan_year,
		laptops.library_name,
      --  laptops.semester,
        laptops.title,
        laptops.item_call_number,
        laptops.loan_policy_name,
        laptops.item_hrid,
        laptops.laptop_type,
        CASE WHEN laptops.loan_policy_name ILIKE '%week%' THEN 'Extended loan' 
                WHEN laptops.loan_policy_name IS NULL THEN 'Did not circulate in Folio'
                ELSE 'Hourly loan' END AS loan_type,
        SUM (laptops.count_of_charges) AS total_charges,
        SUM (laptops.count_of_renews) AS total_renews

FROM laptops 

GROUP BY 
        laptops.loan_date,
        laptops.loan_month,
        laptops.loan_year,
		laptops.library_name,
      --  laptops.semester,
        laptops.loan_policy_name,
        laptops.item_hrid,
        laptops.title,
        laptops.laptop_type,
        laptops.item_call_number
)

SELECT 
        (SELECT start_date::varchar FROM parameters) || ' to '::varchar || (SELECT end_date::varchar FROM parameters) AS date_range,
        loans.loan_date,
        loans.loan_month,
        loans.loan_year,
        loans.library_name,
       -- loans.semester,
        loans.laptop_type,
        loans.loan_type,
        COUNT (loans.item_hrid) AS count_of_laptops,
        SUM (loans.total_charges) AS total_checkouts,
        SUM (loans.total_renews) AS total_renews

FROM loans 

GROUP BY 
		loans.loan_date,
		loans.loan_month,
		loans.loan_year,
        loans.library_name,
      --  loans.semester,
        loans.laptop_type,
        loans.loan_type

ORDER BY  library_name, laptop_type, loan_type

;
