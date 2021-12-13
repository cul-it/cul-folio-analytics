DROP table IF EXISTS LOCAL.h_mo_1;
CREATE TABLE LOCAL.h_mo_1 AS
SELECT
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm.sf,
    sm."content" AS ct1,
    substring(sm."content", 7, 2) AS "type_m"
    FROM srs_marctab sm 
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    where sr.state  = 'ACTUAL'
    and (sm.field = '000' AND substring(sm."content", 7, 2) IN ('aa', 'am', 'cm', 'dm', 'em', 'tm'))
;

CREATE INDEX ON local.h_mo_1 (instance_hrid);
CREATE INDEX ON local.h_mo_1 (instance_id);
CREATE INDEX ON local.h_mo_1 (field);
CREATE INDEX ON local.h_mo_1 (sf);
CREATE INDEX ON local.h_mo_1 (ct1);
CREATE INDEX ON local.h_mo_1 ("type_m");


----------------selects records from previous table and filters on 008 language material------------
DROP table IF EXISTS LOCAL.h_mv_1b;
CREATE TABLE LOCAL.h_mv_1b AS
WITH publ_stat AS(
SELECT
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm.sf,
    sm."content" AS ct2,
    substring(sm."content", 7, 1) AS "type_publ" 
    FROM srs_marctab  AS sm 
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    where sr.state  = 'ACTUAL'
    and (sm.field = '008' AND substring(sm."content", 7, 1) IN ('q', 'r', 's', 't')))
    SELECT 
    h1.instance_hrid,
    h1.instance_id,
    h1b."type_publ",
    h1."type_m"
    FROM LOCAL.h_mo_1 h1
    inner JOIN publ_stat h1b ON h1.instance_id = h1b.instance_id
;

CREATE INDEX ON local.h_mo_1b (instance_hrid);
CREATE INDEX ON local.h_mo_1b (instance_id);
CREATE INDEX ON local.h_mo_1b ("type_publ");
CREATE INDEX ON LOCAL.h_mo_1b ("type_m");

--2--------filter locations-------------------------------
DROP TABLE IF EXISTS LOCAL.h_mo_2; 
CREATE TABLE LOCAL.h_mo_2 AS 
SELECT 
    hm.instance_id,
    hm.instance_hrid,
    he.holdings_id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
    FROM  LOCAL.h_mo_1b hm
    LEFT JOIN  folio_reporting.holdings_ext he ON hm.instance_id=he.instance_id
    WHERE he.permanent_location_name NOT LIKE 'serv,remo'
    AND he.permanent_location_name NOT LIKE 'Borrow Direct'
    AND he.permanent_location_name NOT ILIKE '%LTS%'
    AND he.permanent_location_name NOT LIKE '%A/V'
;
CREATE INDEX ON local.h_mo_2 (instance_id);
CREATE INDEX ON local.h_mo_2 (instance_hrid);
CREATE INDEX ON local.h_mo_2 (holdings_id);
CREATE INDEX ON local.h_mo_2 (hldings_hrid);
CREATE INDEX ON local.h_mo_2 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_2 (call_number);
CREATE INDEX ON local.h_mo_2 (discovery_suppress);

--3------------------------selects records with 245 $h[electronic resource] and filters from h_mono_select------------------------
DROP TABLE IF EXISTS LOCAL.h_mo_3;   
CREATE TABLE LOCAL.h_mo_3 AS
WITH twofortyfive AS (
SELECT
    sm.instance_hrid,
    sm.CONTENT,
    sm.field,
    sm.sf,
    he.instance_id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number
    FROM
    srs_marctab sm
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    WHERE sr.state  = 'ACTUAL'
    AND ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
    OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%'))
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_id, sm.instance_hrid, he.holdings_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, 
    he.permanent_location_name, he.call_number)
    SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.holdings_id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress
    FROM LOCAL.h_mo_2 hm
    LEFT JOIN twofortyfive t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local.h_mo_3 (instance_id);
CREATE INDEX ON local.h_mo_3 (instance_hrid);
CREATE INDEX ON local.h_mo_3 (holdings_id);
CREATE INDEX ON local.h_mo_3 (hldings_hrid);
CREATE INDEX ON local.h_mo_3 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_3 (call_number);
CREATE INDEX ON local.h_mo_3 (discovery_suppress);

--4---------------------selects records with 336 $aunmediated content and filters from h_mono_245_h_245_h----------------  
DROP TABLE IF EXISTS LOCAL.h_mo_4;
CREATE TABLE LOCAL.h_mo_4 AS
WITH threethirtysix AS (
SELECT 
    sm.instance_id,
    sm.field,
    sm.sf,
    sm.content 
    FROM 
    srs_marctab sm
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id 
    WHERE sr.state  = 'ACTUAL'
    AND (sm.field = '336' AND sm.sf = 'a' AND sm.CONTENT = 'unmediated')
    GROUP BY sm.instance_id, sm.field, sm.sf, sm.CONTENT)
    SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.holdings_id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress 
    FROM LOCAL.h_mo_3 hm
    LEFT JOIN threethirtysix t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local.h_mo_4 (instance_id);
CREATE INDEX ON local.h_mo_4 (instance_hrid);
CREATE INDEX ON local.h_mo_4 (holdings_id);
CREATE INDEX ON local.h_mo_4 (hldings_hrid);
CREATE INDEX ON local.h_mo_4 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_4 (call_number);
CREATE INDEX ON local.h_mo_4 (discovery_suppress);

--5--------------------selects records with 300 $amap or maps and filters from hathi_336------------------ 
DROP TABLE IF EXISTS LOCAL.h_mo_5;
CREATE TABLE LOCAL.h_mo_5 AS
WITH threehundred AS 
(SELECT
    sm.instance_hrid,
    sm.CONTENT,
    sm.field,
    sm.sf,
    he.instance_id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
    FROM
    srs_marctab sm
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    WHERE sr.state  = 'ACTUAL'
    AND (sm.field = '300' AND sm.sf ='a' AND sm.CONTENT like '%map%') 
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, he.holdings_hrid,he.permanent_location_name, 
    he.call_number, he.discovery_suppress)
    SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.holdings_id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress
    FROM LOCAL.h_mo_4 hm
    left JOIN threehundred t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local.h_mo_5 (instance_id);
CREATE INDEX ON local.h_mo_5 (instance_hrid);
CREATE INDEX ON local.h_mo_5 (holdings_id);
CREATE INDEX ON local.h_mo_5 (hldings_hrid);
CREATE INDEX ON local.h_mo_5 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_5 (call_number);
CREATE INDEX ON local.h_mo_5 (discovery_suppress);
--6-----------------------filters records by certain values in call number from hm_330-------------------
DROP TABLE IF EXISTS LOCAL.h_mo_6;
CREATE TABLE LOCAL.h_mo_6 AS
SELECT 
    hm.instance_hrid,
    hm.instance_id,
    hm.call_number,
    hm.permanent_location_name,
    hm.holdings_id,
    hm.holdings_hrid,
    hm.discovery_suppress
    FROM LOCAL.h_mo_5 hm  
    WHERE hm.call_number !~~* 'on order%'
    AND hm.call_number !~~* 'in process%'
    AND hm.call_number !~~* 'Available for the library to purchase'
    AND hm.call_number !~~* '%film%' 
    AND hm.call_number !~~* '%fiche%'
    AND hm.call_number !~~* 'On selector%'
    AND hm.call_number !~~* '%dis%'
    AND hm.call_number !~~* '%vault%'
;

CREATE INDEX ON local.h_mo_5 (instance_id);
CREATE INDEX ON local.h_mo_5 (instance_hrid);
CREATE INDEX ON local.h_mo_5 (holdings_id);
CREATE INDEX ON local.h_mo_5 (hldings_hrid);
CREATE INDEX ON local.h_mo_5 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_5 (call_number);
CREATE INDEX ON local.h_mo_5 (discovery_suppress);

--7--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS LOCAL.h_mo_7;
CREATE TABLE LOCAL.h_mo_7 AS
WITH oclc_no AS (
    SELECT
    ii2.instance_id AS instance_id,
    ii2.identifier_type_name AS id_type,
    ii2.identifier AS oclc_number2
    FROM folio_reporting.instance_identifiers AS ii2
    WHERE ii2.identifier_type_name = 'OCLC')
    SELECT 
    DISTINCT hm.instance_id,
    hm.instance_hrid,
    hm.holdings_id,
    hm.holdings_hrid,
    hm.call_number,
    hm.permanent_location_name,
    hm.discovery_suppress,
    oclcno.id_type,
    oclcno.oclc_number2,
    CASE 
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)ocm%' THEN SUBSTRING(oclcno.oclc_number2, 11)
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)ocn%' THEN SUBSTRING(oclcno.oclc_number2, 11)
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)%' THEN SUBSTRING(oclcno.oclc_number2, 8)
        ELSE oclcno.oclc_number2 END AS OCLC
    FROM LOCAL.h_mo_6 hm
    INNER JOIN oclc_no AS oclcno ON hm.instance_id = oclcno.instance_id
;
CREATE INDEX ON local.h_mo_7 (instance_id);
CREATE INDEX ON local.h_mo_7 (instance_hrid);
CREATE INDEX ON local.h_mo_7 (holdings_id);
CREATE INDEX ON local.h_mo_7 (hldings_hrid);
CREATE INDEX ON local.h_mo_7 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_7 (call_number);
CREATE INDEX ON local.h_mo_7 (discovery_suppress);
----------8 cleares statements ----------
DROP TABLE IF EXISTS LOCAL.h_mo_8;
CREATE TABLE LOCAL.h_mo_8 AS 
SELECT
     hm.instance_hrid,
     hs."statement",
     hm.instance_id,
     hm.holdings_id,
     hm.holdings_hrid,
     hm.permanent_location_name,
     hm.call_number,
     he.type_name,
     hm.discovery_suppress 
     FROM LOCAL.h_mo_7 hm
     LEFT JOIN folio_reporting.holdings_ext he ON hm.holdings_id = he.holdings_id
     LEFT JOIN folio_reporting.holdings_statements hs ON hm.holdings_id = hs.holdings_id 
     WHERE  (hs."statement" IN ('1 v.')
     OR hs."statement" IS NULL)
;
CREATE INDEX ON local.h_mo_8 (instance_hrid);
CREATE INDEX ON LOCAL.h_mo_8 ("statement");
CREATE INDEX ON local.h_mo_8 (instance_id);
CREATE INDEX ON local.h_mo_8 (holdings_id);
CREATE INDEX ON local.h_mo_8 (hldings_hrid);
CREATE INDEX ON local.h_mo_8 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_8 (call_number);
CREATE INDEX ON LOCAL.h_mo_8 (type_name);
CREATE INDEX ON local.h_mo_8 (discovery_suppress);
---9-------assigns statuses and conditions-----------
DROP TABLE IF EXISTS LOCAL.h_mo_8b;
CREATE TABLE LOCAL.h_mo_8b AS 
SELECT 
DISTINCT ie.item_id,
     hm."statement",
     hm.instance_hrid,
     hm.instance_id,
     hm.holdings_id,
     hm.holdings_hrid,
     hm.permanent_location_name,
     hm.call_number,
     hm.discovery_suppress,
     hn.note,
     ie.enumeration,
     ie.chronology,
     ie.status_name,
     ie.damaged_status_name
     FROM LOCAL.h_mo_8 hm
     LEFT JOIN folio_reporting.item_ext ie ON hm.holdings_id = ie.holdings_record_id
     LEFT JOIN folio_reporting.holdings_notes hn ON hm.holdings_hrid=hn.holdings_hrid
     GROUP BY hm."statement", ie.item_id, hm.instance_hrid, hm.instance_id, hm.holdings_id, hm.holdings_hrid, hm.permanent_location_name,
     hm.call_number, hn.note, ie.enumeration, ie.chronology, ie.status_name, hm.discovery_suppress, ie.damaged_status_name
;
CREATE INDEX ON local.h_mo_8 (item_id);
CREATE INDEX ON local.h_mo_8 (instance_hrid);
CREATE INDEX ON LOCAL.h_mo_8 ("statement");
CREATE INDEX ON local.h_mo_8 (instance_id);
CREATE INDEX ON local.h_mo_8 (holdings_id);
CREATE INDEX ON local.h_mo_8 (hldings_hrid);
CREATE INDEX ON local.h_mo_8 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_8 (call_number);
CREATE INDEX ON LOCAL.h_mo_8 (note);
CREATE INDEX ON LOCAL.h_mo_8 (enumeration);
CREATE INDEX ON LOCAL.h_mo_8 (chronology);
CREATE INDEX ON LOCAL.h_mo_8 (status_name);
CREATE INDEX ON local.h_mo_8 (discovery_suppress);
CREATE INDEX ON LOCAL.h_mo_8 (damaged_status_name);
-------------------------------------------------------
   DROP TABLE IF EXISTS LOCAL.h_mo_9;
    CREATE TABLE LOCAL.h_mo_9 AS 
    SELECT 
    DISTINCT hm.item_id,
     hm."statement",
     hm.instance_hrid,
     hm.instance_id,
     hm.holdings_id,
     hm.holdings_hrid,
     hm.permanent_location_name,
     hm.call_number,
     hm.enumeration,
     hm.chronology,
     hm.status_name,
     hm.discovery_suppress,
     hm.note,
     hm.damaged_status_name,
      CASE 
          WHEN (hm.discovery_suppress = 'TRUE' AND hm.note iLIKE '%withdr%')
          THEN 'WD' 
               WHEN hm.status_name IN ('Missing', 'Lost and paid', 'Aged to lost', 'Declared lost')
               THEN 'LM' 
                  ELSE 'CH' END AS "Status",
      CASE 
          WHEN (hm.damaged_status_name = 'Damaged')
          THEN 'BRT'
               ELSE '0' END AS "Condition"
FROM LOCAL.h_mo_8b hm;
CREATE INDEX ON local.h_mo_8 (item_id);
CREATE INDEX ON local.h_mo_8 (instance_hrid);
CREATE INDEX ON LOCAL.h_mo_8 ("statement");
CREATE INDEX ON local.h_mo_8 (instance_id);
CREATE INDEX ON local.h_mo_8 (holdings_id);
CREATE INDEX ON local.h_mo_8 (hldings_hrid);
CREATE INDEX ON local.h_mo_8 (permanent_location_name);
CREATE INDEX ON LOCAL.h_mo_8 (call_number);
CREATE INDEX ON LOCAL.h_mo_8 (note);
CREATE INDEX ON LOCAL.h_mo_8 (enumeration);
CREATE INDEX ON LOCAL.h_mo_8 (chronology);
CREATE INDEX ON LOCAL.h_mo_8 (status_name);
CREATE INDEX ON local.h_mo_8 (discovery_suppress);
CREATE INDEX ON LOCAL.h_mo_8 (damaged_status_name);
--9------------------------------selects value for government document from 008 --------------
DROP TABLE IF EXISTS LOCAL.h_mo_final;
CREATE TABLE LOCAL.h_mo_final AS
WITH gov_doc AS (
    SELECT
    sm.instance_hrid AS instance_hrid,
    CASE
        WHEN substring(sm.content, 18, 1) IN ('u')
             AND substring(sm.content, 29, 1) IN ('f')
             THEN '1'
             ELSE '0' END AS GovDoc
    FROM
    srs_marctab sm
    WHERE
    sm.field = '008'
)
SELECT
   os.OCLC,
   hm.instance_hrid AS "Bib Id",
   gd.GovDoc,
   hm."Status",
   hm."Condition"
   FROM  LOCAL.h_mo_9 AS hm
   LEFT JOIN gov_doc AS gd ON hm.instance_hrid = gd.instance_hrid
   LEFT JOIN LOCAL.h_mo_7 AS os ON hm.instance_hrid = os.instance_hrid
   GROUP BY os.OCLC, hm.instance_hrid, hm."Status", hm."Condition", gd.GovDoc
;
CREATE INDEX ON LOCAL.h_mo_final (GovDoc);
CREATE INDEX ON local.h_mo_final (Bib Id);
CREATE INDEX ON local.h_mo_final ("Status");
CREATE INDEX ON LOCAL.h_mo_final ("Condition");
CREATE INDEX ON local.h_mo_final (OCLC);
