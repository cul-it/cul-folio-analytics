-- CR190
-- inactive_patrons_with_open_fines
-- 10-1-22: This query finds expired patrons with open fines.
-- 8-24-23: applied DISTINCT to query
-- 1-17-24: added home address

with user_address as 
(select 
	ua.user_id,
	ua.address_type_name,
	ua.address_type_description,
	concat (ua.address_line_1,'  ', ua.address_line_2,'   ', ua.address_city,', ', ua.address_region,' ',ua.address_postal_code,'   ', ua.address_country_id) as home_address
from folio_reporting.users_addresses ua

where ua.address_type_name = 'Home'

),

user_address2 as 
(select 
	ua.user_id,
	ua.address_type_name,
	ua.address_type_description,
	concat (ua.address_line_1,'  ', ua.address_line_2,'   ', ua.address_city,', ', ua.address_region,' ',ua.address_postal_code,'   ', ua.address_country_id) as campus_address
from folio_reporting.users_addresses ua

where ua.address_type_name = 'Campus'
)


SELECT distinct
	TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
	json_extract_path_text (uu.data,'personal', 'lastName') AS patron_last_name,
	json_extract_path_text (uu.data,'personal','firstName') AS patron_first_name,
	case when uu.active = 'True' then 'Active' else 'Expired' end as patron_status,
	uu.barcode AS patron_barcode,
	uu.username AS patron_netid,
	uu.external_system_id,
	ug.group AS patron_group_name,
	user_address.home_address,
	user_address2.campus_address,
	--udu.department_code,
	--udu.department_name,
	ffo.owner AS feefine_owner,
	ffa.barcode AS item_barcode,
	ffa.title,
	ffa.location AS item_location,
	trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration, ' ',ie.chronology,
		case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)) as call_number,
	--ffa.call_number,
	TO_CHAR (cl.loan_date :: DATE, 'mm/dd/yyyy') AS loan_date,
	TO_CHAR (ffa.due_date :: DATE, 'mm/dd/yyyy') AS due_date,
	TO_CHAR (cl.return_date::DATE, 'mm/dd/yyyy') AS return_date,
	ie.status_name AS current_item_status,
	TO_CHAR (ie.status_date::date, 'mm/dd/yyyy') AS current_item_status_date,
	ffa.fee_fine_type,
	TO_CHAR (json_extract_path_text (ffa.data,'metadata','createdDate')::DATE,'mm/dd/yyyy') AS fine_create_date,
	imt.name AS material_type,
	--string_agg (distinct ffffa.type_action,' | ') as action_type,
	--string_agg (TO_CHAR (ffffa.date_action :: DATE, 'mm/dd/yyyy'),' | ') AS action_date,
	ffa.amount as original_amont,
	ffa.remaining,
	json_extract_path_text (ffa.data,'status','name') AS fine_status,
	json_extract_path_text (ffa.data,'paymentStatus','name') AS payment_status,
	string_agg (distinct ffffa.comments,' | ') as comments,
	string_agg (distinct ffffa.payment_method,' | ') as payment_method	

FROM feesfines_accounts AS ffa 
	
	LEFT JOIN user_users AS uu 
	ON ffa.user_id = uu.id 
	
	left join user_address 
	on uu.id = user_address.user_id
	
	left join user_address2 
	on uu.id = user_address2.user_id
	
	--left join folio_reporting.users_departments_unpacked udu 
	--on uu.id = udu.user_id
	
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
	--json_extract_path_text(ffa.data,'metadata','createdDate')::timestamptz >= current_timestamp - interval '10 days' -- (fine create date - start date)
	--and json_extract_path_text(ffa.data,'metadata','createdDate')::timestamptz <= current_timestamp -- (fine create date - end date)
	--and ffo.owner = 'Olin' -- (fine fee owner)
	json_extract_path_text (ffa.data,'status','name') = 'Open'
	--and ffffa.payment_method like '%CU%T%'
	--and cc.occurred_date_time > ffffa.date_action
	--and cc.item_status_prior_to_check_in = 'Lost and paid'
	and json_extract_path_text (ffa.data,'paymentStatus','name') in ('Outstanding','Waived partially')
	--and imt.name = 'Book' -- (material type name)
	--and json_extract_path_text (ffa.data,'paymentStatus','name') like '%Outstanding%' -- (payment status; can fill in a value like "Waived", "Cancelled", "Transferred", "Paid" etc.))
	--and ug.group in ('Undergraduate','Graduate') -- (patron group)
	--and uu.active = 'true' -- (patron status; a value of 'true' will pull just fines for active students)
	--and uu.barcode != '' -- (must have a barcode in the patron record)
	--and ffa.fee_fine_type != ffffa.type_action -- (this line must stay in if you want Closed fines; should be commented out for Open fines)
	--and uu.username = 'jl41' -- (enter a netid to find fines for a specific patron)
	--and json_extract_path_text (uu.data,'personal', 'lastName') = (enter patron last name)
	--and json_extract_path_text (uu.data,'personal','firstName') = (enter patron first name)
	and ffa.remaining > 0
	AND uu.active = 'false'

group by 
	TO_CHAR (current_date::DATE,'mm/dd/yyyy'),
	json_extract_path_text (uu.data,'personal', 'lastName'),
	json_extract_path_text (uu.data,'personal','firstName'),
	case when uu.active = 'True' then 'Active' else 'Expired' end,
	uu.barcode,
	uu.username,
	uu.external_system_id,
	ug.group,
	user_address.home_address,
	user_address2.campus_address,
	--udu.department_code,
	--udu.department_name,
	ffo.owner,
	ffa.barcode,
	ffa.title,
	ffa.location,
	trim (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration, ' ',ie.chronology,
		case when ie.copy_number >'1' then concat ('c.',ie.copy_number) else '' end)),
	--ffa.call_number,
	TO_CHAR (cl.loan_date :: DATE, 'mm/dd/yyyy'),
	TO_CHAR (ffa.due_date :: DATE, 'mm/dd/yyyy'),
	TO_CHAR (cl.return_date::DATE, 'mm/dd/yyyy'),
	ie.status_name,
	TO_CHAR (ie.status_date::date, 'mm/dd/yyyy'),
	ffa.fee_fine_type,
	TO_CHAR (json_extract_path_text (ffa.data,'metadata','createdDate')::DATE,'mm/dd/yyyy'),
	imt.name,
	--ffffa.type_action AS action_type,
	--TO_CHAR (ffffa.date_action :: DATE, 'mm/dd/yyyy'),
	ffa.amount,
	ffa.remaining,
	json_extract_path_text (ffa.data,'status','name'),
	json_extract_path_text (ffa.data,'paymentStatus','name')
	
ORDER BY patron_last_name, patron_first_name, title, call_number, fine_create_date, item_location
; 
