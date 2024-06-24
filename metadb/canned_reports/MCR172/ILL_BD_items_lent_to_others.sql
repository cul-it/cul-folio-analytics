--MCR172 
--This query provides a list of items owned by CUL which have been loaned to other universities on BD and ILL.
--Query writer: Joanne Leary (jl41)
--Posted on: 6/24/24

WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2023-07-01'::date AS start_date,
        '2024-07-01'::date AS end_date
        )

SELECT DISTINCT
       TO_CHAR (current_date::DATE,'mm/dd/yyyy') AS todays_date,
       li.material_type_name,
       TO_CHAR (li.loan_date::DATE,'mm/dd/yyyy') AS loan_date,
       ie.title,
       ie.instance_hrid,
       he.holdings_hrid,
       li.hrid as item_hrid,
       li.barcode,
       itemext.effective_call_number,
       he.permanent_location_name,
       li.patron_group_name
     

FROM folio_derived.loans_items AS li 
       LEFT JOIN folio_derived.holdings_ext AS he 
       ON li.holdings_record_id = he.holdings_id
       
       LEFT JOIN folio_derived.instance_ext AS ie 
       ON he.instance_id = ie.instance_id
       
       LEFT JOIN folio_derived.item_ext AS itemext 
       ON li.item_id = itemext.item_id
       
    
WHERE
	li.loan_date >= (SELECT start_date FROM parameters)
    	AND li.loan_date < (SELECT end_date FROM parameters)
       	AND (li.patron_group_name = 'Borrow Direct' OR li.patron_group_name = 'Interlibrary Loan')
        
ORDER BY loan_date, title
;
