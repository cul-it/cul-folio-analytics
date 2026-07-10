**MSQ105**  
**Last updated:** 4/17/26  
**Author:** Joanne Leary  

This query fixes the `marc__t` table so it contains only the most recent `srs_id`. It is running as an automated query at 3am every morning. It publishes a new marc__t table in the local_derived schema every morning.
