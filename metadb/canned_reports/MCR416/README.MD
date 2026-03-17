## MCR416

This query takes a `loan_id` and `item_id` as inputs and returns the matching bibliographic and location data for that loaned item.

It works by:

- finding the matching row in `folio_derived.loans_items`
- linking the item to its historical inventory record in `folio_inventory.item__t__`
- following the item's `holdings_record_id` to `folio_inventory.holdings_record__t__`
- pulling the related `instance_id`
- adding the holdings permanent location name
- joining to `folio_inventory.instance__t__` for the title
- joining to `folio_derived.instance_ext` for the instance HRID

This is useful when the item no longer appears in current item tables, but can still be traced through historical inventory tables.
