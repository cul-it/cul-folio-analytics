# MCR170  
## Item Status: In Process  
**Written by:** Joanne Leary  

This query identifies "In Process" item status books that appear to be fully cataloged and should be checked in the stacks to 
determine if they have arrived at the library without their status being updated (record cleanup).  

### Exclusions  
The query excludes:  
- Items with "In process," "On order," "Cancelled," or "OC" in the call number  
- Records without a barcode  
- E-resource records  

---

### Change Log  

- **12/6/24:**  
  - Modified the query to extract the 300 field separately.  
  - Updated item status retrieval to use the `folio_inventory.item` table for the most current status.  

- **12/10/24:**  
  - Added `CASE WHEN` logic as a size designator.  

