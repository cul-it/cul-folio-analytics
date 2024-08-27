# CR242
# cjkt_subject_by_fiscal_year 
<p>
last updated: 5/15/24
<br>
query written and tested by Joanne Leary and Sharon Markus
<br>
  
## Brief description:
This query finds all item or holdings records with Chinese, Japanese, Korean AND Tibetan 
<br> subject headings that were added to the collection in the fiscal year specified.
<br> Query excludes those works in languages chi,jpn,kor,tib.
<br> All libraries AND locations are included. Counts are sorted by month added.
<br> The instance format is extracted FROM the leader, 
<br> and the form of the work (print, e-resource or microform) is determined by the holdings location and call number.
<br> The query excludes suppressed instance and holdings records.
<p>
  
## Updates:
<br> 4-19-24: Added a clause to exclude purchase_on_demand ebooks (EBA books: Evidence based acquisitions) 
<br> that aren't yet in the collection.
<br> 4-20-24: Changed sorting statement for form of work to include 007 and title determinants for microforms
<br> and updated CASE WHEN statements for fiscal year created in item_create and holdings_create subqueries.
<br> To get cumulative language items that include Voyager data going back to FY2000, use FY 2000 in the 
<br> fiscal year filter and change the COALESCE statment for fiscal year in the 
<br> WHERE clause on line 156 to  '>=' instead of '='
<br> The results of this query are combined with the results of CR241 cjkt_language_by_fiscal_year to provide
<br> the CEAL Stats and the All Items reports needed by Asia Studies. 
<br> The language field is changed to "non-CJKT" in the final reports to 
<br> show items within a given fiscal year (for CEAL) or acquired from a given fiscal year forward 
<br>(for All Items) that have CJKT subjects, 
<br> but are not in CJKT languages.

