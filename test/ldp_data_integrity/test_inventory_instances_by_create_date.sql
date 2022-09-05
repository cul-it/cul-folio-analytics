--This query counts inventory instances by create date

WITH parameters AS (
    SELECT
	/* Choose a start and end date */
	'2021-08-10'::DATE AS start_date,
	'2022-08-31'::DATE AS end_date
  ), 
  
data1 as
(SELECT
	ii.id,
	json_extract_path_text (ii.data,'metadata','createdDate')::date as create_date
from inventory_instances as ii
)

SELECT
	data1.create_date,
	count (data1.id)
from data1

WHERE
	data1.create_date >= (SELECT start_date FROM parameters)
    AND data1.create_date < (SELECT end_date FROM parameters)
    
GROUP BY data1.create_date::date
ORDER BY data1.create_date::date
;
