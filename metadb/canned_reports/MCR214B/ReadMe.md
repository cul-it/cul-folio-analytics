MCR214B 
Physical_Item_Counts_incl_items_rec_but_not_yet_cataloged
Created by A&P in FY25 for counts for CU DFS (Division of Financial Services)

Description: With FY25, A&P uses this query each quarter to get volumes added counts for Cornell's Division of Financial 
Services (DFS). This query modifies MCR214, which provides item counts of physical materials by format type. MCR214
only includes counts of items cataloged and made ready for patrons' use. MCR214B additionally includes counts
for items received but not yet cataloged (whose call numbers include "%n process%"). Both queries 
exclude microforms.
Since not all physical items are cataloged in the same year their item records are created, and MCR214 bases 
its items added counts on item record creation dates, some additions are never included in the MCR214 addition 
counts (although all items are included in the held counts once cataloged). MCR214B therefore better meets DFS's needs. 

DFS does not need volumes added retrospectively counted separately; it's counts only need to be divided by 
contract vs. endowed. Filter on "folio_format_type_adc_groups" to include only: Book, Serial, and Serial-Music.
