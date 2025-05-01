--metadb:function test_get_count_user_group

DROP FUNCTION IF EXISTS test_get_count_user_group;

CREATE FUNCTION test_get_count_user_group(
    param_user_group TEXT DEFAULT ''
)
RETURNS TABLE (
    group_id          TEXT,
    group_description TEXT,
    group_name        TEXT,
    count_by_group    INTEGER    
)
AS 
$$
SELECT  
    uu.patron_group :: TEXT       AS group_id,
    ug.desc                       AS group_description,
    ug.group                      AS group_name,
    COUNT(uu.id) :: INTEGER       AS count_by_group
FROM
    folio_users.users__t  AS uu
    LEFT JOIN folio_users.groups__t AS ug ON ug.id::UUID = uu.patron_group::UUID
WHERE 
    (param_user_group = '' OR ug.group = param_user_group)
GROUP BY 
    uu.patron_group,
    ug.desc,
    ug.group
$$
LANGUAGE SQL;

