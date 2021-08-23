WITH parameters AS (
    SELECT
        /* replace the placeholder number with the number of days overdue that is needed for this report */
        '20'::integer AS days_overdue_filter, -- doesn't work if empty
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
    li.patron_group_name as borrower_patron_group_name,
    li.user_id AS borrower_id,
    li.barcode AS borrower_barcode,
    li.loan_due_date,
    days.days_overdue, 
    cr.id AS request_id,
    cr.request_date,
    json_extract_path_text(cr.data, 'metadata','updatedDate')::date AS request_updated_date,
    he.call_number,
    ie.barcode AS item_barcode,
    ins.title,
    ie.material_type_name,
    ie.permanent_location_name,
    ie.effective_location_name
   FROM
	folio_reporting.loans_items as li
 LEFT JOIN public.circulation_requests AS cr
	ON li.item_id=cr.item_id
LEFT JOIN folio_reporting.item_ext AS ie
	ON cr.item_id = ie.item_id
LEFT JOIN folio_reporting.holdings_ext AS he
	ON ie.holdings_record_id=he.holdings_id
LEFT JOIN days ON days.loan_id=li.loan_id
LEFT JOIN public.inventory_instances AS ins 
	ON he.instance_id=ins.id
    WHERE (days.days_overdue > 0 AND days.days_overdue <= (SELECT days_overdue_filter FROM parameters))	
    AND (
    ie.permanent_location_name = (SELECT items_permanent_location_filter FROM parameters)
        OR '' = (SELECT items_permanent_location_filter FROM parameters)
    )
    ;
     
