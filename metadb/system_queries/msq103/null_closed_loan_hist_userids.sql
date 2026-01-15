--MSQ103
--null_closed_loan_hist_userids.sql
--Written by: Sharon Markus
--Tested by: Joanne Leary
--This query is being run weekly by the hosting team supporting Cornell's Metadb reporting database. 
--The purpose of this query is to replace the data in the user_id field with NULL in 2 tables that store
--historical rows of loan data: folio_circulation.loan__ and folio_circulation.loan__t__. 
--After this script is run, those rows of historical data are anonymized, in compliance with the
--Cornell Library's patron privacy policy.


UPDATE folio_circulation.loan__
SET jsonb = jsonb_set(jsonb, '{userId}', 'null'::jsonb, false)
WHERE __current = FALSE;

UPDATE folio_circulation.loan__t__
SET user_id = NULL
WHERE __current = FALSE
AND user_id IS NOT NULL
;
