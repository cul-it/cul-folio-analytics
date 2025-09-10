# MSQ101 — Voyager Patron Data Removal

## Overview

This script, `remove_voyager_patron_ids.sql`, is designed to permanently remove patron identifiers and related data from specific tables in the **Metadb reporting database**. These tables were originally migrated from the **CUL Voyager legacy system** and contain static data.

Since the data is not expected to change, this script will be executed **once only** by the hosting team.

---

## Authors & Reviewers

- **Written by:** Peter Martinez  
- **Reviewed by:** Sharon Markus, Joanne Leary  
- **Last updated:** August 28, 2025

---

## Affected Tables & Fields

The following Voyager-derived tables and fields will be updated:

| Table Name                  | Field Name             | Action                                      |
|----------------------------|------------------------|---------------------------------------------|
| `CALL_SLIP`                | `PATRON_ID`            | Remove patron identifier                    |
| `HOLD_RECALL`              | `PATRON_ID`            | Remove patron identifier                    |
| `LINE_ITEM`                | `REQUESTOR`            | Update to `'yes'` if populated              |
| `CALL_SLIP`                | `NOTE`                 | Remove patron-related notes                 |
| `CALL_SLIP_ARCHIVE`        | `NOTE`                 | Remove patron-related notes                 |
| `HOLD_RECALL`              | `PATRON_COMMENT`       | Remove patron comments                      |
| `HOLD_RECALL_ARCHIVE`      | `PATRON_COMMENT`       | Remove patron comments                      |

---

## Execution Notes

- This script is intended for **one-time execution**.
- It should be run by the **Metadb hosting team** only.
- Ensure backups are in place before execution.

---

## Disclaimer

This script is part of a data privacy initiative and must be handled with care. Unauthorized execution or modification may result in data integrity issues.

