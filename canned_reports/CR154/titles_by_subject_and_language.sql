--titles by subject and language

WITH parameters AS
(SELECT
        '%%'::VARCHAR AS subject_filter, -- 'South Asia', 'India', 'Pakistan', 'Nepal', 'Bangladesh', 'Himalaya', 'Ladakh', 'Bhutan', etc.
        'hin'::VARCHAR AS language_filter, -- 'ben','hin','nep','pan','sin','san','urd','pli','tam','mar','asm','tel','pra','pus','nwc','ori','guj', etc.
        'as'::VARCHAR AS format_filter, -- 'as', 'am', etc.
        'South Asia%'::VARCHAR AS location_filter
),
 
-- get languages and subjects
records AS
(SELECT
        ii.id,
        ii.hrid,
        he.holdings_hrid,
        ii.title,
        il.language AS language_code,
        jllc."Language" AS language_name,
        STRING_AGG (DISTINCT "is".subject,' | ') AS subjects,
        he.permanent_location_name,
        CONCAT (he.call_number_prefix, ' ', he.call_number,' ', he.call_number_suffix) AS whole_call_number
       
FROM inventory_instances as ii
        LEFT JOIN folio_reporting.instance_languages AS il
        ON ii.id = il.instance_id
       
        LEFT JOIN folio_reporting.instance_subjects AS "is"
        ON ii.id = "is".instance_id
       
        LEFT JOIN folio_reporting.holdings_ext AS he
        ON ii.id = he.instance_id
       
        LEFT JOIN local.jl_language_codes AS jllc
        ON il.language = jllc.language_code
       
WHERE ((il.language = (SELECT language_filter FROM parameters) OR (SELECT language_filter FROM parameters) =''))
        AND (("is".subject ILIKE (SELECT subject_filter FROM parameters) OR (SELECT subject_filter FROM parameters) =''))
        AND ((il.language_ordinality = 1) OR (il.language_ordinality IS NULL))
        AND ((he.permanent_location_name ILIKE (SELECT location_filter FROM parameters) OR (SELECT location_filter FROM parameters) =''))
 
GROUP BY
        ii.id,
        ii.hrid,
        he.holdings_hrid,
        ii.title,
        il.language,
        jllc."Language",
        he.permanent_location_name,
        CONCAT (he.call_number_prefix, ' ', he.call_number,' ', he.call_number_suffix)
)
 
-- get formats and join to records data
SELECT
        records.hrid,
        records.holdings_hrid,
        records.title,
        records.language_code,
        records.language_name,
        records.subjects,
        records.permanent_location_name,
        records.whole_call_number,
        SUBSTRING (sm.content, 7, 2) AS format_code,
        jlbfd.bib_format_display AS format_name
               
FROM records
        LEFT JOIN srs_marctab AS sm
        ON records.id::VARCHAR = sm.instance_id
       
        LEFT JOIN local.jl_bib_format_display_csv AS jlbfd
        ON substring (sm.content, 7, 2) = jlbfd.bib_format
 
WHERE sm.field = '000'
        AND (SUBSTRING (sm.content, 7, 2) = (SELECT format_filter from parameters) OR (SELECT format_filter FROM parameters)='')
;
 
