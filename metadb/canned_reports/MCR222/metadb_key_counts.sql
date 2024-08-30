--MCR222
--metadb_key_counts
--Updated 8/29/24
--This query was written and converted to metadb by Sharon Markus and Joanne Leary
--This query counts instances, holdings, items, loans, srs marctab instances, 
--srs marctab records with "001" fields, srs marctab records with "999" fields 
--that include "i" subfields, and srs record instances on the Metadb database. 
--If srs_marctab_001 and 999i counts are equal and within about 1,000 records of the count 
--for SOURCE=MARC in the FOLIO Inventory application, then srs_marctab counts are acceptable.

SELECT  
		to_char (now()::timestamp,'mm/dd/yyyy hh:mi am') as date_time,	
		'metadb' AS DATABASE, 	
(
        SELECT COUNT(id)
        FROM   folio_inventory.instance__t  
        ) AS instances_from_inventory_instances,
        (
        SELECT COUNT(id)
        FROM   folio_inventory.holdings_record__t  
        ) AS holdings_from_inventory_holdings,
        (
        SELECT COUNT(loan_id)
        FROM folio_derived.loans_items  
        ) AS loans_from_loan_items,
		(
        SELECT COUNT(id)
        FROM folio_circulation.loan__t  
        ) AS loans_from_circulation_loans,
		(
        SELECT COUNT(id)
        FROM   folio_inventory.item__t 
        ) AS items_from_inventory_items,
        (
        SELECT COUNT (id)
		FROM folio_source_record.records_lb  
		) AS ids_from_srs_marc,
        (
        SELECT COUNT(instance_id)
        FROM folio_source_record.marc__t  
        ) AS srs_marctab_instances_from_srs_marctab,
        (
        SELECT COUNT(*)
        FROM folio_source_record.marc__t AS sm  
        WHERE sm.field = '001'
        ) AS srs_marctab_001,
        (
        SELECT COUNT (*)
        FROM folio_source_record.marc__t AS sm  
        WHERE sm.field = '999'
        AND sm.sf = 'i'
        ) AS srs_marctab_999i,
        (
        SELECT COUNT(external_id)
        FROM folio_source_record.records_lb  
        WHERE folio_source_record.records_lb.state = 'ACTUAL'  
        ) AS srs_records_instances_from_srs_records
       ;
