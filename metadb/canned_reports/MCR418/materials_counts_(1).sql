--MCR 418
-- Materials Counts (1) - Data Prep
--Query writer: Vandana Shah (vp25), Claude AI
--Date posted: 6/22/26
--NOTE: TABLES CAN BE CREATED IN INDIVIDUAL SCHEMAS; the local_statistics schema is restricted.

--First DROP all tables (for all three queries - MCR418, 419, and 420) before running automated queries, else if a table does not get created,the final counts will be based on an older version of a table.

DROP TABLE IF EXISTS local_statistics.vs_marc_data_prep;
DROP TABLE IF EXISTS local_statistics.vs_primary_formats;
DROP TABLE IF EXISTS local_statistics.vs_primary_formats_flattened;


--Table 1
CREATE TABLE local_statistics.vs_marc_data_prep AS
WITH bibliographic_data AS (
    -- First get all instances that have any of the target fields
    SELECT DISTINCT instance_id FROM local_derived.marc__t 
    WHERE field IN ('000', '007', '008', '245', '948')
),

marc_control_fields AS (
    SELECT DISTINCT 
        instance_id,
        MAX(CASE WHEN field = '000' THEN substring(content, 7, 1) END) as record_type_06,
        MAX(CASE WHEN field = '000' THEN substring(content, 8, 1) END) as bib_level_07,
        -- Changed to array for repeatable 007 field
        array_agg(DISTINCT substring(content, 1, 1)) FILTER (
            WHERE field = '007' AND length(content) > 0
        ) as field_007_00,
        MAX(CASE WHEN field = '008' AND length(content) > 21 
            THEN substring(content, 22, 1) END) as field_008_21
    FROM local_derived.marc__t 
    WHERE field IN ('000', '007', '008')
    GROUP BY instance_id
),


marc_data_fields AS (
    SELECT DISTINCT 
        instance_id,
        array_agg(DISTINCT content) FILTER (WHERE field = '245' AND sf = 'h') as marc_245h,
        array_agg(DISTINCT content) FILTER (WHERE field = '948' AND sf = 'f') as marc_948f
    FROM local_derived.marc__t 
    WHERE (field = '245' AND sf = 'h') OR (field = '948' AND sf = 'f')
    GROUP BY instance_id
),

final_bibliographic_data AS (
    SELECT 
        b.instance_id,
        c.record_type_06,
        c.bib_level_07,
        c.field_007_00,
        c.field_008_21,
        d.marc_245h,
        d.marc_948f
    FROM bibliographic_data b
    LEFT JOIN marc_control_fields c ON b.instance_id = c.instance_id
    LEFT JOIN marc_data_fields d ON b.instance_id = d.instance_id
),

holdings_data AS (
    SELECT 
        hr.instance_id,
        array_agg(DISTINCT 
            CASE 
                WHEN loc.code IS NULL OR TRIM(loc.code) = '' THEN 'no location'
                ELSE TRIM(loc.code) 
            END
        ) as location_codes,
        array_agg(DISTINCT hr.call_number) FILTER (WHERE hr.call_number IS NOT NULL) as call_numbers,
        array_agg(DISTINCT COALESCE(lib.name, 'no library')) as library_names,
        array_agg(DISTINCT 
            CASE 
                WHEN hr.call_number ILIKE '%n order%' THEN 'ordered'
                WHEN hr.call_number ILIKE '%n process%' THEN 'in process'
                WHEN hr.call_number ILIKE '%vailable for the library to purchase%' THEN 'available for purchase'
                WHEN hr.call_number ILIKE '%n selector%' THEN 'in selection'
                ELSE 'regular'
            END
        ) as call_number_statuses
    FROM folio_inventory.holdings_record__t hr
    LEFT JOIN folio_inventory.location__t loc ON hr.permanent_location_id = loc.id
    LEFT JOIN folio_inventory.loclibrary__t lib ON loc.library_id = lib.id
    WHERE (hr.discovery_suppress = false OR hr.discovery_suppress IS NULL)
      AND loc.is_active = true
    GROUP BY hr.instance_id
),

instance_metadata AS (
    SELECT 
        ie.instance_id,
        ie.title
    FROM folio_derived.instance_ext ie
    WHERE ie.discovery_suppress = false OR ie.discovery_suppress IS NULL
),

statistical_codes AS (
    SELECT 
        instance_id,
        array_agg(statistical_code) as instance_stat_codes,
        array_agg(statistical_code) FILTER (
            WHERE statistical_code_type_name ILIKE 'Special format'
        ) as special_format_codes
    FROM folio_derived.instance_statistical_codes
    GROUP BY instance_id
)

-- Final combination
SELECT 
    CURRENT_DATE AS table_create_date,
    b.instance_id,
    b.record_type_06,
    b.bib_level_07,
    b.field_007_00,
    b.field_008_21,
    b.marc_245h,
    b.marc_948f,         
    h.location_codes as location_code,
    h.call_numbers as call_number,
    h.library_names as library_name,
    h.call_number_statuses as call_number_status,
    i.title,
    COALESCE(sc.instance_stat_codes, '{}') as instance_stat_codes,
    COALESCE(sc.special_format_codes, '{}') as special_format_codes
FROM final_bibliographic_data b
INNER JOIN instance_metadata i ON b.instance_id = i.instance_id
LEFT JOIN holdings_data h ON b.instance_id = h.instance_id
LEFT JOIN statistical_codes sc ON b.instance_id = sc.instance_id;

-- Create indexes
CREATE INDEX idx_vs_marc_data_prep_instance ON local_statistics.vs_marc_data_prep(instance_id);
CREATE INDEX idx_vs_marc_data_prep_gin_locations ON local_statistics.vs_marc_data_prep USING gin(location_code);
