MCR403 Readme
<p>
create_circsnapshot4_metadb.sql
</p>
The first step in the process is to create the circsnapshot4_metadb.sql table on Metadb, which is where data updates 
will be appended and stored. Run the create_circsnapshot4_metadb.sql query to create the circsnapshot4 table in the 
local_shared schema on Metadb. 
<br>
This query (run just once) finds all records in the loans_items derived table where the user_id is not null, 
and gets the demographics associated with that user via the user_users table and the users_departmnts_unpacked table. 
This makes the a starting table that is updated by the MCR404 update_circsnapshot4_metadb.sql query daily automatically.
</br>


