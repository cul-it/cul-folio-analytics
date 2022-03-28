Harvest Specification
/*
--I.  Harvest the bibs that have the following characteristics.

--A. Suppression don’t care, want suppressed and unsuppressed bibs.

--B. Leader/06-07=aa, am, cm, dm, em or tm

--C. 008/6=q, r, s, or t

--D. Does not contain a 245 subfield h

--E. If 336 is present subfield a must equal unmediated.

F. Must have an 035 (OCoLC) number

--G. Must not have in 300 subfield a and only subfield a “map” or “maps”

H. Check  if 008/17=u and 008/28=f, if both conditions exist mark in report as “1” and if not “0”, see below for report formatting.
Processing Description
II.  Examine all the MFHDs associated with each bib.
A. Suppression don’t care.
--B. Discard any MFHD with the location serv,remo
--C. Must have content in 852 subfield h other than “On Order,” “In Process,” “Available for the library to purchase”, Film or *fiche (all not case sensitive). 852 k or m subfields cannot contain work Disk or Disc.
--D. Suppressed MFHDs that meet condition c and have "withdrawn" in a holdings statement,mark as “WD” for “Withdrawn.”
E. MFHD must have no 866/"holding statement" or one 866 with text 1 v.
F. Unsuppressed MFHDs that meet condition e must examine item record and if the Voyager 
item status = 12, 13, or 14 mark as “LM” for “Lost/Missing”.
 Any item with status = 17 marks as “WD” for “Withdrawn” 
 and ignore any other statuses for that item. 
 Any other item with any other status, mark as “CH” for “Current Holding.” 
 (12:Missing, 13:Lost--Library Applied, 14:Lost--System Applied, 17:Withdrawn, 
 FOLIO: aged tolost, declared lost, missing, withdrawn)
G. If item has text in item’s enumeration or chronology discard.
H. Unsuppressed MFHDs meeting conditions a,b, and c without items mark as CH
III.  For each MFHD which meets the criteria retreive the following:
A. OCoLC 035 number, drop the prefix (OCoLC) for report, drop any alpha characters preceeding the number such as ocm or ocn. If more than one OCLC number in record, use the first occurrence.
B. Bib id, add bib to number
C. The marked status of the MFHD, CH, LM, or WD.
D. Government document status either 0 (not) or 1 (is government document)
E. Repeat tab delimited values for each holding for the bib that meets the criteria with a maximum file size of 100 MB to be place in HathiTrust server file space. File name: Hathi-MONO-YYYYMMDD-[file number]

For example: bib 12345 has 1 items which meet criteria unsuppressed.

OCLC                Bib Id            Status      Condition           GovDoc

623445              12345           CH                                   0
*/

--1----selects pull of records based on ldr type ans 008 publication status and filters certain locations-----------
DROP table IF EXISTS local_hathi_hathi.h_mo_1;
CREATE TABLE local_hathi.h_mo_1 AS
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

CREATE INDEX ON local_hathi.h_mo_1 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_1 (instance_id);
CREATE INDEX ON local_hathi.h_mo_1 (field);
CREATE INDEX ON local_hathi.h_mo_1 (sf);
CREATE INDEX ON local_hathi.h_mo_1 (ct1);
CREATE INDEX ON local_hathi.h_mo_1 ("type_m");


----------------selects records from previous table and filters on 008 language material------------
DROP table IF EXISTS local_hathi.h_mo_1b;
CREATE TABLE local_hathi.h_mo_1b AS
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
    FROM local_hathi.h_mo_1 h1
    inner JOIN publ_stat h1b ON h1.instance_id = h1b.instance_id
;

CREATE INDEX ON local_hathi.h_mo_1b (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_1b (instance_id);
CREATE INDEX ON local_hathi.h_mo_1b ("type_publ");
CREATE INDEX ON local_hathi.h_mo_1b ("type_m");

--2--------filter locations-------------------------------
DROP TABLE IF EXISTS local_hathi.h_mo_2; 
CREATE TABLE local_hathi.h_mo_2 AS 
SELECT 
    hm.instance_id,
    hm.instance_hrid,
    he.holdings_id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
    FROM  local_hathi.h_mo_1b hm
    LEFT JOIN  folio_reporting.holdings_ext he ON hm.instance_id=he.instance_id
    WHERE he.permanent_location_name NOT LIKE 'serv,remo'
    AND he.permanent_location_name NOT LIKE 'Borrow Direct'
    AND he.permanent_location_name NOT ILIKE '%LTS%'
    AND he.permanent_location_name NOT LIKE '%A/V'
;
CREATE INDEX ON local_hathi.h_mo_2 (instance_id);
CREATE INDEX ON local_hathi.h_mo_2 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_2 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_2 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_2 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_2 (call_number);
CREATE INDEX ON local_hathi.h_mo_2 (discovery_suppress);

--3------------------------selects records with 245 $h[electronic resource] and filters from h_mono_select------------------------
DROP TABLE IF EXISTS local_hathi.h_mo_3;   
CREATE TABLE local_hathi.h_mo_3 AS
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
    FROM local_hathi.h_mo_2 hm
    LEFT JOIN twofortyfive t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_mo_3 (instance_id);
CREATE INDEX ON local_hathi.h_mo_3 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_3 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_3 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_3 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_3 (call_number);
CREATE INDEX ON local_hathi.h_mo_3 (discovery_suppress);

--4---------------------selects records with 336 $aunmediated content and filters from h_mono_245_h_245_h----------------  
DROP TABLE IF EXISTS local_hathi.h_mo_4;
CREATE TABLE local_hathi.h_mo_4 AS
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
    FROM local_hathi.h_mo_3 hm
    LEFT JOIN threethirtysix t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_mo_4 (instance_id);
CREATE INDEX ON local_hathi.h_mo_4 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_4 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_4 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_4 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_4 (call_number);
CREATE INDEX ON local_hathi.h_mo_4 (discovery_suppress);

--5--------------------selects records with 300 $amap or maps and filters from hathi_336------------------ 
DROP TABLE IF EXISTS local_hathi.h_mo_5;
CREATE TABLE local_hathi.h_mo_5 AS
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
    FROM local_hathi.h_mo_4 hm
    left JOIN threehundred t ON hm.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_mo_5 (instance_id);
CREATE INDEX ON local_hathi.h_mo_5 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_5 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_5 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_5 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_5 (call_number);
CREATE INDEX ON local_hathi.h_mo_5 (discovery_suppress);
--6-----------------------filters records by certain values in call number from hm_330-------------------
DROP TABLE IF EXISTS local_hathi.h_mo_6;
CREATE TABLE local_hathi.h_mo_6 AS
SELECT 
    hm.instance_hrid,
    hm.instance_id,
    hm.call_number,
    hm.permanent_location_name,
    hm.holdings_id,
    hm.holdings_hrid,
    hm.discovery_suppress
    FROM local_hathi.h_mo_5 hm  
    WHERE hm.call_number !~~* 'on order%'
    AND hm.call_number !~~* 'in process%'
    AND hm.call_number !~~* 'Available for the library to purchase'
    AND hm.call_number !~~* '%film%' 
    AND hm.call_number !~~* '%fiche%'
    AND hm.call_number !~~* 'On selector%'
    AND hm.call_number !~~* '%dis%'
    AND hm.call_number !~~* '%vault%'
;

CREATE INDEX ON local_hathi.h_mo_6 (instance_id);
CREATE INDEX ON local_hathi.h_mo_6 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_6 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_6 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_6 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_6 (call_number);
CREATE INDEX ON local_hathi.h_mo_6 (discovery_suppress);

--7--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS local_hathi.h_mo_7;
CREATE TABLE local_hathi.h_mo_7 AS
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
    FROM local_hathi.h_mo_6 hm
    INNER JOIN oclc_no AS oclcno ON hm.instance_id = oclcno.instance_id
;
CREATE INDEX ON local_hathi.h_mo_7 (instance_id);
CREATE INDEX ON local_hathi.h_mo_7 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_7 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_7 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_7 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_7 (call_number);
CREATE INDEX ON local_hathi.h_mo_7 (discovery_suppress);
----------8 cleares statements ----------
DROP TABLE IF EXISTS local_hathi.h_mo_8;
CREATE TABLE local_hathi.h_mo_8 AS 
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
     FROM local_hathi.h_mo_7 hm
     LEFT JOIN folio_reporting.holdings_ext he ON hm.holdings_id = he.holdings_id
     LEFT JOIN folio_reporting.holdings_statements hs ON hm.holdings_id = hs.holdings_id 
     WHERE  (hs."statement" IN ('1 v.')
     OR hs."statement" IS NULL)
;
CREATE INDEX ON local_hathi.h_mo_8 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_8 ("statement");
CREATE INDEX ON local_hathi.h_mo_8 (instance_id);
CREATE INDEX ON local_hathi.h_mo_8 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_8 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_8 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_8 (call_number);
CREATE INDEX ON local_hathi.h_mo_8 (type_name);
CREATE INDEX ON local_hathi.h_mo_8 (discovery_suppress);
---9-------assigns statuses and conditions-----------
DROP TABLE IF EXISTS local_hathi.h_mo_8b;
CREATE TABLE local_hathi.h_mo_8b AS 
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
     FROM local_hathi.h_mo_8 hm
     LEFT JOIN folio_reporting.item_ext ie ON hm.holdings_id = ie.holdings_record_id
     LEFT JOIN folio_reporting.holdings_notes hn ON hm.holdings_hrid=hn.holdings_hrid
     GROUP BY hm."statement", ie.item_id, hm.instance_hrid, hm.instance_id, hm.holdings_id, hm.holdings_hrid, hm.permanent_location_name,
     hm.call_number, hn.note, ie.enumeration, ie.chronology, ie.status_name, hm.discovery_suppress, ie.damaged_status_name
;
CREATE INDEX ON local_hathi.h_mo_8b (item_id);
CREATE INDEX ON local_hathi.h_mo_8b (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_8b ("statement");
CREATE INDEX ON local_hathi.h_mo_8b (instance_id);
CREATE INDEX ON local_hathi.h_mo_8b (holdings_id);
CREATE INDEX ON local_hathi.h_mo_8b (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_8b (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_8b (call_number);
CREATE INDEX ON local_hathi.h_mo_8b (note);
CREATE INDEX ON local_hathi.h_mo_8b (enumeration);
CREATE INDEX ON local_hathi.h_mo_8b (chronology);
CREATE INDEX ON local_hathi.h_mo_8b (status_name);
CREATE INDEX ON local_hathi.h_mo_8b (discovery_suppress);
CREATE INDEX ON local_hathi.h_mo_8b (damaged_status_name);
-------------------------------------------------------
   DROP TABLE IF EXISTS local_hathi.h_mo_9;
    CREATE TABLE local_hathi.h_mo_9 AS 
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
FROM local_hathi.h_mo_8b hm;
CREATE INDEX ON local_hathi.h_mo_9 (item_id);
CREATE INDEX ON local_hathi.h_mo_9 (instance_hrid);
CREATE INDEX ON local_hathi.h_mo_9 ("statement");
CREATE INDEX ON local_hathi.h_mo_9 (instance_id);
CREATE INDEX ON local_hathi.h_mo_9 (holdings_id);
CREATE INDEX ON local_hathi.h_mo_9 (hldings_hrid);
CREATE INDEX ON local_hathi.h_mo_9 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mo_9 (call_number);
CREATE INDEX ON local_hathi.h_mo_9 (note);
CREATE INDEX ON local_hathi.h_mo_9 (enumeration);
CREATE INDEX ON local_hathi.h_mo_9 (chronology);
CREATE INDEX ON local_hathi.h_mo_9 (status_name);
CREATE INDEX ON local_hathi.h_mo_9 (discovery_suppress);
CREATE INDEX ON local_hathi.h_mo_9 (damaged_status_name);
--9------------------------------selects value for government document from 008 --------------
DROP TABLE IF EXISTS local_hathi.h_mo_final;
CREATE TABLE local_hathi.h_mo_final AS
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
   FROM  local_hathi.h_mo_9 AS hm
   LEFT JOIN gov_doc AS gd ON hm.instance_hrid = gd.instance_hrid
   LEFT JOIN local_hathi.h_mo_7 AS os ON hm.instance_hrid = os.instance_hrid
   GROUP BY os.OCLC, hm.instance_hrid, hm."Status", hm."Condition", gd.GovDoc
;
CREATE INDEX ON local_hathi.h_mo_final (GovDoc);
CREATE INDEX ON local_hathi.h_mo_final (Bib Id);
CREATE INDEX ON local_hathi.h_mo_final ("Status");
CREATE INDEX ON local_hathi.h_mo_final ("Condition");
CREATE INDEX ON local_hathi.h_mo_final (OCLC);
