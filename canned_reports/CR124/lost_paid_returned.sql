/*In this query, the main filter is by the date range when the item was checked in. Also, as a hardcoded filter,  it only selects items where the status prior to checkin 
was 'lost and paid'. */

WITH parameters AS (
	SELECT
/*Select a date range when the previously lost items were checked-in*/
'2021-01-01'::DATE as returned_start_date,
'2022-01-01'::DATE as returned_end_date)
       SELECT
        (
            SELECT
                returned_start_date::VARCHAR
            FROM
                parameters) || ' to '::VARCHAR || (
            SELECT
                returned_end_date::VARCHAR
            FROM
                parameters) AS lost_items_returned_date_range,
        cc.occurred_date_time as lost_item_returned_date,
        cl.declared_lost_date,
        li.item_status AS loan_status_action,
        cc.item_status_prior_to_check_in,
        li.item_id,
        li.loan_id,
        li.user_id, 
        ug.group_name AS patron_group_name,
        ug.user_first_name,
        ug.user_last_name,
        ug.user_middle_name,
        ug.user_email,
   --   json_extract_path_text(ii.data, 'effectiveCallNumberComponents', 'callNumber') AS call_number,
        ihi.title,
        ihi.barcode AS item_barcode,
        ihi.call_number AS item_call_number
    FROM
    	public.circulation_check_ins AS cc
        	LEFT JOIN folio_reporting.loans_items AS li on cc.item_id=li.item_id
       	 	LEFT JOIN public.inventory_items AS ii ON li.item_id = ii.id
        	LEFT JOIN public.circulation_loans AS cl ON li.loan_id=cl.id 
       		LEFT JOIN folio_reporting.items_holdings_instances AS ihi ON li.item_id = ihi.item_id
        	LEFT JOIN folio_reporting.users_groups AS ug ON li.user_id=ug.user_id
                WHERE cc.occurred_date_time >= (SELECT returned_start_date FROM parameters)
    AND cc.occurred_date_time < (SELECT returned_end_date FROM parameters)
    AND item_status_prior_to_check_in='Lost and paid'
            ;
