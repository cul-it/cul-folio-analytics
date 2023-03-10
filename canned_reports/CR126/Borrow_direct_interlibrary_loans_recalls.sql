--CR 126 
-- overdue BD and ILL loans to other universities, recalled by Cornell patrons
 
WITH BDILL AS 
(
SELECT
       uu.id,
       uu.personal__last_name as patron_last_name,
       uu.personal__first_name as patron_first_name,
       uu.username as borrower_netid,
       ug.desc AS patron_group_name,
       uu.barcode,
       uu.active
FROM
       user_users AS uu
LEFT JOIN user_groups AS ug 
    ON uu.patron_group = ug.id
    
WHERE
       ug.desc LIKE 'Borrow Direct%'
       OR ug.desc LIKE 'Inter%'
ORDER BY
       patron_last_name,
       patron_first_name
),
 
days AS (
SELECT
       item_id,
       DATE_PART('day', NOW() - due_date) AS days_overdue
FROM
       public.circulation_loans
       where circulation_loans.status__name = 'Open' 
),
 
main AS (
SELECT
       to_char(current_date::DATE, 'mm/dd/yyyy') AS todays_date,
       BDILL.patron_last_name,
       BDILL.patron_first_name,
       BDILL.borrower_netid,
       BDILL.barcode AS borrower_barcode,
       iext.title,
       he.permanent_location_name,
       he.call_number,
       ii.enumeration,
       ii.chronology,
       ii.copy_number,
       ii.barcode AS item_barcode,
       to_char (cl.loan_date::DATE, 'mm/dd/yyyy') AS loan_date,
       to_char (ri.request_date::DATE, 'mm/dd/yyyy') AS recall_request_date,
       to_char (cl.due_date::DATE, 'mm/dd/yyyy') AS due_date,
       days.days_overdue,
       cl.system_return_date,
       ii.status__name,
       to_char (ii.status__date,'mm/dd/yyyy') as current_item_status,
       cl.due_date_changed_by_recall,
       ri.request_type,
       ri.request_status,
       uu.personal__last_name as requester_last_name,
       uu.personal__first_name as requester_first_name,
       uu.personal__email as requester_email,
       uu.barcode AS requester_barcode,
       ri.patron_group_name AS requester_patron_group
FROM
       circulation_loans AS cl
       INNER JOIN BDILL
                     ON BDILL.id = cl.user_id
       LEFT JOIN inventory_items AS ii 
               ON cl.item_id = ii.id
       LEFT JOIN folio_reporting.requests_items AS ri 
               ON ii.id = ri.item_id
       LEFT JOIN user_users AS uu 
               ON ri.requester_id = uu.id
       LEFT JOIN folio_reporting.holdings_ext AS he 
               ON ii.holdings_record_id = he.holdings_id
       LEFT JOIN folio_reporting.instance_ext AS iext 
               ON he.instance_id = iext.instance_id
       LEFT JOIN days ON days.item_id = cl.item_id
 
WHERE
        cl.due_date_changed_by_recall = 'true'
        AND cl.system_return_date IS null
        AND cl.due_date < current_date
        AND ii.status__name like 'Checked out%'
        AND ri.request_status = 'Open - Not yet filled'
        AND ri.request_type='Recall'
        )
        
SELECT DISTINCT
       todays_date,
       recall_request_date,
       request_type,
       request_status,
       item_barcode,
       loan_date,
       due_date,
       days_overdue,       
       call_number,
       permanent_location_name,
       title,
       requester_patron_group,
       requester_email,
       patron_last_name as borrower_last_name,
       patron_first_name as borrower_first_name,
       borrower_barcode
FROM main
                
ORDER BY
        days_overdue desc
        ;
 
