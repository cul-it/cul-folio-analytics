--MCR184B
--orig_locs_for_phys_collections_no_library_charges
--Query writer: Linda Miller (lm15)
--Reviewed by Joanne Leary (jl41)
--Posted on: 9/12/24

WITH candidates AS
(SELECT distinct
loans.loan_id,
loans.loan_date,
loans.item_effective_location_id_at_check_out,
loans.item_effective_location_name_at_check_out,
loans.patron_group_name,
loans.material_type_name,
loans.loan_policy_name,
lt.id AS locationid,
lt.name,
llt.id AS libraryid,
llt.name

FROM folio_derived.loans_items AS loans
LEFT JOIN folio_inventory.location__t AS lt on loans.item_effective_location_id_at_check_out = lt.id
LEFT JOIN folio_inventory.loclibrary__t AS llt ON lt.LIBRARY_id = llt.id
WHERE (llt.name = 'Removed Locations' OR llt.name = 'No Library')
AND (loans.loan_date > '2024-07-01'AND loans.loan_date < '2025-07-01')
AND loans.patron_group_name != 'SPEC(Library Dept Card)'
AND loans.loan_policy_name NOT ILIKE '3 hour%' -- this line and next because NOT counting equipment FOR ADC
AND loans.material_type_name NOT ILIKE ALL (ARRAY ['BD MATERIAL', 'Carrel Keys', 'Equipment', 
'ILL MATERIAL', 'Laptop', 'Locker Keys', 'Peripherals', 'Room Keys', 'Supplies', 'Umbrella%'])
)


SELECT 
candidates.item_effective_location_name_at_check_out,
candidates.material_type_name,
candidates.loan_policy_name,
count (DISTINCT candidates.loan_id)

FROM candidates

GROUP BY 
candidates.item_effective_location_name_at_check_out,
candidates.material_type_name,
candidates.loan_policy_name
; 

