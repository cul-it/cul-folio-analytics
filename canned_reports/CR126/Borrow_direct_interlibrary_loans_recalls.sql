WITH parameters AS (
    SELECT
        /* Choose a start and end date for the recalls period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /*Fill in a request type*/
         'Recall'::varchar AS request_type_filter, --Recall, Hold, Page, etc.
        /* Fill in a location name, or leave blank for all locations */
          ''::varchar AS items_permanent_location_filter, --Olin, ILR, Africana, etc.
         /*Fill in 1-4 borrower patron group names*/
         'Borrow Direct'::varchar AS borrower_patron_group_name_filter1, -- Borrow Direct
         'Interlibrary Loan'::varchar AS borrower_patron_group_name_filter2, -- Interlibrary Loan
         ''::varchar AS borrower_patron_group_name_filter3, -- Faculty
         ''::varchar AS borrower_patron_group_name_filter4, -- Graduate
        /* Fill in 1-4 request statuses */
        'Open - Not yet filled'::VARCHAR AS request_status_filter1, --  'Open - Not yet filled', 'Open - Awaiting pickup','Open - In transit', ''Open, Awaiting delivery', 'Closed - Filled', 'Closed - Cancelled', 'Closed - Unfilled', 'Closed - Pickup expired'
        'Open - Awaiting pickup'::VARCHAR AS request_status_filter2, -- other request status to also include
        'Open - In transit'::VARCHAR AS request_status_filter3, -- other request status to also include
        'Open - Awaiting delivery'::VARCHAR AS request_status_filter4 -- other request status to also include
)     
SELECT
  -- SELECT start_date::varchar FROM parameters) || 
  --    ' to ' || 
   --   (SELECT end_date::varchar FROM parameters) AS date_range,
    to_char (cr.request_date:: DATE, 'mm/dd/yyyy')AS request_date,
  --cr.request_type,
    cr.status AS request_status, 
    li.patron_group_name as borrowerPatronGrp,
    ie.barcode AS item_barcode,
 -- li.user_id AS borrower_id,
    uu.barcode AS borrower_barcode,
 -- li.loan_due_date,
 -- cr.id AS request_id,
 -- json_extract_path_text(cr.data, 'metadata','updatedDate')::date AS request_updated_date,
    he.call_number,
  --ie.material_type_name,   
    ie.permanent_location_name,
    ins.title,
    ug.group_name AS requester_user_group,
 -- ug.user_last_name AS requester_user_last_name,
 -- ug.user_first_name AS requester_user_first_name,
 --  ug.user_middle_name AS requester_user_middle_name,
    ug.user_email AS requester_user_email    
FROM
public.circulation_requests AS cr
 LEFT JOIN folio_reporting.loans_items as li
	ON cr.item_id=li.item_id
LEFT JOIN folio_reporting.item_ext AS ie
	ON cr.item_id = ie.item_id
LEFT JOIN folio_reporting.holdings_ext AS he
	ON ie.holdings_record_id=he.holdings_id
LEFT JOIN public.inventory_instances AS ins 
	ON he.instance_id=ins.id
LEFT JOIN folio_reporting.users_groups AS ug
	ON  cr.requester_id = ug.user_id
LEFT JOIN public.user_users AS uu
	ON ug.user_id=uu.id
WHERE
    cr.request_date >= (SELECT start_date FROM parameters)
    AND cr.request_date < (SELECT end_date FROM parameters)
    AND cr.request_type = (SELECT request_type_filter FROM parameters)
    AND 
        cr.status IN ((SELECT request_status_filter1 FROM parameters),
                      (SELECT request_status_filter2 FROM parameters),
                      (SELECT request_status_filter3 FROM parameters),
                      (SELECT request_status_filter4 FROM parameters)
                    )
            AND 
        li.patron_group_name IN ((SELECT borrower_patron_group_name_filter1 FROM parameters),
                      			(SELECT borrower_patron_group_name_filter2 FROM parameters),
                      			(SELECT borrower_patron_group_name_filter3 FROM parameters),
                      			(SELECT borrower_patron_group_name_filter4 FROM parameters)
                    )
           AND (
        ie.permanent_location_name = (SELECT items_permanent_location_filter FROM parameters)
        OR '' = (SELECT items_permanent_location_filter FROM parameters)
    )
   
                
;
