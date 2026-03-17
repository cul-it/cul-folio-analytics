## MCR416

**File:** `loan_id_item_id_hist_bib_search.sql`  
**Created:** 3/17/26  
**Written by:** Sharon Markus

This query takes a `loan_id` and `item_id` as inputs and returns the matching bibliographic and location data for that loaned item.
This is useful when the item no longer appears in current source or derived item tables, 
but can still be traced through historical inventory tables.

### How it works

- finds the matching row in `folio_derived.loans_items`
- links the item to its historical inventory record in `folio_inventory.item__t__`
- follows the item's `holdings_record_id` to `folio_inventory.holdings_record__t__`
- pulls the related `instance_id`
- adds the holdings permanent location name
- joins to `folio_inventory.instance__t__` for the title
- joins to `folio_derived.instance_ext` for the instance HRID

