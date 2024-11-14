--MCR141
--lost_bursared_returned
/*This report finds all items that were billed as lost, then bursared, and later returned. Folio marks such bills as "refunded fully," but in fact refunds have to be processed manually. This report allows you to identify charges that must get manual refunds.
The filters for this query are: start date (for fine create date) through today's date; and material type (which 
can be left blank to inlcude all material types).*/

--Query writers: Linda Miller (lm15), Joanne Leary (jl41)
--Query posted on: 11/14/24

WITH PARAMETERS AS ( 
              SELECT 
        '2021-01-01'::date AS fine_start_date_filter,
/*Enter material type, or leave blank*/
        ''::varchar AS material_type_filter 
)
SELECT 
        
        ffffa.account_id as feefine_id,      
        jsonb_extract_path_text (uu.jsonb,'personal','lastName') AS patron_last_name,
        jsonb_extract_path_text (uu.jsonb,'personal','firstName') AS patron_first_name,
        jsonb_extract_path_text (uu.jsonb,'barcode') AS patron_barcode,
        jsonb_extract_path_text (uu.jsonb,'username') AS patron_netid,
        jsonb_extract_path_text (uu.jsonb,'externalSystemId') AS external_system_id,
        ug.group AS patron_group_name,
        jsonb_extract_path_text (ffah.jsonb,'feeFineOwner') AS fee_fine_owner, 
        jsonb_extract_path_text (ffah.jsonb,'barcode') AS item_barcode,
        jsonb_extract_path_text (ffah.jsonb,'title') AS title,
        jsonb_extract_path_text (ffah.jsonb,'location') AS item_location,
        jsonb_extract_path_text (ffah.jsonb,'callNumber') AS call_number,
        to_char (cl.loan_date :: DATE, 'mm/dd/yyyy') AS loan_date,
        to_char (jsonb_extract_path_text (ffah.jsonb,'dueDate'):: DATE, 'mm/dd/yyyy') AS due_date,
        to_char(jsonb_extract_path_text (ffah.jsonb,'metadata','createdDate')::DATE,'mm/dd/yyyy') AS fine_create_date,
        to_char (ffffa.date_action :: DATE, 'mm/dd/yyyy') AS bursared_date,
        to_char (min (cc.occurred_date_time)::date,'mm/dd/yyyy') as return_date,
        imt.name AS material_type,
        jsonb_extract_path_text (ffah.jsonb,'feeFineType') AS fee_fine_type,
        jsonb_extract_path_text (ffah.jsonb,'amount')::MONEY AS amount,
        jsonb_extract_path_text (ffah.jsonb,'remaining')::MONEY AS remaining,
        jsonb_extract_path_text (ffah.jsonb,'status','name') AS fine_status,
        ffffa.type_action AS action_type,
        to_char (ffffa.date_action,'mm/dd/yyyy') AS action_date,
        jsonb_extract_path_text (ffah.jsonb,'paymentStatus','name') AS payment_status,
        ffffa.payment_method,
        clp.name as loan_policy_name

FROM               
        folio_feesfines.accounts AS ffah
            

        LEFT JOIN folio_users.users AS uu
        ON jsonb_extract_path_text (ffah.jsonb,'userId')::UUID = uu.id

        
        LEFT JOIN folio_inventory.item__t AS ii 
        ON jsonb_extract_path_text (ffah.jsonb,'itemId')::UUID = ii.id
        
        LEFT JOIN folio_circulation.check_in__t AS cc 
        ON jsonb_extract_path_text (ffah.jsonb,'itemId')::UUID = cc.item_id
        
        LEFT JOIN folio_circulation.loan__t AS cl 
        ON jsonb_extract_path_text (ffah.jsonb,'loanId')::UUID = cl.id

        
        LEFT JOIN folio_feesfines.feefineactions__t AS ffffa 
        ON ffah.id = ffffa.account_id
        
        LEFT JOIN folio_inventory.material_type__t AS imt
        ON ii.material_type_id = imt.id
        
                
        LEFT JOIN folio_users.groups__t AS ug
        ON jsonb_extract_path_text (uu.jsonb,'patronGroup')::uuid = ug.id
  
        
        LEFT JOIN folio_circulation.loan_policy__t AS clp 
        ON cl.loan_policy_id = clp.id    
        
WHERE jsonb_extract_path_text (ffah.jsonb,'metadata','createdDate')::date >= (SELECT fine_start_date_filter FROM parameters) 
        AND jsonb_extract_path_text (ffah.jsonb,'metadata','createdDate') <= current_date::VARCHAR -- (today's date)
        AND ffffa.payment_method LIKE '%CU%T%'
        AND cc.occurred_date_time > ffffa.date_action   
        AND cc.item_status_prior_to_check_in = 'Lost and paid'
        AND jsonb_extract_path_text(ffah.jsonb,'paymentStatus','name') LIKE 'Refunded fully%'
        AND (imt.name = (SELECT material_type_filter FROM parameters)
        OR (SELECT material_type_filter FROM parameters) = '')
        AND jsonb_extract_path_text (ffah.jsonb, 'feeFineType') != ffffa.type_action
        
group by 
                ffffa.account_id,      
        jsonb_extract_path_text (uu.jsonb,'personal','lastName'),
        jsonb_extract_path_text (uu.jsonb,'personal','firstName'),
        jsonb_extract_path_text (uu.jsonb,'barcode'),
        jsonb_extract_path_text (uu.jsonb,'username'),
        jsonb_extract_path_text (uu.jsonb,'externalSystemId'),
        ug.group,
        jsonb_extract_path_text (ffah.jsonb,'feeFineOwner'), 
        jsonb_extract_path_text (ffah.jsonb,'barcode'),
        jsonb_extract_path_text (ffah.jsonb,'title'),
        jsonb_extract_path_text (ffah.jsonb,'location'),
        jsonb_extract_path_text (ffah.jsonb,'callNumber'),
        to_char (cl.loan_date :: DATE, 'mm/dd/yyyy'),
        to_char (jsonb_extract_path_text (ffah.jsonb,'dueDate'):: DATE, 'mm/dd/yyyy'),
        to_char(jsonb_extract_path_text (ffah.jsonb,'metadata','createdDate')::DATE,'mm/dd/yyyy'),
        to_char (ffffa.date_action :: DATE, 'mm/dd/yyyy'),
        imt.name,
        jsonb_extract_path_text (ffah.jsonb,'feeFineType'),
        jsonb_extract_path_text (ffah.jsonb,'amount')::MONEY,
        jsonb_extract_path_text (ffah.jsonb,'remaining')::MONEY,
        jsonb_extract_path_text (ffah.jsonb,'status','name'),
        ffffa.type_action,
        to_char (ffffa.date_action,'mm/dd/yyyy'),
        jsonb_extract_path_text (ffah.jsonb,'paymentStatus','name'),
        ffffa.payment_method,
        clp.name
        
ORDER BY patron_last_name, patron_first_name, fine_create_date, action_date, item_location
;


