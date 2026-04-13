CREATE OR REPLACE FUNCTION local_automation.LTS_holdings_admin_notes(
    start_date DATE DEFAULT '2021-07-01',
    end_date   DATE DEFAULT '2050-01-01'
)
RETURNS TABLE (
    holdings_hrid TEXT,
    instance_id UUID,
    administrative_note_clean TEXT,
    maint_date DATE,
    perm_loc_name TEXT,
    cat_stat TEXT
)
AS $$
WITH get_candidates AS (
    SELECT 
        h.instanceid AS instance_id,
        h.id AS holdings_id,
        jsonb_extract_path_text(h.jsonb, 'hrid') AS holdings_hrid,
        admin_notes.jsonb #>> '{}' AS administrative_note,
        admin_notes.ordinality AS administrative_note_ordinality
    FROM folio_inventory.holdings_record h
    CROSS JOIN LATERAL
        jsonb_array_elements(
            jsonb_extract_path(h.jsonb, 'administrativeNotes')
        ) WITH ORDINALITY AS admin_notes(jsonb)
    WHERE admin_notes.jsonb #>> '{}' ILIKE '%ttype:w%'
       OR admin_notes.jsonb #>> '{}' ILIKE '%ttype:t%'
),
all_notes AS (
    SELECT 
        t1.instance_id,
        t1.holdings_id,
        t1.holdings_hrid,
        t1.administrative_note_ordinality,
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(
                                REGEXP_REPLACE(
                                    REGEXP_REPLACE(
                                        REGEXP_REPLACE(
                                            t1.administrative_note,
                                            '([^ ])ploc', '\1 ploc'
                                        ),
                                        'c ttype', ' ttype'
                                    ),
                                    'user:', 'userid:'
                                ),
                                'date:c', 'date:'
                            ),
                            ': ', ':', 'g'
                        ),
                        '&nbsp; ', ' ', 'g'
                    ),
                    '\r|\n|-', '', 'g'
                ),
                '.*(date:\d{8} ttype:[a-z]{1,5} userid:[a-z0-9]{1,7} ploc:[a-z0-9]{1,7}).*',
                '\1'
            )
        ) AS administrative_note_clean
    FROM get_candidates t1
    LEFT JOIN local_derived.marc__t mt
        ON t1.instance_id = mt.instance_id
    WHERE t1.administrative_note ILIKE 'date:%'
      AND mt.field = '008'
    GROUP BY
        t1.instance_id,
        t1.holdings_id,
        t1.holdings_hrid,
        t1.administrative_note_ordinality,
        t1.administrative_note
),
date_notes AS (
    SELECT
        an.instance_id,
        an.holdings_hrid,
        an.administrative_note_clean,
        TO_DATE(
            substring(an.administrative_note_clean, 6, 8),
            'YYYYMMDD'
        ) AS maint_date
    FROM all_notes an
    WHERE an.administrative_note_clean ILIKE 'date:%'
),
notes_loc AS (
    SELECT
        dn.holdings_hrid,
        dn.instance_id,
        dn.administrative_note_clean,
        dn.maint_date,
        he.permanent_location_name AS perm_loc_name
    FROM date_notes dn
    LEFT JOIN folio_derived.holdings_ext he
        ON he.instance_id::uuid = dn.instance_id::uuid
    WHERE dn.maint_date BETWEEN start_date AND end_date
      AND he.permanent_location_name NOT ILIKE '%rmc%'
      AND he.permanent_location_name NOT ILIKE '%rare%'
      AND he.permanent_location_name NOT ILIKE '%law%'
)
SELECT DISTINCT
    nl.holdings_hrid,
    nl.instance_id,
    nl.administrative_note_clean,
    nl.maint_date,
    nl.perm_loc_name,
    CASE 
        WHEN nl.administrative_note_clean ILIKE '%ttype:t%' THEN 'transferred'
        WHEN nl.administrative_note_clean ILIKE '%ttype:w%' THEN 'withdrawal'
    END AS cat_stat
FROM notes_loc nl;
$$
LANGUAGE SQL
STABLE
PARALLEL SAFE;
