select 
        --ihi.item_id,
        ie.instance_hrid,
        ih.hrid as holdings_hrid,
        ihi.hrid as item_hrid,
        --ihi.holdings_id,
        --ihi.instance_id,
        ihi.title,
        ihi.material_type_name,
        ihi.barcode,
        ihi.call_number,
        ihi.item_copy_number,
        iext.status_name as item_status_name,
        to_char(iext.status_date::DATE,'mm/dd/yyyy') as item_status_date,
        ihi.loan_type_name,
        --ih.permanent_location_id,
        --ll.location_id,
        ll.location_name,
        ll.library_name

from inventory_holdings as ih 
        left join folio_reporting.locations_libraries as ll 
        on ih.permanent_location_id = ll.location_id
        
        left join folio_reporting.items_holdings_instances as ihi 
        on ih.id = ihi.holdings_id
        
        left join folio_reporting.instance_ext as ie 
        on ihi.instance_id = ie.instance_id
        
        left join folio_reporting.item_ext as iext 
        on ihi.item_id = iext.item_id

where 
        ll.library_name like 'Nest%' 
        and ihi.material_type_name in ('Equipment','Peripherals','Supplies','Laptop')

order by instance_hrid, holdings_hrid, item_hrid, title, call_number, item_copy_number;
