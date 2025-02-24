-- MCR126 
-- This query finds books that are on loan to BD and ILL, were recalled and are now overdue
--Query writer: Joanne Leary (jl41)
--Query reviewed by:Linda Miller (lm15)
--Date posted: 5/23/24

--Query details:
--This query provides a list of overdue CUL-owned items checked out to Borrow Direct or Interlibrary loan patrons (borrowers) that have been recalled by CU patrons (requestors). (These items have not yet been received back by CUL, based on the current due date). There are no filters for this report. The report contains details of the borrower (institution codes) as well as of the CU requestor who requested the recall. The report also shows the date the item was recalled, and the number of days overdue (based on the recall date).

SELECT DISTINCT 
        CURRENT_DATE::DATE AS todays_date,
        ri.request_date::DATE,
        ri.request_type,
        ri.request_status,
        li.barcode AS item_barcode,
        li.loan_date::DATE,
        li.loan_due_date::DATE,
        CURRENT_DATE::DATE - li.loan_due_date::DATE AS days_overdue, 
        TRIM(CONCAT (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration,' ',ie.chronology,
                CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END)) AS call_number,
        he.permanent_location_name,
        instext.title,
        ug.user_last_name AS borrower_last_name,
        ug.user_first_name AS borrower_first_name,
        ug.barcode AS borrower_barcode,
        ug.group_name AS borrower_patron_group_name, 
        ug2.user_last_name AS requestor_last_name, 
        ug2.user_first_name AS requestor_first_name, 
        ug2.barcode AS requestor_barcode, 
        ug2.user_email AS requestor_email,
        ri.patron_group_name AS requestor_patron_group, 
        CASE WHEN ug2.active = 'true' THEN 'Active' ELSE 'Inactive' END AS requestor_status 

       
FROM folio_derived.loans_items AS li 
        INNER JOIN folio_derived.users_groups AS ug 
        ON li.user_id = ug.user_id
        
        INNER JOIN folio_derived.item_ext AS ie 
        ON li.item_id = ie.item_id
        
        INNER JOIN folio_derived.holdings_ext AS he 
        ON ie.holdings_record_id = he.holdings_id 
        
        INNER JOIN folio_derived.instance_ext AS instext 
        ON he.instance_id = instext.instance_id
        
        INNER JOIN folio_circulation.loan__t 
        ON li.loan_id = loan__t.id
        
        INNER JOIN folio_derived.requests_items AS ri 
        ON li.item_id = ri.item_id
        
        INNER JOIN folio_derived.users_groups AS ug2 
        ON ri.requester_id = ug2.user_id
        
 WHERE ug.group_name SIMILAR TO '(Borrow|Inter)%'
        AND li.loan_return_date IS NULL 
        AND li.loan_due_date::DATE < CURRENT_DATE::DATE
        AND loan__t.due_date_changed_by_recall = 'true'
        AND ri.request_type = 'Recall'
        AND ri.request_status like 'Open%'

ORDER BY borrower_last_name, borrower_first_name
;

