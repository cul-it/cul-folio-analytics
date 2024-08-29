--MCR172 
--This query provides a list of items owned by CUL which have been loaned to other universities on BD and ILL.
--Query writer: Joanne Leary (jl41)
--Posted on: 6/24/24
--Updated on: 8/29/24

WITH parameters AS (
    SELECT
        /* Choose a start AND END date for the loans period */
        '2024-07-01'::date AS start_date,
        '2025-07-01'::date AS end_date
        )

SELECT DISTINCT
       TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
       CONCAT ((SELECT start_date FROM parameters),' - ',(SELECT end_date FROM parameters)) AS loan_date_range,
       date_part ('year', li.loan_date::DATE) AS year_of_loan,
       li.material_type_name,
       ie.title,
       ip.date_of_publication,
       SUBSTRING (ip.date_of_publication,'\d{4}') AS year_of_publication,
       ie.instance_hrid,
       he.holdings_hrid,
       li.hrid AS item_hrid,
       li.barcode,
       TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',itemext.chronology,
       	CASE WHEN itemext.copy_number >'1' THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)) AS effective_call_number,
       CASE      
       	WHEN he.call_number_type_name = 'Library of Congress classification' 
       	THEN SUBSTRING (itemext.effective_call_number,'[A-Z]{1,3}')
       	ELSE NULL END AS lc_class,       	
       (CASE      
       	WHEN he.call_number_type_name = 'Library of Congress classification' 
       	THEN TRIM (trailing '.' FROM SUBSTRING (itemext.effective_call_number,'\d{1,}\.{0,1}\d{0,}')) 
       	ELSE NULL end)::NUMERIC AS lc_class_number,      	
       he.permanent_location_name,
       li.patron_group_name,
       item__t.effective_shelving_order COLLATE "C"
     

FROM folio_derived.loans_items AS li 
       LEFT JOIN folio_derived.holdings_ext AS he 
       ON li.holdings_record_id = he.holdings_id
       
       LEFT JOIN folio_derived.instance_ext AS ie 
       ON he.instance_id = ie.instance_id
       
       LEFT JOIN folio_derived.instance_publication AS ip 
       ON ie.instance_id = ip.instance_id
       
       LEFT JOIN folio_derived.item_ext AS itemext 
       ON li.item_id = itemext.item_id
       
       LEFT JOIN folio_inventory.item__t 
       ON itemext.item_id = item__t.id
       AND li.item_id = item__t.id
       
    
WHERE
	li.loan_date >= (SELECT start_date FROM parameters)
    	AND li.loan_date < (SELECT end_date FROM parameters)
       	AND (li.patron_group_name = 'Borrow Direct' OR li.patron_group_name = 'Interlibrary Loan')
       	AND (ip.publication_ordinality = 1 OR ip.instance_id IS NULL)
        
ORDER BY item__t.effective_shelving_order COLLATE "C", title



;
