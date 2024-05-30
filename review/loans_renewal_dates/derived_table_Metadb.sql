-- 5-28-24: revised loans_renewal_dates derived table (MetaDB) 
-- Corrections:
	-- 1. changed source table to "folio_circulation.audit_loan" 
	-- 2. linked to "folio_circulation.loan" table to get actual loan status
	-- 3. truncated the seconds from the renewal date to eliminate false renewal counts
	-- 4. added item hrid from the folio_inventory.item__t table
	-- 5. renamed "renewal_count" to "folio_renewal_count" (can be used to sum renewals over a date range)
	-- 6. eliminated "loan_renewal_count" from the table, since that is a very misleading figure and must not be used to sum renewals over a date range

SELECT DISTINCT
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','id') AS loan_id,
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','loanDate')::TIMESTAMPTZ AS loan_date,
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','itemId') AS item_id,
        item__t.hrid AS item_hrid,
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','action') AS loan_action,
        DATE_TRUNC ('minute',jsonb_extract_path_text(audit_loan.jsonb, 'loan','metadata','updatedDate')::TIMESTAMPTZ) AS renewal_date, -- truncated to eliminate seconds
        COUNT (DISTINCT jsonb_extract_path_text(audit_loan.jsonb, 'loan','id')) AS folio_renewal_count,
        jsonb_extract_path_text(loan.jsonb, 'status','name') AS loan_status

    FROM folio_circulation.audit_loan
    	LEFT JOIN folio_circulation.loan 
    	ON jsonb_extract_path_text(audit_loan.jsonb, 'loan','id')::UUID = loan.id::UUID
    	
    	LEFT JOIN folio_inventory.item__t 
    	ON jsonb_extract_path_text(audit_loan.jsonb, 'loan','itemId')::UUID = item__t.id::UUID
    	
    WHERE
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','action') IN ('renewed', 'renewedThroughOverride')

    GROUP BY 
	jsonb_extract_path_text(audit_loan.jsonb, 'loan','id'),
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','loanDate')::TIMESTAMPTZ,
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','itemId'),
        item__t.hrid,
        jsonb_extract_path_text(audit_loan.jsonb, 'loan','action'),
        DATE_TRUNC ('minute',jsonb_extract_path_text(audit_loan.jsonb, 'loan','metadata','updatedDate')::TIMESTAMPTZ), -- truncated to eliminate seconds
	jsonb_extract_path_text(loan.jsonb, 'status','name')
		
    ORDER by
    	jsonb_extract_path_text(audit_loan.jsonb, 'loan','id'),
    	date_trunc('minute',jsonb_extract_path_text(audit_loan.jsonb, 'loan','metadata','updatedDate')::TIMESTAMPTZ)
    	;
