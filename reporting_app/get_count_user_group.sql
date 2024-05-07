--ldp:function get_count_user_group

DROP FUNCTION IF EXISTS get_count_user_group;

CREATE FUNCTION get_count_user_group(
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
    user_users.patron_group :: TEXT,
    user_groups.desc,
    user_groups.group,
    COUNT(user_users.id) :: INTEGER
FROM
    public.user_users  
    LEFT JOIN public.user_groups ON user_groups.id = user_users.patron_group
WHERE 
    ((user_groups.group = param_user_group) OR (param_user_group = ''))
GROUP BY 
    user_users.patron_group,
    user_groups.desc,
    user_groups.GROUP
$$
LANGUAGE SQL;
