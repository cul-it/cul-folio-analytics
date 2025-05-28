## MCR213 - Current Encumbrances

**Last Updated:** 11-21-24

**Query written by:** Nancy Bolduc  
**Updated to Metadb by:** Joanne Leary  
**Reviewed by:** Sharon Markus and Ann Crowley

**Description:**  
This query finds current encumbrances by fund and fiscal year. It also shows titles and locations.

**Note:**  
As of 6/21/23, Fully Paid orders may still have a current encumbrance; this is a system issue to be fixed.

**Note:** 
2/6/25: You must enter the current fiscal year to get accurate results. 

**Change Log:**
- **11-19-24:** Converted to Metadb
- **11-21-24:** Corrected "order type" extraction and updated `po_instance` to `vs_po_instance`
- **5-14-25:** updated po_instance to the folio_derived table, which is now correct. (Commented out po_instance subquery.)
- added finance group filter (AND joins to group_fund_fiscal_year__t AND groups__t); also added a join to transaction__t table
- Added pol.receipt_status AND pol.receipt_date to Select stanza
- **5-27-25:** cleaned up commented-out lines
