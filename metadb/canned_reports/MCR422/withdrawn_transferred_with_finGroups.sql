--MCR422
--Withdrawn and Transferred with College Financial Groups
--This query provides counts of withdrawn and transferred items by college financial group, for quarterly reporting to the Division of Financial Affairs (DFA). 
--Query written by: Vandana Shah (vp25), Natalya Pikulik (np55). Original query written by Joanne Leary (jl41).
--Posted on: 6/29/26

--NOTE: This query creates tables, which can be created in individual schemas. 
--CHANGE DATES IN PARAMETERS AS NEEDED

DROP TABLE IF EXISTS local_statistics.vs_transf_and_withdr;
CREATE TABLE  local_statistics.vs_transf_and_withdr AS
WITH parameters AS
( SELECT
        '20250701' AS start_date,
        '20260630' AS end_date
),
admin_notes AS
(SELECT
        holdings_record.id AS holdings_id,
        holdings_record.jsonb#>>'{hrid}' AS holdings_hrid,
        adminnotes.jsonb#>>'{}' AS holdings_admin_notes,
        adminnotes.ordinality AS admin_notes_ordinality
FROM folio_inventory.holdings_record
CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (holdings_record.jsonb,'administrativeNotes'))
WITH ordinality AS adminnotes (jsonb, ordinality)
LEFT JOIN folio_inventory.location__t AS location__t ON holdings_record.permanentlocationid = location__t.id
WHERE location__t.name != 'serv,remo' and location__t.name NOT ilike 'wood%'
  AND (adminnotes.jsonb#>>'{}' ILIKE '%ttype:t%' OR adminnotes.jsonb#>>'{}' ILIKE '%ttype:w%')
  AND SUBSTRING(SPLIT_PART(adminnotes.jsonb#>>'{}', 'date:', 2), '\d{8}')::date >= TO_DATE((SELECT start_date FROM parameters), 'YYYYMMDD')
  AND SUBSTRING(SPLIT_PART(adminnotes.jsonb#>>'{}', 'date:', 2), '\d{8}')::date < TO_DATE((SELECT end_date FROM parameters), 'YYYYMMDD')
),
-- Extract details from each admin note with better parsing
notes_details AS (
SELECT
        admin_notes.holdings_id,
        admin_notes.holdings_hrid,
        admin_notes.admin_notes_ordinality,
        admin_notes.holdings_admin_notes,
        CASE WHEN holdings_admin_notes ILIKE '%ttype:t%' THEN 'transferred'
             WHEN holdings_admin_notes ILIKE '%ttype:w%' THEN 'withdrawn'
             ELSE NULL
        END AS ttype,
        -- Better parsing of original location - get everything after "orig:" until space or end
        CASE WHEN holdings_admin_notes ILIKE '%orig:%'
             THEN LOWER(TRIM(REGEXP_REPLACE(
                 SPLIT_PART(holdings_admin_notes, 'orig:', 2),
                 '[^a-zA-Z,.]', '', 'g')))
             ELSE NULL
        END AS original_location_code,
        -- Better parsing of piece count - get digits after "pcs:"
        COALESCE(
            CASE WHEN holdings_admin_notes ILIKE '%pcs:%'
                 THEN (REGEXP_MATCH(holdings_admin_notes, 'pcs:(\d+)', 'i'))[1]::int
                 ELSE 1
            END,
            1
        ) AS pieces,
        -- Extract date for verification
        SUBSTRING(SPLIT_PART(holdings_admin_notes, 'date:', 2), '\d{8}') as transaction_date
FROM admin_notes
WHERE (holdings_admin_notes ILIKE '%ttype:t%' OR holdings_admin_notes ILIKE '%ttype:w%')
)
SELECT
    CURRENT_DATE::DATE as report_date,
    instance__t.hrid AS instance_hrid,
    nd.holdings_hrid,
    location__t.name AS current_holdings_location_name,
    COALESCE(loclib1.location_name, nd.original_location_code) AS original_location_name,
    nd.original_location_code,
    nd.pieces,
    nd.ttype,
    nd.transaction_date,
    nd.holdings_admin_notes as full_admin_note
FROM notes_details nd
LEFT JOIN folio_inventory.holdings_record__t ON nd.holdings_id = holdings_record__t.id
LEFT JOIN folio_inventory.location__t AS location__t ON holdings_record__t.permanent_location_id = location__t.id
LEFT JOIN folio_inventory.instance__t ON holdings_record__t.instance_id = instance__t.id
LEFT JOIN local_derived.marc__t ON instance__t.hrid = marc__t.instance_hrid
    AND marc__t.field = '000'
LEFT JOIN local_static.vs_locations_libraries AS loclib1
    ON nd.original_location_code = loclib1.location_code
WHERE nd.ttype IN ('transferred', 'withdrawn')
  AND location__t.name != 'serv,remo'
  AND location__t.name NOT ilike 'wood%'
  AND SUBSTRING(marc__t."content", 7, 1) IN ('a', 't', 'c', 'd')
ORDER BY nd.holdings_hrid, nd.transaction_date, nd.admin_notes_ordinality;
 
--Add financial group and get counts
--Can also set up this section as an automated report (additionally)

DROP TABLE IF EXISTS local_statistics.vs_counts_withdr_transf;
CREATE TABLE local_statistics.vs_counts_withdr_transf AS
WITH financial_groups AS (
    SELECT location_name,
        CASE
            -- Handle NULL locations
            WHEN location_name IS NULL THEN 'Unassigned'
            
            -- Contract colleges - pattern-based
            WHEN location_name ~ '^(gnva|ilr|mann|mnsc|orni|vet|Ent)' THEN 'Contract'
            
            -- WCM - pattern-based  
            WHEN location_name ILIKE '%wood%' OR location_name ILIKE '%medical%' THEN 'WCM'
            
            -- Endowed colleges - pattern-based
            WHEN location_name ~ '^(afr|asia|cons|cts|dcap|ech|engr|fine|hote|jgsm|law|lawr|maps|math|mus|oclc|olin|phys|rmc|sasa|uris|was)' THEN 'Endowed'
            
            -- Everything else is unassigned
            ELSE 'Unassigned'
        END AS financial_group
    FROM (
        SELECT DISTINCT 
            CASE WHEN ttype = 'transferred' THEN original_location_name
                 WHEN ttype = 'withdrawn' THEN current_holdings_location_name END AS location_name
        FROM local_statistics.vs_transf_and_withdr
        UNION
        SELECT DISTINCT current_holdings_location_name 
        FROM local_statistics.vs_transf_and_withdr 
        WHERE ttype = 'transferred'
    ) locations
)

SELECT
CURRENT_DATE AS report_create_date,    
transaction_date,
instance_hrid,
holdings_hrid,
	CASE
        WHEN ttype = 'transferred' THEN original_location_name
        WHEN ttype = 'withdrawn' THEN current_holdings_location_name
    END AS from_location,
    
    CASE
        WHEN ttype = 'transferred' THEN current_holdings_location_name
        WHEN ttype = 'withdrawn' THEN 'WITHDRAWN'
    END AS to_location,
    
    ttype,
    
    from_fg.financial_group AS from_college_financial_group,
    CASE 
        WHEN ttype = 'withdrawn' THEN NULL
        ELSE to_fg.financial_group
    END AS to_college_financial_group,
    
    SUM(pieces) AS total_pieces

FROM local_statistics.vs_transf_and_withdr t
LEFT JOIN financial_groups from_fg ON from_fg.location_name = 
    CASE WHEN ttype = 'transferred' THEN original_location_name
         WHEN ttype = 'withdrawn' THEN current_holdings_location_name END
LEFT JOIN financial_groups to_fg ON to_fg.location_name = current_holdings_location_name 
    AND ttype = 'transferred'

GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY ttype, from_location, to_location;

