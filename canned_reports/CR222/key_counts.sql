--Updated 07/07/2023
--This query was written by Sharon Beltaine and reviewed by Joanne Leary
--This query counts instances, holdings, items, loans, srs marctab instances, 
--srs marctab records with "001" fields, srs marctab records with "999" fields 
--that include "i" subfields, and srs record instances on the LDP Production database. 
--If srs_marctab_001 and 999i counts are equal and within about 1,000 records of the count 
--for SOURCE=MARC in the FOLIO Inventory application, then srs_marctab counts are acceptable.

SELECT  
		to_char (now()::timestamp,'mm/dd/yyyy hh:mi am') as date_time,	
		'ldp_cornell' AS DATABASE, 	
(
        SELECT COUNT(id)
        FROM   inventory_instances
        ) AS instances_from_inventory_instances,
        (
        SELECT COUNT(id)
        FROM   inventory_holdings
        ) AS holdings_from_inventory_holdings,
        (
        SELECT COUNT(loan_id)
        FROM folio_reporting.loans_items
        ) AS loans_from_loan_items,
		(
        SELECT COUNT(id)
        FROM circulation_loans
        ) AS loans_from_circulation_loans,
		(
        SELECT COUNT(id)
        FROM   inventory_items
        ) AS items_from_inventory_items,
        (
        SELECT COUNT (id)
		FROM public.srs_marc
		) AS ids_from_srs_marc,
        (
        SELECT COUNT(instance_id)
        FROM srs_marctab
        ) AS srs_marctab_instances_from_srs_marctab,
        (
        SELECT COUNT(*)
        FROM srs_marctab AS sm
        WHERE sm.field = '001'
        ) AS srs_marctab_001,
        (
        SELECT COUNT (*)
        FROM srs_marctab AS sm
        WHERE sm.field = '999'
        AND sm.sf = 'i'
        ) AS srs_marctab_999i,
        (
        SELECT COUNT(external_id)
        FROM srs_records
        WHERE srs_records.state = 'ACTUAL'
        ) AS srs_records_instances_from_srs_records
       ;
