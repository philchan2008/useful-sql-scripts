/****** Object:  StoredProcedure [dbo].[sbp_async_sql_exe_manager]    Script Date: 5/28/2025 12:10:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sbp_async_sql_exe_manager]
AS
BEGIN
  WHILE (1=1)
  BEGIN
		BEGIN TRANSACTION;
		--print N'Debug 1: Start of loop ...';
		DECLARE @ReceivedRequestDlgHandle UNIQUEIDENTIFIER;
		DECLARE @ReceivedRequestMessage XML;
		DECLARE @ReceivedRequestMessageType SYSNAME;
		WAITFOR -- Pop the request queue and retrieve the request
		(
			RECEIVE TOP(1) --1: Single processing, >1: multiple processing
			@ReceivedRequestDlgHandle = conversation_handle,
			@ReceivedRequestMessage = message_body,
			@ReceivedRequestMessageType = message_type_name
			FROM AsyncSqlRequestQueue
		), TIMEOUT 5000;
		--print N'Debug 2: @@ROWCOUNT = ' + cast(@@ROWCOUNT as nvarchar(max));
		--print N'Debug 2: @ReceivedRequestMessage = ' + cast(@ReceivedRequestMessage as nvarchar(max));
		-- We will wait for 5 seconds for a message to appear on
		-- the queue.
		-- it more efficient to cycle this sp then to create a
		-- brand new instance.
		IF (@@ROWCOUNT = 0)
		BEGIN
			ROLLBACK TRANSACTION;
			--return
			BREAK
		END
		ELSE
		BEGIN
			--print N'Debug 5: @ReceivedRequestMessageType = ' + cast(@ReceivedRequestMessageType as nvarchar(max));
			IF @ReceivedRequestMessageType = N'//AsyncSql/RequestMessage'
			BEGIN
				DECLARE @ReturnMessage XML;
				BEGIN TRY
				-- Instruct worker to execute the request.
				--print N'Debug 3: @ReceivedRequestMessage = ' + cast(@ReceivedRequestMessage as nvarchar(max));
				EXEC sbp_async_sql_exe_worker @ReceivedRequestMessage, @ReturnMessage OUTPUT;
				--print CAST(@ReceivedRequestMessage as nvarchar(max))
				--print N'Debug 4: @ResponseMessage = ' + cast(@ReturnMessage as nvarchar(max));
				END TRY
				BEGIN CATCH
					-- Record errors.
					declare @error int, @message varchar(4000), @xstate int;
			        select @error = ERROR_NUMBER(),
			               @message = ERROR_MESSAGE(),
			               @xstate = XACT_STATE();
					rollback
					raiserror ('sbp_async_sql_exe_worker: %d: %s', 16, 1, @error, @message)
					--
					INSERT INTO sb_async_sql_exe_err(ch_id,exe_request,err_msg )
					SELECT @ReceivedRequestDlgHandle, @ReceivedRequestMessage, @message
				    RETURN -1
				END CATCH;
				-- Send reply with results.
				--print N'Debug 6 '
				DECLARE @ResponseMessage XML;
				SET @ResponseMessage = (SELECT @ReceivedRequestMessage,
											   @ReturnMessage
										FOR XML PATH('ExecutionComplete'));
				--print N'Debug 7a: ' + cast(@ResponseMessage as nvarchar(max));
				SEND ON CONVERSATION @ReceivedRequestDlgHandle
				MESSAGE TYPE [//AsyncSql/ResponseMessage]
					( @ResponseMessage );
				--print N'Debug 7b '
			END
			ELSE IF @ReceivedRequestMessageType =
					N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
				OR @ReceivedRequestMessageType =
					N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
			BEGIN
				--print N'Debug 8: End Converstion'
				END CONVERSATION @ReceivedRequestDlgHandle
			END
			--print N'Debug 9: Commit tran ' + cast(@@trancount as nvarchar(max));
			COMMIT TRANSACTION;
		END
	END --WHILE (1=1)
END
GO
