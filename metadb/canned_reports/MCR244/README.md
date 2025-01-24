# MCR244: Annex Items Check for Bound-With

**Written by:** Joanne Leary  
**Last updated:** 1/23/25

This query looks for holdings records that have bound-with barcodes in the holdings notes field, and matches the barcodes from the notes field to a list of barcodes supplied by the Annex. Then it finds all the item records associated with the matched holdings records.

**Note:** This query points to the `local_open` schema on Metadb to find the local file loaded there called `jake_sample_barcodes`. This query can be revised to point to a different file on a different local schema if desired.
