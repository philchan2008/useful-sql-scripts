/****** Object:  StoredProcedure [dbo].[sbp_async_sql_exe_log]    Script Date: 5/28/2025 12:14:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sbp_async_sql_exe_log]
AS
BEGIN
  SET NOCOUNT ON
  DECLARE @ReceivedDlgHandle UNIQUEIDENTIFIER;
  DECLARE @ReceivedReplyMessage XML;
  DECLARE @ReceivedReplyMessageType SYSNAME;
  WHILE (1=1)
  BEGIN
      BEGIN TRANSACTION;
      --
	  WAITFOR -- Pop the queue to get the next message for processing
      (
		RECEIVE TOP(1)
          @ReceivedDlgHandle = conversation_handle,
          @ReceivedReplyMessage = message_body,
          @ReceivedReplyMessageType = message_type_name
         FROM AsyncSqlResponseQueue
      ),TIMEOUT 5000;
      IF (@@ROWCOUNT= 0)
      BEGIN
        ROLLBACK TRANSACTION;
        BREAK
      END
      IF @ReceivedReplyMessageType = N'//AsyncSql/ResponseMessage'
      BEGIN
        --
        INSERT INTO sb_async_sql_exe_log(ch_id, exe_request, exe_result, msg_body)
            SELECT @ReceivedDlgHandle,
				@ReceivedReplyMessage.query('/ExecutionComplete/sqlobject'),
                @ReceivedReplyMessage.query('/ExecutionComplete/WorkerReport'),
                @ReceivedReplyMessage;
        --
        END CONVERSATION @ReceivedDlgHandle
      END
	  -- FOR DEBUG: SELECT * FROM sb_exe_log;
	  -- TODO: add some unexpected behaviour code here.
      COMMIT TRANSACTION;
   END -- WHILE (1=1)
END

