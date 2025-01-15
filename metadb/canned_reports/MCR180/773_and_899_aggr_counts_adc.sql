--MCR180
--773_and_899_aggr_counts_adc

/*For the annual data collection, this query get counts of e-aggregators and other e-collections coded in 
773 and 899 fields, to help track large changes in e-counts from year to year if needed. It merges the 
773 and 899 counts, and sorts the counts in descending order. Excludes PDA/DDA titles unpurchased.
Both 773 and 899 are repeatable, but the subfields used here appear not to be? There is overlap between 
some packages, so these are not intended for counts, but to try to help identify large changes with LTS 
assistance. */

WITH formattype AS 
       (SELECT DISTINCT 
             marc__t.instance_id, 
             substring(marc__t."content", 7, 2) AS "format_type"
       FROM folio_source_record.marc__t
       WHERE marc__t.field = '000'
),
                
unpurch AS
       (SELECT DISTINCT 
             marc__t.instance_id, 
             --marc__t."content"  AS unpurchased
             string_agg(DISTINCT marc__t."content", ', ') AS unpurchased --added this INSTEAD OF above  
       FROM folio_source_record.marc__t  
       WHERE marc__t.field = '899'
       AND marc__t.sf = 'a' 
       GROUP BY marc__t.instance_id --added this
),
  
  
host773 AS 
              (SELECT DISTINCT 
              marc__t."content",
              marc__t.field,
              fmtype."format_type",
    count(marc__t.instance_hrid) AS count
    FROM folio_source_record.marc__t 
    LEFT JOIN folio_derived.instance_ext ON marc__t.instance_id = instance_ext.instance_id
    LEFT JOIN folio_derived.holdings_ext ON instance_ext.instance_id = holdings_ext.instance_id
    LEFT JOIN formattype AS fmtype ON marc__t.instance_id = fmtype.instance_id::uuid
    LEFT JOIN unpurch ON marc__t.instance_id = unpurch.instance_id::uuid
    WHERE marc__t.field = '773'
               AND marc__t.sf = 't'
    AND (instance_ext.discovery_suppress = 'false' OR instance_ext.discovery_suppress IS NULL)
    AND (unpurch.unpurchased NOT ILIKE ALL (ARRAY['%DDA_pqecebks%', '%PDA_casaliniebkmu%']) OR unpurch.unpurchased IS NULL  OR unpurch.unpurchased = '' OR unpurch.unpurchased = ' ')
               AND holdings_ext.permanent_location_name = 'serv,remo'
    GROUP BY marc__t."content", marc__t.field, fmtype."format_type"
),

host899 AS
              (SELECT DISTINCT 
              marc__t."content",
              marc__t.field,
              fmtype."format_type",
    count(marc__t.instance_hrid) AS count
    FROM folio_source_record.marc__t 
    LEFT JOIN folio_derived.instance_ext ON marc__t.instance_id = instance_ext.instance_id
    LEFT JOIN folio_derived.holdings_ext ON instance_ext.instance_id = holdings_ext.instance_id
    LEFT JOIN formattype AS fmtype ON marc__t.instance_id = fmtype.instance_id::uuid
   -- LEFT JOIN micros ON marc__t.instance_id = micros.instance_id::uuid
    LEFT JOIN unpurch ON marc__t.instance_id = unpurch.instance_id::uuid
    WHERE marc__t.field = '899'
               AND marc__t.sf = 'a'
    AND (instance_ext.discovery_suppress = 'false' OR instance_ext.discovery_suppress IS NULL)
    AND (unpurch.unpurchased NOT ILIKE ALL (ARRAY['%DDA_pqecebks%', '%PDA_casaliniebkmu%']) OR unpurch.unpurchased IS NULL  OR unpurch.unpurchased = '' OR unpurch.unpurchased = ' ')
               AND holdings_ext.permanent_location_name = 'serv,remo'
    GROUP BY marc__t."content", marc__t.field, fmtype."format_type"
),

mergeit AS
(SELECT
host773."content",
host773.field,
host773."format_type",
host773.count
FROM host773
--WHERE host773.count > 4999
UNION SELECT
host899."content",
host899.field,
host899."format_type",
host899.count
FROM host899
--WHERE host899.count > 4999
)

SELECT 
mergeit."content",
mergeit.field,
mergeit."format_type",
mergeit.count
FROM mergeit
ORDER BY mergeit.count DESC
;
