--MCR416
--loan_id_item_id_hist_bib_search.sql 
--created 3/17/26
--written by: Sharon Markus
--This query takes a `loan_id` and `item_id` as inputs and returns the matching bibliographic and location data for that loaned item.
--This is useful when the item no longer appears in current tables, but can still be traced through historical inventory tables.

WITH parameters AS (
    SELECT
        'YOUR_LOAN_ID'::uuid AS loan_id,
        'YOUR_ITEM_ID'::uuid AS item_id
)
SELECT DISTINCT
    li.loan_id,
    li.item_id,
    it.holdings_record_id,
    h.instance_id,
    he.permanent_location_name,
    iext.instance_hrid,
    i.title
FROM parameters p
JOIN folio_derived.loans_items AS li
    ON li.loan_id = p.loan_id
   AND li.item_id = p.item_id
JOIN folio_inventory.item__t__ AS it
    ON li.item_id = it.id
JOIN folio_inventory.holdings_record__t__ AS h
    ON it.holdings_record_id = h.id
JOIN folio_inventory.instance__t__ AS i
    ON h.instance_id = i.id
LEFT JOIN folio_derived.holdings_ext AS he
    ON it.holdings_record_id = he.id
LEFT JOIN folio_derived.instance_ext AS iext
    ON h.instance_id = iext.instance_id
;
