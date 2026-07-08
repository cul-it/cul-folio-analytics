# Find Holdings Without Item Records

**File:** `find_holdings_without_item_records.sql`  
**Author:** Joanne Leary  
**Date:** 2026-07-08

## Purpose

Identifies holdings records that do not have associated item records.

This query supports inventory review and data quality efforts by locating holdings that lack item-level records while excluding records that are intentionally suppressed or managed through alternative workflows.

## Selection Criteria

The query:

- Finds holdings records that have no linked item records.
- Excludes suppressed instances.
- Excludes suppressed holdings records.
- Excludes holdings in the following locations:
  - `serv, remo`
- Excludes holdings with notes indicating:
  - Bound-with relationships
  - Filmed-with relationships

## Additional Data Captured

To help analyze why certain holdings lack item records, the query extracts the **instance format category** from the MARC **007 field**, when present.

This information provides additional context about the resource format and may help identify cataloging or inventory practices associated with holdings that do not have item records.

## Use Cases

- Inventory data quality review
- Catalog maintenance and cleanup
- Identification of holdings lacking item-level representation
- Analysis of format-specific cataloging practices
- Investigation of exceptions to standard item-record creation workflows

## Notes

- Suppressed instances and holdings are excluded from the results.
- Holdings in service (`serv`) and remote (`remo`) locations are excluded because item records may not be expected or managed in the same manner for these locations.
- Holdings associated with bound-with or filmed-with relationships are excluded to avoid false positives where inventory is represented differently.
- The extracted MARC 007 format category can help determine whether certain resource types routinely exist without item records.
