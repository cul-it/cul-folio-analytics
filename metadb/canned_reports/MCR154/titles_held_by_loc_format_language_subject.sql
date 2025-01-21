--MCR154
--titles_held_by_loc_format_language_subject

-- This query shows titles held with format, languagge and subject info. 
-- Select a location. Also filter by language code, bibliographic format, and subject word.


--set parameters if wanted

WITH parameters AS
(SELECT
        '%%'::VARCHAR AS subject_filter, -- 'South Asia', 'India', 'Pakistan', 'Nepal', 'Bangladesh', 'Himalaya', 'Ladakh', 'Bhutan', etc.
        ''::VARCHAR AS language_filter, -- 'ben','hin','nep','pan','sin','san','urd','pli','tam','mar','asm','tel','pra','pus','nwc','ori','guj', etc.
        'as'::VARCHAR AS format_filter, -- 'as', 'am', etc.
        '%%'::VARCHAR AS location_filter, -- Use internal name AT https://confluence.cornell.edu/display/folioreporting/Locations
        'Mui Ho%'::VARCHAR AS library_filter -- use inventory_libraries.name AT https://confluence.cornell.edu/display/folioreporting/Locations
),

--make a table of instance record's leader formats
marc_formats AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring(marc__t."content", 7, 2) AS leader0607
       FROM folio_source_record.marc__t 
       WHERE marc__t.field = '000'
),

--make a table of instances languages with ordinality
instance_languages AS
(SELECT
    instances.id AS instance_id,
    jsonb_extract_path_text(instances.jsonb, 'hrid') AS instance_hrid,
    languages.jsonb #>> '{}' AS instance_language,
    languages.ordinality AS language_ordinality
FROM
    folio_inventory.instance AS instances
    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(jsonb, 'languages')) WITH ORDINALITY AS languages (jsonb)
),

--make a table of instance record subject headings
instance_subjects AS 
(SELECT 
    i.id AS instance_id,
    jsonb_extract_path_text(i.jsonb, 'hrid') AS instance_hrid,
    s.jsonb #>> '{value}' AS subjects,
    s.ordinality AS subjects_ordinality
FROM 
    folio_inventory.instance AS i
    CROSS JOIN LATERAL jsonb_array_elements(jsonb_extract_path(i.jsonb, 'subjects')) WITH ORDINALITY AS s (jsonb)
)--,

-- get the records wanted

SELECT
        ii.id,
        jsonb_extract_path_text (ii.jsonb,'hrid') AS instance_hrid,
        holdrect.hrid AS holdings_hrid,
        jsonb_extract_path_text (ii.jsonb,'title') AS title,
        instlang.instance_language,
        mcll.marc_language_name AS language_name,
        marcfmt.leader0607,
        pmf.folio_format_type,
        STRING_AGG (DISTINCT instsub.subjects,' | ') AS subjects,
        loc__t.name AS permanent_location_name,
        loclib__t.name AS Library_name,
        CONCAT (holdrect.call_number_prefix, ' ', holdrect.call_number,' ', holdrect.call_number_suffix) AS whole_call_number
       
FROM   folio_inventory.instance AS ii
                             
                             LEFT JOIN marc_formats AS marcfmt 
                             ON marcfmt.instance_id = ii.id

                             LEFT JOIN instance_languages AS instlang
                             ON instlang.instance_id = ii.id

                             LEFT JOIN instance_subjects AS instsub
                             ON instsub.instance_id = ii.id
        
        LEFT JOIN folio_inventory.holdings_record AS holdrec
        ON holdrec.instanceid = ii.id
        
        LEFT JOIN folio_inventory.holdings_record__t AS holdrect
        ON holdrec.instanceid = holdrect.instance_id
        
        LEFT JOIN folio_inventory.location__t AS loc__t 
        ON holdrect.permanent_location_id = loc__t.id 
        
        LEFT JOIN folio_inventory.loclibrary__t AS loclib__t
        ON loc__t.library_id = loclib__t.id
       
        LEFT JOIN local_shared.lm_marc_code_list_for_languages AS mcll
       ON instlang.instance_language = mcll.marc_language_code
       
       LEFT JOIN local_shared.vs_folio_physical_material_formats AS pmf
       ON marcfmt.leader0607 = pmf.leader0607 
       
WHERE ((instlang.instance_language = (SELECT language_filter FROM parameters) OR (SELECT language_filter FROM parameters) =''))
        AND ((instsub.subjects ILIKE (SELECT subject_filter FROM parameters) OR (SELECT subject_filter FROM parameters) =''))
        AND ((instlang.language_ordinality = 1) OR (instlang.language_ordinality IS NULL))
        AND ((marcfmt.leader0607 = (SELECT format_filter FROM parameters) OR (SELECT format_filter FROM parameters) =''))
        AND ((loc__t.name ILIKE (SELECT location_filter FROM parameters) OR (SELECT location_filter FROM parameters) =''))
        AND ((loclib__t.name ILIKE (SELECT library_filter FROM parameters) OR (SELECT library_filter FROM parameters) = ''))
        
GROUP BY
        ii.id,
        jsonb_extract_path_text (ii.jsonb, 'hrid'),
        holdrect.hrid,
        jsonb_extract_path_text (ii.jsonb, 'title'),
        instlang.instance_language,
        mcll.marc_language_name,
        marcfmt.leader0607,
        pmf.folio_format_type,
        loc__t.name,
        loclib__t.name,
        CONCAT (holdrect.call_number_prefix, ' ', holdrect.call_number,' ', holdrect.call_number_suffix)
        ;

