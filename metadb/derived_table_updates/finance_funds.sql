--metadb:table finance_funds

-- This derived table shows data of the funds from the finance app,
-- including associated data from budgets, ledgers and fiscal years.
-- 5-18-26: removed fields fiscal_year_description and ledger_description because those fields are no longer in the source tables

--DROP TABLE IF EXISTS finance_funds;

--CREATE TABLE finance_funds AS
SELECT
    fiscal_year.id AS fiscal_year_id,
    jsonb_extract_path_text(fiscal_year.jsonb, 'code') AS fiscal_year_code,
    jsonb_extract_path_text(fiscal_year.jsonb, 'name') AS fiscal_year_name,
    jsonb_extract_path_text(fiscal_year.jsonb, 'periodStart')::timestamptz AS fiscal_year_period_start,
    jsonb_extract_path_text(fiscal_year.jsonb, 'periodEnd')::timestamptz  AS fiscal_year_period_end,
    --jsonb_extract_path_text(fiscal_year.jsonb, 'description') AS fiscal_year_description, --removed because field is no longer in fiscal_year table
    budget.id AS budget_id,
    jsonb_extract_path_text(budget.jsonb, 'name') AS budget_name,
    jsonb_extract_path_text(budget.jsonb, 'budgetStatus') AS budget_status,
    fund.id AS fund_id,
    jsonb_extract_path_text(fund.jsonb, 'code') AS fund_code,
    jsonb_extract_path_text(fund.jsonb, 'name') AS fund_name,
    jsonb_extract_path_text(fund.jsonb, 'fundStatus') AS fund_status,
    jsonb_extract_path_text(fund.jsonb, 'description') AS fund_description,
    jsonb_extract_path_text(fund.jsonb, 'fundTypeId')::uuid AS fund_type_id,
    jsonb_extract_path_text(fund_type.jsonb, 'name') AS fund_type_name,
    ledger.id AS ledger_id,
    jsonb_extract_path_text(ledger.jsonb, 'code') AS ledger_code,
    jsonb_extract_path_text(ledger.jsonb, 'name') AS ledger_name,
    jsonb_extract_path_text(ledger.jsonb, 'ledgerStatus') AS ledger_status
    --jsonb_extract_path_text(ledger.jsonb, 'description') AS ledger_description -- removed because field is no longer in loedger table
FROM
    folio_finance.fiscal_year
    LEFT JOIN folio_finance.budget ON budget.fiscalyearid = fiscal_year.id
    LEFT JOIN folio_finance.fund ON fund.id = budget.fundid
    LEFT JOIN folio_finance.fund_type ON fund_type.id = fund.fundtypeid
    LEFT JOIN folio_finance.ledger ON ledger.id = fund.ledgerid;
