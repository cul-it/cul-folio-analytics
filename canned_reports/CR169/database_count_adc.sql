--database_count_adc_20220624 ~6 minutes

--updated 6/16/22: added indicators to review; they are not used consistently enough for even "fd" code.
--updated 6/15/22: added "imagedb" code (adds a few records)

/*These are the queries A&P uses to report its database count to ACRL/NCES. In FOLIO, the procedure is to indicate 
 * databases with instance statistical codes of "fd" or "webfeatdb". In Voyager, these same codes were used in 
 * 948|fs. The 948 coding was not cross-walked to the FOLIO statistical codes, so two queries
 * need to be run and any duplication removed by combinding the 2 resulting datasets of instance ids and removing any
 * duplication. Note that there is also duplication between the use of "fd" and "webfeatdb", so that 
 * duplication is also removed through the second and fourth queries below (repeatable values given in separate
 * rows in the tables used).
 * All of these queries write local tables to local_statistics.
 * 
 * See also 948_with_stat_code_NP20220615 for testing getting other e-counts through
 * this method. 
 */

/*These first two queries get counts of databases through the 948 as most databases do not yet have
 *instance statistical codes. See the third and fourth queries to get those newer counts.*/ 
--https://confluence.cornell.edu/pages/viewpage.action?pageId=326378795#LocalFieldTagsUsedinVoyager(LTSProcedure136V)-A948
--5 minutes; gets count of 4813 on 5/6/22; 4969 on 6/24/22;
DROP TABLE IF EXISTS LOCAL_statistics.dbct948_ct_1; 
CREATE TABLE local_statistics.dbct948_ct_1 AS
SELECT DISTINCT
	sm.srs_id,
    sm.instance_hrid,
    sm.field,
    sm.sf,
    sm.ind1,
    sm.ind2,
    sm."content"
FROM srs_marctab sm
LEFT JOIN srs_records sr ON sm.srs_id = sr.id
LEFT JOIN folio_reporting.instance_ext ie ON sm.instance_id = ie.instance_id
WHERE ((sm.field = '948' AND sm.sf = 'f' and sm."content" = 'fd')
OR (sm.field = '948' AND sm.sf = 'f' and sm."content" = 'webfeatdb')
OR (sm.field = '948' AND sm.sf = 'f' and sm."content" = 'imagedb'))
AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
AND sr.state  = 'ACTUAL'
GROUP BY sm.instance_hrid, sm.srs_id, sm.field, sm.sf, sm.ind1, sm.ind2, sm."content"--, hsc.statistical_code
;
/*gets distinct instance_hrid count and list*/
-- gets 4295 on 5/6/22; gets 4292 on 6/24/22;
DROP TABLE IF EXISTS LOCAL_statistics.dbct948_ct_2; 
CREATE TABLE local_statistics.dbct948_ct_2 AS
SELECT DISTINCT 
dbc.instance_hrid 
FROM local_statistics.dbct948_ct_1 dbc
;


/*The next two queries get distinct list of instance ids via the intance statistics codes method.
 * These ids need to be deduplicated with those above.*/
--gets 35 on 5/6/22; 51 on 6/24/22;
DROP TABLE IF EXISTS LOCAL_statistics.dbctstatnotes_ct_1; 
CREATE TABLE local_statistics.dbctstatnotes_ct_1 AS
SELECT
    ie.instance_hrid,
    hsc.statistical_code
FROM folio_reporting.instance_ext ie
LEFT JOIN folio_reporting.instance_statistical_codes hsc ON ie.instance_id = hsc.instance_id
WHERE (hsc.statistical_code IN ('fd','webfeatdb','imagedb'))
AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
GROUP BY ie.instance_hrid, hsc.statistical_code
;
--gets 28 on 5/6/22. deduplicate in Excel. 12 of these duplciated by above on 5/6/22. 44 on 6/24/22;
DROP TABLE IF EXISTS LOCAL_statistics.dbctstatnotes_ct_2; 
CREATE TABLE local_statistics.dbctstatnotes_ct_2 AS
SELECT DISTINCT 
dbstat.instance_hrid 
FROM local_statistics.dbctstatnotes_ct_1 dbstat
;

/* Now join the two second sets and dedupe. Note that the UNION command removes duplicates, so the
 * second query is not necessary.*/
--gets 4311 on 10/11/22; 4323 on 6/24/22;
DROP TABLE IF EXISTS LOCAL_statistics.dbccombo_ct_1; 
CREATE TABLE local_statistics.dbccombo_ct_1 AS 
(SELECT * FROM local_statistics.dbct948_ct_2 UNION SELECT * FROM local_statistics.dbctstatnotes_ct_2);

--SELECT DISTINCT 
--dbstat.instance_hrid 
--FROM local_statistics.dbccombo_ct_1 dbstat
--;



--This is Natalya's newest 
DROP TABLE IF EXISTS LOCAL_statistics.dbct_allx; 
CREATE TABLE local_statistics.dbct_allx AS

WITH dbsubf AS (
SELECT 
     DISTINCT sm.instance_hrid
    ---hsc.statistical_code
FROM srs_marctab sm
LEFT JOIN srs_records sr ON sm.srs_id = sr.id
LEFT JOIN folio_reporting.instance_ext ie ON sm.instance_id = ie.instance_id
WHERE ((sm.field = '948' AND sm.sf = 'f' and sm."content" = 'fd')
    OR (sm.field = '948' AND sm.sf = 'f' and sm."content" = 'webfeatdb'))
AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
AND sr.state  = 'ACTUAL'
--GROUP BY sm.instance_hrid, sm.srs_id, sm.field, sm.sf, sm."content"--, hsc.statistical_code
),

inst_st_code AS (
SELECT
    DISTINCT ie.instance_hrid
FROM folio_reporting.instance_ext ie
LEFT JOIN folio_reporting.instance_statistical_codes hsc ON ie.instance_id = hsc.instance_id
WHERE (hsc.statistical_code IN ('fd','webfeatdb'))
      AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)), --I added SECOND paren here
--GROUP BY ie.instance_hrid, hsc.statistical_code),

add_together AS (
SELECT d.instance_hrid AS inst_hrid FROM dbsubf d UNION SELECT ie.instance_hrid AS inst_hrid FROM inst_st_code ie)

SELECT count(aa.inst_hrid) 
FROM add_together aa 
;
