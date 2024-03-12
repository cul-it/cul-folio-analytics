--CR233
--ADC Location Translation Table

--This query creates the location translation table that is used for Annual Data Collection (ADC) queries.
--Query writer: Joanne Leary

SELECT
       to_char (current_date::date,'mm/dd/yyyy') as table_create_date, -- keep IN TRANSLATION table
       to_char (invloc.metadata__created_date::date,'mm/dd/yyyy')::date as location_create_date,
       to_char (invloc.metadata__updated_date::date,'mm/dd/yyyy')::date as location_updated_date,
       invloc.id as inv_loc_id, --keep IN TRANSLATION table
       invloc.code AS inv_loc_location_code,
       adc.adc_invloc_location_code, --keep IN TRANSLATION table
       invloc.name AS inv_loc_location_name,
       adc.adc_invloc_location_name, --keep IN TRANSLATION table
       adc.adc_loc_translation, --keep IN TRANSLATION table
       invloc.library_id, --keep IN TRANSLATION table
       invlib.name AS inv_lib_shelvinglibrary_name,
       adc.adc_invlib_shelvinglibrary_name,  --keep IN TRANSLATION table
       case when invloc.is_active = 'True' then 'Active' else 'Inactive' end as location_status,
       invloc.description as inv_loc_desc

from inventory_locations as invloc 
       left join inventory_libraries as invlib 
       on invloc.library_id = invlib.id 
       
       left join local_core.lm_adc_location_translation_table as adc
       on invloc.code = adc.adc_invloc_location_code

order by invloc.code

