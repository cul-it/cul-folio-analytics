CR219B
<br>
Shelf List Inventory Brief version
<br>
This query finds shelf list inventory information by library location. 
The most_recent_patron_group field determines what patron group an item 
was assigned to most recently, which is important for assignments to the 
Borrow Direct and Interlibrary Loan patron groups, which change frequently. 

<br>
There are 2 versions of this query: CR219A and CR219B.The CR219A version of the query provides a more 
expanded set of relevant data fields, which can be useful for troubleshooting or as a base for similar query development.
The CR219 version provides the limited list of fields that are needed to perform a manual shelf list inventory 
in the library for ease of use by the person doing the inventory analysis.
<br>

<br>-- 8-3-24: updated query to put the contributors and most recent patron group subqueries at the end (so they use the previously found <br>records in "recs" to get the data, which greatly speeds up the query)
	<br>-- fixed the Where statements that refers to parameters (parentheses got screwed up); added wildcards to the Library name filter
	<br>-- added item_status_date
	<br>-- shortened the "size" sort and "in process" exclusions to use just the holdings call number components
	<br>-- added the item notes (aggregated) to the "recs" query
	<br>-- added the permanent, temporary and effective locations for the holdings and item call numbers to help explain the strange <br>results appearing on the list
	<br>-- added a statement at the end to fix the carriage returns in call numbers (separate field, "fixed call number")
<br>-- 8-9-24: added a "contributor ordinality" to the Select statement (line 162) and commented out the contributor ordinality condition <br>from that subquery 
	<br>-- added a final subquery that selects the contributor ordinality = 1 or contributor ordinality is null

 
	<br>-- changed the location_name_filter (line 69) to look at itemext.effective_location_name (not he.permanent_location_name)
	<br>-- updated the excluded formats (line 73) to include Archivman, Carrel Keys and Computfile

 
