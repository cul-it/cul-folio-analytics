README for MCR404

update_circsnapshot4_metadb.sql
Last updated: 7/1/24

The update_circ_snapshot4_metadb.sql query uses the INSERT function to get the new checkouts 
and add them to the sm_local_shared.circsnapshot4 table daily automatically. 

The sm_local_shared.circsnapshot4 table is used in circulation queries to generate reports 
that need certain demographic data that is removed everyday from circulation data in the FOLIO system.

