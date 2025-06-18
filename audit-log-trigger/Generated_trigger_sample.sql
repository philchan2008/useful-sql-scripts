/*
--PowerDesigner source code
print 'creating trigger [%QUALIFIER%]%TRIGGER%'
go
create trigger [%QUALIFIER%]%TRIGGER% on [%TABLQUALIFIER%]%TABLE%
    for insert, update, delete as
begin
    --
    .AuditLog
    --
    return
end
go

print 'Set trigger order [%QUALIFIER%]%TRIGGER% to Last'
go
exec sp_settriggerorder @triggername = '[%QUALIFIER%]%TRIGGER%', @order = 'Last', @stmttype = 'Insert'
exec sp_settriggerorder @triggername = '[%QUALIFIER%]%TRIGGER%', @order = 'Last', @stmttype = 'Update'
exec sp_settriggerorder @triggername = '[%QUALIFIER%]%TRIGGER%', @order = 'Last', @stmttype = 'Delete'
go

.AuditViews
*/

if exists (select 1
          from sysobjects
          where id = object_id('trg_aud_tableName')
          and type = 'TR')
   drop trigger trg_aud_tableName
go


print 'creating trigger trg_aud_tableName'
go
create trigger trg_aud_tableName on tableName
    for insert, update, delete as
begin
    --
    set nocount on
    declare @inserted_count int = (SELECT count(*) FROM inserted)
    declare @deleted_count int = (SELECT count(*) FROM deleted)
    --
    declare @action char(1)=
    	case when @inserted_count = 0
    		then 'D'
    	when @deleted_count > 0
    		then 'U'
    	else
    		'I'
    	end
    --
    declare @getdate datetime = getdate()
    declare @app_user_or_db_user varchar(32)
    declare @app_user_hkid varchar(40)
    declare @app_user_post varchar(60)
    declare @app_user_session_datetime datetime
    declare @app_user_session_uuid varchar(38)
    declare @app_func_id  varchar(50)
    declare @app_object_name varchar(255)
    set @app_object_name = isnull(OBJECT_NAME(@@PROCID),'(NULL)')
    exec proc_getDbSessionUser @app_object_name, @app_user_session_uuid output, @app_user_session_datetime output,
            @app_user_or_db_user output, @app_user_post output, @app_user_hkid output,
            @app_func_id output
    --
    if ((select param_value from app_param with (nolock) where param_key = 'AUDIT_TABLE_ENABLED') = 'TRUE'
         --and (trigger_nestlevel() < 2)
        )
        begin
        --
        if (@inserted_count > 0 or @deleted_count > 0)
        begin
            if (@action = 'I')
            	insert app_audit_log with (updlock, rowlock)
                    (session_uuid, session_date, trans_date, trans_type, data_object, data_text, user_id, user_post_code, nest_level)
            	select
                @app_user_session_uuid,
                @app_user_session_datetime,
                @getdate,
            	@action,
            	'tableName',
                cast (
                 --[dbo].f_EscapeXMLCharacters( --remarked it to use standard xml
            	    [dbo].f_RemoveInvalidXMLCharacters (
                        (select inserted.*,
                            @@spid as spid,
                            @app_user_session_datetime as session_date,
                            @getdate as insert_date,
                            @app_user_or_db_user as insert_user,
                            @app_user_post as insert_post
                        from inserted
                        for xml path('inserted'), elements, BINARY BASE64)
                        ) --f_RemoveInvalidXMLCharacters
                --    ) --f_EscapeXMLCharacters
            	    as xml),
                @app_user_or_db_user,
                @app_user_post,
                trigger_nestlevel()
            --
            if (@action = 'D')
            	insert app_audit_log with (updlock, rowlock)
                    (session_uuid, session_date, trans_date, trans_type, data_object, data_text, user_id, user_post_code, nest_level)
            	select
                @app_user_session_uuid,
                @app_user_session_datetime,
                @getdate,
            	@action,
            	'tableName',
                cast (
            	--   [dbo].f_EscapeXMLCharacters(
                      [dbo].f_RemoveInvalidXMLCharacters (
                        (select deleted.*,
                            @@spid as spid,
                            @app_user_session_datetime as session_date,
                            @getdate as insert_date,
                            @app_user_or_db_user as insert_user,
                            @app_user_post as insert_post
                        from deleted
                        for xml path('deleted'), elements, BINARY BASE64)
                        ) --f_RemoveInvalidXMLCharacters
                --    ) --f_EscapeXMLCharacters
            	    as xml),
            	@app_user_or_db_user,
                @app_user_post,
                trigger_nestlevel()
            --
            if (@action = 'U')
            	insert app_audit_log with (updlock, rowlock)
                    (session_uuid, session_date, trans_date, trans_type, data_object, data_text, user_id, user_post_code, nest_level)
            	select
                @app_user_session_uuid,
                @app_user_session_datetime,
                @getdate,
            	@action,
            	'tableName',
                cast (
            	--   [dbo].f_EscapeXMLCharacters(
                    [dbo].f_RemoveInvalidXMLCharacters (
                        (select deleted.*,
                            @@spid as spid,
                            @app_user_session_datetime as session_date,
                            @getdate as delete_date,
                            @app_user_or_db_user as delete_user,
                            @app_user_post as delete_post
                         from deleted
                         for xml path('deleted'), elements, BINARY BASE64)
                         +
                    	(select inserted.*,
                            @@spid as spid,
                            @app_user_session_datetime as session_date,
                            @getdate as insert_date,
                            @app_user_or_db_user as insert_user,
                            @app_user_post as insert_post
                        from inserted
                        for xml path('inserted'), elements, BINARY BASE64)
                        ) --f_RemoveInvalidXMLCharacters
                 --    ) --f_EscapeXMLCharacters
            	    as xml),
            	@app_user_or_db_user,
                @app_user_post,
                trigger_nestlevel()
        end
    end
    set nocount off
    --
    return
end
go

print 'Set trigger order trg_aud_tableName to Last'
go
exec sp_settriggerorder @triggername = 'trg_aud_tableName', @order = 'Last', @stmttype = 'Insert'
exec sp_settriggerorder @triggername = 'trg_aud_tableName', @order = 'Last', @stmttype = 'Update'
exec sp_settriggerorder @triggername = 'trg_aud_tableName', @order = 'Last', @stmttype = 'Delete'
go


if exists (select 1
          from sysobjects
          where id = object_id('audview_tableName_diff')
          and type = 'V')
   drop view audview_tableName_diff
go

if exists (select 1
          from sysobjects
          where id = object_id('audview_tableName_raw')
          and type = 'V')
   drop view audview_tableName_raw
go

create view audview_tableName_raw
with schemabinding
as
select a.guid,a.session_uuid,
 b.parent_uuid as parent_session_uuid,
 b.master_uuid as master_session_uuid,
 a.trans_date,a.nest_level
,a.data_text.value(N'/deleted[1]/unit_id[1]','bigint')  as fr_unit_id
,a.data_text.value(N'/inserted[1]/unit_id[1]','bigint') as to_unit_id
,a.data_text.value(N'/deleted[1]/unit_name[1]','nvarchar(255)')  as fr_unit_name
,a.data_text.value(N'/inserted[1]/unit_name[1]','nvarchar(255)') as to_unit_name
,a.data_text.value(N'/deleted[1]/timestamp[1]','bigint')  as fr_timestamp
,a.data_text.value(N'/inserted[1]/timestamp[1]','bigint') as to_timestamp
,a.data_text.value(N'/deleted[1]/created_by_user[1]','varchar(32)')  as fr_created_by_user
,a.data_text.value(N'/inserted[1]/created_by_user[1]','varchar(32)') as to_created_by_user
,a.data_text.value(N'/deleted[1]/creation_date[1]','datetime')  as fr_creation_date
,a.data_text.value(N'/inserted[1]/creation_date[1]','datetime') as to_creation_date
,a.data_text.value(N'/deleted[1]/modified_by_user[1]','varchar(32)')  as fr_modified_by_user
,a.data_text.value(N'/inserted[1]/modified_by_user[1]','varchar(32)') as to_modified_by_user
,a.data_text.value(N'/deleted[1]/modification_date[1]','datetime')  as fr_modification_date
,a.data_text.value(N'/inserted[1]/modification_date[1]','datetime') as to_modification_date
from dbo.app_audit_log a
left join dbo.app_user_db_session_log b on a.session_uuid = b.uuid
where a.data_object = 'tableName'
go

create view audview_tableName_diff
with schemabinding
as
select guid,session_uuid,parent_session_uuid,master_session_uuid,trans_date,nest_level,
isnull(case when isnull(cast(fr_unit_id as nvarchar(max)),'(null)') <> isnull(cast(to_unit_id as nvarchar(max)),'(null)')then 'unit_id: ' + isnull(cast(fr_unit_id as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_unit_id as nvarchar(max)),'(null)') + char(13) else '' end,'')+
isnull(case when isnull(cast(fr_unit_name as nvarchar(max)),'(null)') <> isnull(cast(to_unit_name as nvarchar(max)),'(null)')then 'unit_name: ' + isnull(cast(fr_unit_name as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_unit_name as nvarchar(max)),'(null)') + char(13) else '' end,'')+
isnull(case when isnull(cast(fr_timestamp as nvarchar(max)),'(null)') <> isnull(cast(to_timestamp as nvarchar(max)),'(null)')then 'timestamp: ' + isnull(cast(fr_timestamp as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_timestamp as nvarchar(max)),'(null)') + char(13) else '' end,'')+
isnull(case when isnull(cast(fr_created_by_user as nvarchar(max)),'(null)') <> isnull(cast(to_created_by_user as nvarchar(max)),'(null)')then 'created_by_user: ' + isnull(cast(fr_created_by_user as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_created_by_user as nvarchar(max)),'(null)') + char(13) else '' end,'')+
isnull(case when isnull(cast(fr_creation_date as nvarchar(max)),'(null)') <> isnull(cast(to_creation_date as nvarchar(max)),'(null)')then 'creation_date: ' + isnull(cast(fr_creation_date as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_creation_date as nvarchar(max)),'(null)') + char(13) else '' end,'')+
isnull(case when isnull(cast(fr_modified_by_user as nvarchar(max)),'(null)') <> isnull(cast(to_modified_by_user as nvarchar(max)),'(null)')then 'modified_by_user: ' + isnull(cast(fr_modified_by_user as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_modified_by_user as nvarchar(max)),'(null)') + char(13) else '' end,'')+
isnull(case when isnull(cast(fr_modification_date as nvarchar(max)),'(null)') <> isnull(cast(to_modification_date as nvarchar(max)),'(null)')then 'modification_date: ' + isnull(cast(fr_modification_date as nvarchar(max)),'(null)') +'-->'+isnull(cast(to_modification_date as nvarchar(max)),'(null)') + char(13) else '' end,'')
as data_diff
from dbo.audview_tableName_raw
go

