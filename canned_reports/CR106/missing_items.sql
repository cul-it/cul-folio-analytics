WITH parameters AS (
    SELECT 
        '01-01-2021'::date AS start_date,
        '12-11-2021'::date AS end_date,
        /*Enter item status*/
        'Missing'::varchar AS item_status_filter, --Missing 
              ---- Fill out a location or an owning library filter ----
         'Olin Library'::varchar AS owning_library_name_filter -- Examples: Olin Library, Library Annex, etc.
        ),
---------- SUB-QUERIES/TABLES ----------
item_subset AS (
    SELECT 
        item_hrid,
        item_id,
        holdings_record_id,
        status_name AS item_status,
        status_date::timestamp AS item_status_date,
        barcode,
        --call_number,
        enumeration,
        chronology,
        copy_number,
        volume
    FROM 
        folio_reporting.item_ext AS it
    WHERE
        status_date::timestamp >= (SELECT start_date FROM parameters)
    AND status_date::timestamp < (SELECT end_date FROM parameters)
    AND (status_name =(SELECT item_status_filter FROM parameters)
        OR (SELECT item_status_filter FROM parameters) = '')
    ),
item_notes_list AS (
    SELECT
        itn.item_id,
        string_agg(DISTINCT itn.note, ' | ') AS notes_list
    FROM
        folio_reporting.item_notes AS itn
        RIGHT JOIN item_subset AS its ON itn.item_id = its.item_id
    GROUP BY
        itn.item_id
),
instance_subset AS (
    SELECT 
        ie.instance_id 
    FROM 
        item_subset AS its
        LEFT JOIN folio_reporting.holdings_ext AS he ON its.holdings_record_id = he.holdings_id
        LEFT JOIN folio_reporting.instance_ext AS ie ON he.instance_id = ie.instance_id
),

"size" as (
select 
        srs.instance_id as srs_instance_id,
        srs.instance_hrid,
        string_agg(srs."content", ' | ') as pagination_size,
        srs.field 

from srs_marctab as srs 
        left join instance_subset on
        instance_subset.instance_id = srs.instance_id 

where srs.field = '300'

group by 
        srs.instance_id,
        srs.instance_hrid,
        srs.field
)

/*publication_dates_list AS (
    SELECT
        ip.instance_id,
        string_agg(DISTINCT date_of_publication, '|') AS publication_dates_list
    FROM
        folio_reporting.instance_publication AS ip
        RIGHT JOIN instance_subset AS ins ON ip.instance_id = ins.instance_id
    GROUP BY
        ip.instance_id
)*/
    ---------- MAIN QUERY ----------
SELECT DISTINCT
    (SELECT start_date::varchar FROM parameters) || 
        ' to ' || 
        (SELECT end_date::varchar FROM parameters) AS date_range,
    ll.library_name as owning_library_name,
    he.permanent_location_name as holdings_perm_loc_name,
    he.call_number_prefix,
    he.call_number,
    he.call_number_suffix,
    --ite.effective_call_number,
    its.enumeration,
    its.chronology,
    its.copy_number,
    --its.volume,
    its.barcode,
    size.pagination_size,
    ie.title,
  --  ite.permanent_location_name AS item_permanent_location_name,
    
    its.item_status,
    TO_CHAR(its.item_status_date :: date,'mm/dd/yyyy')AS item_status_date,
    ite.material_type_name,
    --pd.publication_dates_list,
    nl.notes_list,
    ii.effective_shelving_order
  FROM
    item_subset AS its
    LEFT JOIN folio_reporting.item_ext AS ite ON its.item_id = ite.item_id 
    LEFT JOIN folio_reporting.loans_items AS li ON its.item_id = li.item_id 
    LEFT JOIN public.inventory_items AS ii on its.item_id=ii.id
    LEFT JOIN item_notes_list AS nl ON its.item_id = nl.item_id
    LEFT JOIN folio_reporting.holdings_ext AS he ON its.holdings_record_id = he.holdings_id
    left join folio_reporting.locations_libraries as ll on he.permanent_location_id = ll.location_id
    LEFT JOIN folio_reporting.instance_ext AS ie ON he.instance_id = ie.instance_id
    left join "size" on ie.instance_id = "size".srs_instance_id
   
    --LEFT JOIN publication_dates_list AS pd ON ie.instance_id = pd.instance_id
WHERE 
     (ll.library_name = 
        (SELECT owning_library_name_filter FROM parameters)
        OR (SELECT owning_library_name_filter FROM parameters) = '')
  ORDER BY owning_library_name, holdings_perm_loc_name, material_type_name, effective_shelving_order ;
