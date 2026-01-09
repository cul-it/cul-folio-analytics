 --1----selects pull of records based on ldr type ans 008 publication status and filters certain locations-----------
DROP table IF EXISTS local_hathitrust.h_mo_1;
CREATE TABLE local_hathitrust.h_mo_1 AS
SELECT
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm."content" AS ct1,
    substring(sm."content", 7, 2) AS "type_m"
FROM folio_source_record.marc__t sm 
LEFT JOIN folio_source_record.records_lb__ rl on sm.matched_id=rl.matched_id
WHERE (sm.field = '000' AND substring(sm."content", 7, 2) IN ('aa', 'am', 'cm', 'dm', 'em', 'tm'))
       and rl.state ='ACTUAL'
  ;
--2--------filter locations-------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_2; 
CREATE TABLE local_hathitrust.h_mo_2 AS 
SELECT 
    hm.instance_id,
    hm.instance_hrid,
    he.id as hold_id,
    he.holdings_hrid,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
FROM  local_hathitrust.h_mo_1 hm
LEFT JOIN  folio_derived.holdings_ext he ON hm.instance_id::uuid=he.instance_id::uuid
WHERE he.permanent_location_name NOT ILIKE ALL (ARRAY[
      'serv,remo', 'Borrow Direct', 'Interlibrary Loan - Olin','%LTS%', '%A/V', 'No Library', 
      '%inactive%', '%Olin A/V%', '%micro%'])
;
--3------------------------selects records with 245 $h[electronic resource] and filter------------------------
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
FROM folio_source_record.marc__t sm
LEFT JOIN folio_source_record.records_lb__ rl on sm.matched_id=rl.matched_id
LEFT JOIN folio_derived.holdings_ext he ON rl.external_id::uuid = he.instance_id::uuid
WHERE ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
      OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%'))
      AND he.permanent_location_name !~~ 'serv,remo'
      AND rl.state='ACTUAL'
)
SELECT 
    hm.instance_id,
    hm.instance_hrid,
    hm.hold_id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.discovery_suppress
FROM local_hathitrust.h_mo_2 hm
LEFT JOIN twofortyfive t ON hm.instance_id::uuid = t.instance_id::uuid
WHERE t.instance_id IS NULL
;
---4--------gets rid of some call numbers-------------------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_mo_4;
CREATE TABLE local_hathitrust.h_mo_4 AS
SELECT 
    hm.instance_hrid,
    hm.instance_id,
    hm.call_number,
    hm.permanent_location_name,
    hm.hold_id,
    hm.holdings_hrid,hm.discovery_suppress
FROM local_hathitrust.h_mo_3  hm  
WHERE hm.call_number !~~*'On Order%'and hm.call_number !~~*'In Process'
      and hm.call_number !~~*'%Thesis%' and hm.call_number !~~* '%Film%'
      and hm.call_number !~~*'%Microfiche%'
      and hm.call_number !~~*'%Fiche%'
      and hm.call_number !~~*'%Microprint%'and hm.call_number !~~*'No call number'
      and hm.call_number !~~*'on-order%'and hm.call_number !~~*'%microfiche' 
      and hm.call_number !~~* '%out of print%'
      and hm.call_number !~~* 'in prcess' and hm.call_number !~~*'In  Process'
      and hm.call_number !~~*'suppressed'and hm.call_number !~~*'Decision pending'
      and hm.call_number !~~*'microprint'and hm.call_number !~~*'%cancld%'
      and hm.call_number !~~*'%cancelled%'and hm.call_number !~~*'Gussman Box'
      and hm.call_number !~~*'online'and hm.call_number !~~*'test'
      and hm.call_number !~~* 'order cancelled'and hm.call_number !~~* '%disk%'
      and hm.call_number !~~*'%disc%'
  ;
--5--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS local_hathitrust.h_mo_5;
CREATE TABLE local_hathitrust.h_mo_5 AS
WITH oclc_no AS (
    SELECT DISTINCT ON (ii2.instance_id)
    ii2.instance_id,
    ii2.instance_hrid,
    ii2.identifier_type_name AS id_type,
    ii2.identifier AS oclc_number2,
    ii2.identifier_ordinality
FROM folio_derived.instance_identifiers AS ii2
WHERE ii2.identifier_type_name = 'OCLC' 
ORDER BY ii2.instance_id, ii2.identifier_ordinality
)
SELECT 
    DISTINCT hm.instance_id,
    hm.instance_hrid,
    hm.hold_id,
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
        ELSE oclcno.oclc_number2 END AS oclc
FROM local_hathitrust.h_mo_4 hm
INNER JOIN oclc_no AS oclcno ON hm.instance_id::uuid = oclcno.instance_id::uuid
;

----------6 cleares statements ----------
DROP TABLE IF EXISTS local_hathitrust.h_mo_6;
CREATE TABLE local_hathitrust.h_mo_6 AS 
SELECT
     hm.instance_hrid,hm.oclc,
     hs.holdings_statement,
     hm.instance_id,
     hm.hold_id,
     hm.holdings_hrid,
     hm.permanent_location_name,
     hm.call_number,
     he.type_name,
     han.administrative_note,
     hm.discovery_suppress 
FROM local_hathitrust.h_mo_5 hm
LEFT JOIN folio_derived.holdings_ext he ON hm.hold_id = he.id
LEFT JOIN folio_derived.holdings_statements hs ON hm.hold_id = hs.holdings_id 
LEFT JOIN folio_derived.holdings_administrative_notes han on hm.hold_id=han.holdings_id
WHERE  (hs.holdings_statement IN ('1 v.') OR hs.holdings_statement IS NULL)
;
---7-------assigns statuses and conditions-----------
DROP TABLE IF EXISTS local_hathitrust.h_mo_7;
CREATE TABLE local_hathitrust.h_mo_7 AS 
SELECT
  ie.item_id,
  hm.holdings_statement,
  hm.instance_hrid,hm.oclc,
  hm.instance_id,
  hm.hold_id,
  hm.holdings_hrid,
  hm.permanent_location_name,
  hm.call_number,
  hm.discovery_suppress,
  STRING_AGG(hn.note, ' | ' ORDER BY hn.note) AS note,
  hm.administrative_note,
  ie.enumeration,
  ie.chronology,
  ie.status_name,
  ie.damaged_status_name
FROM local_hathitrust.h_mo_6 hm
LEFT JOIN folio_derived.item_ext ie ON hm.hold_id = ie.holdings_record_id
LEFT JOIN folio_derived.holdings_notes hn ON hm.holdings_hrid = hn.holding_hrid
WHERE NOT (
   COALESCE(ie.enumeration, '') ~* '(disk|disc|cd|dvd)'
   OR COALESCE(ie.chronology,  '') ~* '(disk|disc|cd|dvd)'
)
GROUP BY
  ie.item_id, hm.holdings_statement, hm.instance_hrid,hm.oclc,hm.instance_id,
  hm.hold_id,hm.holdings_hrid,hm.permanent_location_name,hm.call_number,hm.discovery_suppress,
  hm.administrative_note,ie.enumeration,ie.chronology,ie.status_name,ie.damaged_status_name
;

DROP TABLE IF EXISTS local_hathtrust.h_mo_8;
CREATE TABLE local_hathitrust.h_mo_8 AS
SELECT
    hm.item_id,
    hm.holdings_statement,
    hm.instance_hrid,hm.oclc,
    hm.instance_id,
    hm.holdings_hrid,
    hm.permanent_location_name,
    hm.call_number,
    hm.enumeration,
    hm.chronology,
    hm.status_name,
    hm.discovery_suppress,
    hm.note,
    hm.administrative_note,
    hm.damaged_status_name,
    CASE
        WHEN hm.discovery_suppress is TRUE
             AND (hm.note ILIKE ANY (ARRAY['%withdr%', '%wd%', '%wdn%'])
                   OR (hm.administrative_note ILIKE '%type:w%'))
        THEN 'WD'
        WHEN hm.status_name = 'Withdrawn'
        THEN 'WD'
        WHEN hm.status_name IN ('Missing', 'Lost and paid', 'Aged to lost', 'Declared lost', 'Long Missing')
        THEN 'LM'
        ELSE 'CH'
    END AS "Status",
    CASE WHEN hm.damaged_status_name = 'Damaged' THEN 'BRT' ELSE NULL END AS "Condition"
FROM local_hathitrust.h_mo_7 hm
;

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
FROM folio_source_record.marc__t sm
LEFT JOIN folio_source_record.records_lb rl on sm.matched_id=rl.matched_id
WHERE sm.field = '008' and rl.state='ACTUAL'
)
SELECT
   hm.oclc,
   hm.instance_hrid AS local_id,
   gd.GovDoc,
   hm."Status" AS "status",
   hm."Condition" AS "condition"
FROM  local_hathitrust.h_mo_8 AS hm
LEFT JOIN gov_doc AS gd ON hm.instance_hrid = gd.instance_hrid
WHERE hm.oclc NOT IN ('','NEW')
;
DROP table IF EXISTS local_hathitrust.h_mo_1;
DROP table IF EXISTS local_hathitrust.h_mo_2;
DROP table IF EXISTS local_hathitrust.h_mo_3;
DROP table IF EXISTS local_hathitrust.h_mo_4;
DROP table IF EXISTS local_hathitrust.h_mo_5;
DROP table IF EXISTS local_hathitrust.h_mo_6;
DROP table IF EXISTS local_hathitrust.h_mo_7;
DROP table IF EXISTS local_hathitrust.h_mo_8;
DROP table IF EXISTS local_hathitrust.h_mo_9;
