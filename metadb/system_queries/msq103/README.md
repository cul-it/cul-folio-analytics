# MSQ103 — null_closed_loan_hist_userids.sql

**Last updated:** 1-15-26
**Written by:** Sharon Markus  
**Tested by:** Joanne Leary  

## Purpose

This query is run weekly by the hosting team supporting Cornell's Metadb reporting database.

Its purpose is to replace the values in the `user_id` field with `NULL` in two tables that store historical loan data:

- `folio_circulation.loan__`
- `folio_circulation.loan__t__`

After this script runs, the affected historical rows are anonymized in compliance with Cornell Library’s patron privacy policy.

Closed loans are anonymized in the FOLIO system according to criteria set in Circulation Settings before the data is synchronized 
with the Metadb reporting database tables, unless the loan is associated with a fine or fee. This process only anonymizes the 
current rows of data in the Metadb reporting database associated with loans, which is why running the historical loan row 
anonymization process is necessary. Loans associated with fines or fees must be kept by the Library Accounting office for 
6 years in accordance with Cornell University policy 4.7. 

