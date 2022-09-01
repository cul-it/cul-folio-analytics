--This query allows you to see the loans tied to a particular user by netid

with filters as 
	(select 
	''::varchar as net_id_filter
	)

select 
	cl.id as loan_id,
	cl.loan_date,
	cl.user_id,
	cl.item_id,
	invitems.hrid,
	uu.username,
	concat(json_extract_path_text(uu.data,'personal','lastName'),', ',json_extract_path_text (uu.data,'personal','firstName')) as "user"

from circulation_loans as cl 
	left join inventory_items as invitems 
	on cl.item_id = invitems.id 

	left join user_users as uu 
	on cl.user_id = uu.id

where uu.username = (select net_id_filter from filters)
;
