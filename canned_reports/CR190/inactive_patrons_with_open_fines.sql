SELECT 
        TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
        json_extract_path_text (uu.data,'personal', 'lastName') AS patron_last_name,
        json_extract_path_text (uu.data,'personal','firstName') AS patron_first_name,
        uu.barcode AS patron_barcode,
        uu.username AS patron_netid,
        uu.external_system_id,
        ug.group AS patron_group_name,
        ffo.owner AS feefine_owner,
        ffa.barcode AS item_barcode,
        ffa.title,
        ffa.location AS item_location,
        ffa.call_number,
        TO_CHAR (cl.loan_date :: DATE, 'mm/dd/yyyy') AS loan_date,
        TO_CHAR (ffa.due_date :: DATE, 'mm/dd/yyyy') AS due_date,
        TO_CHAR (cl.return_date::DATE, 'mm/dd/yyyy') AS return_date,
        ie.status_name AS current_item_status,
        TO_CHAR (ie.status_date::date, 'mm/dd/yyyy') AS current_item_status_date,
        ffa.fee_fine_type,
        TO_CHAR (json_extract_path_text (ffa.data,'metadata','createdDate')::DATE,'mm/dd/yyyy') AS fine_create_date,
        imt.name AS material_type,
        ffffa.type_action AS action_type,
        TO_CHAR (ffffa.date_action :: DATE, 'mm/dd/yyyy') AS action_date,
        ffa.amount,
        ffa.remaining,
        json_extract_path_text (ffa.data,'status','name') AS fine_status,
        json_extract_path_text (ffa.data,'paymentStatus','name') AS payment_status,
        ffffa.comments,
        ffffa.payment_method     

FROM feesfines_accounts AS ffa 
        
        LEFT JOIN user_users AS uu 
        ON ffa.user_id = uu.id
        
        LEFT JOIN inventory_items AS ii 
        ON ffa.item_id = ii.id
        
        LEFT JOIN folio_reporting.item_ext AS ie 
        ON ii.id = ie.item_id
        
        LEFT JOIN circulation_loans AS cl 
        ON ffa.loan_id = cl.id
        
        LEFT JOIN feesfines_feefineactions AS ffffa 
        ON ffa.id = ffffa.account_id
        
        LEFT JOIN feesfines_owners AS ffo 
        ON ffa.owner_id = ffo.id 
        
        LEFT JOIN inventory_material_types AS imt
        ON ii.material_type_id = imt.id
                
        LEFT JOIN user_groups AS ug
        ON uu.patron_group = ug.id       
        
WHERE 
        json_extract_path_text (ffa.data,'status','name') = 'Open'
        AND uu.active = 'False'

ORDER BY patron_last_name, patron_first_name, fine_create_date, action_date, item_location
;
