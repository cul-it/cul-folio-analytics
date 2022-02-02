DROP TABLE if EXISTS local_automation.np55_bdws;
CREATE TABLE local_automation.bd_with AS 
WITH get_hld AS 
(
 SELECT
 ine.instance_hrid AS inst_hrid_1,
 hn.holdings_hrid AS hold_hrid_1,
 hn.note_type_name AS note_type_name_1,
 hn.note AS note_1,
 ie.item_hrid AS item_hrid_1
 FROM folio_reporting.holdings_notes AS hn
      LEFT JOIN folio_reporting.item_ext AS ie ON frhn.holdings_id = frie.holdings_record_id
      LEFT JOIN folio_reporting.instance_ext ine ON frhn.instance_id = frine.instance_id
      WHERE note_type_name IN ('Bound with item data')
      AND frie.item_hrid is NULL
  GROUP BY frine.instance_hrid, frhn.holdings_hrid, frhn.note_type_name, 
      frhn.note, frie.item_hrid
)
SELECT
    h.inst_hrid_1 AS inst_hrid_1,
    h.hold_hrid_1 AS hold_hrid_child_1,
    h.note_1 AS note_child_1,
    h.item_hrid AS item_parent_2,
    h.barcode AS bc_no_parent_2,
    h.permanent_location_name AS loc_name_parent_2,
    h.accession_number
FROM get_hld AS h 
JOIN folio_reporting.item_ext ie ON nbwc.note_1 = ie.barcode
WHERE h.permanent_location_name ILIKE '%Annex%'
;
