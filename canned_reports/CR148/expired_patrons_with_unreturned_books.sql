SELECT DISTINCT
        TO_CHAR(CURRENT_DATE,'mm/dd/yyyy') as todays_date,
        json_extract_path_text(uu.data,'personal','lastName') AS patron_last_name,
        json_extract_path_text(uu.data,'personal','firstName') AS patron_first_name,
        li.patron_group_name,
        CASE WHEN uu.active ='false' THEN 'inactive' ELSE 'active' END AS patron_status,
        uu.barcode AS patron_barcode,
        uu.external_system_id,
        uu.username AS net_id,
        ll.library_name,
        ihi.title,
        he.permanent_location_name,
        he.call_number_prefix,
        he.call_number,
        he.call_number_suffix,
        li.enumeration,
        li.chronology,
        li.copy_number,
        li.material_type_name,
        li.barcode AS item_barcode,
        li.loan_status,
        TO_CHAR(li.loan_date::DATE,'mm/dd/yyyy') AS loan_date,
        TO_CHAR(li.loan_due_date::DATE,'mm/dd/yyyy') AS due_date,
        DATE_PART('day', NOW() - li.loan_due_date) AS days_overdue,
        json_extract_path_text (ii.data,'status','name') AS item_status_name,
        TO_CHAR(json_extract_path_text(ii.data,'status','date')::DATE,'mm/dd/yyyy') AS item_status_date,
        ii.effective_shelving_order


FROM folio_reporting.loans_items AS li 
        LEFT JOIN user_users AS uu 
        ON li.user_id = uu.id

        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON li.holdings_record_id = he.holdings_id 
        
        LEFT JOIN folio_reporting.items_holdings_instances AS ihi 
        ON he.holdings_id = ihi.holdings_id 
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 
        
        LEFT JOIN inventory_items AS ii
        ON li.item_id = ii.id

WHERE uu.active = 'false'
        AND li.barcode != 'null'
        AND li.loan_status = 'Open'
        AND li.loan_due_date < current_date
        

ORDER BY patron_last_name, patron_first_name, library_name, permanent_location_name, effective_shelving_order;
