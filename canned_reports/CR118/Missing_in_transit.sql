WITH parameters AS (
    SELECT
  /*Days in transit filter is the number of days the item has been 'in transit', starting with today*/  
    
   		'7'::integer AS days_in_transit_filter, -- doesn't work if empty
        'In transit'::VARCHAR AS item_status_filter, --  'Checked out', 'Available', 'In transit'
        ---- Fill out one location or service point filter, leave others blank ----
        'Library Annex'::varchar AS owning_library_filter -- 'Olin, Mann, etc.'
),
days AS (
    SELECT 
        item_id,
        DATE_PART('day', NOW() - date(status_date)) AS days_in_transit
    FROM folio_reporting.item_ext
),
item_notes_list AS (
    SELECT
        item_id,
        string_agg(DISTINCT note, '|'::text) AS notes_list
        
    FROM
        folio_reporting.item_notes
    GROUP BY
        item_id
)
    ---------- MAIN QUERY ----------
    SELECT
        TO_CHAR(ie.status_date :: date,'mm/dd/yyyy')AS status_date,
        days.days_in_transit,
        ine.title,
        ie.status_name,
        ie.in_transit_destination_service_point_name,
        ie.barcode,
        he.call_number,
        ie.enumeration,
        ie.chronology,
        ie.copy_number,
        ie.volume,
        ll.library_name  AS owning_library_name,
        he.permanent_location_name AS holdings_permanent_location_name,
        nl.notes_list,
        ie.material_type_name
        FROM
        folio_reporting.item_ext AS ie
        LEFT JOIN days ON ie.item_id=days.item_id
        LEFT JOIN item_notes_list AS nl ON ie.item_id = nl.item_id
        LEFT JOIN folio_reporting.holdings_ext AS he ON ie.holdings_record_id = he.holdings_id
        LEFT JOIN folio_reporting.instance_ext AS ine ON he.instance_id = ine.instance_id
        LEFT JOIN folio_reporting.locations_libraries AS ll ON he.permanent_location_id=ll.location_id
        WHERE (days.days_in_transit > 0 AND days.days_in_transit >= (SELECT days_in_transit_filter FROM parameters))
        	AND (ll.library_name = (SELECT owning_library_filter FROM parameters)
            	OR (SELECT owning_library_filter FROM parameters) = '')
            AND ie.status_name = 'In transit'
                                      
            ORDER BY call_number, enumeration, chronology, copy_number
                      ;
