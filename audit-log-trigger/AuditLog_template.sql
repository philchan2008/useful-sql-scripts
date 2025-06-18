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
        	'%TABLE%',
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
        	'%TABLE%',
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
        	'%TABLE%',
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
