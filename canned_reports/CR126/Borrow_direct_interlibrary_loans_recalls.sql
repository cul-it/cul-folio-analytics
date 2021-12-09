with BDILL as 
(select 
        uu.id,
        json_extract_path_text(uu.data,'personal','lastName') as patron_last_name,
        json_extract_path_text(uu.data,'personal','firstName') as patron_first_name,
        ug.desc as patron_group_name,
        uu.barcode,
        uu.active

from user_users as uu
        left join user_groups as ug 
        on uu.patron_group = ug.id 

Where ug.desc like 'Borrow Direct%' or ug.desc like 'Inter%'

order by patron_last_name, patron_first_name
),
days AS (
    SELECT 
        item_id,
        DATE_PART('day', NOW() - due_date) AS days_overdue
    FROM public.circulation_loans
)
select 
        to_char(current_date::DATE,'mm/dd/yyyy') as todays_date,
        BDILL.patron_last_name,
        BDILL.patron_first_name,
        BDILL.barcode as borrower_barcode,
        iext.title,
        he.permanent_location_name,
        he.call_number,
        ii.enumeration,
        ii.chronology,
        ii.copy_number,
        ii.barcode as item_barcode,
        to_char(cl.loan_date::DATE,'mm/dd/yyyy') as loan_date,
        to_char(ri.request_date::DATE,'mm/dd/yyyy') as recall_request_date,
        to_char(cl.due_date::DATE,'mm/dd/yyyy') as due_date,
        days.days_overdue,
        cl.system_return_date,
        json_extract_path_text(ii.data,'status','name') as current_item_status,
        to_char(json_extract_path_text(ii.data,'status','date')::DATE,'mm/dd/yyyy') as current_item_status_date,
        cl.due_date_changed_by_recall,
        ri.request_type,
        ri.request_status,
        json_extract_path_text(uu2.data,'personal','lastName') as requester_last_name,
        json_extract_path_text(uu2.data,'personal','firstName') as requester_first_name,
        uu2.barcode as requester_barcode,
        ri.patron_group_name as requester_patron_group
        

from circulation_loans as cl 
        inner join BDILL on BDILL.id = cl.user_id

left join inventory_items as ii 
        on cl.item_id = ii.id

left join folio_reporting.requests_items as ri 
        on ii.id = ri.item_id

left join user_users as uu2 
        on ri.requester_id = uu2.id

left join folio_reporting.holdings_ext as he 
        on ii.holdings_record_id = he.holdings_id
        
left join folio_reporting.instance_ext as iext 
        on he.instance_id = iext.instance_id
        
Left join days on days.item_id=cl.item_id

where cl.due_date_changed_by_recall = 'true'
        and cl.system_return_date is null
        and cl.due_date < current_date
        and json_extract_path_text(ii.data,'status','name') = 'Checked out';
