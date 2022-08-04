/* This is the August 2022 corrected version of charges and renwals used for theFY22 data collection. It counts all renewals 
 * made in FY22 despite when originally charged. The loans_items table is used to limit the charge dates, while 
 * the loans_renewal_dates is used to limit the renewal dates. The 2 sets of counts are gotten separately, and 
 * then merged through a full outer join (which is used because there are 3 renewals without charges in FY22).
 * (Since there are no unique IDs in the charges and the renewals data sets we want, the join between the two sets
 * is made on three fields.)
 * It also makes an adjustment from the earlier query to sort more transactions as reserve transactions.
 * 
 * These counts exclude any charges for the patron group "SPEC" and exclude any items not owned by CUL (i.e., 
 * charged to our users from other institutions through Borrow Direct and Interlibrary Loan).
 * 
 * Use the patron groups ILL and BD to get counts charges and renewals for our materials lent to other 
 * institutions.
 * 
 * 
 */ 


WITH loans AS 
(SELECT 
        ll.library_name,
        li.loan_id,
        CASE
                        WHEN li.patron_group_name IN ('Faculty', 'Proxy Borrower') THEN 'Faculty'
                        WHEN li.patron_group_name = 'Graduate' THEN 'Graduate'
                        WHEN li.patron_group_name = 'Undergraduate' THEN 'Undergraduate'
                        WHEN li.patron_group_name = 'Staff' THEN 'Staff'
                        WHEN li.patron_group_name = 'SPEC(Library Dept Card)' THEN 'SPEC'
                        WHEN li.patron_group_name = 'Borrow Direct' THEN 'BD'
                        WHEN li.patron_group_name = 'Interlibrary Loan' THEN 'ILL'
                        WHEN li.patron_group_name IN ('Library Card', 'Privilege Card (Statutory)') THEN 'Librarycard'
                        WHEN li.patron_group_name = 'Carrel' THEN 'Carrel'
                        ELSE 'Fix' END AS patrongrouptrans,
                        
                CASE
                        WHEN li.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
                        WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
                        WHEN li.material_type_name IS NULL AND li.loan_policy_name LIKE '3 hour%' THEN 'Equipment'
                        WHEN li.item_effective_location_name_at_check_out ILIKE '%reserve%' THEN 'Reserve'                                                                        
                        WHEN li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                        WHEN li.loan_policy_name SIMILAR TO '(1|2)%day%' THEN 'Reserve'                  
                        ELSE 'Regular' END AS collection_type
                
        FROM folio_reporting.loans_items AS li
                LEFT JOIN folio_reporting.locations_libraries AS ll 
                ON li.item_effective_location_id_at_check_out = ll.location_id
        
        WHERE li.loan_date >='2021-07-01' AND li.loan_date < '2022-07-01'
                AND li.patron_group_name NOT ILIKE 'SPEC%'
                AND li.item_effective_location_name_at_check_out NOT ILIKE '%Borrow%'
                AND li.item_effective_location_name_at_check_out NOT ILIKE '%Inter%'
        ),

loans_final AS 
(SELECT 
        loans.library_name,
        loans.patrongrouptrans,
        loans.collection_type,
        count (loans.loan_id) AS total_loans

FROM loans 

GROUP BY 
        loans.library_name,
        loans.patrongrouptrans,
        loans.collection_type
),

renews AS 
(SELECT 
        ll.library_name,
        CASE
                        WHEN li.patron_group_name IN ('Faculty', 'Proxy Borrower') THEN 'Faculty'
                        WHEN li.patron_group_name = 'Graduate' THEN 'Graduate'
                        WHEN li.patron_group_name = 'Undergraduate' THEN 'Undergraduate'
                        WHEN li.patron_group_name = 'Staff' THEN 'Staff'
                        WHEN li.patron_group_name = 'SPEC(Library Dept Card)' THEN 'SPEC'
                        WHEN li.patron_group_name = 'Borrow Direct' THEN 'BD'
                        WHEN li.patron_group_name = 'Interlibrary Loan' THEN 'ILL'
                        WHEN li.patron_group_name IN ('Library Card', 'Privilege Card (Statutory)') THEN 'Librarycard'
                        WHEN li.patron_group_name = 'Carrel' THEN 'Carrel'
                        ELSE 'Fix' END AS patrongrouptrans,
                        
                CASE
                        WHEN li.material_type_name IN ('Peripherals','Supplies','Umbrella','Locker Keys','Carrel Keys','Room Keys','Equipment') THEN 'Equipment'
                        WHEN li.material_type_name = 'Laptop' THEN 'Laptop'
                        when li.material_type_name is null and li.loan_policy_name like '3 hour%' then 'Equipment'
                        when li.item_effective_location_name_at_check_out ilike '%reserve%' then 'Reserve'                                                                        
                        when li.loan_policy_name LIKE '%hour%' THEN 'Reserve'
                        when li.loan_policy_name similar to '(1|2)%day%' THEN 'Reserve' 
                        ELSE 'Regular' END as collection_type,
                        
        COUNT (lrd.loan_id) as renewals

FROM folio_reporting.loans_renewal_dates lrd 
        LEFT JOIN folio_reporting.loans_items AS li 
        ON lrd.loan_id = li.loan_id
        
        LEFT JOIN folio_reporting.locations_libraries AS ll 
        ON li.item_effective_location_id_at_check_out = ll.location_id

WHERE lrd.loan_action_date >= '2021-07-01' AND lrd.loan_action_date < '2022-07-01'
        AND lrd.loan_action ilike 'renewed%'
        AND li.patron_group_name NOT ILIKE 'SPEC%' 
        AND li.item_effective_location_name_at_check_out NOT LIKE '%Borrow%'
        AND li.item_effective_location_name_at_check_out NOT LIKE '%Inter%'
        AND li.item_effective_location_name_at_check_out IS NOT NULL

GROUP BY ll.library_name, li.patron_group_name, li.material_type_name, li.loan_policy_name, li.item_effective_location_name_at_check_out  
),

renews_final AS 
(SELECT 
        renews.library_name,
        renews.patrongrouptrans,
        renews.collection_type,
        SUM (renews.renewals) AS total_renewals

FROM renews 

GROUP BY 
        renews.library_name,
        renews.patrongrouptrans,
        renews.collection_type

ORDER BY library_name, patrongrouptrans, collection_type
)

SELECT 
        loans_final.library_name,
        loans_final.patrongrouptrans,
        loans_final.collection_type,
        loans_final.total_loans,
        CASE WHEN renews_final.total_renewals IS NULL THEN 0 ELSE renews_final.total_renewals END AS total_renewals

FROM loans_final 
FULL OUTER JOIN renews_final
        ON loans_final.library_name = renews_final.library_name 
                AND loans_final.patrongrouptrans = renews_final.patrongrouptrans 
                AND loans_final.collection_type = renews_final.collection_type
;
