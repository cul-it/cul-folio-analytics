--MCR190
--Expired patrons with open fines
--This query finds expired patrons with open fines.
--NOTE: This query uses a CIT table, please check schema location 
--Query writer: Joanne LEary (jl41)
--Query posted on: 11/19/24
--6-3-25: query no longer works because source table has been deleted (local_core.first_patron_data_set_all)


WITH user_address AS -- get Home address
	(SELECT 
		ua.user_id,
		ua.address_type_name,
		CONCAT (ua.address_line_1,' ', ua.address_line_2,' ', ua.address_city,' ', ua.address_region,' ',ua.address_postal_code,' ', ua.address_country_id) AS home_address,
		case
			when trim ((CONCAT (fpds.home_address1,' ',fpds.home_address2,' ',fpds.home_address3,' ',fpds.home_city,' ',fpds.home_state,' ',fpds.home_postal,' ',fpds.home_country))) > ' ' then 
			CONCAT (fpds.home_address1,' ',fpds.home_address2,' ',fpds.home_address3,' ',fpds.home_city,' ',fpds.home_state,' ',fpds.home_postal,' ',fpds.home_country) 
			else null end
			as cit_home_address
		
	FROM folio_derived.users_addresses ua
		left join folio_users.users__t 
		on ua.user_id = users__t.id
		
		left join local_core.first_patron_data_set_all as fpds 
		on users__t.username = trim(fpds.netid)
	
	WHERE ua.address_type_name = 'Home'
),

user_address2 AS -- get Campus address
	(SELECT 
		ua.user_id,
		ua.address_type_name,
		CONCAT (ua.address_line_1,'  ', ua.address_line_2,'   ', ua.address_city,', ', ua.address_region,' ',ua.address_postal_code,'   ', ua.address_country_id) AS campus_address,
		case 
			when trim ((concat (fpds.campus_address,' ',fpds.campus_city,' ',fpds.campus_state,' ',fpds.campus_postal))) > ' ' then
			concat (fpds.campus_address,' ',fpds.campus_city,' ',fpds.campus_state,' ',fpds.campus_postal) 
			else null end 
			as cit_campus_address
		
	FROM folio_derived.users_addresses ua
		left join folio_users.users__t 
		on ua.user_id = users__t.id
		
		left join local_core.first_patron_data_set_all fpds 
		on users__t.username = trim (fpds.netid)
		
	WHERE ua.address_type_name = 'Campus'
),

cust_flds AS -- get college and department from the custom fields section of the users__ table data array
	(SELECT DISTINCT
		u.id AS user_id,
		JSONB_EXTRACT_PATH_TEXT (u.jsonb,'customFields','college') AS college,
		JSONB_EXTRACT_PATH_TEXT (u.jsonb,'customFields','department') AS department
	
	FROM folio_users.users__ u 
),

patron_notes AS -- get patron notes from expired patron records and join to custom fields subquery
	(SELECT DISTINCT
		ug.user_id,
		CASE WHEN ug.active = 'True' THEN 'Active' ELSE 'Expired' END AS patron_status,
		ug.user_last_name,
		ug.user_first_name,
		ug.username AS net_id,
		TRIM (' | ' FROM STRING_AGG (DISTINCT cust_flds.college,' | ')) AS college,
		TRIM (' | ' FROM STRING_AGG (DISTINCT cust_flds.department,' | ')) AS department,
		TRIM (LEADING 'Patron note' FROM STRING_AGG (DISTINCT nt.indexed_content,' | ')) AS patron_note,
		STRING_AGG (DISTINCT to_char (nt.created_date::DATE,'mm/dd/yyyy'),' | ') AS note_date
	
	FROM folio_derived.users_groups AS ug	
		LEFT JOIN cust_flds 
		ON ug.user_id = cust_flds.user_id
		
		LEFT JOIN folio_notes.link__ AS link 
		ON ug.user_id::TEXT = link.object_id::TEXT
		
		LEFT JOIN folio_notes.note_link__ AS nl 
		ON link.id::TEXT = nl.link_id::TEXT
		
		LEFT JOIN folio_notes.note__ AS nt
		ON nl.note_id::TEXT = nt.id::TEXT
	
	WHERE ug.active = 'False'
	
	GROUP BY 
		ug.user_id,
		ug.active,
		ug.user_last_name,
		ug.user_first_name,
		ug.username 
)

SELECT DISTINCT -- Main query; find details of the fine record for expired patrons and join to the previous subqueries for addresses, patron notes and custom fields

		TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
		ug.user_last_name AS patron_last_name,
		ug.user_first_name AS patron_first_name,
		CASE WHEN ug.active = 'True' THEN 'Active' ELSE 'Expired' END AS patron_status,
		ug.barcode AS patron_barcode,
		ug.username AS patron_netid,
		ug.external_system_id,
		ug.group_name AS patron_group_name,
		coalesce (user_address.cit_home_address,user_address.home_address,' - ') as home_address,
		coalesce (user_address2.cit_campus_address, user_address2.campus_address,' - ') as campus_address,
		ffaa.fee_fine_owner AS feefine_owner,
		ffa.barcode AS item_barcode,
		ffa.title,
		ffa.locatiON AS item_location,
		TRIM (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration, ' ',ie.chronology,
			CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)) AS call_number,
		TO_CHAR (loant.loan_date :: DATE, 'mm/dd/yyyy') AS loan_date,
		TO_CHAR (loant.due_date :: DATE, 'mm/dd/yyyy') AS due_date,
		to_char (max (loant.return_date)::date, 'mm/dd/yyyy') AS return_date,
		ie.status_name AS current_item_status,
		TO_CHAR (ie.status_date::DATE, 'mm/dd/yyyy') AS current_item_status_date,
		ffaa.fee_fine_owner,
		ffa.fee_fine_type,
		
		to_char (ffffa.date_action::date,'mm-dd-yyyy') as fine_create_date,
		--ffaa.fine_date::DATE AS fine_create_date,
		ie.material_type_name AS material_type,
	--STRING_AGG (DISTINCT ffffa.type_action,' | ') AS action_type,
	--STRING_AGG (TO_CHAR (ffffa.date_actiON :: DATE, 'mm/dd/yyyy'),' | ') AS action_date,
		ffa.amount AS original_amont,
		ffa.remaining,
		jsonb_extract_path_text (accts.jsonb,'status','name') AS fine_status,
		jsonb_extract_path_text (accts.jsonb,'paymentStatus','name') AS payment_status,
		STRING_AGG (DISTINCT ffffa.comments,' | ') AS comments,
		STRING_AGG (DISTINCT ffffa.payment_method,' | ') AS payment_method,
		pn.college,
		pn.department,
		pn.patron_note,
		pn.note_date

FROM folio_feesfines.accounts__ AS accts

		LEFT JOIN folio_feesfines.accounts__t__ AS ffa
		ON accts.id = ffa.id 
	
		LEFT JOIN folio_derived.users_groups AS ug 
		ON ffa.user_id = ug.user_id 
		
		LEFT JOIN folio_derived.item_ext AS ie 
		ON ffa.item_id = ie.item_id
		
		LEFT JOIN folio_circulation.loan__t__ AS loant 
		ON ffa.loan_id = loant.id
			AND ffa.user_id = ug.user_id
			
		LEFT JOIN folio_feesfines.feefineactions__t__ AS ffffa 
		ON ffa.id = ffffa.account_id 
			and ffa.user_id = ffffa.user_id
	
		LEFT JOIN user_address 
		ON ug.user_id = user_address.user_id
	
		LEFT JOIN user_address2 
		ON ug.user_id = user_address2.user_id

		LEFT JOIN folio_derived.feesfines_accounts_actions AS ffaa 
		ON ffa.id = ffaa.account_id	
		
		LEFT JOIN patron_notes AS pn
		ON ug.user_id = pn.user_id
		
WHERE 
	--json_extract_path_text(ffa.data,'metadata','createdDate')::timestamptz >= current_timestamp - interval '10 days' -- (fine create date - start date)
	--AND json_extract_path_text(ffa.data,'metadata','createdDate')::timestamptz <= current_timestamp -- (fine create date - END date)
	--AND ffo.owner = 'Olin' -- (fine fee owner)
	jsonb_extract_path_text (accts.jsonb,'status','name') = 'Open'
	--AND ffffa.payment_method like '%CU%T%'
	--AND cc.occurred_date_time > ffffa.date_action
	--AND cc.item_status_prior_to_check_in = 'Lost and paid'
	AND jsonb_extract_path_text (accts.jsonb,'paymentStatus','name') in ('Outstanding','Waived partially')
	--AND imt.name = 'Book' -- (material type name)
	--AND json_extract_path_text (ffa.data,'paymentStatus','name') like '%Outstanding%' -- (payment status; can fill in a value like "Waived", "Cancelled", "Transferred", "Paid" etc.))
	--AND ug.group in ('Undergraduate','Graduate') -- (patron group)
	--AND uu.active = 'true' -- (patron status; a value of 'true' will pull just fines for active students)
	--AND uu.barcode != '' -- (must have a barcode in the patron record)
	--AND ffa.fee_fine_type != ffffa.type_action -- (this line must stay in if you want Closed fines; should be commented out for Open fines)
	--AND uu.username = 'jl41' -- (enter a netid to find fines for a specific patron)
	--AND json_extract_path_text (uu.data,'personal', 'lastName') = (enter patron last name)
	--AND json_extract_path_text (uu.data,'personal','firstName') = (enter patron first name)
	AND ffa.remaining > 0
	AND ug.active = 'false'
	--and ug.group_name in ('Faculty','Staff')
	and ffa.__current = TRUE
	and loant.__current = TRUE
	
GROUP BY 

TO_CHAR (current_date::DATE,'mm/dd/yyyy'),
		ug.user_last_name,
		ug.user_first_name,
		CASE WHEN ug.active = 'True' THEN 'Active' ELSE 'Expired' END,
		ug.barcode,
		ug.username,
		ug.external_system_id,
		ug.group_name,
		coalesce (user_address.cit_home_address,user_address.home_address,' - '),
		coalesce (user_address2.cit_campus_address, user_address2.campus_address,' - '),
		--user_address.home_address,
		--user_address2.campus_address,
		ffaa.fee_fine_owner,
		ffa.barcode,
		ffa.title,
		ffa.location,
		TRIM (concat (ie.effective_call_number_prefix,' ',ie.effective_call_number,' ',ie.effective_call_number_suffix,' ',ie.enumeration, ' ',ie.chronology,
			CASE WHEN ie.copy_number >'1' THEN concat ('c.',ie.copy_number) ELSE '' END)),
		TO_CHAR (loant.loan_date :: DATE, 'mm/dd/yyyy'),
		TO_CHAR (loant.due_date :: DATE, 'mm/dd/yyyy'),	
		--TO_CHAR (loant.return_date::DATE, 'mm/dd/yyyy'),
		ie.status_name,
		TO_CHAR (ie.status_date::DATE, 'mm/dd/yyyy'),
		ffa.fee_fine_type,
		to_char (ffffa.date_action::date,'mm-dd-yyyy'),
		--to_char (ffffa.date_ation::date,'mm-dd-yyyy'),
		--ffaa.fine_date::DATE,
		ie.material_type_name,
	--STRING_AGG (DISTINCT ffffa.type_action,' | ') AS action_type,
	--STRING_AGG (TO_CHAR (ffffa.date_actiON :: DATE, 'mm/dd/yyyy'),' | ') AS action_date,
		ffa.amount,
		ffa.remaining,
		jsonb_extract_path_text (accts.jsonb,'status','name'),
		jsonb_extract_path_text (accts.jsonb,'paymentStatus','name'),
		pn.college,
		pn.department,
		pn.patron_note,
		pn.note_date
	
ORDER BY patron_last_name, patron_first_name, title, call_number, fine_create_date, item_location
