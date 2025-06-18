WITH hierarchy(level, master_id, head_id, staff_id, master_post, head_post, staff_post)
AS
(
	SELECT distinct 0, a.staff_id as master_id, a.staff_id as head_id, a.staff_id as staff_id,
			  a.post as master_post, a.post as head_post, a.post as staff_post
	FROM unit_staffs_post AS a
	INNER JOIN unit_staffs_post as b on b.head_staff_id = a.staff_id
	UNION ALL
	SELECT pg.level + 1, pg.master_id as master_id, ng.head_staff_id as head_id, ng.staff_id as staff_id,
			rt.post as master_post,
			pg.staff_post as head_post,
			ng.post as staff_post
	FROM unit_staffs_post AS ng
	INNER JOIN hierarchy as pg ON ng.head_staff_id = pg.staff_id
		and pg.head_id <> ng.staff_id
                and pg.master_id <> ng.staff_id
	INNER JOIN unit_staffs_post rt on pg.master_id = rt.staff_id
    WHERE pg.level <= 100
)
, valid_unit_staffs_map (level, master_post, head_post, staff_post
	--, master_id, head_id, staff_id
	)
as (
	select min(level), master_post, head_post, staff_post
			--, min(master_id), min(head_id), min(staff_id)
	from hierarchy
	where master_post <> staff_post
	group by master_post, head_post, staff_post
	--, master_id, head_id, staff_id
	--having min(level) = max(level)
)
select level, master_post, head_post, staff_post
from valid_unit_staffs_map
;