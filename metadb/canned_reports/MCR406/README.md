# MCR244

## hathitrust_903_mappings

**Last Updated:** 12/3/24  
**Written by:** Michelle Paolillo  
**Revised to Metadb by:** Sharon Markus  

This query creates a table of mapping for instances with 903 values and publishes it to the `local_digpres` schema.

### Description:
The table of mapping for instances with 903 values includes:
- Instance ID
- Instance HRID
- Holdings ID
- Barcode
- State

## Change Log:
12/2/24: To fix the "negative substring length not allowed" error, added a conditional check with a CASE statement in each instance where substring was used. 
This verifies that the calculated length for the substring is not negative before attempting to execute the substring extraction.

