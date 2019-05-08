/*********************Stored Procedures*********************/
USE [DBA_Monitoring];
GO

-- Archive HUK tables 
CREATE PROCEDURE [dbo].[HUK_Archive_Purge_Results]
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION;

		DECLARE @create_table NVARCHAR(MAX)
			   ,@sys_date	  DATETIME2 = SYSDATETIME()
			   ,@archive_Date DATETIME2 = DATEADD(DAY, -7, SYSDATETIME());

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Header_Block_Archive'
		)
		   )
		BEGIN
			SELECT *
			INTO HUK_Header_Block_Archive
			FROM HUK_Header_Block_Results
			WHERE collection_time <= @archive_Date;
		END;
		ELSE
		BEGIN
			INSERT INTO HUK_Header_Block_Archive
			SELECT *
			FROM HUK_Header_Block_Results
			WHERE collection_time <= @archive_Date;
		END;

		DELETE FROM HUK_Header_Block_Results
		WHERE collection_time <= @archive_Date;

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Plan_Cache_Archive'
		)
		   )
		BEGIN
			SELECT *
			INTO HUK_Plan_Cache_Archive
			FROM HUK_Plan_Cache_Results
			WHERE CheckDate <= @archive_Date;
		END;
		ELSE
		BEGIN
			INSERT INTO HUK_Plan_Cache_Archive
			SELECT *
			FROM HUK_Plan_Cache_Results
			WHERE CheckDate <= @archive_Date;
		END;

		DELETE FROM HUK_Plan_Cache_Results
		WHERE CheckDate <= @archive_Date;

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Query_Performance_Archive'
		)
		   )
		BEGIN
			SELECT *
			INTO HUK_Query_Performance_Archive
			FROM HUK_Query_Performance_Results
			WHERE collection_time <= @archive_Date;
		END;
		ELSE
		BEGIN
			INSERT INTO HUK_Query_Performance_Archive
			SELECT *
			FROM HUK_Query_Performance_Results
			WHERE collection_time <= @archive_Date;
		END;

		DELETE qp
		FROM HUK_Query_Performance_Results qp
		WHERE qp.collection_time <= @archive_Date;

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		SELECT ERROR_NUMBER()	 AS ErrorNumber
			  ,ERROR_SEVERITY()	 AS ErrorSeverity
			  ,ERROR_STATE()	 AS ErrorState
			  ,ERROR_PROCEDURE() AS ErrorProcedure
			  ,ERROR_LINE()		 AS ErrorLine
			  ,ERROR_MESSAGE()	 AS ErrorMessage;
		ROLLBACK TRANSACTION;
	END CATCH;
END;
GO

-- Clear Cached plan
CREATE PROCEDURE [dbo].[HUK_Exec_FreeProcCache] @sql_Handle NVARCHAR(200) = NULL
AS
BEGIN
	BEGIN TRY

		DECLARE @cmd NVARCHAR(MAX) = NULL
			   ,@ret NVARCHAR(MAX) = NULL;

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Audit_Execution'
		)
		   )
		BEGIN
			CREATE TABLE HUK_Audit_Execution
			(
				[user_name] NVARCHAR(250) NULL
			   ,[Execution_DateTime] DATETIME2 NOT NULL
			   ,[command_Executed] NVARCHAR(MAX) NULL
			   ,[result] NVARCHAR(MAX) NULL
			);
		END;

		IF @sql_Handle IS NOT NULL
		BEGIN
			IF SUBSTRING(@sql_Handle, 1, 2) = '0x'
			BEGIN
				SET @cmd = N'DBCC FREEPROCCACHE (' + @sql_Handle + N')';
			END;
			ELSE
			BEGIN
				SET @cmd = N'DBCC FREEPROCCACHE (0x' + @sql_Handle + N')';
			END;

			EXEC @ret = sp_executesql @statement = @cmd;

			INSERT INTO HUK_Audit_Execution
			(
				[user_name]
			   ,[Execution_DateTime]
			   ,[command_Executed]
			   ,[result]
			)
			VALUES
			(
				SYSTEM_USER, SYSDATETIME(), @cmd, @ret
			);
		END;
	END TRY
	BEGIN CATCH
		INSERT INTO HUK_Audit_Execution
		(
			[user_name]
		   ,[Execution_DateTime]
		   ,[command_Executed]
		   ,[result]
		)
		VALUES
		(
			SYSTEM_USER, SYSDATETIME(), @cmd, ERROR_MESSAGE()
		);
	END CATCH;
END;
GO

-- Kill Session
CREATE PROCEDURE [dbo].[HUK_Exec_KillSPID] @SPID INT = NULL
AS
BEGIN
	BEGIN TRY

		DECLARE @cmd NVARCHAR(MAX) = NULL
			   ,@ret NVARCHAR(MAX) = NULL;

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Audit_Execution'
		)
		   )
		BEGIN
			CREATE TABLE HUK_Audit_Execution
			(
				[user_name] NVARCHAR(250) NULL
			   ,[Execution_DateTime] DATETIME2 NOT NULL
			   ,[command_Executed] NVARCHAR(MAX) NULL
			   ,[result] NVARCHAR(MAX) NULL
			);
		END;

		IF @SPID IS NOT NULL
		BEGIN
			SET @cmd = N'KILL ' + CAST(@SPID AS NVARCHAR(20));

			EXEC @ret = sp_executesql @statement = @cmd;

			INSERT INTO HUK_Audit_Execution
			(
				[user_name]
			   ,[Execution_DateTime]
			   ,[command_Executed]
			   ,[result]
			)
			VALUES
			(
				SYSTEM_USER, SYSDATETIME(), @cmd, @ret
			);
		END;
	END TRY
	BEGIN CATCH
		INSERT INTO HUK_Audit_Execution
		(
			[user_name]
		   ,[Execution_DateTime]
		   ,[command_Executed]
		   ,[result]
		)
		VALUES
		(
			SYSTEM_USER, SYSDATETIME(), @cmd, ERROR_MESSAGE()
		);
	END CATCH;
END;
GO

-- Get header block queries
CREATE PROCEDURE [dbo].[HUK_GetHeaderBlock] @get_results TINYINT = 1
AS
BEGIN
	BEGIN TRY

		DECLARE @create_table NVARCHAR(MAX)
			   ,@sys_date	  DATETIME2 = SYSDATETIME();

		EXEC [dbo].[sp_whoisactive] @find_block_leaders = 1
								   ,@get_locks = 1
								   ,@get_plans = 1
								   ,@get_transaction_info = 1
								   ,@show_system_spids = 1
								   ,@get_avg_time = 1
								   ,@get_additional_info = 1
								   ,@delta_interval = 1
								   ,@sort_order = '[start_time] ASC'
								   ,@destination_table = '[dbo].[HUK_Header_Block_Results_temp]'
								   ,@return_schema = 1
								   ,@schema = @create_table OUTPUT;

		SELECT @create_table = REPLACE(@create_table, '<table_name>', '[dbo].[HUK_Header_Block_Results_temp]');

		EXEC sp_executesql @statement = @create_table;

		EXEC [dbo].[sp_whoisactive] @find_block_leaders = 1
								   ,@get_locks = 1
								   ,@get_plans = 1
								   ,@get_transaction_info = 1
								   ,@show_system_spids = 1
								   ,@get_avg_time = 1
								   ,@get_additional_info = 1
								   ,@delta_interval = 1
								   ,@sort_order = '[start_time] ASC'
								   ,@destination_table = '[dbo].[HUK_Header_Block_Results_temp]';

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Header_Block_Results'
		)
		   )
		BEGIN
			SELECT *
				  ,SYSTEM_USER AS user_name
			INTO dbo.HUK_Header_Block_Results
			FROM dbo.HUK_Header_Block_Results_temp;
		END;
		ELSE
		BEGIN
			INSERT INTO HUK_Header_Block_Results
			SELECT *
				  ,SYSTEM_USER
			FROM dbo.HUK_Header_Block_Results_temp;
		END;

		DROP TABLE dbo.HUK_Header_Block_Results_temp;

		IF @get_results = 1
		BEGIN
			SELECT [start_time]																AS [Start_Time]
				  ,[dd hh:mm:ss.mss]														AS [Runtime(dd hh:mm:ss.mss)]
				  ,[session_id]																AS [Session_ID]
				  ,[blocking_session_id]													AS [Blocking_Session_ID]
				  ,[blocked_session_count]													AS [blocked_session_count]
				  ,[sql_text]																AS [SQL_Text]
				  ,[host_name]																AS [Host_Name]
				  ,[login_name]																AS [Login_Name]
				  ,[database_name]															AS [Database_Name]
				  ,'EXEC [dbo].[HUK_Exec_KillSPID] @SPID = ' + CAST(session_id AS NVARCHAR) AS [Command_To_Execute]
				  ,[program_name]															AS [Program_Name]
			FROM [dbo].[HUK_Header_Block_Results]
			WHERE collection_time >= @sys_date
				  AND session_id > 50
				  AND status <> 'sleeping'
				  AND blocked_session_count <> 0;
		END;
		ELSE IF @get_results = 2
		BEGIN
			SELECT *
			FROM [dbo].[HUK_Header_Block_Results]
			WHERE collection_time >= @sys_date;
		END;

	END TRY
	BEGIN CATCH
		SELECT ERROR_NUMBER()	 AS ErrorNumber
			  ,ERROR_SEVERITY()	 AS ErrorSeverity
			  ,ERROR_STATE()	 AS ErrorState
			  ,ERROR_PROCEDURE() AS ErrorProcedure
			  ,ERROR_LINE()		 AS ErrorLine
			  ,ERROR_MESSAGE()	 AS ErrorMessage;
	END CATCH;
END;
GO

-- Get Expensive Cached Plan 
CREATE PROCEDURE [dbo].[HUK_GetPlanCache] @get_results TINYINT = 1
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION;

		DECLARE @sys_date DATETIME2 = SYSDATETIME();

		EXEC [dbo].[sp_BlitzCache] @SortOrder = 'CPU,Executions,Duration'
								  ,@OutputDatabaseName = 'Trace'
								  ,@OutputSchemaName = 'dbo'
								  ,@Top = 10
								  ,@OutputTableName = 'HUK_Plan_Cache_Results_temp';

		DECLARE @constraintName VARCHAR(128);
		SET @constraintName =
		(
			SELECT TOP 1
				   CONSTRAINT_NAME
			FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
			WHERE TABLE_NAME = 'HUK_Plan_Cache_Results_temp'
				  AND COLUMN_NAME = 'ID'
		);

		EXEC ('alter table HUK_Plan_Cache_Results_temp drop constraint "' + @constraintName + '"');

		ALTER TABLE HUK_Plan_Cache_Results_temp DROP COLUMN [ID];

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Plan_Cache_Results'
		)
		   )
		BEGIN
			SELECT *
				  ,SYSTEM_USER AS user_name
			INTO [dbo].[HUK_Plan_Cache_Results]
			FROM [dbo].[HUK_Plan_Cache_Results_temp];
		END;
		ELSE
		BEGIN
			INSERT INTO [dbo].[HUK_Plan_Cache_Results]
			SELECT *
				  ,SYSTEM_USER
			FROM [dbo].[HUK_Plan_Cache_Results_temp];
		END;

		DROP TABLE [dbo].[HUK_Plan_Cache_Results_temp];

		IF @get_results = 1
		BEGIN
			SELECT [DatabaseName]																				  AS [DatabaseName]
				  ,[AverageDuration]																			  AS [AverageDuration(ms)]
				  ,[ExecutionCount]																				  AS [ExecutionCount]
				  ,[PlanCreationTime]																			  AS [PlanCreationTime]
				  ,[LastExecutionTime]																			  AS [LastExecutionTime]
				  ,'EXEC [dbo].[HUK_FreeProcCache] @sql_handle = ''' + CONVERT(VARCHAR(MAX), SqlHandle, 2) + '''' AS [Command_To_Execute]
				  ,[QueryText]																					  AS [QueryText]
			FROM [dbo].[HUK_Plan_Cache_Results]
			WHERE CheckDate >= @sys_date;
		END;
		ELSE IF @get_results = 2
		BEGIN
			SELECT *
			FROM [dbo].[HUK_Plan_Cache_Results]
			WHERE CheckDate >= @sys_date
			ORDER BY LastExecutionTime DESC;
		END;

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		SELECT ERROR_NUMBER()	 AS ErrorNumber
			  ,ERROR_SEVERITY()	 AS ErrorSeverity
			  ,ERROR_STATE()	 AS ErrorState
			  ,ERROR_PROCEDURE() AS ErrorProcedure
			  ,ERROR_LINE()		 AS ErrorLine
			  ,ERROR_MESSAGE()	 AS ErrorMessage;
		ROLLBACK TRANSACTION;
	END CATCH;
END;
GO

-- Get Running queries
CREATE PROCEDURE [dbo].[HUK_GetQueryPerformance] @get_results TINYINT = 1
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION;

		DECLARE @create_table NVARCHAR(MAX)
			   ,@sys_date	  DATETIME2 = SYSDATETIME();

		EXEC [dbo].[sp_whoisactive] @return_schema = 1
								   ,@get_plans = 1
								   ,@get_transaction_info = 1
								   ,@show_system_spids = 1
								   ,@get_avg_time = 1
								   ,@get_additional_info = 1
								   ,@delta_interval = 1
								   ,@sort_order = '[start_time] ASC'
								   ,@destination_table = 'dbo.HUK_Query_Performance_Results_temp'
								   ,@schema = @create_table OUTPUT;

		SELECT @create_table = REPLACE(@create_table, '<table_name>', 'dbo.HUK_Query_Performance_Results_temp');

		EXEC sp_executesql @statement = @create_table;

		EXEC [dbo].[sp_whoisactive] @get_plans = 1
								   ,@get_transaction_info = 1
								   ,@show_system_spids = 1
								   ,@get_avg_time = 1
								   ,@get_additional_info = 1
								   ,@delta_interval = 1
								   ,@sort_order = '[start_time] ASC'
								   ,@destination_table = 'dbo.HUK_Query_Performance_Results_temp';

		IF (NOT EXISTS
		(
			SELECT *
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_NAME = 'HUK_Query_Performance_Results'
		)
		   )
		BEGIN
			SELECT *
				  ,SYSTEM_USER AS user_name
			INTO dbo.HUK_Query_Performance_Results
			FROM dbo.HUK_Query_Performance_Results_temp;
		END;
		ELSE
		BEGIN
			INSERT INTO HUK_Query_Performance_Results
			SELECT *
				  ,SYSTEM_USER
			FROM dbo.HUK_Query_Performance_Results_temp;
		END;

		DROP TABLE dbo.HUK_Query_Performance_Results_temp;

		IF @get_results = 1
		BEGIN
			SELECT [start_time]																AS [Start_Time]
				  ,[dd hh:mm:ss.mss]														AS [Runtime(dd hh:mm:ss.mss)]
				  ,[session_id]																AS [Session_ID]
				  ,[blocking_session_id]													AS [Blocking_Session_ID]
				  ,[host_name]																AS [Host_Name]
				  ,[login_name]																AS [Login_Name]
				  ,[database_name]															AS [Database_Name]
				  ,[program_name]															AS [Program_Name]
				  ,'EXEC [dbo].[HUK_Exec_KillSPID] @SPID = ' + CAST(session_id AS NVARCHAR) AS [Command_To_Execute]
				  ,[sql_text]																AS [SQL_text]
			FROM [dbo].[HUK_Query_Performance_Results]
			WHERE collection_time >= @sys_date
				  AND session_id > 50
			ORDER BY start_time ASC;
		END;
		ELSE IF @get_results = 2
		BEGIN
			SELECT *
			FROM [dbo].[HUK_Query_Performance_Results]
			WHERE collection_time >= @sys_date;
		END;

		COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
		SELECT ERROR_NUMBER()	 AS ErrorNumber
			  ,ERROR_SEVERITY()	 AS ErrorSeverity
			  ,ERROR_STATE()	 AS ErrorState
			  ,ERROR_PROCEDURE() AS ErrorProcedure
			  ,ERROR_LINE()		 AS ErrorLine
			  ,ERROR_MESSAGE()	 AS ErrorMessage;
		ROLLBACK TRANSACTION;
	END CATCH;
END;
GO