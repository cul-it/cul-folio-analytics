/*
PURPOSE 
This report shows a list of items that patrons claim they have returned, but are not showing as checked in by the system 
(where the item status is 'claimed returned'). Patron information is also included. 
 
FILTERS FOR USERS TO SELECT
loan date range, location name (permanent location, owning library)
 */
WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '1900-01-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /* Fill in a location name, OR leave blank for all locations */
        ''::varchar AS permanent_location_filter, --Examples: Olin, ILR, Africana, etc.
        ''::varchar AS owning_library_filter -- Examples: Nestle Library, Library Annex, etc.
),
-- CTEs
items_with_notes AS (
    SELECT
        item_id,
        string_agg(DISTINCT note, '|') AS item_notes
    FROM
        folio_reporting.item_notes
    GROUP BY
        item_id
)
SELECT
	(SELECT start_date::varchar FROM parameters) || ' to ' || (SELECT end_date::varchar FROM parameters) AS date_range,
	li.current_item_permanent_location_library_name AS owning_library_name,
    li.current_item_permanent_location_name AS permanent_location_name,
    json_extract_path_text(uu.data, 'personal', 'firstName') AS first_name,
    json_extract_path_text(uu.data, 'personal', 'lastName') AS last_name,
    uu.active AS patron_active_status,
    json_extract_path_text(uu.data, 'personal', 'email') AS email,
    li.patron_group_name,
    ine.title,
    json_extract_path_text(iit.data, 'effectiveCallNumberComponents', 'callNumber') AS call_number,
    li.enumeration,
    li.chronology,
    li.copy_number,
    li.barcode,
    TO_CHAR(li.loan_date :: date,'mm/dd/yyyy')AS loan_date,
    TO_CHAR(li.loan_due_date :: date,'mm/dd/yyyy') AS loan_due_date,
    TO_CHAR (json_extract_path_text(l.data, 'claimedReturnedDate')::date,'mm/dd/yyyy')  AS claimed_returned_date,
    li.item_status,
    nn.item_notes,
    li.loan_policy_name,
    li.material_type_name
 FROM
    folio_reporting.loans_items AS li
    LEFT JOIN public.user_users AS uu ON li.user_id = uu.id
    LEFT JOIN public.circulation_loans AS l ON li.loan_id = l.id
    LEFT JOIN folio_reporting.item_ext AS ie ON li.item_id = ie.item_id
    LEFT JOIN items_with_notes AS nn ON li.item_id = nn.item_id
    LEFT JOIN folio_reporting.holdings_ext AS he ON ie.holdings_record_id = he.holdings_id
    LEFT JOIN public.inventory_instances AS ii ON he.instance_id = ii.id
    LEFT JOIN public.inventory_items AS iit ON li.item_id=iit.id
    LEFT JOIN folio_reporting.instance_ext as ine ON ine.instance_id = he.instance_id 
 --   LEFT JOIN instances_with_publication_dates AS pd ON he.instance_id = pd.instance_id
  --  LEFT JOIN folio_reporting.instance_publication AS ip ON he.instance_id = ip.instance_id
    LEFT JOIN folio_reporting.loans_renewal_count AS lrc ON li.item_id = lrc.item_id
WHERE li.item_status = 'Claimed returned' 
	AND (li.current_item_permanent_location_name = (SELECT permanent_location_filter FROM parameters)
		OR '' = (SELECT permanent_location_filter FROM parameters))
        AND (li.current_item_permanent_location_library_name = (SELECT owning_library_filter FROM parameters)
        OR '' = (SELECT owning_library_filter FROM parameters))
        AND li.loan_date >= (SELECT start_date FROM parameters)
        AND li.loan_date < (SELECT end_date FROM parameters);
