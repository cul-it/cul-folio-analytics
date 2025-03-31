DROP TABLE IF EXISTS local_derived.slm5_test_instance_count;

CREATE TABLE local_derived.slm5_test_instance_count AS

SELECT 
	COUNT (id) AS instances_total
	FROM folio_inventory.instance__t
;
