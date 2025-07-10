SELECT
    so_po,
    COUNT(*) AS po_count
FROM folio_acq.orders
WHERE created_date >= :start_date
  AND created_date < :end_date
  AND (
    :so_po_text IS NULL OR
    so_po ILIKE '%' || :so_po_text || '%'
  )
GROUP BY so_po
ORDER BY so_po;
