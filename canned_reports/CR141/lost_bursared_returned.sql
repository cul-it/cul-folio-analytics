/*This query finds all items that were billed as lost, then bursared, and later returned. Folio marks such bills as "refunded fully," 
but in fact refunds have to be processed manaully. This report allows you to identify charges that must get manual refunds.*/

/*The filters for this query are: start date (for fine create date) through today's date; and material type (which can be left blank to inlcude all 
material types)*/

WITH PARAMETERS AS ( 
	SELECT 
        '2021-01-01'::date AS fine_start_date_filter,
 /*Enter material type, or leave blank*/
        ''::varchar AS material_type_filter 
)
SELECT 
        
        ffffa.account_id as feefine_id,
        json_extract_path_text (uu.data,'personal', 'lastName') AS patron_last_name,
        json_extract_path_text (uu.data,'personal','firstName') AS patron_first_name,
        uu.barcode AS patron_barcode,
        uu.username AS patron_netid,
        uu.external_system_id,
        ug.group AS patron_group_name,
        ffa.fee_fine_owner,
        ffa.barcode AS item_barcode,
        ffa.title,
        ffa.location AS item_location,
        ffa.call_number,
        to_char (cl.loan_date :: DATE, 'mm/dd/yyyy') AS loan_date,
        to_char (ffa.due_date :: DATE, 'mm/dd/yyyy') AS due_date,
        to_char(json_extract_path_text (ffa.data,'metadata','createdDate')::DATE,'mm/dd/yyyy') AS fine_create_date,
        to_char (ffffa.date_action :: DATE, 'mm/dd/yyyy') AS bursared_date,
        to_char (cc.occurred_date_time :: DATE,'mm/dd/yyyy') AS return_date,
        imt.name AS material_type,
        ffa.fee_fine_type,
        ffa.amount :: MONEY,
        ffa.remaining :: MONEY,
        json_extract_path_text (ffa.data,'status','name') AS fine_status,
        ffffa.type_action AS action_type,
        to_char (ffffa.date_action,'mm/dd/yyyy') AS action_date,
        json_extract_path_text (ffa.data,'paymentStatus','name') AS payment_status,
        ffffa.payment_method,
        clp.name as loan_policy_name

FROM
        feesfines_accounts AS ffa 
        
        LEFT JOIN user_users AS uu 
        ON ffa.user_id = uu.id
        
        LEFT JOIN inventory_items AS ii 
        ON ffa.item_id = ii.id
        
        LEFT JOIN circulation_check_ins AS cc 
        ON ffa.item_id = cc.item_id
        
        LEFT JOIN circulation_loans AS cl 
        ON ffa.loan_id = cl.id
        
        LEFT JOIN folio_reporting.locations_service_points AS lsp
        ON cl.checkin_service_point_id = lsp.service_point_id 
        
        LEFT JOIN feesfines_feefineactions AS ffffa 
        ON ffa.id = ffffa.account_id
        
        LEFT JOIN inventory_material_types AS imt
        ON ii.material_type_id = imt.id
                
        LEFT JOIN user_groups AS ug
        ON uu.patron_group = ug.id
        
        LEFT JOIN circulation_loan_policies AS clp 
        ON cl.loan_policy_id = clp.id    
        
WHERE 
		  json_extract_path_text (ffa.data,'metadata','createdDate')::date >= (SELECT fine_start_date_filter FROM parameters) 
        AND json_extract_path_text (ffa.data,'metadata','createdDate') <= current_date::VARCHAR -- (today's date)
        AND ffffa.payment_method LIKE '%CU%T%'
        AND cc.occurred_date_time > ffffa.date_action
        AND cc.item_status_prior_to_check_in = 'Lost and paid'
        AND json_extract_path_text (ffa.data,'paymentStatus','name') LIKE 'Refunded fully%'
        AND (imt.name = (SELECT material_type_filter FROM parameters)
        OR (SELECT material_type_filter FROM parameters) = '')
        AND ffa.fee_fine_type != ffffa.type_action
        
ORDER BY patron_last_name, patron_first_name, fine_create_date, action_date, item_location
;
 



