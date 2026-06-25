--MCR 419
-- Materials Counts (2) - Primary Formats
--Query writer: Vandana Shah (vp25), Claude AI
--Date posted: 6/22/26
--NOTE: TABLES CAN BE CREATED IN INDIVIDUAL SCHEMAS; the local_statistics schema is restricted.

--Table 2

--DROP TABLE IF EXISTS local_statistics.vs_primary_formats;
CREATE TABLE local_statistics.vs_primary_formats AS
WITH instance_formats AS (
    SELECT 
        ibd.instance_id,
        ibd.record_type_06,
        ibd.bib_level_07,
        ibd.field_007_00,
        ibd.field_008_21,
        ibd.marc_245h,
        ibd.marc_948f,
        ibd.title,
        ibd.instance_stat_codes,
        ibd.special_format_codes,
        ibd.location_code,
        ibd.library_name,
        ibd.call_number,
        ibd.call_number_status,
        
        -- EXACT JAVA PROCESSING ORDER:
        CASE 
            -- Step 1: Database statistical codes (highest priority)
            WHEN (ibd.instance_stat_codes IS NOT NULL AND (
                     'fd' = ANY(ibd.instance_stat_codes::text[]) 
                     OR 'webfeatdb' = ANY(ibd.instance_stat_codes::text[])
                 ))
                 OR (ibd.marc_948f IS NOT NULL AND (
                     'fd' = ANY(ibd.marc_948f::text[])
                     OR 'webfeatdb' = ANY(ibd.marc_948f::text[])
                 )) THEN 'Database'
                 
            -- Step 2: Electronic journal (updated criteria)
            WHEN ('j' = ANY(ibd.marc_948f::text[]) OR 'j' = ANY(ibd.instance_stat_codes::text[]))
                 AND (ibd.location_code IS NOT NULL AND 'serv,remo' = ANY(ibd.location_code::text[])) THEN 'Journal/Serial'
            
            -- Step 3: MAIN FORMAT LOGIC (if format == null in Java)
            
            -- Language materials (record_type = 'a')
            WHEN ibd.record_type_06 = 'a' AND ibd.bib_level_07 IN ('a','m','d','c') THEN 'Book'
            WHEN ibd.record_type_06 = 'a' AND ibd.bib_level_07 IN ('b','s') THEN 'Journal/Serial'
            WHEN ibd.record_type_06 = 'a' AND ibd.bib_level_07 = 'i' AND ibd.field_008_21 = 'w' THEN 'Website'
            WHEN ibd.record_type_06 = 'a' AND ibd.bib_level_07 = 'i' AND ibd.field_008_21 = 'm' THEN 'Book'
            WHEN ibd.record_type_06 = 'a' AND ibd.bib_level_07 = 'i' AND ibd.field_008_21 = 'd' THEN 'Database'
            WHEN ibd.record_type_06 = 'a' AND ibd.bib_level_07 = 'i' AND ibd.field_008_21 IN ('n','p') THEN 'Journal/Serial'
                
            -- Manuscript text (record_type = 't') - ONLY monographic here
            WHEN ibd.record_type_06 = 't' AND ibd.bib_level_07 = 'a' THEN 'Book'
            
            -- Musical materials (record_type = 'c', 'd')
            WHEN ibd.record_type_06 IN ('c','d') THEN 'Musical Score'
            
            -- Maps (record_type = 'e', 'f')
            WHEN ibd.record_type_06 IN ('e','f') THEN 'Map'
            
            -- Visual materials (record_type = 'g')
            WHEN ibd.record_type_06 = 'g' THEN 'Video'
            
            -- Audio materials
            WHEN ibd.record_type_06 = 'i' THEN 'Non-musical Recording'
            WHEN ibd.record_type_06 = 'j' THEN 'Musical Recording'
            
            -- Images (record_type = 'k')
            WHEN ibd.record_type_06 = 'k' THEN 'Image'
            
            -- Computer files (record_type = 'm') - WITH STATISTICAL CODE OVERRIDES
            WHEN ibd.record_type_06 = 'm' AND (
                (ibd.instance_stat_codes IS NOT NULL AND 'evideo' = ANY(ibd.instance_stat_codes::text[])) 
                OR (ibd.marc_948f IS NOT NULL AND 'evideo' = ANY(ibd.marc_948f::text[]))
            ) THEN 'Video'
            WHEN ibd.record_type_06 = 'm' AND (
                (ibd.instance_stat_codes IS NOT NULL AND 'eaudio' = ANY(ibd.instance_stat_codes::text[])) 
                OR (ibd.marc_948f IS NOT NULL AND 'eaudio' = ANY(ibd.marc_948f::text[]))
            ) THEN 'Musical Recording'
            WHEN ibd.record_type_06 = 'm' AND (
                (ibd.instance_stat_codes IS NOT NULL AND 'escore' = ANY(ibd.instance_stat_codes::text[])) 
                OR (ibd.marc_948f IS NOT NULL AND 'escore' = ANY(ibd.marc_948f::text[]))
            ) THEN 'Musical Score'
            WHEN ibd.record_type_06 = 'm' AND (
                (ibd.instance_stat_codes IS NOT NULL AND 'emap' = ANY(ibd.instance_stat_codes::text[])) 
                OR (ibd.marc_948f IS NOT NULL AND 'emap' = ANY(ibd.marc_948f::text[]))
            ) THEN 'Map'
            WHEN ibd.record_type_06 = 'm' THEN 'Computer File'
                
            -- Other materials
            WHEN ibd.record_type_06 = 'o' THEN 'Kit'
            
            -- Mixed materials (record_type = 'p') - ONLY if in rare location
            WHEN ibd.record_type_06 = 'p' AND ibd.location_code IS NOT NULL AND EXISTS (
                SELECT 1 FROM unnest(ibd.location_code) AS loc 
                WHERE loc IN (
                    'asia,ranx','asia,rare','ech,rare','ech,ranx','ent,rare','ent,rar2',
                    'gnva,rare','hote,rare','ilr,kanx','ilr,lmdc','ilr,lmdr','ilr,rare',
                    'lawr','lawr,anx','mann,spec','rmc','rmc,anx','rmc,hsci','rmc,icer',
                    'rmc,ref','sasa,ranx','sasa,rare','vet,rare','was,rare','was,ranx'
                )
            ) THEN 'Manuscript/Archive'
            
            -- Objects (record_type = 'r')
            WHEN ibd.record_type_06 = 'r' THEN 'Object'
            
            -- Step 4: FALLBACK LOGIC (if format == null after main logic)
            
            -- Remaining manuscript text (record_type = 't', non-monographic)
            WHEN ibd.record_type_06 = 't' THEN 'Manuscript/Archive'
            
            -- 007 field fallbacks
            WHEN ibd.field_007_00 = 'q' THEN 'Musical Score'
            WHEN ibd.field_007_00 = 'v' THEN 'Video'
            
            -- Ultimate fallback
            ELSE 'Miscellaneous'
            
        END as calculated_format,
        
        -- Microform logic
        COALESCE(
            (ibd.field_007_00 = 'h' 
             OR (ibd.title IS NOT NULL AND (
                 ibd.title ~* '\[microform\]'           
                 OR ibd.title ~* '\[micro\]'            
                 OR ibd.title ~* '\bmicrofilm\b'        
                 OR ibd.title ~* '\bmicrofiche\b'       
                 OR ibd.title ~* '\bmicrocard\b'        
                 OR ibd.title ~* '\bmicroprint\b'       
                 OR ibd.title ~* 'micro\s*reproduction' 
             ))
            ), 
            false
        ) as is_microform,
        
        -- Electronic logic (updated with location requirement)
        COALESCE(
            ((ibd.location_code IS NOT NULL AND 'serv,remo' = ANY(ibd.location_code::text[]))
             AND
             ((ibd.marc_245h IS NOT NULL AND EXISTS(
                 SELECT FROM unnest(ibd.marc_245h) AS h 
                 WHERE lower(h) LIKE '%electronic resource%'
             ))
             OR (ibd.instance_stat_codes IS NOT NULL AND (
                 'ebk' = ANY(ibd.instance_stat_codes::text[])
                 OR 'j' = ANY(ibd.instance_stat_codes::text[])
                 OR 'evideo' = ANY(ibd.instance_stat_codes::text[])
                 OR 'eaudio' = ANY(ibd.instance_stat_codes::text[])
                 OR 'escore' = ANY(ibd.instance_stat_codes::text[])
                 OR 'emap' = ANY(ibd.instance_stat_codes::text[])
                 OR 'webfeatdb' = ANY(ibd.instance_stat_codes::text[])
                 OR 'imagedb' = ANY(ibd.instance_stat_codes::text[])
             ))
             OR (ibd.marc_948f IS NOT NULL AND (
                 'ebk' = ANY(ibd.marc_948f::text[])
                 OR 'j' = ANY(ibd.marc_948f::text[])
                 OR 'evideo' = ANY(ibd.marc_948f::text[])
                 OR 'eaudio' = ANY(ibd.marc_948f::text[])
                 OR 'escore' = ANY(ibd.marc_948f::text[])
                 OR 'emap' = ANY(ibd.marc_948f::text[])
                 OR 'webfeatdb' = ANY(ibd.marc_948f::text[])
                 OR 'imagedb' = ANY(ibd.marc_948f::text[])
             ))
             OR (ibd.special_format_codes IS NOT NULL AND EXISTS(
                 SELECT FROM unnest(ibd.special_format_codes) AS sc 
                 WHERE sc ILIKE ANY (ARRAY['%webfeatdb%','%imagedb%','%ebk%','%j%',
                                          '%evideo%','%eaudio%','%escore%','%ewb%','%emap%','%emisc%'])
             ))
            )),
            false
        ) as is_electronic
        
    FROM local_statistics.vs_marc_data_prep ibd
    
    UNION ALL
    
    -- Additional electronic formats (for multiple format capability)
    SELECT 
        ibd.instance_id,
        ibd.record_type_06,
        ibd.bib_level_07,
        ibd.field_007_00,
        ibd.field_008_21,
        ibd.marc_245h,
        ibd.marc_948f,
        ibd.title,
        ibd.instance_stat_codes,
        ibd.special_format_codes,
        ibd.location_code,
        ibd.library_name,
        ibd.call_number,
        ibd.call_number_status,
        
        -- Additional formats from statistical codes
        CASE 
            WHEN (ibd.instance_stat_codes IS NOT NULL AND 'evideo' = ANY(ibd.instance_stat_codes::text[])) 
                 OR (ibd.marc_948f IS NOT NULL AND 'evideo' = ANY(ibd.marc_948f::text[])) THEN 'Video'
            WHEN (ibd.instance_stat_codes IS NOT NULL AND 'eaudio' = ANY(ibd.instance_stat_codes::text[])) 
                 OR (ibd.marc_948f IS NOT NULL AND 'eaudio' = ANY(ibd.marc_948f::text[])) THEN 'Musical Recording'
            WHEN (ibd.instance_stat_codes IS NOT NULL AND 'escore' = ANY(ibd.instance_stat_codes::text[])) 
                 OR (ibd.marc_948f IS NOT NULL AND 'escore' = ANY(ibd.marc_948f::text[])) THEN 'Musical Score'
            WHEN (ibd.instance_stat_codes IS NOT NULL AND 'emap' = ANY(ibd.instance_stat_codes::text[])) 
                 OR (ibd.marc_948f IS NOT NULL AND 'emap' = ANY(ibd.marc_948f::text[])) THEN 'Map'
            WHEN (ibd.instance_stat_codes IS NOT NULL AND 'ebk' = ANY(ibd.instance_stat_codes::text[])) 
                 OR (ibd.marc_948f IS NOT NULL AND 'ebk' = ANY(ibd.marc_948f::text[])) THEN 'Book'
        END as calculated_format,
        
        COALESCE(
            (ibd.field_007_00 = 'h' 
             OR (ibd.title IS NOT NULL AND (
                 ibd.title ~* '\[microform\]'           
                 OR ibd.title ~* '\[micro\]'            
                 OR ibd.title ~* '\bmicrofilm\b'        
                 OR ibd.title ~* '\bmicrofiche\b'       
                 OR ibd.title ~* '\bmicrocard\b'        
                 OR ibd.title ~* '\bmicroprint\b'       
                 OR ibd.title ~* 'micro\s*reproduction' 
             ))
            ), 
            false
        ) as is_microform,
        
        true as is_electronic
        
    FROM local_statistics.vs_marc_data_prep ibd
    WHERE 
        -- Only include additional electronic formats with serv,remo location
        (ibd.location_code IS NOT NULL AND 'serv,remo' = ANY(ibd.location_code::text[]))
        AND
        ((ibd.instance_stat_codes IS NOT NULL AND (
            'evideo' = ANY(ibd.instance_stat_codes::text[]) 
            OR 'eaudio' = ANY(ibd.instance_stat_codes::text[])
            OR 'escore' = ANY(ibd.instance_stat_codes::text[])
            OR 'emap' = ANY(ibd.instance_stat_codes::text[])
            OR 'ebk' = ANY(ibd.instance_stat_codes::text[])
        ))
        OR (ibd.marc_948f IS NOT NULL AND (
            'evideo' = ANY(ibd.marc_948f::text[])
            OR 'eaudio' = ANY(ibd.marc_948f::text[])
            OR 'escore' = ANY(ibd.marc_948f::text[])
            OR 'emap' = ANY(ibd.marc_948f::text[])
            OR 'ebk' = ANY(ibd.marc_948f::text[])
        )))
)

-- Final output 
SELECT DISTINCT
	CURRENT_DATE AS table_create_date,
    instance_id,
    record_type_06,
    bib_level_07,
    field_007_00,
    field_008_21,
    marc_245h,
    marc_948f,
    instance_stat_codes,
    special_format_codes,
    location_code,
    library_name,
    call_number,
    call_number_status,
    title,
    calculated_format AS primary_format,
    is_microform,
    is_electronic
FROM instance_formats
WHERE calculated_format IS NOT NULL;

-- Create indexes
CREATE INDEX idx_vs_primary_formats_instance ON local_statistics.vs_primary_formats(instance_id);
CREATE INDEX idx_vs_primary_formats_primary ON local_statistics.vs_primary_formats(primary_format);
CREATE INDEX idx_vs_primary_formats_combo ON local_statistics.vs_primary_formats(instance_id, primary_format);
CREATE INDEX idx_vs_primary_formats_gin_locations ON local_statistics.vs_primary_formats USING gin(location_code);
CREATE INDEX idx_vs_primary_formats_electronic ON local_statistics.vs_primary_formats(is_electronic);
CREATE INDEX idx_vs_primary_formats_microform ON local_statistics.vs_primary_formats(is_microform);

