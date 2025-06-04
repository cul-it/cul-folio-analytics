--MCR402 Loan policies used in laptop charges
--This query can be used for the annual data collection to see which loan policy types units used for laptop charges,
--how frequently.

--Query writer: Linda Miller (lm15)
--Query reviewers: Joanne Leary (jl41), Vandana Shah (vp25)
--Query posted on: 6/12/24



WITH 
parameters AS (
SELECT
       /* Choose a start and end date for the loans period */
       '2023-07-01'::TIMESTAMPTZ AS start_date,
       '2024-07-01'::TIMESTAMPTZ AS end_date,
       /* Choose a library or leave blank to include all libraries */
       ''::varchar AS library_filter -- Examples: Olin Library, Mann Library, Mui Ho Fine Arts Library
),

all_data AS (

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
             WHEN holdings_ext.call_number ILIKE '%dell%' THEN 'DELL'
             ELSE 'Other'
       END AS laptop_type,
       CONCAT (item_effective_callno_components.item_effective_call_number_prefix, ' ', 
  	   item_effective_callno_components.item_effective_call_number,        ' ',
	   item_effective_callno_components.item_effective_call_number_suffix, ' ',
       item_ext.enumeration, ' ', item_ext.chronology) AS item_call_number,
       item_ext.barcode,
       loans_items.material_type_name,
       loans_items.loan_policy_name,
       loans_items.material_type_name,
       loans_items.loan_id --added

FROM folio_derived.item_ext      
LEFT JOIN folio_derived.holdings_ext   
        ON   item_ext.holdings_record_id = holdings_ext.id
LEFT JOIN folio_derived.instance_ext 
        ON   holdings_ext.instance_id = instance_ext.instance_id 
LEFT JOIN folio_derived.locations_libraries   
        ON   holdings_ext.permanent_location_id = locations_libraries.location_id  
LEFT JOIN folio_derived.loans_items     
        ON   item_ext.item_id = loans_items.item_id 
LEFT JOIN folio_derived.item_effective_callno_components   
       ON    item_ext.item_id = item_effective_callno_components.item_id      
  
WHERE
       (loans_items.loan_date::TIMESTAMPTZ >= (SELECT start_date FROM parameters) AND loans_items.loan_date::TIMESTAMPTZ < (
       SELECT end_date FROM parameters))
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
       loans_items.material_type_name,
       loans_items.loan_id
)

 --Now group counts by library and loan policy type and count.
SELECT 
 all_data.item_effective_location_name_at_check_out,
all_data.library_name,
all_data.loan_policy_name,
count(DISTINCT all_data.loan_id) AS loan_count
FROM all_data
GROUP BY
all_data.item_effective_location_name_at_check_out,
all_data.library_name,
all_data.loan_policy_name
;
