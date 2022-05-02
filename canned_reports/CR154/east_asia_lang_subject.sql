WITH parameters AS (
    SELECT
     ---- Fill out one, leave others blank to filter subject or language ----
        '' ::VARCHAR AS subject_filter, -- 'South Asia', 'India', 'Pakistan', 'Nepal', 'Bangladesh', 'Himalaya', 'Ladakh', 'Bhutan'
        'ben'::VARCHAR AS language_filter -- 'ben','hin','nep','pan','sin','san','urd',
                                           -- 'pli','tam','mar','asm','tel','pra','pus','nwc','ori','guj'
),
lang_ext AS
(SELECT 
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    substring(sm.content, 36,3) AS "language"
FROM 
    srs_marctab sm 
WHERE 
    sm.field = '008')
,
format AS (
SELECT DISTINCT 
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    substring(sm."content", 7, 2) AS "format_type"
FROM srs_marctab sm 
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
WHERE (sm.field = '000' AND substring(sm.content, 7, 2) IN ('as','ts')) -- change to whatever format IS needed
)
SELECT
DISTINCT(ls.instance_id),
ls.instance_hrid,
hs.permanent_location_name,
hs.call_number,
f."format_type",
string_agg(DISTINCT i.subject, ' | ') AS subject_headings,
l."language"
FROM lang_ext AS l
LEFT JOIN folio_reporting.instance_ext ls ON l.instance_id = ls.instance_id
LEFT JOIN folio_reporting.holdings_ext hs ON ls.instance_id = hs.instance_id
LEFT JOIN format f ON l.instance_id = f.instance_id 
LEFT JOIN folio_reporting.instance_subjects As i ON ls.instance_id = i.instance_id
WHERE 
(l."language" = (SELECT language_filter FROM parameters) OR (SELECT language_filter FROM parameters) = '')
AND
    (i.subject = (SELECT subject_filter FROM parameters) OR (SELECT subject_filter FROM parameters) = '')
GROUP BY
ls.instance_id, 
ls.instance_hrid,
f."format_type",
hs.permanent_location_name, 
hs.call_number,
l."language"
; 
