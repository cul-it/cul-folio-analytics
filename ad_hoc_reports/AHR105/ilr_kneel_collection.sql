WITH get_rec AS (
SELECT
   DISTINCT (sm.instance_hrid),
   he.holdings_hrid,
   he.instance_id,
   he.permanent_location_name,
   sm.field,
   sm.content,
   substring(sm.content, 7, 2) AS type_lvl
FROM srs_marctab sm
LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
WHERE (sm.field = '000' AND substring(sm.content, 7, 2) IN ('pc','pm','tc','tm'))
      AND he.permanent_location_name IN ('ILR Kheel Center')
),
collection_id AS (
SELECT
    DISTINCT(sm.CONTENT) AS collection_id,
    sm.instance_id
FROM srs_marctab sm
WHERE (sm.field = '099' )
),
target AS (
SELECT
    sm.instance_id,
    sm.field AS m_field,
    string_agg((concat('$', sm.sf, ' ', sm.content)), '|' order by sm.sf)AS m_value
    FROM srs_marctab sm
LEFT JOIN folio_reporting.holdings_ext he ON sm.instance_id = he.instance_id
WHERE (sm.field like '6%' )
   AND he.permanent_location_name IN ('ILR Kheel Center')
GROUP BY sm.instance_id, sm.field
)
SELECT
  DISTINCT(ie.instance_hrid),
  g.holdings_hrid,
  g.permanent_location_name,
  ie.title,
  c.collection_id,
    CASE WHEN s.m_field = '600' THEN s.m_value END AS "600",
    CASE WHEN s.m_field = '610' THEN s.m_value END AS "610",
    CASE WHEN s.m_field = '611' THEN s.m_value END AS "611",
    CASE WHEN s.m_field = '630' THEN s.m_value END AS "630",
    CASE WHEN s.m_field = '647' THEN s.m_value END AS "647",
    CASE WHEN s.m_field = '648' THEN s.m_value END AS "648",
    CASE WHEN s.m_field = '650' THEN s.m_value END AS "650",
    CASE WHEN s.m_field = '651' THEN s.m_value END AS "651",
    CASE WHEN s.m_field = '653' THEN s.m_value END AS "653",
    CASE WHEN s.m_field = '655' THEN s.m_value END AS "655",
    CASE WHEN s.m_field = '656' THEN s.m_value END AS "656",
    CASE WHEN s.m_field = '691' THEN s.m_value END AS "691",
    CASE WHEN s.m_field = '697' THEN s.m_value END AS "697",
    CASE WHEN s.m_field = '699' THEN s.m_value END AS "699"
FROM get_rec AS g
INNER JOIN collection_id AS c ON c.instance_id = g.instance_id
INNER JOIN target AS s ON s.instance_id = c.instance_id
INNER JOIN folio_reporting.instance_ext ie ON s.instance_id = ie.instance_id
GROUP BY g.instance_id, s.m_field, s.m_value,ie.instance_hrid, g.holdings_hrid, g.permanent_location_name,
         ie.title, c.collection_id
;
