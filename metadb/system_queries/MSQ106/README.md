**MSQ106**

- **Created:** 2/16/26  
- **Written by:** Joanne Leary and Sharon Markus  

---

### Description
This query counts distinct `id` values on the `records_lb` table that are associated with `external_hrid` values on the same table.  
It is intended to provide an additional check related to the count performed by the **MSQ102** query.

---

### Assumptions
- `instance_hrid` on `marc__t` = `external_hrid` on `records_lb`  
- `id` on `records_lb` = `srs_id` on `marc__t`
- `instance_hrid` on `marc__t` = `external_hrid` on `records.lb 
- `instance_id` on `marc__t` = `external_id` on `records.lb` 



-matched_id on records_lb = matched_id on marc _ _ t 
