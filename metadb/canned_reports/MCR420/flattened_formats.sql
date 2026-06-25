--MCR 420
-- Materials Counts (3) - Flattened formats
--Query writer: Vandana Shah (vp25), Claude AI
--Date posted: 6/22/26
--NOTE: TABLES CAN BE CREATED IN INDIVIDUAL SCHEMAS; the local_statistics schema is restricted.

--Table number 3

-- Create flattened table (not view) with all fields from vs_primary_formats
--DROP TABLE IF EXISTS local_statistics.vs_primary_formats_flattened;
CREATE TABLE local_statistics.vs_primary_formats_flattened AS
SELECT 
    -- All original fields from vs_primary_formats
	CURRENT_DATE AS table_create_date,    
	f.instance_id,
    f.record_type_06,
    f.bib_level_07,
    f.field_007_00,
    f.field_008_21,
    f.marc_245h,                    -- Keep as array
    f.marc_948f, 					-- Keep as array
    f.instance_stat_codes,          -- Keep as array
    f.special_format_codes,         -- Keep as array
    f.title,
    f.primary_format,
    f.is_microform,
    f.is_electronic,
        
    -- Flattened holdings fields (from arrays to individual values)
    loc_code as location_code,
    lib_name as library_name,
    cn as call_number,
    cn_status as call_number_status
    
FROM local_statistics.vs_primary_formats f
CROSS JOIN unnest(
    COALESCE(f.location_code, ARRAY[NULL::text]),
    COALESCE(f.library_name, ARRAY[NULL::text]), 
    COALESCE(f.call_number, ARRAY[NULL::text]),
    COALESCE(f.call_number_status, ARRAY[NULL::text])
) as holdings(loc_code, lib_name, cn, cn_status);

-- Create comprehensive indexes on the flattened table
CREATE INDEX idx_vs_primary_formats_flattened_instance ON local_statistics.vs_primary_formats_flattened(instance_id);
CREATE INDEX idx_vs_primary_formats_flattened_format ON local_statistics.vs_primary_formats_flattened(primary_format);
CREATE INDEX idx_vs_primary_formats_flattened_library ON local_statistics.vs_primary_formats_flattened(library_name);
CREATE INDEX idx_vs_primary_formats_flattened_location ON local_statistics.vs_primary_formats_flattened(location_code);
CREATE INDEX idx_vs_primary_formats_flattened_electronic ON local_statistics.vs_primary_formats_flattened(is_electronic);
CREATE INDEX idx_vs_primary_formats_flattened_microform ON local_statistics.vs_primary_formats_flattened(is_microform);
CREATE INDEX idx_vs_primary_formats_flattened_call_status ON local_statistics.vs_primary_formats_flattened(call_number_status);

--The "combo" in the index name below refers to a combination index (also called a composite index). 
--This index is built on multiple columns together: instance_id AND primary_format.
CREATE INDEX idx_vs_primary_formats_flattened_combo ON local_statistics.vs_primary_formats_flattened(instance_id, primary_format);
CREATE INDEX idx_vs_primary_formats_flattened_lib_format ON local_statistics.vs_primary_formats_flattened(library_name, primary_format);

-- Add GIN indexes for the array fields that are preserved
CREATE INDEX idx_vs_primary_formats_flattened_gin_245h ON local_statistics.vs_primary_formats_flattened USING gin(marc_245h);
CREATE INDEX idx_vs_primary_formats_flattened_gin_948f ON local_statistics.vs_primary_formats_flattened USING gin(marc_948f);
CREATE INDEX idx_vs_primary_formats_flattened_gin_stat_codes ON local_statistics.vs_primary_formats_flattened USING gin(instance_stat_codes);
CREATE INDEX idx_vs_primary_formats_flattened_gin_special_codes ON local_statistics.vs_primary_formats_flattened USING gin(special_format_codes);
