/****** Object:  Trigger [dbo].[trg_async_sql_proc]    Script Date: 5/28/2025 12:16:40 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER trigger [dbo].[trg_async_sql_proc] on [dbo].[table_name]
for insert, update, delete
as
begin
    declare
       @numrows  int

    select  @numrows = @@rowcount
    if @numrows = 0
       return

    if update(affected_column)
	begin
        declare @src_type char(1)
        set @src_type = 'R'     -- user defined value
        IF trigger_nestlevel() < 2   --prevent nested trigger over 2 layers
        begin
            DECLARE @ch UNIQUEIDENTIFIER;
            BEGIN DIALOG CONVERSATION @ch
                  FROM SERVICE [AsyncSqlRequestService]
                  TO SERVICE 'AsyncSqlResponseService'
                  ON CONTRACT [//AsyncSql/Contract]
                  WITH ENCRYPTION = OFF ;
            --
            insert into sb_parameter_table (ch, user_id, src_id, src_type)
            select @ch, user_id, id, @src_type from inserted
            union
            select @ch, user_id, id, @src_type from deleted
            --
            DECLARE @msg NVARCHAR(MAX) ;
            SET @msg = '<sqlobject>
            			   <sqlcommand commandText="proc_name" commandtype="storeprocedure" >
                               <sqlparametercollection>
            						<sqlparameter parametername="@ch" dbtype="varchar(38)" direction="input" value="'+cast(@ch as varchar(max))+'"/>
            				   </sqlparametercollection>
                           </sqlcommand>
            			</sqlobject>';
            --set @msg = '<xml></xml>'; --for testing the queue
            SEND ON CONVERSATION @ch MESSAGE TYPE [//AsyncSql/RequestMessage] (@msg);
        end
    end
    return
end
GO
