-- MCR404
-- update_circsnapshot4_metadb.sql
-- Last updated: 7/1/24
-- Written by Joanne Leary. Reviewed and tested by Sharon Markus.
-- The update_circ_snapshot4_metadb.sql query
-- runs the following code on Metadb, which uses the INSERT function to get the new checkouts 
-- and add them to the sm_local_shared.circsnapshot4 table daily automatically. 
-- The sm_local_shared.circsnapshot4 table is used in circulation queries to generate reports 
-- that need certain demographic data that is removed everyday from circulation data in the FOLIO system.
 
-- 6-27-24: This query creates the "insert into" portion of the circ_snapshot4 query

INSERT INTO local_core.sm_circ_snapshot4

-- 1. In order to get to the department code in the departments__t table, we need to extract the department ID from the jsonb array in the users__ table

WITH depts AS 
(SELECT
	users__.id AS user_id,
	departments.jsonb #>> '{}' AS department_id
	FROM 
		folio_users.users__
		CROSS JOIN jsonb_array_elements((users__.jsonb #> '{departments}')::jsonb) as departments
	WHERE users__.__current = 'true'		
)

-- 2. Use the results of the depts subquery above to link to the departments__t table and users__t table
	
SELECT
   NOW() AS extract_date,
   loan__t.id as loan_id,
   loan__t.item_id,
   item__t.barcode,
   loan__t.loan_date::timestamptz,
   loan__t.return_date::timestamptz as loan_return_date,
   groups__t.group AS patron_group_name,
   jsonb_extract_path_text (folio_users.users__.jsonb,'customFields','department') AS custom_fields__department,
   jsonb_extract_path_text (folio_users.users__.jsonb,'customFields','college') AS custom_fields__college,
   departments__t.code AS department_code

FROM 
	folio_users.users__
	LEFT JOIN folio_users.users__t 
   	ON users__.id = users__t.id
   	
   	LEFT JOIN depts 
   	ON users__.id = depts.user_id
   	
   	LEFT JOIN folio_users.departments__t 
    ON depts.department_id::UUID = departments__t.id

    LEFT JOIN folio_circulation.loan__t
    ON loan__t.user_id = users__t.id
    
    LEFT JOIN folio_users.groups__t 
    ON users__t.patron_group = groups__t.id

    LEFT JOIN folio_inventory.item__t 
    ON loan__t.item_id = item__t.id
   
WHERE
   loan__t.id NOT IN 
	   (SELECT cs4.loan_id::UUID
	   FROM local_core.sm_circ_snapshot4 as cs4
	   )
   AND loan__t.user_id is not null 
   AND users__.__current = true
   ;
   
  
