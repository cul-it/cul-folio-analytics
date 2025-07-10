DROP FUNCTION IF EXISTS TEST_LTS_ACQ_sopo;
CREATE FUNCTION TEST_LTS_ACQ_1_sopo(
    start_date DATE DEFAULT '2021-07-01',
    end_date DATE DEFAULT '2050-01-01')
    so_po_text TEXT DEFAULT NULL
)
RETURNS TABLE (
    so_po TEXT,
    po_count BIGINT
)
LANGUAGE SQL
AS $$
    SELECT
        so_po,
        COUNT(*) AS po_count
    FROM folio_acq.orders
    WHERE created_date >= start_date
      AND created_date < end_date
      AND (
            so_po_text IS NULL
         OR so_po ILIKE '%' || so_po_text || '%'
      )
    GROUP BY so_po
    ORDER BY so_po;
$$;

