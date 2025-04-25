--MCR403
--create_circsnapshot4_metadb.sql
--The first step in the process of setting up the circ snapshot is to create the circsnapshot4.sql table in metadb, 
--which is where data updates will be appended and stored. 
--Run the create_circsnapshot4.sql query to create the circsnapshot4 table in the local_core schema in metadb. 
--This query (run just once) finds all records in the loans_items table where the user_id is not null, 
--and gets the demographics associated with that user via the user_users table and the users_departmnts_unpacked table. 
--This makes the a starting table that is updated by the update_circsnapshot4_metadb query daily automatically.

CREATE TABLE local_core.test_circ_snapshot4
 AS 
 SELECT 
  now() AS extract_date,
  li.loan_id,
  li.item_id,
  li.barcode,
  li.loan_date,
  li.loan_return_date,
  li.patron_group_name,
  uu.custom_fields__department,
  uu.custom_fields__college,
  udu.department_code
 
 FROM folio_derived.loans_items AS li 
  LEFT JOIN folio_users.users__t AS uu 
  ON li.user_id::UUID = uu.id::UUID 
  
  LEFT JOIN folio_derived.users_departments_unpacked AS udu 
  ON li.user_id::UUID = udu.user_id::UUID 
  
 WHERE li.user_id IS NOT NULL
;

