--1----selects pull of records based on ldr and filters certain locations-----------
DROP TABLE IF EXISTS local_hathi.h_s_1; 
CREATE TABLE local_hathi.h_s_1 AS
SELECT
DISTINCT sm.instance_hrid,
    sm.instance_id,
    sm.field,
    sm.sf,
    sm.content,
    substring(sm.content, 7, 2) AS "type",
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
    FROM srs_marctab sm 
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    LEFT JOIN srs_records sr ON sm.srs_id = sr.id
    WHERE sr.state  = 'ACTUAL'
    AND (sm.field = '000' AND substring(sm.content, 7, 2) IN ('as'))
    AND he.permanent_location_name !~~ 'serv,remo'
    AND he.permanent_location_name !~~ 'Borrow Direct'
    AND he.permanent_location_name !~~* '%LTS%'
;
CREATE INDEX ON local_hathi.h_s_1 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_1 (instance_id);
CREATE INDEX ON local_hathi.h_s_1 (field);
CREATE INDEX ON local_hathi.h_s_1 (sf);
CREATE INDEX ON local_hathi.h_s_1 (content);
CREATE INDEX ON local_hathi.h_s_1 (permanent_location_name);
CREATE INDEX ON local_hathi.h_s_1 (call_number);
CREATE INDEX ON local_hathi.h_s_1 (discovery_suppress);

--2------------selects/deselects records with 945 (monoseries standing orders) and filters it from h_s_1 table-------------------------------------
DROP TABLE IF EXISTS local_hathi.h_s_2;
CREATE TABLE local_hathi.h_s_2 AS
WITH ninefortyfive AS 
(SELECT
    sm.instance_id
    FROM
    srs_marctab sm
    WHERE (sm.sf = 'a' AND sm.field = '945')
    GROUP BY
    sm.instance_id)
    SELECT 
    hsr.instance_hrid,
    hsr.instance_id,
    hsr.permanent_location_name,
    hsr.call_number 
    FROM local_hathi.h_s_1 hsr
    LEFT JOIN ninefortyfive n ON hsr.instance_id = n.instance_id
    WHERE n.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_s_2(instance_hrid);
CREATE INDEX ON local_hathi.h_s_2(instance_id);
CREATE INDEX ON local_hathi.h_s_2(permanent_location_name);
CREATE INDEX ON local_hathi.h_s_2(call_number);

--3------------------------selects/deselects records with 245 $h[electronic resource] and filters from h_s_2 tabe------------------------
DROP TABLE IF EXISTS local_hathi.h_s_3;   
CREATE TABLE local_hathi.h_s_3 AS 
WITH twofortyfive AS (
SELECT
    sm.instance_hrid,
    sm.CONTENT,
    sm.field,
    sm.sf,
    he.instance_id,
    he.permanent_location_name,
    he.call_number
    FROM
    srs_marctab sm
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    WHERE 
    ((sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[electronic resource]%')
    OR (sm.field = '245' AND sm.sf ='h' AND sm.CONTENT like '%[microform]%'))
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_id, sm.instance_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, 
    he.permanent_location_name, he.call_number)
    SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number
    FROM local_hathi.h_s_2 h 
    LEFT JOIN twofortyfive t ON h.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_s_3 (instance_id);
CREATE INDEX ON local_hathi.h_s_3 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_3 (permanent_location_name);
CREATE INDEX ON local_hathi.h_s_3 (call_number);

--4---------------------selects/deselects records with 336 $aunmediated content and filters from h_s_3----------------  
DROP TABLE IF EXISTS local_hathi.h_s_4;
CREATE TABLE local_hathi.h_s_4 AS
WITH threethirtysix AS (
SELECT 
    sm.instance_id,
    sm.field,
    sm.sf,
    sm.content 
    FROM 
    srs_marctab sm
    WHERE
    (sm.field = '336' AND sm.sf = 'a' AND sm.CONTENT = 'unmediated')
    GROUP BY sm.instance_id, sm.field, sm.sf, sm.CONTENT)
    SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number 
    FROM local_hathi.h_s_3 h
    LEFT JOIN threethirtysix t ON h.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_s_4 (instance_id);
CREATE INDEX ON local_hathi.h_s_4 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_4 (permanent_location_name);
CREATE INDEX ON local_hathi.h_s_4 (call_number);

--5--------------------selects/deselects records with 300 $amap or maps and filters from h_s_4------------------ 
DROP TABLE IF EXISTS local_hathi.h_s_5;
CREATE TABLE local_hathi.h_s_5 AS
WITH threehundred AS 
(SELECT
    sm.instance_hrid,
    sm.CONTENT,
    sm.field,
    sm.sf,
    he.instance_id,
    he.permanent_location_name,
    he.call_number,
    he.discovery_suppress 
    FROM
    srs_marctab sm
    LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
    WHERE 
    (sm.field = '300' AND sm.sf ='a' AND sm.CONTENT like '%map%')
    AND he.permanent_location_name !~~ 'serv,remo'
    GROUP BY sm.instance_hrid, sm.CONTENT, sm.field, sm.sf, he.instance_id, he.permanent_location_name, 
    he.call_number, he.discovery_suppress)
    SELECT 
    h.instance_id,
    h.instance_hrid,
    h.permanent_location_name,
    h.call_number,
    t.discovery_suppress
    FROM local_hathi.h_s_4 h
    left JOIN threehundred t ON h.instance_id = t.instance_id
    WHERE t.instance_id IS NULL
;
CREATE INDEX ON local_hathi.h_s_5 (instance_id);
CREATE INDEX ON local_hathi.h_s_5 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_5 (permanent_location_name);
CREATE INDEX ON local_hathi.h_s_5 (call_number);
CREATE INDEX ON local_hathi.h_s_5 (discovery_suppress);
--6-----------------------filters suppressed holding records with the note "decision - no"-----------
DROP TABLE IF EXISTS local_hathi.h_s_6;
CREATE TABLE local_hathi.h_s_6 AS
WITH holdings_note AS
(SELECT 
    hn.note,
    h.instance_id,
    h.instance_hrid,
    hn.holdings_hrid,
    hn.holdings_id,
    h.discovery_suppress 
    FROM local_hathi.h_s_5 h 
    LEFT JOIN folio_reporting.holdings_notes hn ON h.instance_id= hn.instance_id 
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
    FROM local_hathi.h_s_5 h
    left JOIN holdings_note hn ON h.instance_id = hn.instance_id
    WHERE hn.instance_id IS NULL;
CREATE INDEX ON local_hathi.h_s_6 (instance_id);
CREATE INDEX ON local_hathi.h_s_6 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_6 (permanent_location_name);
CREATE INDEX ON local_hathi.h_s_6 (call_number);
CREATE INDEX ON local_hathi.h_s_6 (discovery_suppress);
;

--7-----------------------filters records by certain values in call number from h_s_6-------------------
DROP TABLE IF EXISTS local_hathi.h_s_7;
CREATE TABLE local_hathi.h_s_7 AS
SELECT 
    hhn.instance_hrid,
    hhn.instance_id,
    hhn.call_number,
    hhn.permanent_location_name 
    FROM local_hathi.h_s_6 hhn  
    WHERE hhn.call_number !~~* 'on order%'
    AND hhn.call_number !~~* 'in process%'
    AND hhn.call_number !~~* 'Available for the library to purchase'
    AND hhn.call_number !~~* '%film%' 
    AND hhn.call_number !~~* '%fiche%'
    AND hhn.call_number !~~* 'On selector%'
;
CREATE INDEX ON local_hathi.h_s_7 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_7 (instance_id);
CREATE INDEX ON local_hathi.h_s_7 (call_number);
CREATE INDEX ON local_hathi.h_s_7 (permanent_location_name);

--8--------------------filters records for presents of oclc number------------------    
DROP TABLE IF EXISTS local_hathi.h_s_8;
CREATE TABLE local_hathi.h_s_8 AS
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
    FROM local_hathi.h_s_7 hsn 
    INNER JOIN oclc_no AS oclcno ON hsn.instance_id = oclcno.instance_id
;
CREATE INDEX ON local_hathi.h_s_8 (instance_id);
CREATE INDEX ON local_hathi.h_s_8 (instance_hrid);
CREATE INDEX ON local_hathi.h_s_8 (call_number);
CREATE INDEX ON local_hathi.h_s_8 (permanent_location_name);
CREATE INDEX ON local_hathi.h_s_8 (id_type);
CREATE INDEX ON local_hathi.h_s_8 (oclc_number2);
CREATE INDEX ON local_hathi.h_s_8 (oclc_no);

--9------------------------------selects issn number and value for government document from 008 --------------
DROP TABLE IF EXISTS local_hathi.h_s_final;
CREATE TABLE local_hathi.h_s_final AS
WITH gov_doc AS (
    SELECT
    sm.instance_hrid AS instance_hrid,
    CASE
        WHEN substring(sm.content, 18, 1) IN ('u')
             AND substring(sm.content, 29, 1) IN ('f')
             THEN '1'
             ELSE '0' END AS gov_doc
    FROM
    srs_marctab sm
    WHERE
    sm.field = '008'
),
issn_select AS (
    SELECT 
    sm.instance_hrid AS instance_hrid,
    sm.field AS field,
    sm.CONTENT AS issn_no
    FROM srs_marctab sm
    WHERE (sm.field = '022' AND sm.sf = 'a' )
),
dist_hrid_select AS (
   SELECT 
   DISTINCT(ho.instance_hrid),
   ho.oclc_no AS oclc_no
   FROM local_hathi.h_s_8 AS ho
)
SELECT
   ds.oclc_no,
   ds.instance_hrid,
   issn.issn_no,
   gd.gov_doc
   FROM dist_hrid_select AS ds
   LEFT JOIN gov_doc AS gd ON ds.instance_hrid = gd.instance_hrid
   LEFT JOIN issn_select AS issn ON ds.instance_hrid = issn.instance_hrid
   GROUP BY ds.oclc_no, ds.instance_hrid,  issn.issn_no, gd.gov_doc
;
CREATE INDEX ON local_hathi.h_s_final (oclc_no);
CREATE INDEX ON local_hathi.h_s_final (instance_hrid);
CREATE INDEX ON local_hathi.h_s_final (issn_no);
CREATE INDEX ON local_hathi.h_s_final (gov_doc);
