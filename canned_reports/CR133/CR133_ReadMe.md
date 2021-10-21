For a list of all the options you may use with the filters at the top of this query, see the Filter Directory

CR133

Shelf List Duplicate Flagging

This query finds all holdings in a specific location, and shows other locations that have holdings for the same titles. First, the subquery finds the Instance IDs for all titles in the main location.
These instance ids are then used in the main query to find other locations' holdings. The list is in order by call number, then by instance_id (so same titles group together).
The item record count for each holdings record is also included, which allows the user to order by number of volumes in descending order if they want.
