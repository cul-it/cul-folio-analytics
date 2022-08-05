--title_count_servremo_viaculcodes_adc_20220804
/*This is the query currently (FY22) used by A&P for the annual data collection for serv,remo title counts.
 *It is based on codes assigned by CUL, rather than coding in the instance leader, as the assigned
 *codes are thought to be more accurate.  These CUL-assigned codes also have their issues (e.g., not all e-resources
 *have these codes), but we will work to make sure they are more accurate in FY23.
 *This query was originally written by Natalya for ebook counts (hence some of the table names). 
 *It has been modified to include all types of e-resources that CUL has coded for.
 *First run the first query to get ebooks_all.  Then run the shorter second query to get summed counts with instance
 *format.
 */
--Change tracking (sorry this is not yet neat - for Linda's use):
--was 948_with_stat_codeNP20220628withall when ran in FY22.
--6/15/22: Natalya wrote this to get ebook counts through coding. 
--6/28/28: added a grouped by to the 3rd query.
--6/28/22: saw that removing the grouping from the first query addes several hundred counts and messes up 
--sort some; in ebks_all, there are ebk_identifiers with multiple workds: ebk, ebk, ebk
--6/28/22 updated to include all format codes. and added to the final query that results should include code first.
--6/28/22: we added that the 3 query should indicate should be actual.
--I added full bib format. In union query removed location field and added bib format.
--Added a short query to get counts by format.
--Can use this set of queries for other formats by updating the codes in the later subqueries; but uses
--indicator 1, so not usable for webfeatdb unless you modify.
--The second query uses a derived table that breaks each stat code out separately if repeated. The 
--948 also seems to be repeatable and codes entered separately; so not sure why stringagg used?
--Review each year: codes to be searched for.
--for 948|f, first indicator is supposed to be 1, except for webfeatdb, which is supposed to be 2 and have 
--|b of m.  But I'm getting very different counts with this query that with the previous db count query written.
--other codes:
/* j for journals
 * evideo for visual?
 * eaudio for audio
 *emap for maps
 *escore for scores
 *fd or webfeatdb or imagesdb
 *ewb = webpage
 *emisc = other*/
--https://confluence.cornell.edu/x/KyV0Ew
--6/16/22 tryhing it without indicator field.
--trying with just instance id in the union query 6/17/ doesn't appear to make a difference.
--trying 948 codes with % around - doesn't work

DROP TABLE IF EXISTS local_statistics.ebks_all;
CREATE TABLE local_statistics.ebks_all AS
--select all records in serv, remo location
 WITH ebks AS (SELECT
    sm.instance_hrid,
    sm.instance_id,
    ie.title,
    substring(sm.content, 7, 2)::text AS "format_type",
    he.permanent_location_name AS perm_location
    FROM  srs_marctab sm
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    LEFT JOIN folio_reporting.instance_ext ie ON sm.instance_id = ie.instance_id
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
WHERE (sm.field = '000')
AND sr.state  = 'ACTUAL'
AND he.permanent_location_name LIKE 'serv,remo'
AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
GROUP BY sm.instance_hrid,sm.instance_id, ie.title,sm.CONTENT,he.permanent_location_name -- taking this out adds some data and separates some counts 
),
--select only the records that have statistical code of 'ebk' from "ebks" subquery
ebks_stats AS(
SELECT
    e.instance_hrid,
    e."format_type",
    string_agg(isc.statistical_code, ', ') AS ebk_identifier
    FROM ebks AS e
    LEFT JOIN folio_reporting.instance_statistical_codes isc ON e.instance_id=isc.instance_id
WHERE isc.statistical_code IN ('fd','webfeatdb','imagedb','ebk','j','evideo','eaudio','escore','ewb','emap','emisc')
GROUP BY e.instance_hrid, e."format_type", isc.statistical_code
), -- i this line added back 6/28/22
--select only the records that have 948 "f" = ebk from "ebks" subquery
ebks_948 AS (
SELECT
    e.instance_hrid,
    e."format_type",
    sm.content AS ebk_identifier
    FROM  ebks AS e
    LEFT JOIN srs_marctab sm ON e.instance_hrid = sm.instance_hrid -- DO we need actual here?
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id -- I added 6/28/22
    --WHERE (sm.field = '948' AND sm.ind1 = '1' AND sm.sf = 'f' AND sm.content IN ('fd','webfeatdb','imagedb'))
    --WHERE (sm.field = '948' AND sm.ind1 = '2' AND sm.sf = 'f' AND sm.content IN ('fd','webfeatdb','imagedb'))
    WHERE (sm.field = '948' AND sm.sf = 'f' AND sm.content IN ('fd','webfeatdb','imagedb','ebk','j','evideo','eaudio','escore','ewb','emap','emisc'))
    AND sr.state  = 'ACTUAL' -- I added 6/28/22
    GROUP BY e.instance_hrid, e."format_type", ebk_identifier -- I added this 6/28/22
)
--combine both selected records with statistical code and 948"f"
SELECT
es.instance_hrid,
es."format_type",
es.ebk_identifier
FROM ebks_stats es
UNION SELECT
eb.instance_hrid,
eb."format_type",
eb.ebk_identifier
FROM ebks_948 eb
;


--this is my addition to break out by format and be sure distinct.
SELECT 
eba.ebk_identifier,
eba."format_type",
count(DISTINCT eba.instance_hrid)
FROM local_statistics.ebks_all eba
GROUP BY eba.ebk_identifier,eba."format_type"
ORDER BY eba.ebk_identifier, eba."format_type";
