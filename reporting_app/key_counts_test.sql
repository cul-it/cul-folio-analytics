--key_counts_test.sql

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
        ) AS items_from_inventory_items
        ;
