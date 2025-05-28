/****** Object:  StoredProcedure [dbo].[sbp_async_sql_exe_worker]    Script Date: 5/28/2025 12:10:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sbp_async_sql_exe_worker]
      @RequestMessage XML,
      @ReturnMessage XML OUTPUT
AS
BEGIN
  DECLARE @ParamDefinition NVARCHAR(4000)
  DECLARE @BeginTime datetime2
  DECLARE @FinishTime datetime2
  DECLARE @AffectedRows int
  DECLARE @StatusCode int
  SET @ParamDefinition = STUFF((
  SELECT
    ','  AS[text()],
    collection.param.value('@parametername','sysname') AS[text()],
            ' = ' AS[text()],
    CASE WHEN
        collection.param.value('@dbtype','sysname') LIKE '%char%'
      OR
        collection.param.value('@dbtype','sysname') = 'sysname'
     THEN '''' + collection.param.value('@value','nvarchar(4000)')
           + ''''
     ELSE
        collection.param.value('@value','nvarchar(4000)')
    END AS [text()],
    SPACE(1)AS[text()],
    NULLIF( LOWER(collection.param.value('@direction','sysname')), 'input')AS[text()]
   FROM @RequestMessage.nodes(
           '/sqlobject/sqlcommand/sqlparametercollection/sqlparameter')
            AS collection(param)
   FOR XML PATH(''),TYPE).value('.','nvarchar(4000)'),1,1,'')
   DECLARE @Query NVARCHAR(4000)
   SET @Query =N'EXEC '
            + @RequestMessage.value('(/sqlobject/sqlcommand/@commandText)[1]', 'nvarchar(4000)')
            + SPACE(1)
            + isnull(@ParamDefinition,'')
      -- Declare table to hold result. This is a somewhat crude
      -- method of processing a request/result.
      -- A more elegant solution is waiting to be discovered.
   print @Query
   SET @BeginTime = CURRENT_TIMESTAMP
   SET QUERY_GOVERNOR_COST_LIMIT 0
   EXEC (@Query)
   SET @AffectedRows = @@ROWCOUNT
   SET @StatusCode = @@ERROR
   SET @FinishTime = CURRENT_TIMESTAMP
   -- Convert the result recordset to xml and pass it back to the
   -- caller (OUTPUT var).
   SET @ReturnMessage = (SELECT
   		@StatusCode as [StatusCode], @AffectedRows as [Rowcount],
   		@BeginTime as BeginAt, @FinishTime as FinishAt FOR XML PATH('WorkerReport'))
END
GO
