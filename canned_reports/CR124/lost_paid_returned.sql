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
        TO_CHAR (cl.declared_lost_date :: date, 'mm/dd/yyyy') AS declared_lost_date,
        TO_CHAR (cc.occurred_date_time:: date, 'mm/dd/yyyy') AS lost_item_returned_date,
        li.item_status AS loan_status_action,
        cc.item_status_prior_to_check_in,
        li.loan_id,
        ug.group_name AS patron_group_name,
        ug.user_first_name,
        ug.user_last_name,
        ug.user_middle_name,
        ug.user_email,
        ihi.title,
        ihi.barcode AS item_barcode,
        ihi.call_number AS item_call_number,
        json_extract_path_text(ffa.data, 'status', 'name') AS fine_status,
        ffff.amount_action ::MONEY,
        ffff.type_action,
        ffff.balance,
        TO_CHAR (ffff.date_action,'mm/dd/yyyy') AS action_date
    FROM
    	public.circulation_check_ins AS cc
        	LEFT JOIN folio_reporting.loans_items AS li on cc.item_id=li.item_id
       	 	LEFT JOIN public.inventory_items AS ii ON li.item_id = ii.id
        	LEFT JOIN public.circulation_loans AS cl ON li.loan_id=cl.id 
       		LEFT JOIN folio_reporting.items_holdings_instances AS ihi ON li.item_id = ihi.item_id
        	LEFT JOIN folio_reporting.users_groups AS ug ON li.user_id=ug.user_id
        	LEFT JOIN feesfines_accounts AS ffa ON li.loan_id=ffa.loan_id
        	LEFT JOIN feesfines_feefineactions AS ffff ON ffa.id=ffff.account_id
                WHERE cc.occurred_date_time >= (SELECT returned_start_date FROM parameters)
                AND (ffff.type_action LIKE '%fully%'
                OR ffff.type_action LIKE '%partial%')
    AND cc.occurred_date_time < (SELECT returned_end_date FROM parameters)
    AND item_status_prior_to_check_in='Lost and paid'
    ORDER BY loan_id, date_action
            ;
