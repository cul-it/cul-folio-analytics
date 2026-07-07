--MCR 421
-- Materials Counts (4) - Materials Counts
--Query writer: Vandana Shah (vp25), Claude AI
--Date posted: 6/22/26
--NOTE: TABLES CAN BE CREATED IN INDIVIDUAL SCHEMAS; the local_statistics schema is restricted.

--Note: there are two separate queries for counts Items and instances). Run them individually. 

/*==========================================================================
 Query 1: Physical Items Count
============================================================================*/

WITH fiscal_year_data AS (
    SELECT 
        item.id as item_id,
        pf.instance_id,
        pf.primary_format,
        pf.is_microform,
        lib.name as library_name,
        loc.code as location_code,
        CASE       
            WHEN DATE_PART('month', (item_raw.jsonb#>>'{metadata,createdDate}')::date) > 6 
            THEN CONCAT('FY ', DATE_PART('year', (item_raw.jsonb#>>'{metadata,createdDate}')::date) + 1) 
            ELSE CONCAT('FY ', DATE_PART('year', (item_raw.jsonb#>>'{metadata,createdDate}')::date))
        END AS record_created_fiscal_year
        
    FROM local_statistics.vs_primary_formats pf
    JOIN folio_inventory.holdings_record__t hr ON pf.instance_id = hr.instance_id
    JOIN folio_inventory.location__t loc ON hr.permanent_location_id = loc.id
    JOIN folio_inventory.loclibrary__t lib ON loc.library_id = lib.id
    JOIN folio_inventory.item__t item ON hr.id = item.holdings_record_id
    LEFT JOIN folio_inventory.item item_raw ON item.id = item_raw.id  -- For createdDate access
    
    /*filtering out inactive locations, suppressed instance and holdings records, 
    and null or Wood libnames */
    WHERE 
        pf.is_electronic = false
        AND (hr.discovery_suppress = false OR hr.discovery_suppress IS NULL)
        AND loc.is_active = true
        AND (lib.name IS NULL OR (
            lib.name NOT ILIKE '%Wood%' AND lib.name NOT ILIKE '%WCM%'
        ))
        AND (item_raw.jsonb#>>'{metadata,createdDate}') IS NOT NULL
	
	/*FOR QUARTERLY COUNTS ONLY: set dates as needed
	  AND (item_raw.jsonb#>>'{metadata,createdDate}')::date >= '2026-04-01'
        AND (item_raw.jsonb#>>'{metadata,createdDate}')::date < '2026-07-01'
	*/
)

SELECT 
	CURRENT_DATE AS todays_date,
    record_created_fiscal_year,
    primary_format,
    library_name,
    location_code,
    is_microform,
    is_microform,
            CASE
            WHEN location_code IS NULL THEN 'Unassigned'
            WHEN location_code ~* '^(gnva|ilr|mann|mnsc|orni|vet|ent)' THEN 'Contract'
            WHEN location_code ILIKE '%wood%' OR location_code ILIKE '%medical%' THEN 'WCM'
            WHEN location_code ~* '^(afr|asia|cons|cts|dcap|ech|engr|fine|hote|jgsm|law|lawr|maps|math|mus|oclc|olin|phys|rmc|sasa|uris|was)' THEN 'Endowed'
            ELSE 'Unassigned'
        END AS financial_group,
    COUNT(DISTINCT item_id) as total_physical_items
       
FROM fiscal_year_data
GROUP BY current_date, record_created_fiscal_year, primary_format, is_microform, financial_group, library_name, location_code

/*==============================================================================================================================================
QUERY 2: INSTANCE COUNTS
============================================================================================================================================*/
	SELECT primary_format, COUNT(DISTINCT instance_id) as instance_count,
location_code, library_name, is_microform, is_electronic
FROM local_statistics.vs_primary_formats_flattened
WHERE library_name NOT ILIKE '%Wood%'
  AND library_name NOT ILIKE '%WCM%'
  GROUP BY primary_format,is_microform, is_electronic, location_code, library_name;
ORDER BY record_created_fiscal_year, library_name, location_code, primary_format;

  AND library_name NOT ILIKE '%WCM%'
  GROUP BY current_date, primary_format,is_microform, is_electronic, location_code, library_name;
