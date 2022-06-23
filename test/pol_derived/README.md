
PO Lines to Holdings Changes for Derived Tables

-RM Team needs to revise set of PO Line related derived tables to accommodate changes in the way location information associated with POs is included in the system, now pointing to holdings

-We've discovered an issue with po_lines table that impacts derived tables and thus, queries for institutions live with LDP. Intentionally, the po_lines table data array locations "section"  includes holdingID or locationID as a result of the Kiwi upgrade. The holdingID or the locationID is attached to the PO line depending how the purchase order is manually entered.

Before the Kiwi upgrade, only the locationID was included in the data array. We need logic that looks for the locationID, then if not found, using the holdingID with a pointer to the holding location.


-Derived tables impacted:
po_instance
po_pieces
po_lines locations
po_lines eresources


