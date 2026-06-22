--MCR 418
-- Materials Counts (1) - Data Prep
--Query writer: Vandana Shah (vp25), Claude AI
--Date posted: 6/22/26
--NOTE: TABLES CAN BE CREATED IN INDIVIDUAL SCHEMAS; the local_statistics schema is restricted.

--Table 1

DROP TABLE IF EXISTS local_statistics.vs_marc_data_prep;
CREATE TABLE local_statistics.vs_marc_data_prep AS
WITH bibliographic_data AS (
    -- Extract bibliographic-level MARC data (one record per instance)
    SELECT DISTINCT 
        instance_id,
        -- Leader positions 6-7 (field = '000') - single values per instance
        MAX(CASE WHEN field = '000' THEN substring(content, 7, 1) END) as record_type_06,
        MAX(CASE WHEN field = '000' THEN substring(content, 8, 1) END) as bib_level_07,
        
        -- Control fields - single values per instance  
        MAX(CASE WHEN field = '007' AND length(content) > 0 
            THEN substring(content, 1, 1) END) as field_007_00,
        MAX(CASE WHEN field = '008' AND length(content) > 21 
            THEN substring(content, 22, 1) END) as field_008_21,
            
        -- Bibliographic fields that can have multiple occurrences
        array_agg(DISTINCT content) FILTER (WHERE field = '245' AND sf = 'h') as marc_245h,
        array_agg(DISTINCT content) FILTER (WHERE field = '948' AND sf = 'f') as marc_948f,
        
        -- ADD: 653$a field (research guides)
        array_agg(DISTINCT content) FILTER (WHERE field = '653' AND sf = 'a') as marc_653a,
        
        -- ADD: 502 field (thesis detection)
        CASE WHEN COUNT(*) FILTER (WHERE field = '502') > 0 THEN true ELSE false END as is_thesis
        
    FROM local_derived.marc__t 
    GROUP BY instance_id
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

-- Final combination with new fields
SELECT 
    b.instance_id,
    b.record_type_06,
    b.bib_level_07,
    b.field_007_00,
    b.field_008_21,
    b.marc_245h,
    b.marc_948f,
    b.marc_653a,        
    b.is_thesis,        
    h.location_codes as location_code,
    h.call_numbers as call_number,
    h.library_names as library_name,
    h.call_number_statuses as call_number_status,
    i.title,
    COALESCE(sc.instance_stat_codes, '{}') as instance_stat_codes,
    COALESCE(sc.special_format_codes, '{}') as special_format_codes
FROM bibliographic_data b
INNER JOIN instance_metadata i ON b.instance_id = i.instance_id
LEFT JOIN holdings_data h ON b.instance_id = h.instance_id
LEFT JOIN statistical_codes sc ON b.instance_id = sc.instance_id;

-- Create indexes
CREATE INDEX idx_vs_marc_data_prep_instance ON local_statistics.vs_marc_data_prep(instance_id);
CREATE INDEX idx_vs_marc_data_prep_gin_locations ON local_statistics.vs_marc_data_prep USING gin(location_code);
