-1----selects pull of records based on ldr and filters certain locations-----------
DROP TABLE IF EXISTS local_hathitrust.h_s_1; 
CREATE TABLE local_hathitrust.h_s_1 AS
SELECT
DISTINCT sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm.content,
    substring(sm.content, 7, 2) AS bib_type,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
FROM folio_source_record.marc__t sm 
LEFT JOIN folio_source_record.records_lb__ rl on sm.matched_id=rl.matched_id
LEFT JOIN folio_derived.holdings_ext he ON sm.instance_id = he.instance_id::uuid
WHERE (sm.field = '000' AND substring(sm.content, 7, 2) IN ('as'))
      AND he.permanent_location_name NOT ILIKE ALL (ARRAY[
      'serv,remo', 'Borrow Direct', 'Interlibrary Loan - Olin','%LTS%', '%A/V', 'No Library', 
      '%inactive%', '%Olin A/V%', '%micro%'])
      AND rl.state ='ACTUAL'
;

--2------------selects/deselects records with 945 (monoseries standing orders) and filters it from h_s_1 table-------------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_s_2;
CREATE TABLE local_hathitrust.h_s_2 AS
WITH ninefortyfive AS 
(SELECT
    sm.instance_id
    FROM
    folio_source_record.marc__t sm
    left join folio_source_record.records_lb__ rl on sm.matched_id=rl.matched_id
    WHERE (sm.sf = 'a' AND sm.field = '945') and rl.state ='ACTUAL'
    GROUP BY
    sm.instance_id)
SELECT 
    hsr.instance_hrid,
    hsr.instance_id,
    hsr.permanent_location_name,
    hsr.call_number 
FROM local_hathitrust.h_s_1 hsr
LEFT JOIN ninefortyfive n ON hsr.instance_id = n.instance_id
WHERE n.instance_id IS NULL
;


--3------------------------selects/deselects records with 245 $h[electronic resource] and filters from h_s_2 tabe------------------------
DROP TABLE IF EXISTS local_hathitrust.h_s_3;   
CREATE TABLE local_hathitrust.h_s_3 AS 
WITH twofortyfive AS (
SELECT
    sm.instance_hrid,
    sm.CONTENT AS bib_type,
    sm.field,
    sm.sf,
    he.instance_id,
    he.permanent_location_name,
    he.call_number, he.discovery_suppress
    FROM
    folio_source_record.marc__t sm
    LEFT JOIN folio_source_record.records_lb__ rl on sm.matched_id=rl.matched_id
    LEFT JOIN folio_derived.holdings_ext he ON sm.instance_id = he.instance_id::uuid
WHERE 
    ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
    OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%'))
    AND he.permanent_location_name !~~ 'serv,remo'  
    aAND rl.state ='ACTUAL'
    GROUP BY sm.instance_id, sm.instance_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, 
    he.permanent_location_name, he.call_number, he.discovery_suppress)
SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number,t.discovery_suppress
FROM local_hathitrust.h_s_2 h 
LEFT JOIN twofortyfive t ON h.instance_id::uuid= t.instance_id::uuid
WHERE t.instance_id IS NULL
;
--6-----------------------filters suppressed holding records with the note "decision - no"-----------
DROP TABLE IF EXISTS local_hathitrust.h_s_6;
CREATE TABLE local_hathitrust.h_s_6 AS
WITH holdings_note AS
(SELECT 
    hn.note,
    h.instance_id,
    h.instance_hrid,
    hn.holding_hrid,
    hn.holding_id,
    h.discovery_suppress 
    FROM local_hathitrust.h_s_3 h 
    LEFT JOIN folio_derived.holdings_notes hn ON h.instance_id::uuid = hn.instance_id::uuid
    WHERE hn.note ilike ('%decision%%no%')
    AND h.discovery_suppress IS NULL 
    )
SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number,
    hn.note,
    hn.discovery_suppress
FROM local_hathitrust.h_s_3 h
LEFT JOIN holdings_note hn ON h.instance_id = hn.instance_id
WHERE hn.instance_id IS NULL;


--7-----------------------filters records by certain values in call number from h_s_6-------------------
DROP TABLE IF EXISTS local_hathitrust.h_s_7;
CREATE TABLE local_hathitrust.h_s_7 AS
SELECT 
    hhn.instance_hrid,
    hhn.instance_id,
    hhn.call_number,
    hhn.permanent_location_name 
FROM local_hathitrust.h_s_6 hhn  
WHERE hhn.call_number !~~*'On Order%'and hhn.call_number !~~*'In Process'
      and hhn.call_number !~~*'%Thesis%' and hhn.call_number !~~* '%Film%'
      and hhn.call_number !~~*'%Microfiche%'
      and hhn.call_number !~~*'%Fiche%'
      and hhn.call_number !~~*'%Microprint%'and hhn.call_number !~~*'No call number'
      and hhn.call_number !~~*'on-order%'and hhn.call_number !~~*'%microfiche' 
      and hhn.call_number !~~* '%out of print%'
      and hhn.call_number !~~* 'in prcess' and hhn.call_number !~~*'In  Process'
      and hhn.call_number !~~*'suppressed'and hhn.call_number !~~*'Decision pending'
      and hhn.call_number !~~*'microprint'and hhn.call_number !~~*'%cancld%'
      and hhn.call_number !~~*'%cancelled%'and hhn.call_number !~~*'Gussman Box'
      and hhn.call_number !~~*'online'and hhn.call_number !~~*'test'
      and hhn.call_number !~~* 'order cancelled'and hhn.call_number !~~* '%disk%'
      and hhn.call_number !~~*'%disc%' and hhn.call_number !~~* 'On selector%'
      and hhn.call_number !~~* '%DECISION%%not selected%'
;


--8--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS local_hathitrust.h_s_8;
CREATE TABLE local_hathitrust.h_s_8 AS
WITH oclc_no AS (
    SELECT
    ii2.instance_id AS instance_id,
    ii2.identifier_type_name AS id_type,
    ii2.identifier AS oclc_number2
    FROM folio_derived.instance_identifiers AS ii2
    WHERE ii2.identifier_type_name = 'OCLC')
SELECT 
DISTINCT hsn.instance_id,
    hsn.instance_hrid,
    hsn.call_number,
    hsn.permanent_location_name,
    oclcno.id_type,
    oclcno.oclc_number2,
    CASE 
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)ocm%' THEN SUBSTRING(oclcno.oclc_number2, 11)
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)ocn%' THEN SUBSTRING(oclcno.oclc_number2, 11)
        WHEN oclcno.oclc_number2 LIKE '(OCoLC)%' THEN SUBSTRING(oclcno.oclc_number2, 8)
        ELSE oclcno.oclc_number2 
        END AS oclc_no
FROM local_hathitrust.h_s_7 hsn 
INNER JOIN oclc_no AS oclcno ON hsn.instance_id::uuid= oclcno.instance_id::uuid
;


--9------------------------------selects issn number and value for government document from 008 --------------
DROP TABLE IF EXISTS local_hathitrust.h_s_final;
CREATE TABLE local_hathitrust.h_s_final AS
WITH gov_doc AS (
    SELECT
    sm.instance_hrid AS instance_hrid,
    CASE
        WHEN substring(sm.content, 18, 1) IN ('u')
             AND substring(sm.content, 29, 1) IN ('f')
             THEN '1'
             ELSE '0' END AS gov_doc
    FROM
    folio_source_record.marc__t sm
    WHERE
    sm.field = '008'
),
issn_select AS (
    SELECT 
    sm.instance_hrid AS instance_hrid,
    sm.field AS field,
    sm.CONTENT AS issn_no
    FROM folio_source_record.marc__t sm
  left join folio_source_record.records_lb__ rl on sm.matched_id=rl.matched_id
    WHERE (sm.field = '022' AND sm.sf = 'a' ) and rl.state='ACTUAL'
),
dist_hrid_select AS (
   SELECT 
   DISTINCT(ho.instance_hrid),
   ho.oclc_no AS oclc_no
   FROM local_hathitrust.h_s_8 AS ho
)
SELECT
   ds.oclc_no AS oclc,
   ds.instance_hrid AS local_id,
   issn.issn_no AS issn,
   gd.gov_doc AS govdoc
FROM dist_hrid_select AS ds
LEFT JOIN gov_doc AS gd ON ds.instance_hrid = gd.instance_hrid
LEFT JOIN issn_select AS issn ON ds.instance_hrid = issn.instance_hrid
GROUP BY ds.oclc_no, ds.instance_hrid,  issn.issn_no, gd.gov_doc
;
DROP table IF EXISTS local_hathitrust.h_s_1;
DROP table IF EXISTS local_hathitrust.h_s_2;
DROP table IF EXISTS local_hathitrust.h_s_3;
DROP table IF EXISTS local_hathitrust.h_s_6;
DROP table IF EXISTS local_hathitrust.h_s_7;
DROP table IF EXISTS local_hathitrust.h_s_8;
--DROP table IF EXISTS local_hathitrust.h_s_8;
