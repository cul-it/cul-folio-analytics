--CR164 title_count_servremo_adc_stats-June142022 ~7 minutes
 --6/14/22 updates: removing any requirements by call number.  some records are blank by call number, and so 
 --are dropped.  Also, all the other locs exclusions are not needed.
--earlier update: added sr.state = 'ACTUAL'; added names of the other sets of title queries used;
--added VACUUM ANALYZE; added sql to remove unpurchased pda/dda (had somehow dropped the actual from
--subquery in Query 4 by mistake by 6/23/22; put back in).
 
/* This set of queries pulls counts of titles with holdings locations of serv,remo. Includes any
 * remote electronic resources cataloged on print records.
 * 
 * A&P uses this and two other sets of queries to get the title counts needed for ARL, ACRL 
 * and NCES reporting (CR162 for titles with physical holdings - excluding microform holdings; and
 * CR163 for microform holdings). ARL asks for one title count (all formats). ACRL asks for title 
 * counts by bib format, and by electronic vs. physcial. For ACRL, all serials are counted as serials, 
 * and any non-serial microforms are counted as media. Duplication between formats is to be included.
 * 
 *The first 3 queries create local data tables stored in the "local_statistics" schema. The results
 *of the third query are used by the fourth query to a count of remote e-resources titles by 
 *translated bib format. The fourth query also removes known unpurchased PDA/DDA items via a subquery.
 * 
 *Filtering requiring updates as needed:
 *Query 2: locations to be excluded (review as needed with LTS and unit libraries)
 *Query 4: update the bib_fmt_and_location_trans_table_csv table (review as needed with LTS)
 *Query 4: list of unpurchased PDA/DDA 899 codes to be excluded (review as needed; current expert: You Lee Chun)
 */

 /* Query 1: this query pulls all unspressed records, with leader bib format type from 000 and 
  * date created.*/
-- ~5 min; 8,731,475 Records on 4/15/22; 5 min, 8,711,927 on 6/14/22; 5 min, 8,713,315? on 6/23/22.
DROP TABLE IF EXISTS LOCAL_statistics.titlservr_ct_1; 
CREATE TABLE local_statistics.titlservr_ct_1 AS
SELECT DISTINCT 
	sm.instance_hrid,
    sm.instance_id,
    sm.field,
    substring(sm."content", 7, 2) AS "format_type",
    ie.discovery_suppress,
    ie.record_created_date::date AS date_created
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.instance_ext AS ie ON sm.instance_id = ie.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE sm.field LIKE '000'
    AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
    AND sr.state  = 'ACTUAL'
;
CREATE INDEX ON local_statistics.titlservr_ct_1(instance_hrid);
CREATE INDEX ON local_statistics.titlservr_ct_1(instance_id);
CREATE INDEX ON local_statistics.titlservr_ct_1(field);
CREATE INDEX ON local_statistics.titlservr_ct_1("format_type");
CREATE INDEX ON local_statistics.titlservr_ct_1(discovery_suppress);
CREATE INDEX ON local_statistics.titlservr_ct_1(date_created);
VACUUM ANALYZE local_statistics.titlservr_ct_1;

/*Query 2: Adds holdings information and removes records with locations and statuses not wanted.
 * Gets records with serv,remo locations only (excluding microforms).
 * Holdings records must be unsuppressed*/
-- 1 min; 2,523,159 records on 4/15/22; 1 min, 2,654,854 on 6/14/22; 1 min, 2,654,882 on 6/23/22.
DROP TABLE IF EXISTS local_statistics.titlservr_ct_2; 
CREATE TABLE local_statistics.titlservr_ct_2 AS 
SELECT DISTINCT 
	tc1.instance_id,
    tc1.instance_hrid,
    tc1."format_type",
    h.holdings_hrid,
    h.holdings_id,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress,
    tc1.date_created
    FROM  local_statistics.titlservr_ct_1 AS tc1
    LEFT JOIN  folio_reporting.holdings_ext AS h ON tc1.instance_id=h.instance_id
    WHERE h.permanent_location_name LIKE 'serv,remo'
    /*not needed: AND h.permanent_location_name NOT ilike 'Agricultural Engineering'
    AND h.permanent_location_name NOT ilike 'Bindery Circulation'
    AND h.permanent_location_name NOT ilike 'Biochem Reading Room'
    AND h.permanent_location_name NOT iLIKE 'Borrow Direct'
    AND h.permanent_location_name NOT ilike 'CISER'
    AND h.permanent_location_name NOT ilike 'cons,opt'
    AND h.permanent_location_name NOT ilike 'Engineering'
    AND h.permanent_location_name NOT ilike 'Engineering Reference'
    AND h.permanent_location_name NOT ilike 'Engr,wpe'
    AND h.permanent_location_name NOT ilike 'Entomology'
    AND h.permanent_location_name NOT ilike 'Food Science'
    AND h.permanent_location_name NOT ilike 'Law Technical Services'
    AND h.permanent_location_name NOT ilike 'LTS Review Shelves'
    AND h.permanent_location_name NOT ilike 'LTS E-Resources & Serials'
    AND h.permanent_location_name NOT ilike 'Mann Gateway'
    AND h.permanent_location_name NOT ilike 'Mann Hortorium'
    AND h.permanent_location_name NOT ilike 'Mann Hortorium Reference'
    AND h.permanent_location_name NOT ilike 'Mann Technical Services'
    AND h.permanent_location_name NOT ilike 'Iron Mountain'
    AND h.permanent_location_name NOT ilike 'Interlibrary Loan%'
    AND h.permanent_location_name NOT ilike 'Phys Sci'
    AND h.permanent_location_name NOT ilike 'RMC Technical Services'
    AND h.permanent_location_name NOT ilike 'No Library'
    AND h.permanent_location_name NOT ilike 'x-test'
    AND h.permanent_location_name NOT ilike 'z-test location'*/
    /*this will not work this way because some all numbers blank so records dropped.
     * only a few with %film%, but they are guides.
     * --AND h.call_number !~~* 'on order%'
    --AND h.call_number !~~* 'in process%'
    --AND h.call_number !~~* 'Available for the library to purchase'
    --AND h.call_number !~~* '%film%' 
    --AND h.call_number !~~* '%fiche%'
    --AND h.call_number !~~* '%micro%'
    --AND h.call_number !~~* '%vault%'
    --AND h.call_number !~~* 'On selector%'*/
    AND (h.discovery_suppress = 'FALSE' 
    OR h.discovery_suppress IS NULL )
;
CREATE INDEX ON local_statistics.titlservr_ct_2 (instance_id);
CREATE INDEX ON local_statistics.titlservr_ct_2 (instance_hrid);
CREATE INDEX ON local_statistics.titlservr_ct_2 ("format_type");
CREATE INDEX ON local_statistics.titlservr_ct_2 (holdings_hrid);
CREATE INDEX ON local_statistics.titlservr_ct_2 (holdings_id);
CREATE INDEX ON local_statistics.titlservr_ct_2 (permanent_location_name);
CREATE INDEX ON local_statistics.titlservr_ct_2 (call_number);
CREATE INDEX ON local_statistics.titlservr_ct_2 (discovery_suppress);
CREATE INDEX ON local_statistics.titlservr_ct_2 (date_created);
VACUUM ANALYZE local_statistics.titlservr_ct_2;


/*Query 3: To make title count unique again.*/
-- 1 minute; 2,523,139 rows on 4/15/22; 1 min, 2,653,430 on 6/14/22 with correction; 1 min, 2,653,446 on 6/23/22.
DROP TABLE IF EXISTS local_statistics.titlservr_ct_3; 
CREATE TABLE LOCAL_statistics.titlservr_ct_3 AS 
SELECT distinct
	ft."format_type",
	ft.instance_hrid
FROM local_statistics.titlservr_ct_2 ft
;
CREATE INDEX ON local_statistics.titlservr_ct_3 ("format_type");
CREATE INDEX ON local_statistics.titlservr_ct_3 (instance_hrid);
VACUUM ANALYZE local_statistics.titlservr_ct_3;

--Query 4: Groups and counts titles in titlservr_ct_3 by format, adding format TRANSLATION. Also removes
--known unpurchased PDA/DDA items through a subquery.*/
-- 1 minute; 46 rows group 2,516,100 titles on 4/15/22; gets 2,461,016 on 5/20/22; gets 2,645,976 on 6/14/22;
--gets 46 rows, 2,645,948; 1 min, 46 rows, 2,646,184 with ACTUAL added.
WITH title_unpurch AS 
(SELECT DISTINCT 
	sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm."content",
    ie.discovery_suppress
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.instance_ext AS ie ON sm.instance_id = ie.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE sm.field LIKE '899'
    AND sm.sf LIKE 'a'
    AND ((sm."content" ILIKE 'DDA_pqecebks') 
    OR (sm."content" ILIKE 'DDA_eastvwebksmu')
    OR (sm."content" ILIKE ' DDA_eastvwebksmu')
    OR (sm."content" ILIKE 'DDA_esatvwebksmu')
    OR (sm."content" ILIKE 'DDA_casaliniebkmu')
    OR (sm."content" ILIKE 'Appr_eastvwebks'))
    --OR (sm."content" ILIKE 'Couttspdbappr'))
    AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
    AND sr.state  = 'ACTUAL' --I added this back ON 6/23/22
)
SELECT DISTINCT 
tc3."format_type" AS "Bib Format",
bft.bib_format_display,
count(tc3.instance_hrid) AS "Total"
FROM local_statistics.titlservr_ct_3 tc3
LEFT JOIN local_statistics.bib_fmt_and_location_trans_tables_csv bft ON tc3."format_type" = bft.bib_format
LEFT JOIN title_unpurch ON tc3.instance_hrid = title_unpurch.instance_hrid
WHERE title_unpurch.instance_hrid IS NULL
GROUP BY tc3."format_type", bft.bib_format_display
ORDER BY bft.bib_format_display
; 
