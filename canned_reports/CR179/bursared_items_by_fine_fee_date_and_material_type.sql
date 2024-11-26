--CR179
--bursared_items_by_fine_fee_date_and_material_type
--last updated: 11/26/24
--11/24/24: fixed LDP 2.1.0 errors
--This query finds bursared items with fines or fees using the payment method of "CUL Transfer Account" 
--and a fine fee type action of "Transferred Fully." Filters for fine date range and material type 
--are included.

WITH PARAMETERS AS ( 
	SELECT 
   
/*Enter fine start date and fine end date within the quote marks to see a range of transactions
 * or leave blank to see all dates*/
	    '2021-07-01'::DATE AS fine_start_date_filter,
 		  '2021-10-01'::DATE AS fine_end_date_filter,
 		
/*Enter material type between the quote marks, or leave blank to retrieve all material types
 * See list of material types at https://confluence.cornell.edu/display/folioreporting/Material+Types */
        ''::VARCHAR AS material_type_filter   
)
SELECT 
        CURRENT_DATE,
        (SELECT fine_start_date_filter::varchar FROM parameters) || ' to '::varchar || 
        (SELECT fine_end_date_filter::varchar FROM parameters) AS fine_date_range,
        uu.external_system_id AS cornell_id_no,
        ffa.barcode AS item_barcode,
        imt.name AS material_type,
  		  ffa.title,
        ffa.location AS item_location,
        ffa.fee_fine_owner,
       	ffa.call_number,
        to_char(jsonb_extract_path_text (ffa.data,'metadata','createdDate')::DATE,'mm/dd/yyyy') AS fine_create_date,
        to_char (ffffa.date_action :: DATE, 'mm/dd/yyyy') AS bursared_date,
        to_char (cl.loan_date :: DATE, 'mm/dd/yyyy') AS loan_date,
        to_char (ffa.due_date :: DATE, 'mm/dd/yyyy') AS due_date,
        to_char (cc.occurred_date_time :: DATE,'mm/dd/yyyy') AS return_date,
        ffffa.transaction_information, 
        ffa.fee_fine_type,
        ffa.amount :: MONEY,
        ffa.remaining :: MONEY,
        jsonb_extract_path_text (ffa.data,'status','name') AS fine_status,
        ffffa.type_action AS action_type,
        to_char (ffffa.date_action,'mm/dd/yyyy') AS action_date,
        jsonb_extract_path_text (ffa.data,'paymentStatus','name') AS payment_status,
        ffffa.payment_method AS payment_method,
        clp.name as loan_policy_name,
        ffffa.account_id as feefine_id,
    	  ffa.item_id

FROM
      feesfines_accounts AS ffa  
      LEFT JOIN user_users AS uu ON ffa.user_id = uu.id
      LEFT JOIN inventory_items AS ii ON ffa.item_id = ii.id
      LEFT JOIN circulation_check_ins AS cc ON ffa.item_id = cc.item_id
      LEFT JOIN circulation_loans AS cl ON ffa.loan_id = cl.id
      LEFT JOIN folio_reporting.locations_service_points AS lsp
        	ON cl.checkin_service_point_id = lsp.service_point_id 
      LEFT JOIN feesfines_feefineactions AS ffffa 
        	ON ffa.id = ffffa.account_id
      LEFT JOIN inventory_material_types AS imt
        	ON ii.material_type_id = imt.id                      
      LEFT JOIN circulation_loan_policies AS clp 
        	ON cl.loan_policy_id = clp.id    
        
WHERE
     jsonb_extract_path_text (ffa.data,'metadata','createdDate')::DATE >= 
			  (SELECT fine_start_date_filter FROM parameters) 
      AND jsonb_extract_path_text (ffa.data,'metadata','createdDate')::DATE < 
        	(SELECT fine_end_date_filter FROM parameters)
      AND cc.occurred_date_time > ffffa.date_action
      AND ffa.fee_fine_type != ffffa.type_action
      AND (imt.name = (SELECT material_type_filter FROM parameters)
        	OR (SELECT material_type_filter FROM parameters) = '')
      AND ffffa.payment_method = 'CUL Transfer Account'
		  AND ffffa.type_action iLIKE 'Transferred fully'
;


        	OR (SELECT material_type_filter FROM parameters) = '')
      AND ffffa.payment_method = 'CUL Transfer Account'
		  AND ffffa.type_action iLIKE 'Transferred fully'
;
