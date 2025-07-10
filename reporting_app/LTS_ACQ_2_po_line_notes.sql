DROP FUNCTION IF EXISTS po_line_notes;
CREATE FUNCTION po_line_notes()
RETURNS TABLE (
               creation_date DATE,
               po_line_number TEXT,
               title_or_package TEXT,
               receiving_note TEXT,
               requester_present TEXT,
               selector_present TEXT,
               donor_present TEXT,
               rush_order TEXT,
               cancellation_restriction_note TEXT,
               renewal_note TEXT
) 
AS 
$$
SELECT 
    pl.creation_date::date,
    plt.po_line_number,
    plt.title_or_package,
    CASE 
      WHEN jsonb_extract_path_text(pl.jsonb, 'details','receivingNote') IS NOT NULL 
           AND jsonb_extract_path_text(pl.jsonb, 'details','receivingNote') ILIKE '%req%' 
      THEN 'yes' 
      ELSE jsonb_extract_path_text(pl.jsonb, 'details','receivingNote')
    END AS receiving_note,
    CASE WHEN plt.requester IS NOT NULL THEN 'yes' END AS requester_present,
    CASE WHEN plt.selector IS NOT NULL THEN 'yes' END AS selector_present,
    CASE WHEN plt.donor IS NOT NULL THEN 'yes' END AS donor_present,
    CASE WHEN plt.rush IS NOT NULL THEN 'yes' END AS rush_order,
    plt.cancellation_restriction_note,
    plt.renewal_note
FROM folio_orders.po_line__t plt 
LEFT JOIN folio_orders.po_line pl ON plt.purchase_order_id = pl.purchaseorderid
WHERE pl.creation_date::date >= now() - INTERVAL '90 DAYS'
ORDER BY pl.creation_date DESC;
$$
LANGUAGE SQL
STABLE
PARALLEL SAFE;
