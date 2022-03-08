SELECT
        TO_CHAR(CURRENT_DATE::DATE,'mm/dd/yyyy') AS as_of_date,
        ffy.code AS fiscal_year,
        fg.name AS team,
        fg.description AS fund_manager,
        fft.name AS fund_type,
        ff.code AS finance_funds_code,
        ff.name AS finance_funds_name,
        ff.description,
        fb.total_funding,
        fb.expenditures,
        fb.encumbered,
        fb.awaiting_payment,
        (fb.total_funding - fb.available) AS total_spent_encumbered_or_awaiting_payment,
        fb.cash_balance,
        fb.available AS available_balance
        
        

FROM
        finance_group_fund_fiscal_years AS fgffy 
        LEFT JOIN finance_groups AS fg                    
        ON fgffy.group_id = fg.id
        
        LEFT JOIN finance_fiscal_years AS ffy
        ON fgffy.fiscal_year_id = ffy.id
        
        LEFT JOIN finance_funds AS ff
        ON fgffy.fund_id = ff.id
        
        LEFT JOIN finance_budgets AS fb
        ON ff.id = fb.fund_id
        
        LEFT JOIN finance_fund_types AS fft
        ON ff.fund_type_id = fft.id

ORDER BY team, finance_funds_code, finance_funds_name
;
