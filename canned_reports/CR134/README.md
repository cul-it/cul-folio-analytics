# CR134

# Approved invoices with bib data  
<p>
  
## Brief description:
This query provides the list of approved invoices within a date range along with vendor name, finance group name, vendor invoice number, fund details, purchase order details, language, instance subject, LC classification, LC class, LC class number, and bibliographic format. 
<p>
  
## Updates:
<br>--6-28-23: updated instance_subject_extract subquery to work with Orchid release
<br>--8-26-23: added LC Class and LC Classification from the 050$a field and added it to parameters
<br>--8-29-23: added LC class number and updated the source table for formats to vs_folio_physical_material_formats;
<br>--added wildcards to format name, expense class name and transaction ledger name and changed the Where statements to "ilike"
<br>--8-30-23: reviewed by Jean Pajerek
<br>--9-11-23: changed instance_subject_extract subquery to point to folio_reporting.instance_subjects; removed pol_holdings_id subquery (not needed)
<br>--9-12-23: created a Case When statement to assign the correct finance group name to those 2CUL funds that merged into Area Studies in FY2024
<br>--9-13-23: reviewed by Jean Pajerek, Vandana Shah, Ann Crowley, and Sharon Beltaine
<br>--9-14-23: corrected the WHERE expression for finance_expense_class to work with wildcard and Null entries (line 246). Ditto other Where statements for parameters with wildcards or null entries.
<br>--Added fund name to ftie subquery and to main query.
<br>--12-19-23: Added fund 2352 to the CASE WHEN statements that select the correct finance group for funds that were merged into Area Studies from 2CUL in FY2024 based on invoice payment date.
<br>--06-06-24 Added invoice_line_number to SELECT to distinguish invoice line payments that would otherwise be combined by DISTINCT as identical, which was reducing expenditure totals compared to the total expenditures shown in the ledger.
<br>-- 6-14-24: in locations subquery, added "distinct" 
<br>-- 7-25-24: updated fund code sort for Course Reserve funds, which were changed to "Interdisciplinary" starting with FY2025
<br>
-In cases where the quantity was incorrectly entered as zero, this query replaces zero with 1.
--11-5-24: updated "json" to "jsonb"; cast UUID's where needed

  

