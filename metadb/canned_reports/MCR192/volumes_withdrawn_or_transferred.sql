--MRC192 – Volumes withdrawn or transferred
--Query writers: Joanne Leary (jl41), Vandana Shah(vp25)

--04/9/26 - Query updated to account for information (piece count, original location) that was not always caputured in the earlier version due to non-uniform data entry in Folio.

--CHANGE DATE PARAMETERS AS NEEDED
 WITH parameters AS 
(
    SELECT 
        '20260101' AS start_date,
        '20260401' AS end_date
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
        WITH ordinality AS adminnotes (jsonb, ordinality)

),

hlgsnotes AS 
(SELECT
        holdings_record.id AS holdings_id,
        holdings_record.jsonb#>>'{hrid}' AS holdings_hrid,
        STRING_AGG (holdnotes.jsonb#>>'{note}',' | ' ORDER BY holdnotes.ordinality) AS holdings_notes
         
        
        FROM folio_inventory.holdings_record 
        CROSS JOIN LATERAL jsonb_array_elements (jsonb_extract_path (holdings_record.jsonb,'notes')) 
        WITH ordinality AS holdnotes (jsonb, ordinality)
        
        
        
        GROUP BY 
        holdings_record.id,
        holdings_record.jsonb#>>'{hrid}'
        ),
        
 --  select text that follows 'orig'
 
 notes_details AS  ( 
 
SELECT
        admin_notes.holdings_hrid,

 CASE
            WHEN holdings_admin_notes ILIKE '%ttype:t%' THEN 'transferred'
            WHEN holdings_admin_notes ILIKE '%ttype:w%' THEN 'withdrawn'
            ELSE NULL
        END AS ttype,

CASE
    WHEN holdings_admin_notes ILIKE '%orig:%'
        THEN TRIM(SPLIT_PART(LOWER(holdings_admin_notes), 'orig:', 2))
    ELSE NULL
END AS location_source_segment,
            
--  original location code (derived from 'orig', max 2 words, change to lowercase, seperate by comma, no spaces) 
            LOWER(REGEXP_REPLACE(SPLIT_PART(TRIM(SPLIT_PART(LOWER(holdings_admin_notes),  'orig', 2)),
            ' ', 1), '[:0-9]', '', 'g')) AS original_location_code

--COALESCE(NULLIF((regexp_match(holdings_admin_notes, 'pcs:\s*([0-9]+)', 'i'))[1], '')::int, 1) AS pieces

FROM admin_notes
),    
   
pieces_count AS (
SELECT 
       holdings_hrid,
        administrative_note,
        substring (administrative_note,'\d{8}') as date,
        case 
                when substring (split_part (administrative_note,'pcs',2),'\d{1,3}')::int is null then 1
                when substring (split_part (administrative_note,'pcs',2),'\d{1,3}')::int > 500 then 1 
                else substring (split_part (administrative_note,'pcs',2),'\d{1,3}')::int 
                end as pieces

FROM folio_derived.holdings_administrative_notes as han
WHERE
        (han.administrative_note like '%ttype:t%' or han.administrative_note like '%ttype:w%')
       -- and substring (han.administrative_note,'\d{8}') >='20260101' and substring (han.administrative_note,'\d{8}') <'20260404'

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
    loclib.college_financial_group,
    notes_details.location_source_segment,
   	loclib1.college_financial_group AS original_financial_group,
    notes_details.original_location_code,
    loclib1.location_name AS original_location_name,
    pieces_count.pieces,
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
        WHEN date_part('month', SUBSTRING(admin_notes.holdings_admin_notes, '\d{8}')::date) > 6
            THEN CONCAT('FY ', date_part('year', SUBSTRING(admin_notes.holdings_admin_notes, '\d{8}')::date) + 1)
        ELSE CONCAT('FY ', date_part('year', SUBSTRING(admin_notes.holdings_admin_notes, '\d{8}')::date))
    END AS fiscal_year,

    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 2), '\d{8}')::date AS note_date,
    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 4), '[a-z]{2,3}\d{1,3}') AS netid,
    SUBSTRING(SPLIT_PART(admin_notes.holdings_admin_notes, ':', 5), '[a-z]{3,4}') AS unit,
    notes_details.ttype
    
    FROM admin_notes
LEFT JOIN folio_inventory.holdings_record__t 
    ON admin_notes.holdings_id = holdings_record__t.id
LEFT JOIN hlgsnotes 
    ON holdings_record__t.id = hlgsnotes.holdings_id
LEFT JOIN notes_details
    ON admin_notes.holdings_hrid = notes_details.holdings_hrid
LEFT JOIN pieces_count
	ON pieces_count.holdings_hrid = admin_notes.holdings_hrid
LEFT JOIN folio_inventory.location__t AS location__t
    ON holdings_record__t.permanent_location_id = location__t.id
LEFT JOIN folio_inventory.instance__t 
    ON holdings_record__t.instance_id = instance__t.id 
LEFT JOIN local_derived.marc__t 
    ON instance__t.hrid = marc__t.instance_hrid 
LEFT JOIN local_static.vs_locations_libraries AS loclib
     ON holdings_record__t.permanent_location_id = loclib.location_id::UUID
LEFT JOIN local_static.vs_locations_libraries AS loclib1
ON NULLIF (notes_details.original_location_code, '') = loclib1.location_code
WHERE notes_details.ttype IN ('transferred', 'withdrawn')
 AND location__t.name != 'serv,remo'
 AND (marc__t.field = '000' AND SUBSTRING(marc__t."content", 7, 1) IN ('a', 't', 'c', 'd'))
  
AND SUBSTRING(
            SPLIT_PART(admin_notes.holdings_admin_notes, ':', 2),
            '\d{8}'
        )::date >= TO_DATE((SELECT start_date FROM parameters), 'YYYYMMDD')
    AND SUBSTRING(
            SPLIT_PART(admin_notes.holdings_admin_notes, ':', 2),
            '\d{8}'
        )::date < TO_DATE((SELECT end_date FROM parameters), 'YYYYMMDD');
