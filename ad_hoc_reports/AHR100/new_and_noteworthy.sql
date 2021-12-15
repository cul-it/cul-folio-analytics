select 
        he.holdings_hrid,
        ie.item_hrid,
        ihi.title,
        --he.holdings_id,
        he.permanent_location_name,
        he.temporary_location_name,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        --he.instance_id,
        he.type_name,
        ie.permanent_loan_type_name,
        ie.temporary_loan_type_name,
        ihi.material_type_name,
        ihi.loan_type_name,
        --ihi.holdings_record_id,
        --ihi.instance_id,
        ihi.barcode,
        --li.item_id,
        li.loan_date,
        li.loan_due_date,
        li.renewal_count,
        li.loan_policy_name

from folio_reporting.holdings_ext as he 
left join folio_reporting.items_holdings_instances as ihi 
        on he.holdings_id = ihi.holdings_record_id

left join folio_reporting.item_ext as ie 
        on ihi.item_id = ie.item_id

left join folio_reporting.loans_items as li 
        on ie.item_id = li.item_id

where he.call_nUmber_prefix = 'New & Noteworthy'
        and li.loan_date >'2021/11/01'

order by loan_date;
