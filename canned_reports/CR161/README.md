# ACRL’s Academic Library Trends and Statistical Survey and NCES’s Academic Libraries Survey

## Purpose:
* Run annually, the ACRL Academic Library Trends and Statistics Survey requests the following counts that can often be provided through library management systems like FOLIO:
  * Total library materials expenditures, with these breakouts:
    * One-time purchases of books, serial back-files, and other materials
      * E-books (not sure we can get this; haven’t been providing; not requested by NCES)
    * Ongoing commitments to subscriptions
      * E-books (not sure we can get this; haven’t been providing; not requested by NCES)
      * E-journals (not sure we can get this; haven’t been providing; not requested by NCES)
    * All other materials/services costs
      * Binding
      * New materials shipping
  * Seven different title counts:
    * Physical book titles
    * Digital/electronic book titles
    * Digital/electronic database titles
    * Physical media titles
    * Digital/electronic media titles
    * Physical serial titles
    * Digital/electronic serial titles
  * Volumes held (not requested by NCES)
  * Initial circulations (including reserves; excluding equipment)
* By design the NCES Academic Libraries (National Center for Education Statistics) requests only a subset of data collected by ACRL, so once you’ve finished the ACRL survey, you have all of the data you need for the NCES survey. 
* This Readme takes you through those measures and indicates which reports you can use to get each at CUL.
* You can see CUL’s latest full submissions for the ACRL and NCES surveys, along with the survey instructions on Confluence at https://confluence.cornell.edu/x/G8n-Fg .

## Work still to be done:
* Expenditures: need to review queries for CUL’s ACRL needs, see which counts are get-able, and write documentation.
* Title counts: 
  * Need to add to queries removing PDA/DDA unpurchased counts from physical and electronic.
  * Need to decide how will get database title count.
  * Can we eventually get a non-duplicative HathiTrust count from FOLIO?
* Circulation: need to write documentation.

## Which queries to use for the different measures:

### Materials expenditures:
* Documentation coming soon.

### Title counts:
* Run multiple sets of queries to get the ACRL title counts, and in some cases, add counts from outside of FOLIO (gotten by Assessment & Planning (A&P)). The following spells out which reports A&P is currently using for which measures.  
* It is not as complicated as it looks, because the three main title queries supply counts by bib format; you don’t have to run separate queries for different bib formats. For ACRL/NCES counts, serials of all formats are included under serials. Except for serials, microforms are counted as physical media. The national counts indicate that titles should not be deduplicated between formats. 
* Physical book titles:
  * Use book and music title counts from Title_count_non-micr-physical_adc_stats (which excludes serv,remo and microform titles). [Here I am assuming we can remove any unpurchased pda/dda items in the queries; not yet done.]
* Digital/electronic book titles:
  * Use e-book and e-music title counts from Title_count_servremo_adc_stats.  [Here I am assuming we can remove any unpurchased pda/dda items in the queries; not yet done.] You will also need to add a count of HathiTrust book titles; at this time, that is a set number not gotten through FOLIO (contact A&P).
* Digital/electronic database titles
  * [Not sure yet how we are going to do this. We have a work-around if needed.]
* Physical media titles:
  * Use 3-dimensional object, map, recording (music and nonmusic), and visual material title counts from Title_count_non-micro-physical_adc_stats. Add all microform titles except those that are serials, using Title_count_micro_adc_stats.
* Digital/electronic media titles
  * Get counts for e-media titles (3-dimensional object, map, recording (music and nonmusic), and visual material) using Title_count_servremo_adc_stats.  [Here I am assuming we can remove any unpurchased pda/dda items in the queries.] Add the count of images Ithaca cataloged in Artstor (Assessment & Planning pulls this count from Artstor).
* Physical serial titles
  * Get all serial counts (in all formats) from Title_count_non-micr-physical_adc_stats. Add in serial microforms titles using Micro_on_print_adc_stats.
* Digital/electronic serial titles
  * Use all serial counts (in all formats) from Title_count_servremo_adc_stats.  

### Volumes held:
* Use the following query to get the count of volumes held:  Volume_count_adc_stats (use the grand total).

### Initial circulations (including reserves; excluding equipment):
* Documentation coming soon.

## Filters:
See individual queries.

## Output:
See individual queries.
