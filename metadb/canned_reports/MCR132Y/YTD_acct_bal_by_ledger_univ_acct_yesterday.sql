--MCR132Y 
--ytd_acct_bal_by_ledger_univ_acct_yesterday
--last updated: 11-11-26
--written by Sharon Markus and reviewed by Ann Crowley
--This report uses historical tables to provide yesterday's 
--year-to-date external account cash balance, total_expenditures, 
--initial allocation, and net allocation. 
--Historical snapshots are created for budget, fund, and ledger amounts.
--The fiscal year, currently set to FY2026, can be changed in the WHERE clause.
--8-15-25: added or subtracted credits into the YTD_expenditures and cash_balance calculations
--Example below captures snapshots for “yesterday at 6:00 PM ET.” 
--Change TIME value to change time snapshots are taken.

WITH params AS (
  SELECT (date_trunc('day', (CURRENT_TIMESTAMP AT TIME ZONE 'America/New_York'))::timestamp
          - INTERVAL '1 day' + TIME '18:00') AS as_of_local_ts
  -- OR: SELECT '2025-11-05 16:03:00'::timestamp AS as_of_local_ts
),
asof0 AS (
  -- Convert local wall-clock to timestamptz
  SELECT (p.as_of_local_ts AT TIME ZONE 'America/New_York') AS as_of_utc_tmp
  FROM params p
),
fy AS (
  -- time-slice the FY row itself from the historical table and get actual FY boundaries
  SELECT
      ffy.id AS fy_id,
      ffy.code,
  -- treat period_end as inclusive by building an exclusive end at next local midnight
      (ffy.period_start::timestamp AT TIME ZONE 'America/New_York') AS fy_start_utc,
      ((ffy.period_end::date + 1)::timestamp AT TIME ZONE 'America/New_York') AS fy_end_excl_utc,
      a0.as_of_utc_tmp
  FROM folio_finance.fiscal_year__t__ ffy
  CROSS JOIN asof0 a0
  WHERE ffy.code = 'FY2026'
    AND ffy.__start < a0.as_of_utc_tmp
    AND ffy.__end   > a0.as_of_utc_tmp
),
asof AS (
  -- clamp the final as-of to the FY window (not before start; not past exclusive end)
  SELECT
      GREATEST(fy.fy_start_utc,
               LEAST(fy.as_of_utc_tmp, fy.fy_end_excl_utc - INTERVAL '1 microsecond')) AS as_of_utc,
      fy.fy_id
  FROM fy
)
SELECT
    (a.as_of_utc AT TIME ZONE 'America/New_York')::date AS current_date,
    ldr.name                                            AS finance_ledger_name,
    fnd.external_account_no::text                       AS external_account,
    SUM(COALESCE(bgt.expenditures, 0) - COALESCE(bgt.credits, 0)) AS ytd_expenditures,
    SUM(COALESCE(bgt.initial_allocation, 0)) AS initial_allocation,
    SUM(COALESCE(bgt.initial_allocation, 0) + COALESCE(bgt.allocation_to, 0)
        - COALESCE(bgt.allocation_from, 0)) AS total_allocated,
    SUM(COALESCE(bgt.initial_allocation, 0) + COALESCE(bgt.allocation_to, 0)
        - COALESCE(bgt.allocation_from, 0) + COALESCE(bgt.net_transfers, 0)) AS total_funding,
    SUM(COALESCE(bgt.initial_allocation, 0) + COALESCE(bgt.allocation_to, 0)
        - COALESCE(bgt.allocation_from, 0) + COALESCE(bgt.net_transfers, 0)
        - COALESCE(bgt.expenditures, 0) + COALESCE(bgt.credits, 0)) AS cash_balance
FROM asof a

--budget snapshot (historical table) within FY at the same instant
JOIN folio_finance.budget__t__ AS bgt
  ON bgt.__start < a.as_of_utc
 AND bgt.__end   > a.as_of_utc
 AND bgt.fiscal_year_id = a.fy_id

--fund snapshot (historical) to freeze status and account at the same instant
JOIN folio_finance.fund__t__ AS fnd
  ON fnd.__start < a.as_of_utc
 AND fnd.__end   > a.as_of_utc
 AND fnd.id = bgt.fund_id

--ledger snapshot (historical) for name at the same instant 
LEFT JOIN folio_finance.ledger__t__ AS ldr
  ON ldr.__start < a.as_of_utc
 AND ldr.__end   > a.as_of_utc
 AND ldr.id::uuid = fnd.ledger_id

WHERE
  fnd.fund_status = 'Active'
GROUP BY
  ldr.name, 
  fnd.external_account_no, 
  a.as_of_utc
ORDER BY
  finance_ledger_name, 
  external_account
;


