MCR217B
HathiTrust_title_counts_to_add_to_ADC_e-counts

Brief description: This query is used by A&P staff to get counts of titles CUL sent to Google to be digitized in one of the 
Google Books Projects, that are now fully accessible to all Cornell users. There aren't e-records for these titles in FOLIO, 
but there is coding on the instance records that triggers a mechanism in the public catalog that lets users know that the 
e-version is available to them through HathiTrust.
The query is run through DBeaver Enterprise on a HathiTrust database; A&P’s access was set up by CUL IT and ITIS.

The bib format translations per 
https://www.hathitrust.org/member-libraries/resources-for-librarians/data-resources/hathifiles/hathifiles-description/ are: 
BK - monographic book; SE - serial, continuing resources (e.g., journals, newspapers, periodicals); 
CF - computer files and electronic resources; MP - maps, including atlases and sheet maps; 
MU - music, including sheet music (counted with e-scores); VM - visual material ; and MX - mixed materials.

If item counts are needed for any reason, one can replace this query’s count distinct line with 
the following: “count(distinct volume_identifier) as item_count” .
