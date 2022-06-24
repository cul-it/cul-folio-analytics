--773_and_899_aggr_counts_adc_20220624

-- 6/16/22 These queries get counts of aggregators and other collections coded in 773 and 899 fields,
--to help track large changes in e-counts from year to year.
--Used for the annual data collection.

--Query 1: Gets counts of aggregators tracked in 773s, by format. Does not exclude PDA/DDA unpurchased.
--https://confluence.cornell.edu/display/LTSP/EBSCO+Record+loads
--18 minutes on 6/24/22; need to share to save.
WITH formattype AS 
(select
    sm.instance_id,
    sm.field,
    substring(sm."content", 7, 2) AS "format_type",
    ie.discovery_suppress
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.instance_ext AS ie ON sm.instance_id = ie.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE sm.field LIKE '000'
    AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
    AND sr.state  = 'ACTUAL'
  ) 
SELECT DISTINCT 
	sm."content",
	fmtype."format_type",
    count(sm.instance_hrid) AS count
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.instance_ext AS ie ON sm.instance_id = ie.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    LEFT JOIN formattype AS fmtype ON sm.instance_id = fmtype.instance_id
    WHERE sm.field LIKE '773'
   	AND sm.sf LIKE 't'
    AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
    AND sr.state  = 'ACTUAL'
    GROUP BY sm."content", fmtype."format_type"
   --ORDER BY sm."content";
;
 
--Query 2: Gets counts of aggregators tracked in 889s, by format. Does not exclude PDA/DDA unpurchased.
--Does not take into account inidicators, so includes electronic and physical.
--https://confluence.cornell.edu/pages/viewpage.action?pageId=326378795#LocalFieldTagsUsedinVoyager(LTSProcedure136V)-A899
--6 minutes on 6/24/22; need to share to save.
WITH formattype AS 
(select
    sm.instance_id,
    sm.field,
    sm.ind1,
    substring(sm."content", 7, 2) AS "format_type",
    ie.discovery_suppress
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.instance_ext AS ie ON sm.instance_id = ie.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE sm.field LIKE '000'
    AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
    AND sr.state  = 'ACTUAL'
  ) 
SELECT DISTINCT 
	sm."content",
	fmtype."format_type",
    count(sm.instance_hrid) AS count
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.instance_ext AS ie ON sm.instance_id = ie.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    LEFT JOIN formattype AS fmtype ON sm.instance_id = fmtype.instance_id
    --WHERE (sm.field LIKE '899' AND sm.sf LIKE 'a') 
    --WHERE (sm.field LIKE '899' AND sm.ind1 !~~* '1' AND sm.sf LIKE 'a')
    WHERE (sm.field LIKE '899' AND sm.ind1 LIKE '2' AND sm.sf LIKE 'a')
    AND (ie.discovery_suppress = 'FALSE' OR ie.discovery_suppress IS NULL)
    AND sr.state  = 'ACTUAL'
    GROUP BY sm."content", fmtype."format_type"
   --ORDER BY sm."content";
;
