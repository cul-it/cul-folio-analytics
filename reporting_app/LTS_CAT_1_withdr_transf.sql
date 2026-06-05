--metadb:function LTS_Holdings_Admin_Notes

DROP FUNCTION IF EXISTS LTS_Holdings_Admin_Notes(date,date,text);
CREATE OR REPLACE FUNCTION LTS_Holdings_Admin_Notes(
    start_date DATE DEFAULT NULL,
    end_date DATE DEFAULT NULL,
    cat_stat_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    instance_id UUID,
    holdings_id UUID,
    holdings_hrid TEXT,
    administrative_note TEXT,
    maint_date DATE,
    perm_loc_name TEXT,
    cat_stat TEXT
)
AS $$
    SELECT 
        h.instanceid AS instance_id,
        h.id AS holdings_id,
        jsonb_extract_path_text(h.jsonb, 'hrid') AS holdings_hrid,
        admin_notes.value AS administrative_note,
        CASE 
            WHEN LOWER(admin_notes.value) ~ 'date:\d{8}'
            THEN TO_DATE(SUBSTRING(admin_notes.value FROM 'date:(\d{8})'),'YYYYMMDD')
            ELSE NULL
        END AS maintnance_date,
        he.permanent_location_name AS "location",
        CASE 
            WHEN LOWER(admin_notes.value) LIKE '%ttype:t%' THEN 'transferred'
            WHEN LOWER(admin_notes.value) LIKE '%ttype:w%' THEN 'withdrawal'
        END AS cataloging_stat
    FROM folio_inventory.holdings_record h
    CROSS JOIN LATERAL
    jsonb_array_elements_text( jsonb_extract_path(h.jsonb, 'administrativeNotes')) AS admin_notes(value)
    LEFT JOIN folio_derived.holdings_ext he ON he.id = h.id
    WHERE jsonb_extract_path(h.jsonb, 'administrativeNotes') IS NOT NULL
    AND (LOWER(admin_notes.value) LIKE '%ttype:t%' 
    OR LOWER(admin_notes.value) LIKE '%ttype:w%')
    -- Date range filter
    AND (start_date IS NULL OR 
        CASE 
            WHEN LOWER(admin_notes.value) ~ 'date:\d{8}'
            THEN TO_DATE(SUBSTRING(admin_notes.value FROM 'date:(\d{8})'),'YYYYMMDD')
            ELSE NULL
        END >= start_date)
    AND (end_date IS NULL OR 
        CASE 
            WHEN LOWER(admin_notes.value) ~ 'date:\d{8}'
            THEN TO_DATE(SUBSTRING(admin_notes.value FROM 'date:(\d{8})'),'YYYYMMDD')
            ELSE NULL
            END <= end_date)
    -- Category status filter
    AND (cat_stat_filter IS NULL OR 
        CASE 
            WHEN LOWER(admin_notes.value) LIKE '%ttype:t%' THEN 'transferred'
            WHEN LOWER(admin_notes.value) LIKE '%ttype:w%' THEN 'withdrawal'
            END = LOWER(cat_stat_filter));
$$
LANGUAGE SQL
STABLE
PARALLEL SAFE;
