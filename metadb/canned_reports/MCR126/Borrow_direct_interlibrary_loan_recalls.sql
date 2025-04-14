-- MCR126 
-- This query finds books that are on loan to BD and ILL, were recalled and are now overdue
-- Query writer: Joanne Leary (jl41)
-- Query reviewed by:Linda Miller (lm15)
-- Date posted: 5/23/24

--Query details:
--This query provides a list of overdue CUL-owned items checked out to Borrow Direct or Interlibrary loan patrons (borrowers) that have been recalled by CU patrons (requestors). (These items have not yet been received back by CUL, based on the current due date). There are no filters for this report. The report contains details of the borrower (institution codes) as well as of the CU requestor who requested the recall. The report also shows the date the item was recalled, and the number of days overdue (based on the recall date).

SELECT DISTINCT 
        CURRENT_DATE::DATE AS todays_date,
        request__t.request_date::DATE,
        request__t.request_type,
        request__t.status AS request_status,
        item__t.barcode,
        loan__t.loan_date::DATE,
        loan__t.due_date::DATE AS loan_due_date,
        CURRENT_DATE::DATE - loan__t.due_date::DATE AS days_overdue, 
        TRIM (CONCAT (        
	        item.jsonb#>>'{effectiveCallNumberComponents,callNumberPrefix}',' ',
	        item.jsonb#>>'{effectiveCallNumberComponents,callNumber}',' ',
	        item.jsonb#>>'{effectiveCallNumberComponents,callNumberSuffix}',' ',
	        item__t.enumeration,' ',
	        item__t.chronology,
	                CASE WHEN item__t.copy_number >'1' 
	                THEN CONCAT ('c.',item__t.copy_number) 
	                ELSE '' 
	                END)
	                ) AS call_number,
        location__t.name AS item_effective_location_name, --changed from holdings permanent location to item effective location
        instance__t.title,
        users.jsonb#>>'{personal,lastName}' AS borrower_last_name,
        users.jsonb#>>'{personal,firstName}' AS borrower_first_name,
        users.jsonb#>>'{barcode}' AS borrower_barcode,
        groups__t.group AS patron_group_name, 
        users2.jsonb#>>'{personal,lastName}' AS requestor_last_name,
        users2.jsonb#>>'{personal,firstName}' AS requestor_first_name,
        users2.jsonb#>>'{barcode}' AS requestor_barcode, 
        users2.jsonb#>>'{personal,email}' AS requestor_email,
        groups__t2.group AS requestor_patron_group, 
        CASE WHEN (users2.jsonb#>>'{active}')::BOOLEAN = TRUE
        	THEN 'Active'
        	ELSE 'Inactive'
        	END AS requestor_status

       
FROM folio_circulation.loan__t  
        INNER JOIN folio_users.users 
        ON loan__t.user_id = users.id 
        
        INNER JOIN folio_users.groups__t 
        ON (users.jsonb#>>'{patronGroup}')::UUID = groups__t.id
        
        INNER JOIN folio_inventory.item__t 
        ON loan__t.item_id = item__t.id 
        
        INNER JOIN folio_inventory.item 
        ON item__t.id = item.id
        
        INNER JOIN folio_inventory.location__t 
        ON item__t.effective_location_id = location__t.id
        
        INNER JOIN folio_inventory.holdings_record__t 
        ON item__t.holdings_record_id = holdings_record__t.id  
        
        INNER JOIN folio_inventory.instance__t
        ON holdings_record__t.instance_id = instance__t.id 
        
        INNER JOIN folio_circulation.request__t  
        ON loan__t.item_id = request__t.item_id 
        
        INNER JOIN folio_users.users AS users2  
        ON request__t.requester_id = users2.id 
        
        INNER JOIN folio_users.groups__t AS groups__t2 
        ON (users2.jsonb#>>'{patronGroup}')::UUID = groups__t2.id
              
 WHERE groups__t.group SIMILAR TO '(Borrow|Inter)%' 
        AND loan__t.return_date IS NULL  
        AND loan__t.due_date::DATE < CURRENT_DATE::DATE 
        AND loan__t.due_date_changed_by_recall = TRUE
        AND request__t.request_type = 'Recall'
        AND request__t.status LIKE 'Open%'

ORDER BY borrower_last_name, borrower_first_name
;

