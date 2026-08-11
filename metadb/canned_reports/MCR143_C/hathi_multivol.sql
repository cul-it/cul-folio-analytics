--1-----------------selects records based on type from a Leader/000------------------------------
DROP table IF EXISTS local_hathitrust.h_mv_1_26;
CREATE TABLE local_hathitrust.h_mv_1_26 AS
SELECT
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm.sf,
    sm."content" AS ct1,
    substring(sm."content", 7, 2) AS "type_m"
FROM local_derived.marc__t sm 
WHERE (sm.field = '000' AND substring(sm."content", 7, 2) IN ('aa', 'am', 'cm', 'dm', 'em', 'tm'));

--2--------filters records based on locations-------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mv_2_26; 
CREATE TABLE local_hathitrust.h_mv_2_26 AS 
SELECT 
    lhm.instance_id,
    lhm.instance_hrid,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress 
FROM local_hathitrust.h_mv_1_26 lhm
LEFT JOIN  folio_derived.holdings_ext h ON lhm.instance_id::uuid = h.instance_id::uuid
WHERE h.permanent_location_name NOT ILIKE ALL (ARRAY[
      'serv,remo', 'Borrow Direct', 'Interlibrary Loan - Olin','%LTS%', '%A/V', 'No Library', 
      '%inactive%', '%Olin A/V%', '%micro%', 'wood%']) ---WOOD library excluded;

--3------------------------selects/deselects records with 245 $h[electronic resource] etc-----------------------
DROP TABLE IF EXISTS local_hathitrust.h_mv_3_26;   
CREATE TABLE local_hathitrust.h_mv_3_26 AS
WITH twofortyfive AS (
SELECT
    sm.instance_hrid,
    sm.CONTENT as content,
    sm.field,
    sm.sf,
    he.instance_id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number
FROM local_derived.marc__t sm
LEFT JOIN folio_derived.holdings_ext he ON sm.instance_id::uuid = he.instance_id::uuid
WHERE ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
    OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%')
    OR (sm.field = '245' AND sm.sf = 'h' AND sm.CONTENT LIKE '%[sound recording]%'))
    AND he.permanent_location_name !~~ 'serv,remo'
GROUP BY sm.instance_id, sm.instance_hrid, he.holdings_hrid, 
    sm.CONTENT, sm.field, sm.sf, he.instance_id, 
    he.permanent_location_name, he.call_number)
SELECT 
    h.instance_id,
    h.instance_hrid,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress,
    t.content AS "245_f"
FROM local_hathitrust.h_mv_2_26 h
LEFT JOIN twofortyfive t ON h.instance_id::uuid = t.instance_id::uuid
WHERE t.instance_id IS NULL
;

--4---------------------selects/deselects records with 336 $atext content and filters from h_mv_3----------------  
DROP TABLE IF EXISTS local_hathitrust.h_mv_4_26;
CREATE TABLE local_hathitrust.h_mv_4_26 AS
SELECT 
    h.instance_id,
    h.instance_hrid,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress 
FROM local_hathitrust.h_mv_3_26 h
WHERE NOT EXISTS (
    SELECT 1
    FROM local_derived.marc__t sm
    WHERE sm.instance_id::uuid = h.instance_id::uuid
      AND sm.field = '336'
      AND sm.sf = 'a'
      AND sm.content != 'text');


--5-----------------------filters records by certain values in call number from h_mv_5-------------------
DROP TABLE IF EXISTS local_hathitrust.h_mv_5_26;
CREATE TABLE local_hathitrust.h_mv_5_26 AS
SELECT 
    hhn.instance_id,
    hhn.instance_hrid,
    hhn.holdings_hrid,
    hhn.call_number,
    hhn.permanent_location_name,
    hhn.discovery_suppress
FROM local_hathitrust.h_mv_4_26 hhn  
WHERE hhn.call_number !~~* 'on order%' AND hhn.call_number !~~* 'in process%'
    AND hhn.call_number !~~* 'Available for the library to purchase'
    AND hhn.call_number !~~* '%film%' AND hhn.call_number !~~* '%fiche%'
    AND hhn.call_number !~~* 'On selector%' AND hhn.call_number !~~* '%dis%'
    AND hhn.call_number !~~* '%film%' AND hhn.call_number !~~* '%vault%' 
    AND hhn.call_number !~~* '%cancelled%' AND hhn.call_number !~~* '%no call number%';


--6--------------------filters records with oclc number------------------    
DROP TABLE IF EXISTS local_hathitrust.h_mv_6_26;
CREATE TABLE local_hathitrust.h_mv_6_26 AS
WITH oclc_no AS (
SELECT
    ii2.instance_id AS instance_id,
    ii2.identifier_type_name AS id_type,
    ii2.identifier AS oclc_number2
FROM folio_derived.instance_identifiers AS ii2
WHERE ii2.identifier_type_name = 'OCLC')
SELECT DISTINCT 
    hsn.instance_id,
    hsn.instance_hrid,
    hsn.holdings_hrid,
    hsn.call_number,
    hsn.permanent_location_name,
    hsn.discovery_suppress,
    oclcno.id_type,
    oclcno.oclc_number2,
    regexp_replace(oclcno.oclc_number2, '^\(OCoLC\)(ocm|ocn|on)?', '') AS oclc_no
FROM local_hathitrust.h_mv_5_26 hsn 
INNER JOIN oclc_no AS oclcno ON hsn.instance_id::uuid= oclcno.instance_id::uuid;


--7-------- clears holdings statements ----------
DROP TABLE IF EXISTS local_hathitrust.h_mv_7_26 ;
CREATE table local_hathitrust.h_mv_7_26 AS 
SELECT
      hm.instance_id,
      hm.instance_hrid,
      hm.holdings_hrid,
      STRING_AGG(hs.holdings_statement, ' | ') AS holdings_statement,
      hm.permanent_location_name,
      string_agg(hn.note,'|') as holdings_notes,
      hm.oclc_no,
      hm.call_number,
      he.type_name,
      hm.discovery_suppress, he.id
FROM local_hathitrust.h_mv_6_26 hm
LEFT JOIN folio_derived.holdings_ext  he ON hm.holdings_hrid = he.holdings_hrid
LEFT JOIN folio_derived.holdings_statements hs ON hm.holdings_hrid = hs.holdings_hrid 
LEFT JOIN folio_derived.holdings_notes hn ON hm.holdings_hrid = hn.holding_hrid
WHERE (hs.holdings_statement NOT IN ('1 v.'))
GROUP BY hm.instance_id, hm.instance_hrid, hm.holdings_hrid, hm.permanent_location_name,
      hn.note,hm.oclc_no, hm.call_number, he.type_name, hm.discovery_suppress, he.id;

--8------gets item records----------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mv_7b_26;
CREATE TABLE local_hathitrust.h_mv_7b_26 AS 
SELECT DISTINCT 
    he.item_id,
    he.item_hrid,
    hm.instance_id,
    hm.instance_hrid,
    hm.holdings_hrid,hm.id,
    hm.permanent_location_name,
    hm.call_number,
    he.enumeration,
    he.chronology,
    he.number_of_pieces,
    he.number_of_missing_pieces,
    he.status_name,
    he.damaged_status_name,
    hm.holdings_notes,
    hm.discovery_suppress,
    hm.oclc_no
FROM local_hathitrust.h_mv_7_26 hm
LEFT JOIN folio_derived.item_ext he ON hm.id = he.holdings_record_id;

---9-------assigns statuses and conditions-----------
DROP TABLE IF EXISTS local_hathitrust.h_mv_8_26;
CREATE TABLE local_hathitrust.h_mv_8_26 as
SELECT DISTINCT 
    hs.item_id,
    hs.instance_hrid,
    hs.instance_id,
    hs.id,
    hs.holdings_hrid,
    hs.permanent_location_name,
    hs.call_number,
    hs.enumeration,
    hs.chronology,
    hs.status_name,
    hs.oclc_no,
CASE
     WHEN ((hs.enumeration IS NULL and hs.chronology IS NULL)
               AND (hs.discovery_suppress IS TRUE OR hs.discovery_suppress IS NULL))
     THEN 'WD' 
     WHEN ((hs.enumeration IS NULL and hs.chronology IS NULL)
                  AND (hs.discovery_suppress IS false))
             THEN 'NWD'    
     WHEN hs.status_name IN ('Missing', 'Lost and paid', 'Aged to lost', 'Declared lost', 'Long missing')
             THEN 'LM' 
             ELSE 'CH' END AS "status",
    hs.damaged_status_name,
CASE WHEN (hs.damaged_status_name = 'Damaged')
           THEN 'BRT'
           ELSE NULL END AS "condition",
CASE WHEN (hs.enumeration IS NOT NULL)
            THEN hs.enumeration 
            WHEN hs.enumeration IS NULL 
            THEN hs.chronology 
            ELSE '' END AS "Enum/Chron"
FROM local_hathitrust.h_mv_7b_26 hs 
GROUP BY hs.instance_hrid, hs.instance_id, hs.id, hs.holdings_hrid, hs.item_id,
     hs.oclc_no, hs.permanent_location_name, hs.call_number, hs.enumeration,
     hs.chronology, hs.status_name, hs.discovery_suppress, hs.damaged_status_name;


--10------------------------------selects value for government document from 008 ---------
DROP TABLE IF EXISTS local_hathitrust.h_mv_final_26;
CREATE TABLE local_hathitrust.h_mv_final_26 AS
WITH gov_doc AS (
SELECT
    sm.instance_hrid AS instance_hrid,
    CASE
        WHEN substring(sm.content, 18, 1) IN ('u')
             AND substring(sm.content, 29, 1) IN ('f')
             THEN '1'
             ELSE '0' END AS GovDoc
    FROM local_derived.marc__t sm
    WHERE sm.field = '008'
)
SELECT
   hm.oclc_no AS "oclc",
   hm.instance_hrid AS "local_id",
   hm.status AS "status",
   hm."condition" AS "condition",
   hm."Enum/Chron" AS "enum_chron",
   coalesce(gd.GovDoc::numeric,0) AS GovDoc
   FROM local_hathitrust.h_mv_8_26 AS hm
   LEFT JOIN gov_doc AS gd ON hm.instance_hrid = gd.instance_hrid
   WHERE hm.status != 'NWD';

DROP table IF EXISTS local_hathitrust.h_mv_1;
DROP table IF EXISTS local_hathitrust.h_mv_2;
DROP table IF EXISTS local_hathitrust.h_mv_3;
DROP table IF EXISTS local_hathitrust.h_mv_4;
DROP table IF EXISTS local_hathitrust.h_mv_5;
DROP table IF EXISTS local_hathitrust.h_mv_6;
DROP table IF EXISTS local_hathitrust.h_mv_7;
DROP table IF EXISTS local_hathitrust.h_mv_7b;
DROP table IF EXISTS local_hathitrust.h_mv_8;
