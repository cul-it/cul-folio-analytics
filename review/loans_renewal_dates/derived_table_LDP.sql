-- 5-22-24: this is a revision of the loans_renewal_dates derived table in LDP.
-- This uses the circulation_loan_history table for the data source; this table has been significantly changed since the derived table was originally created
-- Changes to query: 
        -- truncated the renewal date ("created date") to 'minutes' to eliminate renewals seconds apart, which are artifacts of system processes, not actual patron renewals.
        -- added the item hrid
        -- selected the loan status from the circulation_loans table, not the circulation_loan_history table (which always shows "Open" for renewals)
        -- removed the loan history id ("id") from Select statement, since including it would make it impossible group by loan_id and count renewals
        -- removed the "loan_renewal_count" field (selected from the circulation_loan_history table) to prevent misuse of the field in calculating total renewals over a date range.
        -- 5-28-24: cast the truncated date as "timestamptz"
        
SELECT     
        clh.loan__id AS loan_id,
        clh.loan__loan_date AS loan_date,
        clh.loan__item_id AS item_id,
        invitems.hrid AS item_hrid,
        clh.loan__actiON AS loan_action,
        DATE_TRUNC ('minute', clh.created_date::TIMESTAMPTZ) AS renewal_date,
        COUNT (DISTINCT clh.loan__id) AS folio_renewal_count,   
        cl.status__name AS loan_status
        
    FROM public.circulation_loan_history AS clh
            LEFT JOIN public.circulation_loans AS cl 
            ON clh.loan__id::UUID = cl.id::UUID     
            
            LEFT JOIN inventory_items AS invitems 
            ON clh.loan__item_id::UUID = invitems.id::UUID
    
    WHERE
        clh.loan__actiON IN ('renewed', 'renewedThroughOverride')
        
    GROUP BY         
        clh.loan__id,
        clh.loan__loan_date,
        clh.loan__item_id,
        invitems.hrid,
        clh.loan__action,
        DATE_TRUNC ('minute', clh.created_date::TIMESTAMPTZ),
        cl.status__name
        
    ORDER BY
        clh.loan__id,
        DATE_TRUNC ('minute', clh.created_date::TIMESTAMPTZ) asc
        ;

