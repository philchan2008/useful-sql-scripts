
if exists (select 1
          from sysobjects
          where id = object_id('audview_%TABLE%_diff')
          and type = 'V')
   drop view audview_%TABLE%_diff
go

if exists (select 1
          from sysobjects
          where id = object_id('audview_%TABLE%_raw')
          and type = 'V')
   drop view audview_%TABLE%_raw
go

create view audview_%TABLE%_raw
with schemabinding
as
select a.guid,a.session_uuid,
 b.parent_uuid as parent_session_uuid,
 b.master_uuid as master_session_uuid,
 a.trans_date,a.nest_level
.FOREACH_COLUMN()
,a.data_text.value(N'/deleted[[1\]]/%COLUMN%[[1\]]','%COLTYPE%')  as fr_%COLUMN%
,a.data_text.value(N'/inserted[[1\]]/%COLUMN%[[1\]]','%COLTYPE%') as to_%COLUMN%
.ENDFOR
from dbo.app_audit_log a
left join dbo.app_user_db_session_log b on a.session_uuid = b.uuid
where a.data_object = '%TABLE%'
go

create view audview_%TABLE%_diff
with schemabinding
as
select guid,session_uuid,parent_session_uuid,master_session_uuid,trans_date,nest_level,
.ALLCOL("isnull(case when isnull(cast(fr_%COLUMN% as nvarchar(max)),'(null)') <> isnull(cast(to_%COLUMN% as nvarchar(max)),'(null)')then '%COLUMN%: ' + isnull(cast(fr_%COLUMN% as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_%COLUMN% as nvarchar(max)),'(null)') + char(13) else '' end,'')","","+","")
as data_diff
from dbo.audview_%TABLE%_raw
go