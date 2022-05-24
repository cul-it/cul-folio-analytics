WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2022-01-01'::date AS start_date,
        '2022-06-30'::date AS end_date
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
     

FROM folio_reporting.loans_items AS li 
       LEFT JOIN folio_reporting.holdings_ext AS he 
       ON li.holdings_record_id = he.holdings_id
       
       LEFT JOIN folio_reporting.instance_ext AS ie 
       ON he.instance_id = ie.instance_id
       
       LEFT JOIN folio_reporting.item_ext AS itemext 
       ON li.item_id = itemext.item_id
       
    
WHERE
	li.loan_date >= (SELECT start_date FROM parameters)
    	AND li.loan_date < (SELECT end_date FROM parameters)
       	AND (li.patron_group_name = 'Borrow Direct' OR li.patron_group_name = 'Interlibrary Loan')
        
ORDER BY loan_date, title
;
