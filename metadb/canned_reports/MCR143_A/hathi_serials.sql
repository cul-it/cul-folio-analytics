-1----selects pull of records based on ldr and filters certain locations-----------
DROP TABLE IF EXISTS local_hathitrust.h_s_1; 
CREATE TABLE local_hathitrust.h_s_1 AS
SELECT DISTINCT 
    sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm.content,
    substring(sm.content, 7, 2) AS bib_type,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
FROM local_derived.marc__t sm 
LEFT JOIN folio_derived.holdings_ext he ON sm.instance_id = he.instance_id::uuid
WHERE (sm.field = '000' AND substring(sm.content, 7, 2) = 'as')
  AND (he.permanent_location_name IS NULL OR he.permanent_location_name NOT ILIKE ALL (ARRAY[
            'serv,remo', 'Borrow Direct', 'Interlibrary Loan - Olin', '%LTS%', '%A/V',
            'No Library', '%inactive%', '%Olin A/V%', '%micro%', 'wood%']));

--2------------selects/deselects records with 945 (monoseries standing orders) and filters it from h_s_1 table-------------------------------------
DROP TABLE IF EXISTS local_hathitrust.h_s_2;
CREATE TABLE local_hathitrust.h_s_2 AS
SELECT 
    hsr.instance_hrid,
    hsr.instance_id,
    hsr.permanent_location_name,
    hsr.call_number 
FROM local_hathitrust.h_s_1 hsr
WHERE NOT EXISTS (
    SELECT 1
    FROM local_derived.marc__t sm
    WHERE sm.instance_id = hsr.instance_id AND sm.sf = 'a' AND sm.field = '945');

--3------------------------selects/deselects records with 245 $h[electronic resource] and filters from h_s_2 table------------------------
DROP TABLE IF EXISTS local_hathitrust.h_s_3;   
CREATE TABLE local_hathitrust.h_s_3 AS 
SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number,
    he.discovery_suppress,
    he.id
FROM local_hathitrust.h_s_2 h
LEFT JOIN folio_derived.holdings_ext he ON h.instance_id::uuid = he.instance_id::uuid
     AND he.permanent_location_name !~~ 'serv,remo'
WHERE NOT EXISTS (
    SELECT 1
    FROM local_derived.marc__t sm
    LEFT JOIN folio_derived.holdings_ext he2 ON sm.instance_id = he2.instance_id::uuid
    WHERE sm.instance_id = h.instance_id
      AND sm.field = '245'
      AND sm.sf = 'h'
      AND (sm.content LIKE '%[electronic resource]%' OR sm.content LIKE '%[microform]%'));

--4-----------------------filters suppressed holding records with the note "decision - no"-----------
DROP TABLE IF EXISTS local_hathitrust.h_s_4;
CREATE TABLE local_hathitrust.h_s_4 AS
SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number,
    h.discovery_suppress
FROM local_hathitrust.h_s_3 h
WHERE NOT EXISTS (
    SELECT 1
    FROM folio_derived.holdings_notes hn
    WHERE h.id::uuid = hn.holding_id::uuid
      AND hn.note ILIKE '%decision%no%');


--5-----------------------filters records by certain values in call number from h_s_6-------------------
DROP TABLE IF EXISTS local_hathitrust.h_s_5;
CREATE TABLE local_hathitrust.h_s_5 AS
SELECT 
    hhn.instance_hrid,
    hhn.instance_id,
    hhn.call_number,
    hhn.permanent_location_name 
FROM local_hathitrust.h_s_4 hhn  
WHERE hhn.call_number !~~*'On Order%'and hhn.call_number !~~*'In Process'
  AND hhn.call_number !~~*'%Thesis%' and hhn.call_number !~~* '%Film%'
  AND hhn.call_number !~~*'%Microfiche%'
  AND hhn.call_number !~~*'%Fiche%'
  AND hhn.call_number !~~*'%Microprint%'and hhn.call_number !~~*'No call number'
  AND hhn.call_number !~~*'on-order%'and hhn.call_number !~~*'%microfiche' 
  AND hhn.call_number !~~* '%out of print%'
  AND hhn.call_number !~~* 'in prcess' and hhn.call_number !~~*'In  Process'
  AND hhn.call_number !~~*'suppressed'and hhn.call_number !~~*'Decision pending'
  AND hhn.call_number !~~*'microprint'and hhn.call_number !~~*'%cancld%'
  AND hhn.call_number !~~*'%cancelled%'and hhn.call_number !~~*'Gussman Box'
  AND hhn.call_number !~~*'online'and hhn.call_number !~~*'test'
  AND hhn.call_number !~~* 'order cancelled'and hhn.call_number !~~* '%disk%'
  AND hhn.call_number !~~*'%disc%' and hhn.call_number !~~* 'On selector%'
  AND hhn.call_number !~~* '%DECISION%%not selected%';

--6--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS local_hathitrust.h_s_6;
CREATE TABLE local_hathitrust.h_s_6 AS
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
    hsn.call_number,
    hsn.permanent_location_name,
    oclcno.id_type,
    oclcno.oclc_number2,
    regexp_replace(oclcno.oclc_number2, '^\(OCoLC\)(ocm|ocn|on)?', '') AS oclc_no
FROM local_hathitrust.h_s_5 hsn 
INNER JOIN oclc_no AS oclcno ON hsn.instance_id::uuid= oclcno.instance_id::uuid
;


--9------------------------------selects issn number and value for government document from 008 --------------
DROP TABLE IF EXISTS local_hathitrust.h_s_final;
CREATE TABLE local_hathitrust.h_s_final AS
WITH gov_doc AS (
SELECT
    sm.instance_hrid AS instance_hrid,
    CASE WHEN substring(sm.content, 18, 1) IN ('u') AND substring(sm.content, 29, 1) IN ('f') THEN '1'
    ELSE '0' 
    END AS gov_doc
FROM
    local_derived.marc__t sm
    WHERE
    sm.field = '008'
),
issn_select AS (
SELECT 
    sm.instance_hrid AS instance_hrid,
    sm.field AS field,
    sm.CONTENT AS issn_no
FROM local_derived.marc__t sm
WHERE (sm.field = '022' AND sm.sf = 'a' ) 
),
dist_hrid_select AS (
SELECT DISTINCT
   (ho.instance_hrid),
   ho.oclc_no AS oclc_no
   FROM local_hathitrust.h_s_6 AS ho
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
DROP table IF EXISTS local_hathitrust.h_s_4;
DROP table IF EXISTS local_hathitrust.h_s_5;
DROP table IF EXISTS local_hathitrust.h_s_6;
