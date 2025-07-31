--MCR233
--ADC Location Translation Table
--created 3/12/24
--This query creates the location translation table that is used for Annual Data Collection (ADC) queries.
--Query writer: Joanne Leary
--Reviewed by: Linda Miller


SELECT
       to_char (current_date::date,'mm/dd/yyyy') as table_create_date, -- keep IN TRANSLATION TABLE
       to_char (jsonb_extract_path_text (invloc.jsonb,'metadata', 'createdDate')::date,'mm/dd/yyyy')::date AS location_create_date,
       to_char (jsonb_extract_path_text (invloc.jsonb,'metadata', 'updatedDate')::date,'mm/dd/yyyy')::date as location_updated_date,
       invloc.id as inv_loc_id, --keep IN TRANSLATION table
       invloc__t.code AS inv_loc_location_code,
       adc.adc_invloc_location_code, --keep IN TRANSLATION TABLE
       invloc__t.name AS inv_loc_location_name,
       adc.adc_invloc_location_name, --keep IN TRANSLATION table
       adc.adc_loc_translation, --keep IN TRANSLATION table
       invloc__t.library_id, --keep IN TRANSLATION table
       invloclib__t.name AS invlib_shelvinglibrary_name,
       adc.adc_invlib_shelvinglibrary_name,  --keep IN TRANSLATION TABLE
       CASE WHEN (jsonb_extract_path_text (invloc.jsonb,'isActive')) = 'true' THEN 'Active' ELSE 'Inactive' END AS location_status,
      jsonb_extract_path_text (invloc.jsonb, 'description') AS inv_loc_desc,
       adc.dfs_college_group --keep IN TRANSLATION TABLE

FROM folio_inventory."location" AS invloc 
       LEFT JOIN folio_inventory.location__t AS invloc__t ON invloc.id = invloc__t.id
       left join folio_inventory.loclibrary__t as invloclib__t on invloc.libraryid = invloclib__t.id
       
       left join local_static.lm_adc_location_translation_table as adc
       on invloc.id = adc.inv_loc_id::uuid  -- I had TO ADD this TO the adc table

order by invloc__t.code
;
