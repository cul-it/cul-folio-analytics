--- selects records that were cataloged in OCLC and created in Folio 
--- holdings notes were moved to administrative notes on instances since LDP report was written
WITH source_pcc AS (
   SELECT DISTINCT 
    sm1.instance_hrid,
    sm1.instance_id,
    sm1.field AS "042",
    sm1."content" AS "042_cnt",
    sm2.instance_hrid AS coo_instance_hrid,
    sm2.instance_id AS coo_instance_id,
    sm2.field AS "040",
    sm2.sf,
    sm2."content" AS "040_cnt"
   FROM folio_source_record.marc__t sm1
   LEFT JOIN folio_source_record.marc__t sm2 ON sm1.instance_id = sm2.instance_id
   WHERE (sm1.field = '042' AND sm1.sf = 'a' AND sm1."content" = 'pcc')
   AND ((sm2.field = '040' AND sm2.sf = 'a' AND sm2."content" = 'COO')
   OR (sm2.field = '040' AND sm2.sf = 'd' AND sm2."content" = 'COO'))
)
   SELECT 
    scc.coo_instance_hrid,
    scc."042",
    scc."042_cnt",
    scc."040",
    scc.sf,
    scc."040_cnt",
    hn.administrative_note,
    hn.administrative_note_ordinality,
    jsonb_extract_path_text(users.jsonb, 'personal', 'lastName') AS last_name,
    jsonb_extract_path_text(users.jsonb, 'personal', 'firstName') AS first_name
   FROM source_pcc scc
   LEFT JOIN folio_derived.instance_ext ie ON scc.coo_instance_id = ie.instance_id
   LEFT JOIN folio_inventory.instance ii ON ie.instance_id = ii.id 
   LEFT JOIN folio_users.users ON ii.created_by::uuid = users.id 
   LEFT JOIN folio_derived.instance_administrative_notes hn ON ii.id = hn.instance_id 
   WHERE ie.record_created_date::date >= '2021-07-01' -- IF you need TO use RANGE of dates use 'BETWEEN'
   AND hn.administrative_note LIKE '%ttype:o%'
   -- '%ttype:b% or m or c or i or r or f'
   -- or you can do it by user "LIKE '%netid%'" etc
;
