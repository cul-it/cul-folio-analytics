/* PURPOSE
This report produces a list of individual loans which can then be grouped and summed to create loans and renewals counts.

MAIN TABLES INCLUDED
loans_items (derived table)

AGGREGATION
No aggregation

FILTERS FOR USER TO SELECT
start_date, end_date, item_permanent_location, item_temporary_location, item_effective_location, item_permanent_location_institution_name, 
item_permanent_location_campus_name, item_permanent_location_library_name.

*/
 
WITH parameters AS (
    SELECT
        /* Choose a start and end date for the loans period */
        '2021-07-01'::date AS start_date,
        '2022-06-30'::date AS end_date,
        /* Fill one out, leave others blank to filter by location */
        ''::varchar AS items_permanent_location_filter, -- Examples: Olin, ILR, Africana, etc.
        ''::varchar AS items_temporary_location_filter, -- Examples: Olin, ILR, Africana, etc.
        ''::varchar AS items_effective_location_filter, --Examples: Olin, ILR, Africana, etc.
        /* The following connect to the item's permanent location */
        ''::varchar AS institution_filter, -- Examples: Cornell University
        ''::varchar AS campus_filter, -- Examples: Ithaca
        ''::varchar AS library_filter -- Examples: Nestle Library', Library Annex, etc.
)
    --MAIN QUERY
    SELECT
        (
            SELECT
                start_date::varchar
            FROM
                parameters) || ' to '::varchar || (
        SELECT
            end_date::varchar
        FROM
            parameters) AS date_range,
    li.loan_date::date,
    li.loan_due_date AS loan_due_date,
    li.loan_return_date AS loan_return_date,
    li.loan_status AS loan_status,
    1::int AS num_loans, -- each row is a single loan
    li.renewal_count AS num_renewals,
    li.patron_group_name AS patron_group_name,
    li.material_type_name AS material_type_name,
    li.loan_policy_name AS loan_policy_name,
    li.permanent_loan_type_name AS permanent_loan_type_name,
    li.temporary_loan_type_name AS temporary_loan_type_name,
    li.current_item_permanent_location_name AS permanent_location_name,
    li.current_item_temporary_location_name AS temporary_location_name,
    li.current_item_effective_location_name AS effective_location_name,
    li.current_item_permanent_location_library_name AS permanent_location_library_name,
    li.current_item_permanent_location_campus_name AS permanent_location_campus_name,
    li.current_item_permanent_location_institution_name AS permanent_location_institution_name
FROM
    folio_reporting.loans_items AS li
WHERE
    loan_date >= (
        SELECT
            start_date
        FROM
            parameters)
    AND loan_date < (
        SELECT
            end_date
        FROM
            parameters)
    AND (li.current_item_permanent_location_name = (
            SELECT
                items_permanent_location_filter
            FROM
                parameters)
            OR '' = (
                SELECT
                    items_permanent_location_filter
                FROM
                    parameters))
        AND (li.current_item_temporary_location_name = (
                SELECT
                    items_temporary_location_filter
                FROM
                    parameters)
                OR '' = (
                    SELECT
                        items_temporary_location_filter
                    FROM
                        parameters))
            AND (li.current_item_effective_location_name = (
                    SELECT
                        items_effective_location_filter
                    FROM
                        parameters)
                    OR '' = (
                        SELECT
                            items_effective_location_filter
                        FROM
                            parameters))
                AND (li.current_item_permanent_location_library_name = (
                        SELECT
                            library_filter
                        FROM
                            parameters)
                        OR '' = (
                            SELECT
                                library_filter
                            FROM
                                parameters))
                    AND (li.current_item_permanent_location_campus_name = (
                            SELECT
                                campus_filter
                            FROM
                                parameters)
                            OR '' = (
                                SELECT
                                    campus_filter
                                FROM
                                    parameters))
                        AND (li.current_item_permanent_location_institution_name = (
                                SELECT
                                    institution_filter
                                FROM
                                    parameters)
                                OR '' = (
                                    SELECT
                                        institution_filter
                                    FROM
                                        parameters));
