/* phys_serial_titles_currrec_adc_2022_05_10.sql (physical serial titles currently received) ~3 minutes
 * This is the set of queries used to count physical serial titles currently received for the CUL annual
 * data collection. See separate query for e-resource titles.
 * Experts consulted: Liisa and Pam
 * 
 *Query 1: Creates table local_statistics.sercurr_ct_1 with title, order and holdings information for
 *titles where:
 *   -purchase order type is 'Ongoing'
 *   -holdings receipt status is 'Currently received'
 *   -intance and holdings records are not suppressed
 *   -holdings permanent location is not 'serv,remo'
 *   -holdings permanent locations are not locations we don't include in our counts
 *     because they are not owned by the library, or are not available to users, etc.
 *   -holdings call number is not 'on order%', 'in process%', 'Available for the library to purchase',
 *     or 'On selector%'
 *   -(the latter 2 points do not remove much, but do remove some)
 */   
--on 5/5/22 gets 14,515 rows
DROP TABLE IF EXISTS local_statistics.sercurr_ct_1;    
CREATE TABLE local_statistics.sercurr_ct_1 AS
    SELECT
    poi.pol_instance_id,
    poi.pol_instance_hrid,
    poi.title,
    poi.po_wf_status,
    poi.pol_location_name,
    ppo.order_type,
    ie.instance_hrid,
    he.holdings_hrid,
    he.receipt_status,
    he.permanent_location_name,
    he.call_number
    FROM folio_reporting.po_instance poi 
    LEFT JOIN po_lines pl ON poi.po_line_number = pl.po_line_number 
    LEFT JOIN po_purchase_orders ppo ON pl.purchase_order_id =ppo.id
    LEFT JOIN folio_reporting.instance_ext ie ON poi.pol_instance_id = ie.instance_id 
    LEFT JOIN folio_reporting.holdings_ext he ON ie.instance_id = he.instance_id 
    WHERE ppo.order_type = 'Ongoing' 
    AND he.receipt_status IN ('Currently received')
    AND ie.discovery_suppress IS NOT TRUE
    AND he.discovery_suppress IS NOT TRUE
    AND he.permanent_location_name NOT ilike '%LTS%'
	AND he.permanent_location_name NOT ilike 'serv,remo'
    AND he.permanent_location_name NOT ilike 'Agricultural Engineering'
    AND he.permanent_location_name NOT ilike 'Bindery Circulation'
    AND he.permanent_location_name NOT ilike 'Biochem Reading Room'
    AND he.permanent_location_name NOT iLIKE 'Borrow Direct'
    AND he.permanent_location_name NOT ilike 'CISER'
    AND he.permanent_location_name NOT ilike 'cons,opt'
    AND he.permanent_location_name NOT ilike 'Engineering'
    AND he.permanent_location_name NOT ilike 'Engineering Reference'
    AND he.permanent_location_name NOT ilike 'Engr,wpe'
    AND he.permanent_location_name NOT ilike 'Entomology'
    AND he.permanent_location_name NOT ilike 'Food Science'
    AND he.permanent_location_name NOT ilike 'Law Technical Services'
    AND he.permanent_location_name NOT ilike 'LTS Review Shelves'
    AND he.permanent_location_name NOT ilike 'LTS E-Resources & Serials'
    AND he.permanent_location_name NOT ilike 'Mann Gateway'
    AND he.permanent_location_name NOT ilike 'Mann Hortorium'
    AND he.permanent_location_name NOT ilike 'Mann Hortorium Reference'
    AND he.permanent_location_name NOT ilike 'Mann Technical Services'
    AND he.permanent_location_name NOT ilike 'Iron Mountain'
    AND he.permanent_location_name NOT ilike 'Interlibrary Loan%'
    AND he.permanent_location_name NOT ilike 'Phys Sci'
    AND he.permanent_location_name NOT ilike 'RMC Technical Services'
    AND he.permanent_location_name NOT ilike 'No Library'
    AND he.permanent_location_name NOT ilike 'x-test'
    AND he.permanent_location_name NOT ilike 'z-test location'
    AND he.call_number !~~* 'on order%'
    AND he.call_number !~~* 'in process%'
    AND he.call_number !~~* 'Available for the library to purchase'
    AND he.call_number !~~* 'On selector%'
;

/* Query 2: Creates table local_statistics.sercurr_ct_2, which limits the titles in the first table created
 * to serial titles.
 */
--on 5/5/22 gets 11,935 rows
DROP TABLE IF EXISTS local_statistics.sercurr_ct_2;    
CREATE TABLE local_statistics.sercurr_ct_2 AS
    SELECT
    sm.instance_hrid,
    ss.holdings_hrid,
    ss.title,
    sm.field,
    sm.content,
    substring(sm.content, 8, 1)::text AS "format_type",
    ss.po_wf_status,
    ss.pol_location_name,
    ss.order_type,
    ss.receipt_status,
    ss.permanent_location_name, -- i added
    ss.call_number -- i added
    FROM  local_statistics.sercurr_ct_1 ss
    inner JOIN srs_marctab sm ON ss.pol_instance_hrid = sm.instance_hrid
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
WHERE (sm.field = '000' AND substring(sm."content", 8, 1) IN ('s'))
AND sr.state  = 'ACTUAL'
;

/*Query 3: This query is used to get a count of unique instance ids.*/
--on 5/5/22 gets 10,477 rows
SELECT DISTINCT 
ss2p.instance_hrid 
FROM local_statistics.sercurr_ct_2 AS ss2p;
