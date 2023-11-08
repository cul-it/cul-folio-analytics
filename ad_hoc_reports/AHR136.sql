-- AHR 136
-- cornell_tech_requests_by_fiscal year
-- 10-30-23: this query finds filled requests to Cornell Tech by fiscal year, calendar year and month, and ownership (Cornell or Borrow Direct).
-- written by Joanne Leary and reviewed by Sharon Beltaine

select 
	case when date_part ('month', ri.request_date::date) < 7 then concat ('FY ',date_part ('year',ri.request_date::date))
		else concat ('FY ',date_part ('year',ri.request_date::date)+1) end as fiscal_year_requested,
	CAST(date_part ('year',ri.request_date::date) AS VARCHAR) as calendar_year_requested,
	date_part ('month',ri.request_date::date) as month_requested,
	case when ri.item_effective_location_name = 'Borrow Direct' then 'Borrow Direct' else 'CUL-owned' end as owning_library_group,
	ri.pickup_service_point_name,
	ri.request_status,
	count (ri.request_id) as number_of_filled_requests

from folio_reporting.requests_items as ri 

where ri.pickup_service_point_name like '%Tech%'
	and ri.request_status = 'Closed - Filled'
	
group by 
	case when date_part ('month', ri.request_date::date) < 7 then concat ('FY ',date_part ('year',ri.request_date::date))
		else concat ('FY ',date_part ('year',ri.request_date::date)+1) end, 
		date_part ('year',ri.request_date::date),
		date_part ('month', ri.request_date::date),
		case when ri.item_effective_location_name = 'Borrow Direct' then 'Borrow Direct' else 'CUL-owned' end,
		ri.pickup_service_point_name,
		ri.request_status

order by fiscal_year_requested, calendar_year_requested, month_requested, request_status;
