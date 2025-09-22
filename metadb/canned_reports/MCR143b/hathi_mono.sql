-------------------selects records based on type from a Leader/000------------------------------
DROP table IF EXISTS local_hathitrust.h_mo_1;
CREATE TABLE local_hathitrust.h_mo_1 AS
SELECT
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm."content" AS ct1,
    substring(sm."content", 7, 2) AS "type_m"
    FROM folio_source_record.marc__t sm 
    WHERE (sm.field = '000' AND substring(sm."content", 7, 2) IN ('aa', 'am', 'cm', 'dm', 'em', 'tm'))
;

----------------selects records from previous table and filters on 008 language material------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_1b;
CREATE TABLE local_hathitrust.h_mo_1b AS
WITH publ_stat AS(
SELECT
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm."content" AS ct2,
    substring(sm."content", 7, 1) AS "type_publ" 
    FROM folio_source_record.marc__t  AS sm 
    where (sm.field = '008' AND substring(sm."content", 7, 1) IN ('q', 'r', 's', 't')))
    SELECT 
    h1.instance_hrid,
    h1.instance_id,
    h1b."type_publ",
    h1."type_m"
    FROM local_hathitrust.h_mo_1 h1
    inner JOIN publ_stat h1b ON h1.instance_id = h1b.instance_id
;

--2--------filter locations-------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_2; 
CREATE TABLE local_hathitrust.h_mo_2 AS 
SELECT 
    hm.instance_id,
    hm.instance_hrid,
    he.id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
    FROM  local_hathitrust.h_mo_1b hm
    LEFT JOIN  folio_derived.holdings_ext he ON hm.instance_id::uuid=he.instance_id::uuid
    WHERE he.permanent_location_name NOT LIKE 'serv,remo'
    AND he.permanent_location_name NOT LIKE 'Borrow Direct'
    AND he.permanent_location_name NOT ILIKE '%LTS%'
    AND he.permanent_location_name NOT LIKE '%A/V'
;


--3------------------------selects records with 245 $h[electronic resource] and filters from h_mono_select------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_3;   
CREATE TABLE local_hathitrust.h_mo_3 AS
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
    folio_source_record.marc__t sm
    LEFT JOIN folio_derived.holdings_ext he ON sm.instance_id::uuid = he.instance_id::uuid
    WHERE ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
    OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%'))
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_id, sm.instance_hrid, he.holdings_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, 
    he.permanent_location_name, he.call_number)
    SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress
    FROM local_hathitrust.h_mo_2 hm
    LEFT JOIN twofortyfive t ON hm.instance_id::uuid = t.instance_id::uuid
    WHERE t.instance_id IS NULL
;


--4---------------------selects records with 336 $aunmediated content and filters from h_mono_245_h_245_h----------------  
DROP TABLE IF EXISTS local_hathitrust.h_mo_4;
CREATE TABLE local_hathitrust.h_mo_4 AS
WITH threethirtysix AS (
SELECT 
    sm.instance_id,
    sm.field,
    sm.sf,
    sm.content 
    FROM 
    folio_source_record.marc__t sm
    WHERE (sm.field = '336' AND sm.sf = 'a' AND sm.CONTENT = 'unmediated')
    GROUP BY sm.instance_id, sm.field, sm.sf, sm.CONTENT)
    SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress 
    FROM local_hathitrust.h_mo_3 hm
    LEFT JOIN threethirtysix t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;

--5--------------------selects records with 300 $amap or maps and filters from hathi_336------------------ 
DROP TABLE IF EXISTS local_hathitrust.h_mo_5;
CREATE TABLE local_hathitrust.h_mo_5 AS
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
    folio_source_record.marc__t sm
    LEFT JOIN folio_derived.holdings_ext he ON sm.instance_id::uuid = he.instance_id::uuid
    WHERE (sm.field = '300' AND sm.sf ='a' AND sm.CONTENT like '%map%') 
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, he.holdings_hrid,he.permanent_location_name, 
    he.call_number, he.discovery_suppress)
    SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress
    FROM local_hathitrust.h_mo_4 hm
    left JOIN threehundred t ON hm.instance_id::uuid = t.instance_id::uuid
    WHERE t.instance_id IS NULL
;

--6-----------------------filters records by certain values in call number from hm_330-------------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_6;
CREATE TABLE local_hathitrust.h_mo_6 AS
SELECT 
    hm.instance_hrid,
    hm.instance_id,
    hm.call_number,
    hm.permanent_location_name,
    hm.id,
    hm.holdings_hrid,
    hm.discovery_suppress
    FROM local_hathitrust.h_mo_5 hm  
    WHERE hm.call_number !~~* 'on order%'
    AND hm.call_number !~~* 'in process%'
    AND hm.call_number !~~* 'Available for the library to purchase'
    AND hm.call_number !~~* '%film%' 
    AND hm.call_number !~~* '%fiche%'
    AND hm.call_number !~~* 'On selector%'
    AND hm.call_number !~~* '%dis%'
    AND hm.call_number !~~* '%vault%'
;

--7--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS local_hathitrust.h_mo_7;
CREATE TABLE local_hathitrust.h_mo_7 AS
WITH oclc_no AS (
    SELECT
    ii2.instance_id AS instance_id,
    ii2.identifier_type_name AS id_type,
    ii2.identifier AS oclc_number2
    FROM folio_derived.instance_identifiers AS ii2
    WHERE ii2.identifier_type_name = 'OCLC')
    SELECT 
    DISTINCT hm.instance_id,
    hm.instance_hrid,
    hm.id,
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
    FROM local_hathitrust.h_mo_6 hm
    INNER JOIN oclc_no AS oclcno ON hm.instance_id::uuid = oclcno.instance_id::uuid
;

----------8 cleares statements ----------
DROP TABLE IF EXISTS local_hathitrust.h_mo_8;
CREATE TABLE local_hathitrust.h_mo_8 AS 
SELECT
     hm.instance_hrid,
     hs.holdings_statement,
     hm.instance_id,
     hm.id,
     hm.holdings_hrid,
     hm.permanent_location_name,
     hm.call_number,
     he.type_name,
     hm.discovery_suppress 
     FROM local_hathitrust.h_mo_7 hm
     LEFT JOIN folio_derived.holdings_ext he ON hm.id = he.id
     LEFT JOIN folio_derived.holdings_statements hs ON hm.id = hs.holdings_id 
     WHERE  (hs.holdings_statement IN ('1 v.')
     OR hs.holdings_statement IS NULL)
;

---9-------assigns statuses and conditions-----------
DROP TABLE IF EXISTS local_hathitrust.h_mo_8b;
CREATE TABLE local_hathitrust.h_mo_8b AS 
SELECT 
DISTINCT ie.item_id,
     hm.holdings_statement,
     hm.instance_hrid,
     hm.instance_id,
     hm.id,
     hm.holdings_hrid,
     hm.permanent_location_name,
     hm.call_number,
     hm.discovery_suppress,
     hn.note,
     ie.enumeration,
     ie.chronology,
     ie.status_name,
     ie.damaged_status_name
     FROM local_hathitrust.h_mo_8 hm
     LEFT JOIN folio_derived.item_ext ie ON hm.id = ie.holdings_record_id
     LEFT JOIN folio_derived.holdings_notes hn ON hm.holdings_hrid=hn.holding_hrid
     GROUP BY hm.holdings_statement, ie.item_id, hm.instance_hrid, hm.instance_id, hm.id, hm.holdings_hrid, hm.permanent_location_name,
     hm.call_number, hn.note, ie.enumeration, ie.chronology, ie.status_name, hm.discovery_suppress, ie.damaged_status_name
;

-------------------------------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_9;
CREATE TABLE local_hathitrust.h_mo_9 AS 
SELECT 
 DISTINCT hm.item_id,
     hm.holdings_statement,
     hm.instance_hrid,
     hm.instance_id,
     hm.id,
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
FROM local_hathitrust.h_mo_8b hm;

--9------------------------------selects value for government document from 008 --------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_final;
CREATE TABLE local_hathitrust.h_mo_final AS
WITH gov_doc AS (
    SELECT
    sm.instance_hrid AS instance_hrid,
    CASE
        WHEN substring(sm.content, 18, 1) IN ('u')
             AND substring(sm.content, 29, 1) IN ('f')
             THEN '1'
             ELSE '0' END AS GovDoc
    FROM
    folio_source_record.marc__t sm
    WHERE
    sm.field = '008'
)
SELECT
   os.OCLC,
   hm.instance_hrid AS "Bib Id",
   gd.GovDoc,
   hm."Status",
   hm."Condition"
   FROM  local_hathitrust.h_mo_9 AS hm
   LEFT JOIN gov_doc AS gd ON hm.instance_hrid = gd.instance_hrid
   LEFT JOIN local_hathitrust.h_mo_7 AS os ON hm.instance_hrid = os.instance_hrid
   GROUP BY os.OCLC, hm.instance_hrid, hm."Status", hm."Condition", gd.GovDoc
;
DROP table IF EXISTS local_hathitrust.h_mo_1;
DROP table IF EXISTS local_hathitrust.h_mo_1b;
DROP table IF EXISTS local_hathitrust.h_mo_2;
DROP table IF EXISTS local_hathitrust.h_mo_3;
DROP table IF EXISTS local_hathitrust.h_mo_4;
DROP table IF EXISTS local_hathitrust.h_mo_5;
DROP table IF EXISTS local_hathitrust.h_mo_6;
DROP table IF EXISTS local_hathitrust.h_mo_7;
DROP table IF EXISTS local_hathitrust.h_mo_8;
DROP table IF EXISTS local_hathitrust.h_mo_8b;
DROP table IF EXISTS local_hathitrust.h_mo_9;
