--shelf list inventory
--This query finds shelf list inventory information by library location. 
--The most_recent_patron_group field determines what patron group an item 
--was assigned to most recently, which is important for assignments to the 
--Borrow Direct and Inter Library Loan patron groups, which change frequently

--written by Sharon Beltaine
--reviewed by 

WITH parameters AS (
    SELECT 
         -- Fill out -owning library filter ----
         'Olin Library'::varchar AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc.
         --add permanent location name
),
        
max_loan_status AS
		(SELECT li.item_id,
		       MAX (li.loan_date::TIMESTAMP) AS max_loan_date

		FROM folio_reporting.loans_items AS li 
		
		GROUP BY
		li.item_id
),

recent_patron_group AS 
 		(SELECT 
 		li.item_id,
 		max_loan_status.max_loan_date,
 		li.patron_group_name
 		
 		FROM max_loan_status
 		INNER JOIN folio_reporting.loans_items AS li ON max_loan_status.item_id = li.item_id 
 		AND max_loan_status.max_loan_date = li.loan_date
 )	
 		
SELECT
--show size as +++, ++, or + with call number, copy number, enumeration, and chronology
        CASE WHEN TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',
             itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
             itemext.chronology,' ',CASE WHEN itemext.copy_number > '1' 
             THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)) 
             LIKE '%+++%' THEN '+++'
             
             WHEN TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',
             itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
             itemext.chronology,' ',CASE WHEN itemext.copy_number > '1' 
             THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)) 
             LIKE '%++%' THEN '++'
             
             WHEN TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',
             itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
             itemext.chronology,' ',CASE WHEN itemext.copy_number > '1' 
             THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)) 
             LIKE '%+%' THEN '+'        
             ELSE ' 'END AS "size",
         
        TRIM (CONCAT (itemext.effective_call_number_prefix,' ',itemext.effective_call_number,' ',
             itemext.effective_call_number_suffix,' ',itemext.enumeration,' ',
             itemext.chronology,' ',CASE WHEN itemext.copy_number > '1' 
             THEN CONCAT ('c.',itemext.copy_number) ELSE '' END)) AS whole_call_number,
                     
        itemext.barcode,
        instext.title,
        itemext.status_name AS item_status,
        itemext.material_type_name AS format,
		ic.contributor_name AS primary_author,
		rpg.patron_group_name AS most_recent_patron_group	
             
FROM folio_reporting.instance_ext AS instext
     LEFT JOIN folio_reporting.holdings_ext AS he ON instext.instance_id = he.instance_id        
     LEFT JOIN folio_reporting.locations_libraries AS ll ON he.permanent_location_id = ll.location_id       
     LEFT JOIN folio_reporting.item_ext AS itemext ON he.holdings_id = itemext.holdings_record_id
     LEFT JOIN inventory_items AS ii ON itemext.item_id = ii.id
     LEFT JOIN folio_reporting.item_notes AS itemnotes ON itemext.item_id = itemnotes.item_id
     LEFT JOIN folio_reporting.instance_contributors AS ic ON instext.instance_id = ic.instance_id
     LEFT JOIN recent_patron_group AS rpg ON rpg.item_id = itemext.item_id
               
WHERE  (ll.library_name = (SELECT owning_library_name_filter FROM parameters)
        OR (SELECT owning_library_name_filter FROM parameters) = '')
    AND (he.discovery_suppress = 'FALSE' OR he.discovery_suppress IS NULL)
    AND (ic.contributor_primary = 'TRUE' OR ic.contributor_primary IS NULL)
    AND (ic.contributor_rdatype_name = 'Author' OR ic.contributor_rdatype_name IS NULL)
    --AND itemext.material_type_name = 'Book'
    --AND instext.mode_of_issuance_name = 'single unit'
    AND itemext.material_type_name NOT ILIKE 'Map' 
    AND itemext.material_type_name NOT ILIKE 'Microform'
    AND itemext.material_type_name NOT ILIKE 'Microfiche'
    AND itemext.material_type_name NOT ILIKE 'Newspaper'
    AND itemext.material_type_name NOT ILIKE 'Object'
    AND itemext.material_type_name NOT ILIKE 'Soundrec'
    AND itemext.material_type_name NOT ILIKE 'Visual'

 --removes items that are being processed in some way
    AND he.call_number NOT ILIKE '%In%ro%'
    AND he.call_number NOT ILIKE '%Order%'
    AND he.call_number NOT ILIKE '%Cancelled%' 

--Call Number Filter
    --AND itemext.effective_call_number LIKE 'PS%'
    AND itemext.effective_call_number BETWEEN 'PQ%' AND 'PZ%'
--using regular expression for LC call number range
    --AND SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') LIKE 'PS%'
    --AND SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') >= 'PQ%' 
    --AND SUBSTRING (he.call_number,'^([a-zA-z]{1,3})') <= 'PZ%' 
        
ORDER BY 
"size",
ii.effective_shelving_order COLLATE "C", 
itemext.enumeration,
itemext.chronology,
itemext.copy_number,
itemext.status_name,
instext.title,
itemext.effective_call_number_suffix
;
