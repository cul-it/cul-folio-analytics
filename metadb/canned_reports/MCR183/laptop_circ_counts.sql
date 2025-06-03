--MCR183
--laptop_circ_counts
--This query counts laptop circs and renewals by library, date, loan type, and laptop type (Mac or PC).  Also counts how many laptops were used on any given day.
--Original query written by Joanne LEary (jl41)
--This query ported to Metadb by Linda Miller (lm15)
--Query reviewers: Joanne Leary (jl41), Vandana Shah(vp25)
--Date posted: 6/7/24

WITH 
parameters AS (
SELECT
       /* Choose a start and end date for the loans period */
       '2023-07-01'::TIMESTAMPTZ AS start_date,
       '2024-07-01'::TIMESTAMPTZ AS end_date,
       /* Choose a library or leave blank to include all libraries */
       ''::varchar AS library_filter
       -- Examples: Olin Library, Mann Library, 
       --Mui Ho Fine Arts Library, etc.
),

laptops AS 
(
SELECT
       instance_ext.instance_hrid, 
       holdings_ext.holdings_hrid,
       item_ext.item_hrid,
       locations_libraries.library_name,
       loans_items.item_effective_location_name_at_check_out,
       instance_ext.title,
       holdings_ext.call_number AS holdings_call_number,
       CASE
             WHEN holdings_ext.call_number ILIKE '%mac%' THEN 'Mac'
             WHEN holdings_ext.call_number ILIKE '%dell%' THEN 'Dell' 
             ELSE 'Other'
       END AS laptop_type,
       CONCAT (item_effective_callno_components.item_effective_call_number_prefix, 
       ' ', 
  		item_effective_callno_components.item_effective_call_number,
       ' ',
		item_effective_callno_components.item_effective_call_number_suffix,
       ' ',
       item_ext.enumeration,
       ' ', item_ext.chronology) AS item_call_number,
       item_ext.barcode,
       loans_items.material_type_name, 
       loans_items.loan_policy_name,
       date_part ('year', loans_items.loan_date::TIMESTAMPTZ) AS "year",
       date_part ('month', loans_items.loan_date::TIMESTAMPTZ) AS month_number,
       date_part ('day', loans_items.loan_date::TIMESTAMPTZ) AS day_number,
       TO_CHAR (loans_items.loan_date::TIMESTAMPTZ, 'mm/dd/yyyy') AS loan_date,
       TO_CHAR (loans_items.loan_date::TIMESTAMPTZ, 'Month') AS month_name,
       TO_CHAR (loans_items.loan_date::TIMESTAMPTZ, 'Day') AS day_name,
       loans_items.loan_id AS li_loan_id,
       loans_renewal_dates.loan_id AS lrd_loan_id,   
       sum(loans_renewal_dates.folio_renewal_count::INT) AS renewal_count 
FROM
       folio_derived.item_ext    
LEFT JOIN folio_derived.holdings_ext  
        ON   item_ext.holdings_record_id = holdings_ext.id
LEFT JOIN folio_derived.instance_ext  
        ON   holdings_ext.instance_id = instance_ext.instance_id 
LEFT JOIN folio_derived.locations_libraries   
        ON   holdings_ext.permanent_location_id = locations_libraries.location_id       
LEFT JOIN folio_derived.loans_items    
        ON   item_ext.item_id = loans_items.item_id 
LEFT JOIN folio_derived.item_effective_callno_components   
        ON   item_ext.item_id = item_effective_callno_components.item_id      
LEFT JOIN local_static.loans_renewal_dates   
        ON   loans_items.loan_id = loans_renewal_dates.loan_id::uuid     
WHERE
       (loans_items.loan_date::TIMESTAMPTZ >= (SELECT start_date FROM parameters) AND loans_items.loan_date::TIMESTAMPTZ < (
       SELECT end_date FROM parameters))    
       AND ((loans_renewal_dates.renewal_date::TIMESTAMPTZ >= (SELECT start_date FROM parameters) 
       AND loans_renewal_dates.renewal_date::TIMESTAMPTZ < (SELECT end_date FROM parameters))
       OR loans_renewal_dates.renewal_date::TIMESTAMPTZ IS NULL) 
       AND loans_items.material_type_name = 'Laptop'
       AND (locations_libraries.library_name = (SELECT library_filter FROM parameters) OR 
       (SELECT library_filter FROM parameters)= '')
GROUP BY
       instance_ext.instance_hrid,
       holdings_ext.holdings_hrid,
       item_ext.item_hrid,
       locations_libraries.library_name,
       loans_items.item_effective_location_name_at_check_out,
       instance_ext.title,
       holdings_ext.call_number,
item_effective_callno_components.item_effective_call_number_prefix,
  item_effective_callno_components.item_effective_call_number,
item_effective_callno_components.item_effective_call_number_suffix,
       item_ext.enumeration,
       item_ext.chronology,
       item_ext.barcode,
       loans_items.material_type_name, 
       loans_items.loan_policy_name,
       loans_items.loan_date,
       loans_items.loan_id,
       loans_renewal_dates.loan_id,
       loans_renewal_dates.folio_renewal_count       
                   
 ),
        
loans AS 
        (
SELECT
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
       CASE
             WHEN laptops.loan_policy_name ILIKE '%week%' THEN 'Extended loan'
             WHEN laptops.loan_policy_name IS NULL THEN 'Did not circulate in Folio'
             ELSE 'Hourly loan'
       END AS loan_type,
       count (DISTINCT laptops.li_loan_id) AS total_charges, 
       sum (laptops.renewal_count) AS total_renews  
FROM
       laptops
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
       (
       SELECT
             start_date::date
       FROM
             parameters)::varchar || ' to ' || (
       SELECT
             end_date::date
       FROM
             parameters)::varchar AS date_range,
       loans.library_name,
       loans."year"::varchar,
       loans.month_name,
       loans.month_number,
       loans.day_number,
       loans.day_name,
       loans.laptop_type,
       loans.loan_type,
       COUNT (DISTINCT loans.item_hrid) AS number_of_laptops_loaned,
       SUM (loans.total_charges) AS total_checkouts,
       COALESCE (SUM (loans.total_renews), 0) AS total_renews
FROM
       loans
GROUP BY
       loans."year",
       loans.month_number,
       loans.month_name,
       loans.day_number,
       loans.day_name,
       loans.library_name,
       loans.laptop_type,
       loans.loan_type
ORDER BY
       library_name,
       "year",
       month_number,
       day_number,
       laptop_type,
       loan_type
;
