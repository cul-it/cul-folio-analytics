# MSQ101 — remove_voyager_patron_ids.sql

**Written by:** Peter Martinez  
**Reviewed by:** Sharon Markus, Joanne Leary  
**Last updated:** 2025-08-28

## Description

This query removes patron identifiers and other patron-related data from specific tables in the **Metadb reporting database**. These tables were originally migrated from the **CUL Voyager legacy system**.

Since the data in these tables is static, this update script will be executed **only once** by our hosting team.

## Voyager Tables Impacted

- `CALL_SLIP.PATRON_ID`
- `HOLD_RECALL.PATRON_ID`
- `LINE_ITEM.REQUESTOR`  
  _Updating to ‘yes’ if populated_
- `CALL_SLIP.NOTE`
- `CALL_SLIP_ARCHIVE.NOTE`
- `HOLD_RECALL.PATRON_COMMENT`
- `HOLD_RECALL_ARCHIVE.PATRON_COMMENT`
