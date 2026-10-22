--metadb:table patron_notes

-- 10-20-26: This query derives patron notes from the folio_users table and creates the patron_notes table in the local_derived schema.

DROP TABLE IF EXISTS local_derived.patron_notes;

CREATE TABLE local_derived.patron_notes AS
SELECT 
	users.id as user_id,
	users.jsonb#>>'{personal,lastName}' AS last_name,
	users.jsonb#>>'{personal,firstName}' AS first_name,
	users.jsonb#>>'{personal,middleName}' AS middle_name,
	users.jsonb#>>'{username}' AS net_id,
	users.jsonb#>>'{barcode}' AS patron_barcode,
	CASE WHEN (users.jsonb#>>'{active}')::BOOLEAN = true THEN 'Active' ELSE 'Inactive' END AS patron_status,
	users.jsonb#>>'{externalSystemId}' AS external_id,
	users.jsonb#>>'{personal,email}' AS email_address,
	type.name AS note_type_name,
	TRIM (E'\t' FROM 
		COALESCE 
			(CASE 
				WHEN TRIM (replace (replace (replace (note.content,'<p>',''),'</p>',''),'<br>','')) IS NULL
					OR TRIM (replace (replace (replace (note.content,'<p>',''),'</p>',''),'<br>','')) = '' 
				THEN null 
				ELSE TRIM (replace (replace (replace (note.content,'<p>',''),'</p>',''),'<br>','')) 
				END, 
			CASE 
				WHEN note.title = ''
					OR note.title IS NULL
				THEN null 
				ELSE note.title 
				END, 
			note.indexed_content
			)
		) AS patron_note,
	CONCAT (users2.jsonb#>>'{personal,firstName}',' ',users2.jsonb#>>'{personal,lastName}') AS created_by,
	TO_CHAR (note.created_date::timestamptz,'mm-dd-yyyy hh:mi am') AS created_date

FROM folio_users.users 
	LEFT JOIN folio_notes.link 
	ON users.id::TEXT = link.object_id::text
	
	LEFT JOIN folio_notes.note_link 
	ON link.id = note_link.link_id
	
	LEFT JOIN folio_notes.note 
	ON note_link.note_id::UUID = note.id::UUID
	
	LEFT JOIN folio_notes.type 
	ON note.type_id = type.id
	
	LEFT JOIN folio_users.users AS users2 
	ON note.created_by::UUID = users2.id
	
WHERE note.domain = 'users'

ORDER BY 
	users.jsonb#>>'{personal,lastName}',
	users.jsonb#>>'{personal,firstName}',
	users.jsonb#>>'{username}',
	note.created_date::timestamptz ASC
;
