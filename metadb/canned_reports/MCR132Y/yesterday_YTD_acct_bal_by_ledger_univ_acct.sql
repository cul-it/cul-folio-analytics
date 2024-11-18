--MCR132Y 
--yesterday_YTD_acct_bal_by_ledger_univ_acct
--last updated: 11/18/24
--written by Nancy Bolduc, revised to Metadb by Sharon Markus and reviewed by Ann Crowley
--This report provides the previous day's totals for the year-to-date external account cash balance 
--along with total_expenditures, initial allocation, and net allocation. 
--The fiscal year can be modified in the WHERE clause. 

SELECT
    CURRENT_DATE-INTERVAL '1 day' AS date,
    fl.name AS finance_ledger_name,
    ff.external_account_no AS external_account,
    SUM(COALESCE (fb.expenditures,0)) AS YTD_expenditures,
    SUM(COALESCE (fb.initial_allocation,0)) AS initial_allocation,
    SUM(COALESCE (fb.initial_allocation,0) + COALESCE (fb.allocation_to,0)
        -COALESCE (fb.allocation_from,0)) AS total_allocated,
    SUM(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)
        -COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)) AS total_funding,
    SUM(COALESCE (fb.initial_allocation,0)+COALESCE (fb.allocation_to,0)
        -COALESCE (fb.allocation_from,0)+COALESCE (fb.net_transfers,0)
        -COALESCE (fb.expenditures,0)) AS cash_balance -- This balance excludes encumbrances and awaiting payment
FROM
    folio_finance.fund__t AS ff
    LEFT JOIN folio_finance.budget__t AS fb ON fb.fund_id = ff.id  
    LEFT JOIN folio_finance.fiscal_year__t AS ffy ON fb.fiscal_year_id = ffy.id
    LEFT JOIN folio_finance.ledger__t AS fl ON fl.id::UUID = ff.ledger_id
WHERE
    ff.fund_status LIKE 'Active'
    AND ffy.code LIKE 'FY2025' --change fiscal year here, e.g., FY2024
GROUP BY
    external_account_no,
    fl.name
ORDER BY
    finance_ledger_name,
    external_account_no ASC; 
