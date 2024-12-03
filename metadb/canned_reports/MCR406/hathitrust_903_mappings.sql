--MCR244
--hathitrust_903_mappings
--last updated: 12/3/24
--written by Michelle Paolillo, revised to Metadb by Sharon Markus
--This query creates a table of mapping for instances with 903 values and publishes it to the local_digpres schema.
--The table of mapping for instances with 903 values includes instance id, instance hrid, holdings id, barcode and state


DROP TABLE IF EXISTS local_hathitrust.test_z_metadbuser_cornell_ALL_903s;
CREATE TABLE local_hathitrust.test_z_metadbuser_cornell_ALL_903s AS
SELECT
    cast(folio_source_record.marc__t.instance_id as varchar), -- Changed from public.srs_marctab
    folio_source_record.marc__t.instance_hrid, -- Changed from public.srs_marctab
    folio_source_record.marc__t.field, -- Changed from public.srs_marctab
    folio_source_record.records_lb.state, -- Changed from public.srs_records
    folio_source_record.marc__t.ord, -- Changed from public.srs_marctab
    folio_source_record.marc__t.ind1, -- Changed from public.srs_marctab
    folio_source_record.marc__t.ind2, -- Changed from public.srs_marctab
    -- the function below composes the 903 as a single varchar string with all subfields
    string_agg(
        '$':: VARCHAR || folio_source_record.marc__t.sf || ' ' || folio_source_record.marc__t.content, -- Changed from public.srs_marctab
        ' '
        ORDER BY
            folio_source_record.marc__t.sf -- Changed from public.srs_marctab
        ) AS sf_content
FROM
    folio_source_record.marc__t -- Changed from public.srs_marctab
LEFT JOIN folio_source_record.records_lb on cast (folio_source_record.marc__t.srs_id as UUID)--Changed to srs_id as UUID
    = folio_source_record.records_lb.id -- Changed from public.srs_records
WHERE
    folio_source_record.marc__t.field = '903' AND -- Changed from public.srs_marctab
      folio_source_record.records_lb.state = 'ACTUAL' -- Changed from public.srs_records
GROUP BY
    folio_source_record.marc__t.instance_id, -- Changed from public.srs_marctab
    folio_source_record.marc__t.instance_hrid, -- Changed from public.srs_marctab
    folio_source_record.marc__t.field, -- Changed from public.srs_marctab
    folio_source_record.marc__t.ord, -- Changed from public.srs_marctab
    folio_source_record.marc__t.ind1, -- Changed from public.srs_marctab
    folio_source_record.marc__t.ind2, -- Changed from public.srs_marctab
    folio_source_record.records_lb.state -- Changed from public.srs_records
ORDER BY
    folio_source_record.marc__t.instance_hrid::INTEGER ASC; -- Changed from public.srs_marctab
--
-- Index table fields
--
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (instance_id);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (instance_hrid);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (field);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (state);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (ord);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (ind1);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (ind2);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s (sf_content);
 
-- Create table based on local_hathitrust.test_z_metadbuser_cornell_ALL_903s where the subfields of sf_content are parsed out to individual fields.
--
DROP TABLE IF EXISTS local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed;
CREATE TABLE local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed AS
SELECT
    instance_id,
    instance_hrid,
    field,
    state,
    ord,
    ind1,
    ind2,
    sf_content,
    -- parse out the preservation repo in which the item resides ($a)
    CASE 
        WHEN (position('$b' in sf_content) - 5) > (position('$a' in sf_content) + 3) THEN
            substring(sf_content, (position('$a' in sf_content) + 3), (position('$b' in sf_content) - 5 - (position('$a' in sf_content) + 3)))
        ELSE NULL
    END AS repo,
    -- parse out the barcode of the item digitized ($b)
    substring(sf_content, (position('$b' in sf_content) + 3), 14) AS barcode,
    -- parse out the added Identifier if any ($h)
    CASE
        WHEN position('$h' in sf_content) > 0 AND position('$n' in sf_content) > position('$h' in sf_content) THEN
            substring(sf_content, (position('$h' in sf_content) + 3), (position('$n' in sf_content) - (position('$h' in sf_content) + 3)))
        ELSE NULL
    END AS foreign_id,
    -- parse out persistent ID in the preservation repository ($n)
    CASE
        WHEN position('$v' in sf_content) > 0 THEN
            substring(sf_content, (position('$n' in sf_content) + 3), (position('$v' in sf_content) - (position('$n' in sf_content) + 3)))
        ELSE
            substring(sf_content, (position('$n' in sf_content) + 3))
    END AS pres_id,
    -- parse out volume conditionally if it exists ($v)
    CASE
        WHEN position('$v' in sf_content) > 0 THEN
            substring(sf_content, (position('$v' in sf_content) + 2))
        ELSE NULL
    END AS volume
FROM local_hathitrust.test_z_metadbuser_cornell_all_903s
;

--
-- Index table fields
--
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (instance_id);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (instance_hrid);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (field);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (state);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (ord);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (ind1);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (ind2);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (sf_content);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (repo);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (barcode);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (foreign_id);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (pres_id);
CREATE INDEX ON local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed (volume);
 
--Use the table local_hathitrust.test_z_metadbuser_cornell_all_903s_parsed as a foundation, and add HTIDs in a new table local_hathitrust.local_digpres.test_metadb_903_with_htid
drop table if exists local_hathitrust.test_metadb_903_with_htid;
create table local_hathitrust.test_metadb_903_with_htid as
select
    instance_id,
    instance_hrid,
    field,
    state,
    ord,
    ind1,
    ind2,
    sf_content,
    repo,
    barcode,
    foreign_id,
    pres_id,
    volume,
    case
        when ind1 like '1' then concat('coo.', pres_id)
        when ind1 like '2' then concat('coo1.', pres_id)
        else concat('coo.', pres_id)
    end as htid
from local_hathitrust.test_z_metadbuser_cornell_all_903s_parsed;
--build indexes
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (instance_id);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (instance_hrid);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (field);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (state);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (ord);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (ind1);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (ind2);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (sf_content);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (repo);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (barcode);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (foreign_id);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (pres_id);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (volume);
CREATE INDEX ON local_hathitrust.test_metadb_903_with_htid (htid);

--Make a new table that has white spaces in identifiers trimmed out - place that table in local_digpres

DROP TABLE IF EXISTS local_digpres.test_metadb_903_with_htid;
CREATE TABLE local_digpres.test_metadb_903_with_htid as
select
    instance_id,
    instance_hrid,
    field,
    state,
    ord,
    ind1,
    ind2,
    sf_content,
    repo,
    barcode,
    trim(foreign_id) as foreign_id,
    trim(pres_id)as pres_id,
    trim(volume) as volume,
	trim(htid) as htid
from local_hathitrust.test_metadb_903_with_htid
;
--build indexes
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (instance_id);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (instance_hrid);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (field);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (state);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (ord);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (ind1);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (ind2);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (sf_content);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (repo);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (barcode);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (foreign_id);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (pres_id);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (volume);
CREATE INDEX ON local_digpres.test_metadb_903_with_htid (htid);

--tidy up - delete intermediate tables in local_hathitrust
 DROP TABLE IF EXISTS local_hathitrust.test_z_metadbuser_cornell_ALL_903s;
 DROP TABLE IF EXISTS local_hathitrust.test_z_metadbuser_cornell_ALL_903s_parsed;
 DROP TABLE IF EXISTS local_hathitrust.test_metadb_903_with_htid;

--assign permissions
  GRANT SELECT, INSERT, UPDATE, DELETE ON local_digpres.test_metadb_903_with_htid TO z_mb327;
  GRANT SELECT, INSERT, UPDATE, DELETE ON local_digpres.test_metadb_903_with_htid TO z_map6;
  GRANT SELECT, INSERT, UPDATE, DELETE ON local_digpres.test_metadb_903_with_htid TO z_fbw4;

