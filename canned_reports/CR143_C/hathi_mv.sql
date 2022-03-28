/*Harvest Specification

 I. Harvest the bibs that have the following characteristics.

--A. Suppression don't care, want suppressed and unsuppressed bibs.

--B. Leader/06-07=aa, am, cm, dm, em or tm

--C. 008/6=m or q, r, s, or t

D. Does not contain a 245 subfield h

E. If 336 is present subfield a must equal "text".

F. Must have an 035 (OCoLC) number

G. Must not have in 300 subfield a and only subfield a “map” or “maps”

H. Check  if 008/17=u and 008/28=f, if both conditions exist mark in report as “1” and if not “0”, see below for report formatting.
Processing Description
II. Examine all the MFHDs associated with each bib.
--A. Suppression don’t care.
--B. Discard any MFHD with the location serv,remo
--C. Must have content in 852 subfield h other than “On Order,” “In Process,” “Available for the library to purchase”, Film or *fiche (all not case sensitive). 852 k or m subfields cannot contain work Disk or Disc.
--D. MFHD must have at least one 866 or if one 866 cannot have text 1 v.
E. Suppressed MFHDs that meet condition d mark as “WD” for “Withdrawn.”
F. Unsuppressed MFHDs that meet condition  must examine item record and if the Voyager 
item status = 12, 13, or 14 mark as “LM” for “Lost/Missing”. 
Any item with status = 17 marks as “WD” for “Withdrawn” and ignore any other statuses for that item.
 Any other item with any other status, mark as “CH” for “Current Holding.”
G. Item must have text in item’s enumeration or chronology.
H. Unsuppressed MFHDs that are not serv,remo that meets conditions c and d and lack items mark as CH
III. For each MFHD which meets the criteria retrieve the following: OCoLC 035 number, drop the prefix (OCoLC) for report, drop any alpha characters preceding the number such as ocm or ocn. If more than one OCLC number in record, use the first occurrence.
A. Bib id, add bib to number
B. The marked status of the MFHD or item, CH, LM, or WD.
C. Include null value for condition.
D. Include text from enum/chron of item as applicable.
E. Government document status either 0 (not) or 1 (is government document)
F. Repeat tab delimited values for each holding/item for the bib that meets the criteria with a maximum file size of 100 MB to be place in HathiTrust server file space. File name: Hathi-MULTI-YYYYMMDD-[file number]

For example: bib 12345 has 1 items which meet criteria unsuppressed.

OCLC                Bib Id            Status      Condition  Enum/chron     GovDoc

623445              bib12345       CH                           v.3                        0 */

-------------------selects records based on type from a Leader/000------------------------------
DROP table IF EXISTS local_hathi.h_mv_1;
CREATE TABLE local_hathi.h_mv_1 AS
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

CREATE INDEX ON local_hathi.h_mv_1 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_1 (instance_id);
CREATE INDEX ON local_hathi.h_mv_1 (field);
CREATE INDEX ON local_hathi.h_mv_1 (sf);
CREATE INDEX ON local_hathi.h_mv_1 (ct1);
CREATE INDEX ON local_hathi.h_mv_1 ("type_m");


----------------selects records from previous table and filters on 008 language material------------
DROP table IF EXISTS local_hathi.h_mv_1b;
CREATE TABLE local_hathi.h_mv_1b AS
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
    and (sm.field = '008' AND substring(sm."content", 7, 1) IN ('m', 'q', 'r', 's', 't')))
    SELECT 
    h1.instance_hrid,
    h1.instance_id,
    h1b."type_publ",
    h1."type_m"
    FROM local_hathi.h_mv_1 h1
    inner JOIN publ_stat h1b ON h1.instance_id = h1b.instance_id
;

CREATE INDEX ON local_hathi.h_mv_1b (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_1b (instance_id);
CREATE INDEX ON local_hathi.h_mv_1b ("type_publ");
CREATE INDEX ON local_hathi.h_mv_1b ("type_m");

--2--------filters records based on locations-------------------------------
DROP TABLE IF EXISTS local_hathi.h_mv_2; 
CREATE TABLE local_hathi.h_mv_2 AS 
SELECT 
    lhm.instance_id,
    lhm.instance_hrid,
    h.holdings_id,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress 
    FROM  local_hathi.h_mv_1b lhm
    LEFT JOIN  folio_reporting.holdings_ext h ON lhm.instance_id=h.instance_id
    WHERE h.permanent_location_name NOT like 'serv,remo'
    AND h.permanent_location_name NOT LIKE 'Borrow Direct'
    AND h.permanent_location_name NOT ilike '%LTS%'
    AND h.permanent_location_name NOT LIKE '%A/V'
;

CREATE INDEX ON local_hathi.h_mv_2 (instance_id);
CREATE INDEX ON local_hathi.h_mv_2 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_2 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_2 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_2 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_2 (call_number);
CREATE INDEX ON local_hathi.h_mv_2 (discovery_suppress);



--3------------------------selects/deselects records with 245 $h[electronic resource] and filters from h_mv_2------------------------
DROP TABLE IF EXISTS local_hathi.h_mv_3;   
CREATE TABLE local_hathi.h_mv_3 AS
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
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    WHERE 
    ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
    OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%')
    OR (sm.field = '245' AND sm.sf = 'h' AND sm.CONTENT LIKE '%[sound recording]%'))
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_id, sm.instance_hrid, he.holdings_hrid, 
    sm.CONTENT, sm.field, sm.sf, he.instance_id, 
    he.permanent_location_name, he.call_number)
    SELECT 
    h.instance_id,
    h.instance_hrid,
    h.holdings_id,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress
    FROM local_hathi.h_mv_2 h
    LEFT JOIN twofortyfive t ON h.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;

CREATE INDEX ON local_hathi.h_mv_3 (instance_id);
CREATE INDEX ON local_hathi.h_mv_3 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_3 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_3 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_3 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_3 (call_number);
CREATE INDEX ON local_hathi.h_mv_3 (discovery_suppress);


--4---------------------selects/deselects records with 336 $atext content and filters from h_mv_3----------------  
DROP TABLE IF EXISTS local_hathi.h_mv_4;
CREATE TABLE local_hathi.h_mv_4 AS
WITH threethirtysix AS (
SELECT 
    sm.instance_id,
    sm.field,
    sm.sf,
    sm.content 
    FROM 
    srs_marctab sm
    WHERE
    (sm.field = '336' AND sm.sf = 'a' AND sm.CONTENT != 'text')
    GROUP BY sm.instance_id, sm.field, sm.sf, sm.CONTENT)
    SELECT 
    h.instance_id,
    h.instance_hrid,
    h.holdings_id,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress 
    FROM local_hathi.h_mv_3 h
    LEFT JOIN threethirtysix t ON h.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_mv_4 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_4 (instance_id);
CREATE INDEX ON local_hathi.h_mv_4 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_4 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_4 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_4 (call_number);
CREATE INDEX ON local_hathi.h_mv_4 (discovery_suppress);

--5--------------------selects records with 300 $amap or maps and filters from h_mv_4------------------ 
DROP TABLE IF EXISTS local_hathi.h_mv_5;
CREATE TABLE local_hathi.h_mv_5 AS
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
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE 
    (sm.field = '300' AND sm.sf ='a' AND sm.CONTENT like '%map%') 
    AND sr.state  = 'ACTUAL'
    GROUP BY 
    sm.instance_hrid, 
    sm.CONTENT, 
    sm.field, 
    sm.sf, 
    he.instance_id, 
    he.holdings_hrid,
    he.permanent_location_name, 
    he.call_number, 
    he.discovery_suppress)
    SELECT 
    h.instance_id,
    h.instance_hrid,
    h.holdings_id,
    h.holdings_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress
    FROM local_hathi.h_mv_4 h
    left JOIN threehundred t ON h.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_mv_5 (instance_id);
CREATE INDEX ON local_hathi.h_mv_5 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_5 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_5 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_5 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_5 (call_number);
CREATE INDEX ON local_hathi.h_mv_5 (discovery_suppress);

--6-----------------------filters records by certain values in call number from h_mv_5-------------------
DROP TABLE IF EXISTS local_hathi.h_mv_6;
CREATE TABLE local_hathi.h_mv_6 AS
SELECT 
    hhn.instance_id,
    hhn.instance_hrid,
    hhn.holdings_id,
    hhn.holdings_hrid,
    hhn.call_number,
    hhn.permanent_location_name,
    hhn.discovery_suppress
    FROM local_hathi.h_mv_5 hhn  
    WHERE hhn.call_number !~~* 'on order%'
    AND hhn.call_number !~~* 'in process%'
    AND hhn.call_number !~~* 'Available for the library to purchase'
    AND hhn.call_number !~~* '%film%' 
    AND hhn.call_number !~~* '%fiche%'
    AND hhn.call_number !~~* 'On selector%'
    AND hhn.call_number !~~* '%dis%'
    AND hhn.call_number !~~* '%film%'
    AND hhn.call_number !~~* '%vault%'
;

CREATE INDEX ON local_hathi.h_mv_6 (instance_id);
CREATE INDEX ON local_hathi.h_mv_6 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_6 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_6 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_6 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_6 (call_number);
CREATE INDEX ON local_hathi.h_mv_6 (discovery_suppress);

--7--------------------filters records with oclc number------------------    
DROP TABLE IF EXISTS local_hathi.h_mv_7;
CREATE TABLE local_hathi.h_mv_7 AS
WITH oclc_no AS (
    SELECT
    ii2.instance_id AS instance_id,
    ii2.identifier_type_name AS id_type,
    ii2.identifier AS oclc_number2
    FROM folio_reporting.instance_identifiers AS ii2
    WHERE ii2.identifier_type_name = 'OCLC')
    SELECT 
    DISTINCT hsn.instance_id,
    hsn.instance_hrid,
    hsn.holdings_id,
    hsn.holdings_hrid,
    hsn.call_number,
    hsn.permanent_location_name,
    hsn.discovery_suppress,
    oclcno.id_type,
    oclcno.oclc_number2,
    CASE 
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)ocm%' THEN SUBSTRING(oclcno.oclc_number2, 11)
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)ocn%' THEN SUBSTRING(oclcno.oclc_number2, 11)
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)%' THEN SUBSTRING(oclcno.oclc_number2, 8)
        ELSE oclcno.oclc_number2 END AS oclc_no
    FROM local_hathi.h_mv_6 hsn 
    INNER JOIN oclc_no AS oclcno ON hsn.instance_id = oclcno.instance_id
;

CREATE INDEX ON local_hathi.h_mv_7 (instance_id);
CREATE INDEX ON local_hathi.h_mv_7 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_7 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_7 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_7 (call_number);
CREATE INDEX ON local_hathi.h_mv_7 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_7 (discovery_suppress);
CREATE INDEX ON local_hathi.h_mv_7 (id_type);
CREATE INDEX ON local_hathi.h_mv_7 (oclc_number2);
CREATE INDEX ON local_hathi.h_mv_7 (oclc_no);

----------8 clears holdings statements ----------
drop table IF EXISTS local_hathi.h_mv_8 ;
CREATE table local_hathi.h_mv_8 as
SELECT
      hm.instance_id,
      hm.instance_hrid,
      hm.holdings_id,
      hm.holdings_hrid,
      hs."statement",
      hm.permanent_location_name,
      hn.note,
      hm.oclc_no,
      hm.call_number,
      he.type_name,
      hm.discovery_suppress 
FROM local_hathi.h_mv_7 hm
LEFT JOIN folio_reporting.holdings_ext  he ON hm.holdings_id = he.holdings_id
LEFT JOIN folio_reporting.holdings_statements hs ON hm.holdings_id = hs.holdings_id 
LEFT JOIN folio_reporting.holdings_notes hn ON hm.holdings_id = hn.holdings_id
where (hs."statement" NOT IN ('1 v.'))
;
CREATE INDEX ON local_hathi.h_mv_8 (instance_id);
CREATE INDEX ON local_hathi.h_mv_8 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_8 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_8 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_8 ("statement");
CREATE INDEX ON local_hathi.h_mv_8 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_8 (note);
CREATE INDEX ON local_hathi.h_mv_8 (call_number);
CREATE INDEX ON local_hathi.h_mv_8 (type_name)
CREATE INDEX ON local_hathi.h_mv_8 (discovery_suppress);

------------------------------------------
DROP TABLE IF EXISTS local_hathi.h_mv_8b;
CREATE TABLE local_hathi.h_mv_8b AS 
SELECT 
DISTINCT he.item_id,
he.item_hrid,
hm.instance_id,
hm.instance_hrid,
hm.holdings_id,
hm.holdings_hrid,
hm.permanent_location_name,
hm.call_number,
he.enumeration,
he.chronology,
he.number_of_pieces,
he.number_of_missing_pieces,
he.status_name,
he.damaged_status_name,
hm.note,
hm.discovery_suppress,
hm.oclc_no
FROM local_hathi.h_mv_8 hm
LEFT JOIN folio_reporting.item_ext he ON hm.holdings_id = he.holdings_record_id
--WHERE ((he.enumeration IS NULL and he.chronology IS NULL)
--AND (hm.discovery_suppress IS TRUE OR hm.discovery_suppress IS NULL))
;

CREATE INDEX ON local_hathi.h_mv_8b (item_hrid);
CREATE INDEX ON local_hathi.h_mv_8b (instance_id);
CREATE INDEX ON local_hathi.h_mv_8b (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_8b (holdings_id);
CREATE INDEX ON local_hathi.h_mv_8b (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_8b (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_8b (call_number);
CREATE INDEX ON local_hathi.h_mv_8b (enumeration);
CREATE INDEX ON local_hathi.h_mv_8b (chronology);
CREATE INDEX ON local_hathi.h_mv_8b (number_of_pieces);
CREATE INDEX ON local_hathi.h_mv_8b (number_of_missing_pieces);
CREATE INDEX ON local_hathi.h_mv_8b (status_name);
CREATE INDEX ON local_hathi.h_mv_8b (damaged_status_name);
CREATE INDEX ON local_hathi.h_mv_8b (note);
CREATE INDEX ON local_hathi.h_mv_8b (discovery_suppress);

---9-------assigns statuses and conditions-----------
DROP TABLE IF EXISTS local_hathi.h_mv_9;
CREATE TABLE local_hathi.h_mv_9 as
SELECT 
DISTINCT hs.item_id,
hs.instance_hrid,
hs.instance_id,
hs.holdings_id,
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
                   WHEN hs.status_name IN ('Missing', 'Lost and paid', 'Aged to lost', 'Declared lost')
                   THEN 'LM' 
                        ELSE 'CH' END AS "status",
hs.damaged_status_name,
CASE WHEN (hs.damaged_status_name = 'Damaged')
           THEN 'BRT'
           ELSE '0' END AS "condition",
CASE WHEN (hs.enumeration IS NOT NULL)
            THEN hs.enumeration 
            WHEN hs.enumeration IS NULL 
            THEN hs.chronology 
            ELSE '' END AS "Enum/Chron"
FROM local_hathi.h_mv_8b hs 
GROUP BY 
hs.instance_hrid,
hs.instance_id,
hs.holdings_id,
hs.holdings_hrid,
hs.item_id,
hs.oclc_no,
hs.permanent_location_name,
hs.call_number,
hs.enumeration,
hs.chronology,
hs.status_name,
hs.discovery_suppress,
hs.damaged_status_name
;
CREATE INDEX ON local_hathi.h_mv_9 (item_id);
CREATE INDEX ON local_hathi.h_mv_9 (instance_id);
CREATE INDEX ON local_hathi.h_mv_9 (instance_hrid);
CREATE INDEX ON local_hathi.h_mv_9 (holdings_id);
CREATE INDEX ON local_hathi.h_mv_9 (holdings_hrid);
CREATE INDEX ON local_hathi.h_mv_9 (permanent_location_name);
CREATE INDEX ON local_hathi.h_mv_9 (call_number);
CREATE INDEX ON local_hathi.h_mv_9 (enumeration);
CREATE INDEX ON local_hathi.h_mv_9 (chronology);
CREATE INDEX ON local_hathi.h_mv_9 (number_of_pieces);
CREATE INDEX ON local_hathi.h_mv_9 (number_of_missing_pieces);
CREATE INDEX ON local_hathi.h_mv_9 (status_name);
CREATE INDEX ON local_hathi.h_mv_9 (status);
CREATE INDEX ON local_hathi.h_mv_9 (oclc_no);
CREATE INDEX ON local_hathi.h_mv_9 (damaged_status_name);
CREATE INDEX ON local_hathi.h_mv_9 (discovery_suppress);


--10------------------------------selects value for government document from 008 ---------
-- total number of records as of 12/07/2021 is 928,334 --------------
DROP TABLE IF EXISTS local_hathi.h_mv_final;
CREATE TABLE local_hathi.h_mv_final AS
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
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE
    sm.field = '008'AND sr.state  = 'ACTUAL'
)
SELECT
   hm.oclc_no AS "OCLC",
   hm.instance_hrid AS "Bib_id",
   hm.status AS "Status",
   hm."condition" AS "Condition",
   hm."Enum/Chron",
   gd.GovDoc
   FROM local_hathi.h_mv_9 AS hm
   LEFT JOIN gov_doc AS gd ON hm.instance_hrid = gd.instance_hrid
   WHERE hm.status != 'NWD'
;
CREATE INDEX ON local_hathi.h_mv_final (OCLC);
CREATE INDEX ON local_hathi.h_mv_final (Bib_id);
CREATE INDEX ON local_hathi.h_mv_final (Status);
CREATE INDEX ON local_hathi.h_mv_final ("Condition");
CREATE INDEX ON local_hathi.h_mv_final ("Enum/Chron")
CREATE INDEX ON local_hathi.h_mv_final (GovDoc);
