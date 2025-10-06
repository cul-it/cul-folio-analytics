--MRC192 – Volumes withdrawn or transferred

--10/1/25: VS made a few additions; added date range and dfs college group for original location. 


--3-26-25: this is an alternative to using derived tables for MCR192 - volumes withdrawn or transferred 
--  This query gets the ttype code, date, number of pieces, and other information from the 'administrativeNotes' field of the holdings_record table. 
--  This uses the "SPLIT_PART" function to parse out the components of the administrative note
--  The query takes about 3 minutes to run, but gets up-to-the-minute results. The query with the derived tables takes about 30 seconds to run.
--Date?: JL updated the query to account for the possible blank spaces in the piece count calculation, 
--  and cast the piece count “Case when” statement as Integer; added a location__t.name != ’serv,remo’
--  in the WHERE clause to get rid of those stragglers. 
--July 2025: LM added location code so those removed in MCR214 could be removed (manually, not to slow query down more).
--  Also started to add SQL to remove microforms, but then commented out so as not to slow down, so must address this in results through call nubmers and titles.
--  Similarly need to address location codes that are removed in MCR214 and address bound-withs through holdings notes.
--7-16-25: JL updated pieces formula to capture piece counts from split_parts 5, 6 or 7
--  added "distinct" to the last subquery*; commented out admin_notes ordinality(LM added this back).
--  JL found the first run took 22 minutes, and subsequent runs 3 minutes.
--  (JL determined that keeping the admin notes ordinality does not cause duplication, so it’s OK to keep it in.
--  *JL still doens't know what caused the one duplicate record I found in the FY25 run (no longer included), but she says it probably 
--   had something to do with the holdings notes (aggregated) and the holdings administrative notes (not aggregated).)
 

--change date parameters for correct quarter
 WITH parameters AS 
(
    SELECT 
        '20250701' AS start_date, 
        '20251001' AS end_date
),

admin_notes AS 
(SELECT
        holdings_record.id AS holdings_id,
        holdings_record.jsonb#>>'{hrid}' AS holdings_hrid,
        adminnotes.jsonb#>>'{}' AS holdings_admin_notes,
        adminnotes.ordinality AS admin_notes_ordinality, 
        TO_DATE((SELECT start_date FROM parameters), 'YYYYMMDD') AS start_date,
        TO_DATE((SELECT end_date FROM parameters), 'YYYYMMDD') AS end_date
        FROM folio_inventory.holdings_record
        CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (holdings_record.jsonb,'administrativeNotes'))
        WITH ordinality AS adminnotes (jsonb)
),

hlgsnotes AS 
(SELECT
        holdings_record.id AS holdings_id,
        holdings_record.jsonb#>>'{hrid}' AS holdings_hrid,
        STRING_AGG (holdnotes.jsonb#>>'{note}',' | ' ORDER BY holdnotes.ordinality) AS holdings_notes
        
        FROM folio_inventory.holdings_record 
        CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (holdings_record.jsonb,'notes')) 
        WITH ordinality AS holdnotes (jsonb)
        
        GROUP BY 
        holdings_record.id,
        holdings_record.jsonb#>>'{hrid}'
)

SELECT DISTINCT
    CURRENT_DATE::DATE,
    CONCAT(admin_notes.start_date, ' to ', admin_notes.end_date) AS date_range,
    instance__t.title,
    instance__t.discovery_suppress AS instance_suppress,
    holdings_record__t.discovery_suppress AS holdings_suppress,
    SUBSTRING(marc__t."content", 7, 2) AS format_code,
    instance__t.hrid AS instance_hrid,
    admin_notes.holdings_hrid,
    location__t.name AS holdings_location_name,
    location__t.code AS holdings_location_code,
    adclt.dfs_college_group,
    adclt1.adc_invloc_location_name AS original_holdings_location_name,
    TRIM(LOWER(SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 7), '\s{0,1}[a-zA-Z]{1,}[,]{0,1}\s{0,}[a-zA-Z]{0,}'))) AS original_holdings_location_code,
    admin_notes.admin_notes_ordinality,
    adclt1.dfs_college_group AS original_dfs_college_group,
    TRIM(CONCAT(
        holdings_record__t.call_number_prefix, ' ',
        holdings_record__t.call_number, ' ',
        holdings_record__t.call_number_suffix,
        CASE 
            WHEN holdings_record__t.copy_number > '1' THEN CONCAT('c.', holdings_record__t.copy_number) 
            ELSE '' 
        END
    )) AS holdings_call_number,
    hlgsnotes.holdings_notes,
    admin_notes.holdings_admin_notes,
    CASE 
        WHEN date_part('month', SUBSTRING(admin_notes.holdings_admin_notes, '\d{1,}')::date) > 6
            THEN CONCAT('FY ', date_part('year', SUBSTRING(admin_notes.holdings_admin_notes, '\d{1,}')::date) + 1)
        ELSE CONCAT('FY ', date_part('year', SUBSTRING(admin_notes.holdings_admin_notes, '\d{1,}')::date))
    END AS fiscal_year,
    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 2), '\d{8}') AS note_date,
    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 3), '[a-z]{1}') AS ttype_code,
    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 4), '[a-z]{2,3}\d{1,3}') AS netid,
    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 5), '[a-z]{3,4}') AS unit,
    (
        TRIM(CASE 
            WHEN SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 5), '\d{1,}') IS NULL 
                AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 6), '\d{1,}') IS NULL 
                AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 7), '\d{1,}') IS NULL
                THEN '1'
            WHEN SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 5), '\d{1,}') IS NULL 
                AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 6), '\d{1,}') IS NULL 
                AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 7), '\d{1,}') IS NOT NULL
                THEN SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 7), '\d{1,}')
            WHEN SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 5), '\d{1,}') IS NULL 
                AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 6), '\d{1,}') IS NOT NULL
                THEN (
                    CASE 
                        WHEN SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 6), '\d{0,}') > ' %'
                            THEN SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 6), '\d{1,}')
                        ELSE SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 6), '\s{0,}\d{0,4}')
                    END
                )
            ELSE SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 5), '\d{1,}')
        END)
    )::int AS pieces

FROM admin_notes
LEFT JOIN folio_inventory.holdings_record__t 
    ON admin_notes.holdings_id = holdings_record__t.id
LEFT JOIN hlgsnotes 
    ON holdings_record__t.id = hlgsnotes.holdings_id
LEFT JOIN folio_inventory.location__t 
    ON holdings_record__t.permanent_location_id = location__t.id
LEFT JOIN folio_inventory.instance__t 
    ON holdings_record__t.instance_id = instance__t.id 
LEFT JOIN folio_source_record.marc__t 
    ON instance__t.hrid = marc__t.instance_hrid 
LEFT JOIN local_static.lm_adc_location_translation_table AS adclt 
    ON holdings_record__t.permanent_location_id = adclt.inv_loc_id::UUID
LEFT JOIN local_static.lm_adc_location_translation_table AS adclt1
    ON TRIM(LOWER(SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 7), '\s{0,1}[a-zA-Z]{1,}[,]{0,1}\s{0,}[a-zA-Z]{0,}'))) = adclt1.adc_invloc_location_code        

WHERE admin_notes.holdings_admin_notes ILIKE '%ttype%'
    AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 3), '[a-z]{1}') IN ('t', 'w')
    AND (marc__t.field = '000' AND SUBSTRING(marc__t."content", 7, 1) IN ('a', 't', 'c', 'd'))
    AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 2), '\d{8}') >= (SELECT start_date FROM parameters)
    AND SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 2), '\d{8}') < (SELECT end_date FROM parameters)
    AND location__t.name != 'serv,remo'

ORDER BY title, holdings_hrid, note_date
;


