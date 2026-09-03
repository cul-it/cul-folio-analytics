--MCR426
--BD_ILL_Aged_to_lost_and_paid
-- Query writer: Joanne Leary (jl41)

--Date posted: 9/3/26

SELECT 
	current_date::date AS todays_date,	
	he.permanent_location_name,
	instance__t.hrid AS instance_hrid,
	he.holdings_hrid,
	item_ext.item_hrid,
	li.loan_id,
	li.material_type_name,
	instance__t.title,
	li.barcode,
	loan.jsonb#>>'{status,name}' AS loan_status_name,
	li.loan_date::date,
	li.loan_due_date::date,
	li.loan_return_date::date,
	item_ext.status_name AS item_status,
	item_ext.status_date::date AS item_status_date,
	li.renewal_count,
	users.jsonb#>>'{personal,lastName}' AS borrower_last_name,
	users.jsonb#>>'{personal,firstName}' AS borrower_first_name,
	users.jsonb#>>'{username}' AS net_id,
	li.patron_group_name,
	STRING_AGG (CONCAT (feefineactions__t.type_action,' - ',feefineactions__t.date_action::date),' | ' ORDER BY feefineactions__t.__id) AS fine_action_and_date,
	feefineactions__t.amount_action,
	li.loan_policy_name

FROM folio_inventory.instance__t 
	LEFT JOIN folio_derived.holdings_ext AS he 
	ON instance__t.id = he.instance_id
	
	LEFT JOIN folio_derived.item_ext 
	ON he.id = item_ext.holdings_record_id
	
	LEFT JOIN folio_derived.loans_items AS li
	ON item_ext.item_id = li.item_id

	inner join folio_circulation.loan 
	ON li.loan_id = loan.id
	
	LEFT JOIN folio_feesfines.accounts__t 
	ON li.loan_id = accounts__t.loan_id
	
	LEFT JOIN folio_feesfines.feefineactions__t 
	ON accounts__t.id = feefineactions__t.account_id
	
	LEFT JOIN folio_users.users 
	ON li.user_id = users.id

WHERE li.material_type_name in ('BD MATERIAL','ILL MATERIAL')
AND item_ext.status_name ilike '%Lost%'

GROUP BY 
	he.permanent_location_name,
	instance__t.hrid,
	he.holdings_hrid,
	item_ext.item_hrid,
	li.loan_id,
	li.material_type_name,
	instance__t.title,
	li.barcode,
	loan.jsonb#>>'{status,name}',
	li.loan_date::date,
	li.loan_due_date::date,
	li.loan_return_date::date,
	item_ext.status_name,
	item_ext.status_date::date,
	li.renewal_count,
	users.jsonb#>>'{personal,lastName}',
	users.jsonb#>>'{personal,firstName}',
	users.jsonb#>>'{username}',
	li.patron_group_name,
	feefineactions__t.amount_action,
	li.loan_policy_name
	
ORDER BY material_type_name, loan_date, barcode
;
