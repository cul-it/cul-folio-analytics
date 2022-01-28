WITH parameters AS (
    SELECT
    /*Fill out owning library filter or leave blank to include all libraries*/
        'Olin Library'::varchar AS owning_library_filter -- 'Olin Library, Mann Library, etc.'
  )
 SELECT 
        TO_CHAR(current_date::DATE,'mm/dd/yyyy') AS todays_date,
        ll.library_name,
        itmext.material_type_name,
        li.patron_group_name,
        itmext.barcode,
        instext.instance_hrid,
        he.holdings_hrid,
        itmext.item_hrid,
        instext.title,
        he.call_number,
        itmext.enumeration,
        itmext.chronology,
        itmext.copy_number,
        itmext.damaged_status_name,
        itmext.status_name,
        TO_CHAR (itmext.status_date::DATE,'mm/dd/yyyy') AS status_date,
        "in".note AS item_note,
        hsc.statistical_code_name,
        COUNT(li.loan_id) AS number_of_loans,
        SUM(CASE WHEN li.renewal_count IS NULL THEN '0' ELSE li.renewal_count END) AS number_of_renewals


FROM folio_reporting.instance_ext AS instext
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON instext.instance_id = he.instance_id
        
        LEFT JOIN folio_reporting.item_ext AS itmext 
        ON he.holdings_id = itmext.holdings_record_id
        
        LEFT JOIN inventory_holdings AS ih 
        ON he.holdings_id = ih.id

        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON itmext.effective_location_id = ll.location_id
        
        LEFT JOIN folio_reporting.item_notes AS "in" 
        ON itmext.item_id = "in".item_id
        
        LEFT JOIN folio_reporting.holdings_statistical_codes AS hsc 
        ON he.holdings_id = hsc.holdings_id
        
        LEFT JOIN folio_reporting.loans_items AS li 
        ON itmext.item_id = li.item_id

WHERE (ll.library_name = (SELECT owning_library_filter FROM parameters)
        OR (SELECT owning_library_filter FROM parameters) = '') 
        AND itmext.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment','Laptop')

GROUP BY 
        to_char(current_date::DATE,'mm/dd/yyyy'),
        ll.library_name,
        itmext.material_type_name,
        li.patron_group_name,
        itmext.barcode,
        instext.instance_hrid,
        he.holdings_hrid,
        itmext.item_hrid,
        instext.title,
        he.call_number,
        itmext.enumeration,
        itmext.chronology,
        itmext.copy_number,
        itmext.damaged_status_name,
        itmext.status_name,
        TO_CHAR(itmext.status_date::DATE,'mm/dd/yyyy'),
        "in".note,
        hsc.statistical_code_name
        
ORDER BY itmext.material_type_name, he.call_number, enumeration, chronology, copy_number
;
