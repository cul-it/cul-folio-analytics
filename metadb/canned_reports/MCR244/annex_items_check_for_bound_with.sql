-- 3-29-23: This query looks for holdings records that have bound-with barcodes in the holdings notes field, and matches the

-- barcodes from the notes field to a list of barcodes supplied by the Annex. Then it finds all the item records associatd with

-- the matched holdings records.

-- 11-11-24: converted to Metadb. NOTE: as of 11-11-24, waiting for local_shared to get the jake_sample_barcodes file

 

-- 1. Find all holdings records with barcodes in the holdings notes.

 

WITH holdbarcodes AS

(SELECT

        hn.holding_id,

        hn.holding_hrid,

        string_agg (DISTINCT hn.note,' | ') AS holdings_notes,

        substring (hn.note,'\d{14}') AS hn_barcode

 

FROM folio_derived.holdings_notes AS hn

WHERE hn.note ILIKE '%31924%'

GROUP BY holding_id, holding_hrid, hn.note

),

 

--2. Find the holdings records that match Jake's list of barcodes

 

matches AS

(SELECT

        hb.holding_id,

        hb.holding_hrid,

        hb.hn_barcode,

        --jsb.seq_no,

        jsb."Item Barcode"

       

FROM holdbarcodes AS hb

INNER JOIN LOCAL_OPEN.jake_sample_barcodes jsb

ON hb.hn_barcode = jsb."Item Barcode"

)

 

-- 3. From the matched holdings records, find the item records associated with them. Show the item location, item enumeration, item barcodes

 

SELECT

        ii.title,

        he.permanent_location_name AS holdings_location_name,

        he.call_number,

        ii.hrid AS instance_hrid,

        matches.holding_hrid,

        matches."Item Barcode" AS jake_barcode,

        --matches.seq_no,

        ie.item_hrid AS item_hrid_for_matched_holdings_record,

        ie.barcode AS item_barcode_for_matched_holdings_record,

        ie.enumeration AS item_enumeration_for_matched_holdings_record,

        ie.effective_location_name AS item_location_for_matched_holdings_record

 

FROM matches

        LEFT JOIN folio_derived.item_ext AS ie

        ON matches.holding_id = ie.holdings_record_id

       

        LEFT JOIN folio_derived.holdings_ext AS he

        ON matches.holding_id = he.holdings_id

       

        LEFT JOIN folio_inventory.instance__t as ii --inventory_instances AS ii

        ON he.instance_id::UUID = ii.id

;
