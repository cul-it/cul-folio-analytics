--AHR133
--Median Year of Publication for Print Monographs
--Query writer: Joanne Leary (jl41)
--Query reviewer: Vandana Shah (vp25)
--Date posted: 8/16/23
/*This query finds the median year of publication for the print monograph collection. First the query identifies the set of records that met the criteria for print monograph (and that had an actual numeric publication date), then it applies the expression for median value. Requested by Adam Chandler. */

WITH pubs AS 
(SELECT 
       sm.instance_id::varchar,
       sm.instance_hrid,
       substring (sm.content,8,4) AS year_of_publication

FROM srs_marctab AS sm 
WHERE sm.field = '008'
),

-- 2. Find all monographs that are not electronic resources and are not suppressed, and join them to year of publication. 
-- Exclude non-numeric characters from year of publication, and cast as integer to find the median value from that ordered list

recs AS 
(SELECT DISTINCT
       ii.id,
       pubs.instance_hrid,
       moi.name AS mode_of_issuance,
       ii.title,
       pubs.year_of_publication

FROM inventory_instances AS ii 
       LEFT JOIN folio_reporting.holdings_ext AS he 
       ON ii.id = he.instance_id 
       
       LEFT JOIN inventory_modes_of_issuance AS moi
       ON ii.mode_of_issuance_id = moi.id
       
       LEFT JOIN pubs
       ON ii.id::varchar = pubs.instance_id

WHERE moi.name IN ('single unit','multipart monograph')
       AND he.type_name ILIKE '%monograph%'
       AND he.permanent_location_name != 'serv,remo'
       AND (he.discovery_suppress = 'False' OR he.discovery_suppress IS NULL)
       AND (ii.discovery_suppress = 'False' OR ii.discovery_suppress IS NULL)
       AND pubs.year_of_publication NOT LIKE '%u%'
       AND pubs.year_of_publication NOT LIKE '%|%'
       AND pubs.year_of_publication NOT LIKE '% %'
       AND pubs.year_of_publication NOT LIKE '%x%'
       AND pubs.year_of_publication NOT LIKE '%s%'
       AND pubs.year_of_publication NOT LIKE '%n%'
       AND pubs.year_of_publication NOT LIKE '%?%'
       AND pubs.year_of_publication NOT LIKE '%y%'
       AND pubs.year_of_publication NOT LIKE '%/%'
       AND pubs.year_of_publication NOT LIKE '%[%'
       AND pubs.year_of_publication NOT LIKE '%]%'
)

SELECT 
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY recs.year_of_publication::integer)::varchar AS median_pub_year,
       COUNT (distinct recs.instance_hrid) AS number_of_instances

FROM recs
;
