# MCR134

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
<br>--12-19-23: Added fund 2352 to the CASE WHEN statements that SELECT the correct finance group for funds that were merged into Area Studies from 2CUL in FY2024 based on invoice payment date.
<br>--03-04-24: Changed json extract for all locations to get them from folio_derived.po_lines_locations since it will ran before other tables that use json extract
<br>-- 6-14-24: in locations subquery, added "distinct" and changed to an inner join to po_line__t table
<br>	-- corrected fund code list in Case When statement to include fund 2352
<br>	-- commented out all the filters in the Where clause at the end
<br>	-- updated subjects subquery to use the corrected code for the instance_subjects derived table
<br>	-- updated the instance_languages Where clause condition to (lang.language_ordinality = 1 OR lang.instance_hrid ISNULL)
<br>	-- added "Approved" to the invoice status criteria
<br>-- 6-17-24: added invoice status (inv.status AS invoice_status) to SELECT clause in order to make it display in the query results
<br>	-- removed the "or-is-blank" component from all the WHERE clause statements
<br>-- 7-17-24: updated fund sort for Course Reserves (7311, 7342, 7370, p7358) - changed to Interdisciplinary finance group for FY2025
<br>-- 7-25-24: added the original filter statements back in, and corrected the CASE WHEN sort for funds
<br>-- 1-24-25: replaced derived tables with primary tables by adding the derivations for each as subqueries (finance_transaction_invoices, instance_languages, po_lines_locations)




