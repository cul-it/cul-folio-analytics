WITH parameters AS (
--choose a patron netid
SELECT 'jl41':: varchar AS netid_filter
)
SELECT
        
        to_char (current_date,'mm/dd/yyyy') AS todays_date,
        json_extract_path_text(uu.data,'personal','firstName') AS first_name,
        json_extract_path_text(uu.data,'personal','lastName') AS last_name,
        uu.username,
        uu.active,
        li.current_item_effective_location_name AS item_loc,
        ie.title,
        li.barcode,
        he.call_number,
        li.enumeration,
        li.chronology,
        li.copy_number,
        li.patron_group_name,
        to_char(li.loan_date::DATE,'mm/dd/yyyy') AS loandate,
        to_char(li.loan_due_date::DATE,'mm/dd/yyyy') AS duedate,
        to_char(li.loan_return_date::DATE,'mm/dd/yyyy') AS returndate,
        li.loan_policy_name,
        li.material_type_name,
        li.loan_status,
        li.item_status


FROM folio_reporting.loans_items AS li 
        LEFT JOIN user_users AS uu 
        ON li.user_id = uu.id 
        
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON li.holdings_record_id = he.holdings_id
        
        LEFT JOIN folio_reporting.instance_ext AS ie 
        ON he.instance_id = ie.instance_id

WHERE uu.username = (SELECT netid_filter FROM parameters)

ORDER BY title
;
