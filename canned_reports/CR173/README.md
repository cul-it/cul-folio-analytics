CR 173

Patron_purchase_requests

Lists patron requests to purchase items, including requestor netid or other requestor information (where available) and item details including location name (from PO lines), fund name, fund code, and total circulation count (all currently only for data in Folio). 

NOTE: Please examine results carefully, as this query picks up requester name from the purchase order lines table, and if a request was modified or cancelled and then re-ordered, the item will show up multiple times. 
