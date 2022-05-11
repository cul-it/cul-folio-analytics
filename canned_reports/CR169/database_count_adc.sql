--database_count_adc_20220506 ~6 minutes

/*These are the queries A&P uses to report to ACRL/NCES. In FOLIO, the procedure is to indicate databases
 * with instance statistical codes of "fd" or "webfeatdb". In Voyager, these same codes were used in 
 * 948|fs. The 948 coding was not cross-walked to the FOLIO statistical codes, so two queries
 * need to be run and any duplication removed by combinding the 2 resulting datasets of instance ids and removing any
 * duplication. Note that there is also duplication between the use of "fd" and "webfeatdb", so that 
 * duplication is removed through the second and fourth queries below.
 * All of these queries write local tables to local_statistics.
 * 
 * We are also testing this to see if this set of queries should be used for other e-counts. Terms to use:
 * ebks 2M plus
 * j
 * escore 26,590 on 5/10/22 compared to 26,943 recently
 * evideo  18,472 on 5/10/22 compared to 28,883 recently
 * eaudio  173,352 on 5/10/22 compared to 165,957 recently
 * emap  10,256 on 5/10/22 compared to 14,596 recently
 * 
 */

/*These first two queries get counts of databases through the 948 as most databases do not yet have
 *instance statistical codes. See the third and fourth queries to get those newer counts.*/  
--5 minutes; gets count of 4813 on 5/6/22
DROP TABLE IF EXISTS LOCAL_statistics.dbct948_ct_1; 
CREATE TABLE local_statistics.dbct948_ct_1 AS
SELECT DISTINCT
	sm.srs_id,
    sm.instance_hrid,
    sm.field,
    sm.sf,
    sm."content"
FROM srs_marctab sm
LEFT JOIN srs_records sr ON sm.srs_id = sr.id
LEFT JOIN folio_reporting.instance_ext ie ON sm.instance_id = ie.instance_id
WHERE ((sm.field = '948' AND sm.sf = 'f' and sm."content" = 'fd')
OR (sm.field = '948' AND sm.sf = 'f' and sm."content" = 'webfeatdb'))
AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
AND sr.state  = 'ACTUAL'
GROUP BY sm.instance_hrid, sm.srs_id, sm.field, sm.sf, sm."content"--, hsc.statistical_code
;
/*gets distinct instance_hrid count and list*/
-- gets 4295 on 5/6/22 
DROP TABLE IF EXISTS LOCAL_statistics.dbct948_ct_2; 
CREATE TABLE local_statistics.dbct948_ct_2 AS
SELECT DISTINCT 
dbc.instance_hrid 
FROM local_statistics.dbct948_ct_1 dbc
;


/*The next two queries get distinct list of instance ids via the intance statistics codes method.
 * These ids need to be deduplicated with those above.*/
--gets 35 on 5/6/22
DROP TABLE IF EXISTS LOCAL_statistics.dbctstatnotes_ct_1; 
CREATE TABLE local_statistics.dbctstatnotes_ct_1 AS
SELECT
    ie.instance_hrid,
    hsc.statistical_code
FROM folio_reporting.instance_ext ie
LEFT JOIN folio_reporting.instance_statistical_codes hsc ON ie.instance_id = hsc.instance_id
WHERE (hsc.statistical_code IN ('fd','webfeatdb'))
AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
GROUP BY ie.instance_hrid, hsc.statistical_code
;
--gets 28 on 5/6/22. deduplicate in Excel. 12 of these duplciated by above on 5/6/22.
DROP TABLE IF EXISTS LOCAL_statistics.dbctstatnotes_ct_2; 
CREATE TABLE local_statistics.dbctstatnotes_ct_2 AS
SELECT DISTINCT 
dbstat.instance_hrid 
FROM local_statistics.dbctstatnotes_ct_1 dbstat
;

/* Now join the two second sets and dedupe. Note that the UNION command removes duplicates, so the
 * second query is not necessary.*/
--gets 4311 on 10/11/22
DROP TABLE IF EXISTS LOCAL_statistics.dbccombo_ct_1; 
CREATE TABLE local_statistics.dbccombo_ct_1 AS 
(SELECT * FROM local_statistics.dbct948_ct_2 UNION SELECT * FROM local_statistics.dbctstatnotes_ct_2);

--SELECT DISTINCT 
--dbstat.instance_hrid 
--FROM local_statistics.dbccombo_ct_1 dbstat
--;
