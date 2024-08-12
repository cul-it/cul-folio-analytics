CR219
<br>
Shelf List Inventory
<br>
This query finds shelf list inventory information by library location. 
The most_recent_patron_group field determines what patron group an item 
was assigned to most recently, which is important for assignments to the 
Borrow Direct and Interlibrary Loan patron groups, which change frequently.

-- 8-3-24: updated query to put the contributors and most recent patron group subqueries at the end (so they use the previously found records in "recs" to get the data, which greatly speeds up the query)
	-- fixed the Where statements that refers to parameters (parentheses got screwed up); added wildcards to the Library name filter
	-- added item_status_date
	-- shortened the "size" sort and "in process" exclusions to use just the holdings call number components
	-- added the item notes (aggregated) to the "recs" query
	-- added the permanent, temporary and effective locations for the holdings and item call numbers to help explain the strange results appearing on the list
	-- added a statement at the end to fix the carriage returns in call numbers (separate field, "fixed call number")
-- 8-9-24: added a "contributor ordinality" to the Select statement (line 162) and commented out the contributor ordinality condition from that subquery 
	-- added a final subquery that selects the contributor ordinality = 1 or contributor ordinality is null
	-- changed the location_name_filter (line 69) to look at itemext.effective_location_name (not he.permanent_location_name)
	-- updated the excluded formats (line 73) to include Archivman, Carrel Keys and Computfile
 
