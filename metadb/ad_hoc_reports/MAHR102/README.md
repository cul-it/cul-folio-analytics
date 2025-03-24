## MAHR102 – Physical Items Acquired Since 2019

**File Name:** `physical_items_acquired_since_2019.sql`

**Written by:** Joanne Leary  
**Tested by:** Sharon Markus

### Description

This query provides physical items acquired since 2019, including their OCLC numbers and circulation counts. It continues a project initiated in 2019 to analyze the usage of titles matching OCLC data for instances acquired from 2019 through 2024.

Specifically, the query identifies all instances associated with circulating items at Cornell University Library (CUL), as indicated by the loan type. Additionally, it provides language codes and OCLC identifiers, and compares Cornell-affiliated circulation usage versus Borrow Direct (BD) and Interlibrary Loan (ILL) usage for the period 2019-2024.

### Change Log

- **3-12-25:** Applied `COALESCE` function to replace NULL values with zeroes in circulation subqueries. Runtime as of 3-12-25 is approximately 15 minutes.
- **2-27-25:** Corrected `lc_marc` extraction to retrieve only the first LC classification when multiple `050` fields exist.
- **2-25-25:** Initial version covering physical items acquired 2019-2024, including OCLC numbers, circulation counts, and language codes.






