CR 173

Patron_purchase_requests

NOTE: All data in Folio in this query are only for Folio. For limited versions of this report that include fiscal year and days till fulfillment, see ad hoc reports  AHR112 (Folio data) and AHR113 (Voyager data).

Lists patron requests to purchase items, including requestor netid or other requestor information (where available) and item details including location name (from PO lines), fund name, fund code, and total circulation count. The request_date field comes from the created_date field on the po_purchase_orders table.

NOTE: Please examine results carefully, as this query picks up requester name from the purchase order lines table, and if a request was modified or cancelled and then re-ordered, the item will show up multiple times. 
