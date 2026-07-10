# MSQ102: Multiple SRS ID Check

**Last updated:** 11/17/25  
**File:** multiple_srs_id_check.sql  
**Written by:** Joanne Leary  
**Reviewed by:** Sharon Markus

## Purpose

This query finds instance_hrid records that are linked to multiple distinct srs_ids.

For each instance_hrid in `folio_source_record.marc__t`, it counts the unique srs_id values and returns only those instances where that count is greater than one (potential duplicates).

## Output

- instance_hrid
- Count of distinct srs_id records attached to it



-matched_id on records_lb = matched_id on marc _ _ t 
