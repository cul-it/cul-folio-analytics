WITH parameters AS (
    SELECT
        /* Choose a start and end date for the recalls period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /* replace the placeholder number with the number of days overdue that is needed for this report */
        '20'::integer AS days_overdue_filter, -- doesn't work if empty
        /*Fill in a request type*/
         'Recall'::varchar AS request_type_filter, --Recall, Hold, Page, etc.
        /* Fill in a location name, or leave blank for all locations */
          ''::varchar AS items_permanent_location_filter, --Olin, ILR, Africana, etc.
         /*Fill in 1-4 borrower patron group names*/
         'Borrow Direct'::varchar AS borrower_patron_group_name_filter1, -- Borrow Direct
         'interlibrary Loan'::varchar AS borrower_patron_group_name_filter2, -- Interlibrary Loan
         ''::varchar AS borrower_patron_group_name_filter3, -- Faculty
         ''::varchar AS borrower_patron_group_name_filter4 -- Graduate
        ),
days AS (
    SELECT 
        loan_id,
        DATE_PART('day', NOW() - loan_due_date) AS days_overdue
    FROM folio_reporting.loans_items
)
SELECT
    (SELECT start_date::varchar FROM parameters) || 
        ' to ' || 
        (SELECT end_date::varchar FROM parameters) AS date_range,
    li.patron_group_name as borrower_patron_group_name,
    li.user_id AS borrower_id,
    li.barcode AS borrower_barcode,
    li.loan_due_date,
    days.days_overdue, 
    cr.id AS request_id,
    cr.request_date,
    json_extract_path_text(cr.data, 'metadata','updatedDate')::date AS request_updated_date,
    cr.request_type,
    cr.status AS request_status,
    he.call_number,
    ie.barcode AS item_barcode,
    ins.title,
    ie.material_type_name,
    ie.permanent_location_name,
    ie.effective_location_name,
    ug.group_name AS requester_user_group,
    ug.user_last_name AS requester_user_last_name,
    ug.user_first_name AS requester_user_first_name,
    ug.user_middle_name AS requester_user_middle_name,
    ug.user_email AS requester_user_email    
FROM
	folio_reporting.loans_items as li
 LEFT JOIN public.circulation_requests AS cr
	ON li.item_id=cr.item_id
LEFT JOIN folio_reporting.item_ext AS ie
	ON cr.item_id = ie.item_id
LEFT JOIN folio_reporting.holdings_ext AS he
	ON ie.holdings_record_id=he.holdings_id
LEFT JOIN folio_reporting.users_groups AS ug
	ON  cr.requester_id = ug.user_id
LEFT JOIN days ON days.loan_id=li.loan_id
LEFT JOIN public.inventory_instances AS ins 
	ON he.instance_id=ins.id
    WHERE (days.days_overdue > 0 AND days.days_overdue <= (SELECT days_overdue_filter FROM parameters))	
AND
    cr.request_date >= (SELECT start_date FROM parameters)
    AND cr.request_date < (SELECT end_date FROM parameters)
    AND cr.request_type = (SELECT request_type_filter FROM parameters)
    AND (
        ie.permanent_location_name = (SELECT items_permanent_location_filter FROM parameters)
        OR '' = (SELECT items_permanent_location_filter FROM parameters)
    )
    AND (
        li.patron_group_name IN ((SELECT borrower_patron_group_name_filter1 FROM parameters),
                      			(SELECT borrower_patron_group_name_filter2 FROM parameters),
                      			(SELECT borrower_patron_group_name_filter3 FROM parameters),
                      			(SELECT borrower_patron_group_name_filter4 FROM parameters)
                    )
                    
        OR ('' = (SELECT borrower_patron_group_name_filter1 FROM parameters) AND
            '' = (SELECT borrower_patron_group_name_filter2 FROM parameters) AND
            '' = (SELECT borrower_patron_group_name_filter3 FROM parameters) AND
            '' = (SELECT borrower_patron_group_name_filter4 FROM parameters)
            )
            )
            ;
     
