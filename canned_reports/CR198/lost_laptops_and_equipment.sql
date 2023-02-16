--CR198
--Lost laptops and equipment

WITH parameters AS 
(SELECT ''::VARCHAR AS library_name_filter -- enter a library name or leave blank. For example, "Mann Library", "Fine Arts Library", etc.
),

recs AS 
(SELECT 
        ll.library_name,
        ie.effective_location_name,
        ii.title,
        TRIM (CONCAT (he.call_number_prefix, ' ',he.call_number, ' ',he.call_number_suffix,' ',ie.enumeration, ' ',ie.chronology,
                CASE WHEN ie.copy_number >'1' THEN CONCAT ('c.',ie.copy_number) ELSE '' END)) AS whole_call_number,
        ie.item_id,
        ie.item_hrid,
        ie.barcode,
        ie.material_type_name,
        ie.status_name as item_status,
        ie.status_date::DATE as item_status_date

FROM
        inventory_instances AS ii 
        LEFT JOIN folio_reporting.holdings_ext AS he 
        ON ii.id = he.instance_id 
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON he.permanent_location_id = ll.location_id 
        
        LEFT JOIN folio_reporting.item_ext AS ie 
        on he.holdings_id = ie.holdings_record_id 
        
        LEFT JOIN folio_reporting.loans_items AS li 
        ON ie.item_id = li.item_id
        
        WHERE ((SELECT library_name_filter FROM parameters) = '' OR ll.library_name = (SELECT library_name_filter FROM parameters))
        AND ie.status_name ILIKE '%ost%'
        AND ie.material_type_name IN ('Carrel Keys','Equipment','Laptop','Locker Keys','Peripherals','Room Keys','Supplies')
),

-- 2. Get most recent loan for above items

loans AS 
(SELECT
        recs.library_name,
        recs.effective_location_name,
        recs.title,
        recs.whole_call_number,
        recs.item_id,
        recs.item_hrid,
        recs.barcode,
        recs.material_type_name,
        recs.item_status,
        recs.item_status_date::DATE,
        MAX (li.loan_date) AS most_recent_loan_date

FROM recs 
LEFT JOIN folio_reporting.loans_items AS li 
        ON recs.item_id = li.item_id 

GROUP BY 
        recs.library_name,
        recs.effective_location_name,
        recs.title,
        recs.whole_call_number,
        recs.item_id,
        recs.item_hrid,
        recs.barcode,
        recs.material_type_name,
        recs.item_status,
        recs.item_status_date::DATE
)

--3. Get patron info and other loan info

SELECT
        TO_CHAR (CURRENT_DATE::DATE, 'mm/dd/yyyy') as todays_date,
        loans.library_name,
        loans.effective_location_name,
        loans.title,
        loans.whole_call_number,
        loans.item_hrid,
        loans.barcode,
        loans.material_type_name,
        li.loan_policy_name,
        loans.item_status,
        TO_CHAR (loans.item_status_date::date,'mm/dd/yyyy') AS item_status_date,
        li.loan_status, 
        TO_CHAR (li.loan_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') AS loan_date,     
        TO_CHAR (li.loan_due_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') AS due_date,
        TO_CHAR (li.loan_return_date::TIMESTAMP,'mm/dd/yyyy hh:mi am') AS return_date,
        CONCAT (uu.personal__last_name,', ',uu.personal__first_name) AS borrower,
        uu.username as net_id,
        li.patron_group_name,
        CASE WHEN uu.active = 'True' THEN 'Active' ELSE 'Expired' END AS patron_status,
        uu.personal__email
        
        FROM loans 
        LEFT JOIN folio_reporting.loans_items AS li 
                ON loans.item_id = li.item_id 
                AND loans.most_recent_loan_date = li.loan_date
        
        LEFT JOIN user_users AS uu 
        ON li.user_id = uu.id

ORDER BY uu.username, library_name, material_type_name, title, whole_call_number
;


