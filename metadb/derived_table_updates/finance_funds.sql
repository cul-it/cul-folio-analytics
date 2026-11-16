--metadb:table finance_funds

-- This derived table shows data of the funds from the finance app,
-- including associated data from budgets, ledgers and fiscal years.
-- 5-18-26: removed fields fiscal_year_description and ledger_description because those fields are no longer in the source tables
-- 11-15-26: restored DROP/CREATE statements (were commented out);
--           added fiscal_year_currency, budget amount fields (allocated, available,
--           expenditures, encumbered, awaiting_payment, unavailable, initial_allocation,
--           total_funding, cash_balance), fund_external_account_no,
--           fund_restrict_by_locations, ledger_restrict_expenditures,
--           ledger_restrict_encumbrance
-- 11-15-26: restored fiscal_year_description and ledger_description; fields are
--           confirmed present in the current FOLIO fiscal_year and ledger schemas
--           (jsonb_extract_path_text returns NULL safely where data is absent)

DROP TABLE IF EXISTS finance_funds;

CREATE TABLE finance_funds AS
SELECT
    -- Fiscal year fields
    fiscal_year.id AS fiscal_year_id,
    jsonb_extract_path_text(fiscal_year.jsonb, 'code') AS fiscal_year_code,
    jsonb_extract_path_text(fiscal_year.jsonb, 'name') AS fiscal_year_name,
    jsonb_extract_path_text(fiscal_year.jsonb, 'currency') AS fiscal_year_currency,
    jsonb_extract_path_text(fiscal_year.jsonb, 'periodStart')::timestamptz AS fiscal_year_period_start,
    jsonb_extract_path_text(fiscal_year.jsonb, 'periodEnd')::timestamptz AS fiscal_year_period_end,
    jsonb_extract_path_text(fiscal_year.jsonb, 'description') AS fiscal_year_description,
    -- Budget fields
    budget.id AS budget_id,
    jsonb_extract_path_text(budget.jsonb, 'name') AS budget_name,
    jsonb_extract_path_text(budget.jsonb, 'budgetStatus') AS budget_status,
    jsonb_extract_path_text(budget.jsonb, 'initialAllocation')::numeric(19,4) AS budget_initial_allocation,
    jsonb_extract_path_text(budget.jsonb, 'allocated')::numeric(19,4) AS budget_allocated,
    jsonb_extract_path_text(budget.jsonb, 'totalFunding')::numeric(19,4) AS budget_total_funding,
    jsonb_extract_path_text(budget.jsonb, 'available')::numeric(19,4) AS budget_available,
    jsonb_extract_path_text(budget.jsonb, 'unavailable')::numeric(19,4) AS budget_unavailable,
    jsonb_extract_path_text(budget.jsonb, 'awaitingPayment')::numeric(19,4) AS budget_awaiting_payment,
    jsonb_extract_path_text(budget.jsonb, 'encumbered')::numeric(19,4) AS budget_encumbered,
    jsonb_extract_path_text(budget.jsonb, 'expenditures')::numeric(19,4) AS budget_expenditures,
    jsonb_extract_path_text(budget.jsonb, 'cashBalance')::numeric(19,4) AS budget_cash_balance,
    -- Fund fields
    fund.id AS fund_id,
    jsonb_extract_path_text(fund.jsonb, 'code') AS fund_code,
    jsonb_extract_path_text(fund.jsonb, 'name') AS fund_name,
    jsonb_extract_path_text(fund.jsonb, 'fundStatus') AS fund_status,
    jsonb_extract_path_text(fund.jsonb, 'description') AS fund_description,
    jsonb_extract_path_text(fund.jsonb, 'externalAccountNo') AS fund_external_account_no,
    jsonb_extract_path_text(fund.jsonb, 'restrictByLocations')::boolean AS fund_restrict_by_locations,
    jsonb_extract_path_text(fund.jsonb, 'fundTypeId')::uuid AS fund_type_id,
    jsonb_extract_path_text(fund_type.jsonb, 'name') AS fund_type_name,
    -- Ledger fields
    ledger.id AS ledger_id,
    jsonb_extract_path_text(ledger.jsonb, 'code') AS ledger_code,
    jsonb_extract_path_text(ledger.jsonb, 'name') AS ledger_name,
    jsonb_extract_path_text(ledger.jsonb, 'ledgerStatus') AS ledger_status,
    jsonb_extract_path_text(ledger.jsonb, 'description') AS ledger_description,
    jsonb_extract_path_text(ledger.jsonb, 'restrictExpenditures')::boolean AS ledger_restrict_expenditures,
    jsonb_extract_path_text(ledger.jsonb, 'restrictEncumbrance')::boolean AS ledger_restrict_encumbrance
FROM
    folio_finance.fiscal_year
    LEFT JOIN folio_finance.budget ON budget.fiscalyearid = fiscal_year.id
    LEFT JOIN folio_finance.fund ON fund.id = budget.fundid
    LEFT JOIN folio_finance.fund_type ON fund_type.id = fund.fundtypeid
    LEFT JOIN folio_finance.ledger ON ledger.id = fund.ledgerid;
