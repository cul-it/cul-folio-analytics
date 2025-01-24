--MCR408
--annex_in_transit.sql
--written by: Joanne Leary
--last updated 1/24/25
--This query finds items accessioned at the Annex with an "In transit" status, using an imported file of barcodes.

SELECT DISTINCT
        TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
        instance__t.title,
        location__t.name as holdings_location_name,
        loc2.name as item_effective_location_name,
        CONCAT (holdings_record__t.call_number_prefix,' ',holdings_record__t.call_number,' ',holdings_record__t.call_number_suffix) AS holdings_call_number,
        item__t.enumeration,
        item__t.chronology,
        item__t.copy_number,
        item__t.barcode as item_barcode,
        jsb."Item Barcode" AS jake_barcode,
        instance__t.hrid AS instance_hrid,
        holdings_record__t.hrid as holdings_hrid,
        item.jsonb #>> '{hrid}' as item_hrid,
        item.jsonb #>> '{status, name}' as item_status_name,
        (item.jsonb #>> '{status, date}')::date as item_status_date,
        CASE
                WHEN uu.jsonb #>>'{personal,firstName}' IS NOT NULL
                THEN CONCAT (uu.jsonb#>>'{personal,lastName}',' ,', uu.jsonb #>>'{personal,firstName}')
                ELSE uu.jsonb #>>'{personal,firstName}'
                END AS update_user_name,
        (item.jsonb #>> '{metadata, updatedDate}')::date as update_date,
        item__t.effective_shelving_order COLLATE "C"

 FROM local_open.jake_sample_barcodes AS jsb
        LEFT JOIN folio_inventory.item__t
        ON jsb."Item Barcode" = item__t.barcode
 
        LEFT JOIN folio_inventory.item
        ON item__t.id = item.id

        LEFT JOIN folio_inventory.location__t as loc2
        ON (item.jsonb #>>'{effectiveLocationId}')::UUID =loc2.id

        LEFT JOIN folio_inventory.holdings_record__t
        ON holdings_record__t.id = item__t.holdings_record_id

        LEFT JOIN folio_inventory.location__t
        ON holdings_record__t.permanent_location_id = location__t.id
 
        LEFT JOIN folio_inventory.instance__t 
        ON holdings_record__t.instance_id = instance__t.id

        LEFT JOIN folio_users.users AS uu
        ON (item.jsonb #>>'{metadata,updatedByUserId}')::UUID = uu.id

WHERE item.jsonb #>> '{status, name}' = 'In transit'

ORDER BY item__t.effective_shelving_order COLLATE "C"
;
