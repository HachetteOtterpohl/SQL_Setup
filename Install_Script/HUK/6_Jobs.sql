/***************************************************************Jobs***************************************************************/

IF NOT EXISTS
(
	SELECT name
FROM msdb.dbo.syscategories
WHERE name = N'[DBA_DB_Maintenance]'
	AND category_class = 1
)
BEGIN
	EXEC msdb.dbo.sp_add_category @class = N'JOB'
											   ,@type = N'LOCAL'
											   ,@name = N'[DBA_DB_Maintenance]';
END;

IF NOT EXISTS
(
	SELECT name
FROM msdb.dbo.syscategories
WHERE name = N'[DBA_DB_Reliablity]'
	AND category_class = 1
)
BEGIN
	EXEC msdb.dbo.sp_add_category @class = N'JOB'
											   ,@type = N'LOCAL'
											   ,@name = N'[DBA_DB_Reliablity]';

END;


-- Long Running Query job
USE [msdb];
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'LongRunningQuery-Alert', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'DBA_sa', 
		@notify_email_operator_name=N'DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CollectData', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec HUK_GetQueryPerformance', 
		@database_name=N'DBA_Monitoring', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

-- Tempdb Alert Job
USE [msdb];
BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'tempDBUsage - Alert'
									  ,@enabled = 1
									  ,@notify_level_eventlog = 0
									  ,@notify_level_email = 2
									  ,@notify_level_netsend = 0
									  ,@notify_level_page = 0
									  ,@delete_level = 0
									  ,@description = N'No description available.'
									  ,@category_name = N'[DBA_DB_Maintenance]'
									  ,@owner_login_name = N'DBA_sa'
									  ,@notify_email_operator_name = N'DBA'
									  ,@job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId
										  ,@step_name = N'DBA - TempDB Exceeds Threshold'
										  ,@step_id = 1
										  ,@cmdexec_success_code = 0
										  ,@on_success_action = 1
										  ,@on_success_step_id = 0
										  ,@on_fail_action = 2
										  ,@on_fail_step_id = 0
										  ,@retry_attempts = 0
										  ,@retry_interval = 0
										  ,@os_run_priority = 0
										  ,@subsystem = N'TSQL'
										  ,@command = N'
 
  
	  DECLARE @xml NVARCHAR(MAX)DECLARE @body NVARCHAR(MAX) DECLARE @pname NVARCHAR(MAX) 
	SET @xml =CAST((
 
	  SELECT  
	  ss.program_name AS ''td'','''',
	  ss.host_name AS ''td'','''',
	  su.Session_ID AS ''td'','''',
	  ss.Login_Name AS ''td'','''', 
	  rq.Command AS ''td'','''',
	  su.Task_Alloc AS ''td'','''',
	  su.Task_Dealloc AS ''td'','''',
	 --Find Offending Query Text:
	  (SELECT SUBSTRING(text, rq.statement_start_offset/2 + 1,
	   (CASE WHEN statement_end_offset = -1 
			 THEN LEN(CONVERT(nvarchar(max),text)) * 2 
			 ELSE statement_end_offset 
	   END - rq.statement_start_offset)/2)
	  FROM sys.dm_exec_sql_text(rq.sql_handle)) AS ''td''
	  ,
		(SELECT TOP 1
	qp.query_plan AS QueryPlan
	FROM sys.dm_exec_cached_plans AS cp
	CROSS APPLY sys.dm_exec_query_plan(rq.plan_handle) AS qp) AS ''td''

	  FROM      
	  (SELECT su.session_id, su.request_id,
	   SUM(su.internal_objects_alloc_page_count + su.user_objects_alloc_page_count) AS Task_Alloc,
	   SUM(su.internal_objects_dealloc_page_count + su.user_objects_dealloc_page_count) AS Task_Dealloc
	  FROM sys.dm_db_task_space_usage AS su 
	  GROUP BY session_id, request_id) AS su, 
	   sys.dm_exec_sessions AS ss, 
	   sys.dm_exec_requests AS rq
	  WHERE su.session_id = rq.session_id 
	   AND(su.request_id = rq.request_id) 
	   AND (ss.session_id = su.session_id)
	   AND su.session_id > 50  --sessions 50 and below are system sessions and should not be killed
	   AND su.session_id <> (SELECT @@SPID)
		--Eliminates current user session from results
	 ORDER BY su.task_alloc DESC  --The largest "Task Allocation/Deallocation" is probably the query that is causing the db growth

	 FOR XML PATH (''tr''), ELEMENTS ) AS NVARCHAR(MAX))


	insert  into [DBA_Monitoring].[dbo].[tempdb_Data]
	  SELECT  
	  ss.program_name AS ''td'','''',
	  ss.host_name AS ''td'','''',
	  su.Session_ID AS ''td'','''',
	  ss.Login_Name AS ''td'','''', 
	  rq.Command AS ''td'','''',
	  su.Task_Alloc AS ''td'','''',
	  su.Task_Dealloc AS ''td'','''',
	 --Find Offending Query Text:
	  (SELECT SUBSTRING(text, rq.statement_start_offset/2 + 1,
	   (CASE WHEN statement_end_offset = -1 
			 THEN LEN(CONVERT(nvarchar(max),text)) * 2 
			 ELSE statement_end_offset 
	   END - rq.statement_start_offset)/2)
	  FROM sys.dm_exec_sql_text(rq.sql_handle)) AS ''td''
	  ,
		(SELECT TOP 1
	qp.query_plan AS QueryPlan
	FROM sys.dm_exec_cached_plans AS cp
	CROSS APPLY sys.dm_exec_query_plan(rq.plan_handle) AS qp) AS ''td''

	  FROM      
	  (SELECT su.session_id, su.request_id,
	   SUM(su.internal_objects_alloc_page_count + su.user_objects_alloc_page_count) AS Task_Alloc,
	   SUM(su.internal_objects_dealloc_page_count + su.user_objects_dealloc_page_count) AS Task_Dealloc
	  FROM sys.dm_db_task_space_usage AS su 
	  GROUP BY session_id, request_id) AS su, 
	   sys.dm_exec_sessions AS ss, 
	   sys.dm_exec_requests AS rq
	  WHERE su.session_id = rq.session_id 
	   AND(su.request_id = rq.request_id) 
	   AND (ss.session_id = su.session_id)
	   AND su.session_id > 50  --sessions 50 and below are system sessions and should not be killed
	   AND su.session_id <> (SELECT @@SPID)
		--Eliminates current user session from results
	 ORDER BY su.task_alloc DESC 
	--BODY OF EMAIL - Edit for your environment

	SET @body =''<html><H1>Tempdb Large Query</H1>
	<body bgcolor=white>The query below with the <u>highest task allocation 
	and high task deallocation</u> is most likely growing the tempdb. NOTE: Please <b>do not kill system tasks</b> 
	that may be showing up in the table below.
	<U>Only kill the query that is being run by a user and has the highest task allocation/deallocation.</U><BR> 
	<BR>
	To stop the query from running, do the following:<BR>
	<BR>
	1. Open <b>SQL Server Management Studio</b><BR>
	2. <b>Connect to database engine using Windows Authentication</b><BR>
	3. Click on <b>"New Query"</b><BR>
	4. Type <b>KILL [type session_id number from table below];</b> - It should look something like this:  KILL 537; <BR>
	5. Hit the <b>F5</b> button to run the query<BR>
	<BR>
	This should kill the session/query that is growing the large query.  It will also kick the individual out of the application.<BR>
	You have just stopped the growth of the tempdb, without having to restart SQL Services, and have the large-running query available for your review.
	<BR>
	<BR>
	<table border = 2><tr>
	<th>program_name</th>
	<th>host_name</th>
	<th>Session_ID</th>
	<th>Login_Name</th>
	<th>Command</th>
	<th>Task_Alloc</th>
	<th>Task_Dealloc</th>
	<th>Query_Text</th>
	<th>QueryPlan</th>
	</tr>'' 
	SET @body = @body + @xml +''</table></body></html>''
	--Send email to recipients:
	SET @pname = (select name from msdb.dbo.sysmail_profile)
	EXEC msdb.dbo.sp_send_dbmail
	@recipients =N''HUK.DBA@hachette.co.uk'', --Insert the TO: email Address here
	--Insert the CC: Address here; If multiple addresses, separate them by a comma (,)
	@body = @body,
	@body_format =''HTML'',
	@importance =''High'',
	@subject =''tempDB Usage High'', --Provide a subject for the email
	@profile_name = @pname--Database Mail profile here
	'
										  ,@database_name = N'tempdb'
										  ,@flags = 0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId
										 ,@start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
											,@server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
EndSave:
GO

-- HUK_GetQueryPerformance
BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'HUK_GetQueryPerformance'
									  ,@enabled = 1
									  ,@notify_level_eventlog = 0
									  ,@notify_level_email = 0
									  ,@notify_level_netsend = 0
									  ,@notify_level_page = 0
									  ,@delete_level = 0
									  ,@description = N'No description available.'
									  ,@category_name = N'[DBA_DB_Maintenance]'
									  ,@owner_login_name = N'DBA_sa'
									  ,@job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId
										  ,@step_name = N'HUK_GetQueryPerformance'
										  ,@step_id = 1
										  ,@cmdexec_success_code = 0
										  ,@on_success_action = 1
										  ,@on_success_step_id = 0
										  ,@on_fail_action = 2
										  ,@on_fail_step_id = 0
										  ,@retry_attempts = 0
										  ,@retry_interval = 0
										  ,@os_run_priority = 0
										  ,@subsystem = N'TSQL'
										  ,@command = N'EXEC HUK_GetQueryPerformance @get_results = 0'
										  ,@database_name = N'DBA_Monitoring'
										  ,@flags = 0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId
										 ,@start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
											,@server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
EndSave:
GO

-- DBCC CheckDB

BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'DBBC_CheckDB'
									  ,@enabled = 1
									  ,@notify_level_eventlog = 0
									  ,@notify_level_email = 2
									  ,@notify_level_netsend = 0
									  ,@notify_level_page = 0
									  ,@delete_level = 0
									  ,@description = N'DBCC CheckDB (Reliablity)'
									  ,@category_name = N'[DBA_DB_Reliablity]'
									  ,@owner_login_name = N'DBA_sa'
									  ,@notify_email_operator_name = N'DBA'
									  ,@job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId
										  ,@step_name = N'CheckDB'
										  ,@step_id = 1
										  ,@cmdexec_success_code = 0
										  ,@on_success_action = 1
										  ,@on_success_step_id = 0
										  ,@on_fail_action = 2
										  ,@on_fail_step_id = 0
										  ,@retry_attempts = 0
										  ,@retry_interval = 0
										  ,@os_run_priority = 0
										  ,@subsystem = N'TSQL'
										  ,@command = N'EXEC dbo.DatabaseIntegrityCheck @Databases = N''ALL_DATABASES''
								,@CheckCommands = N''CHECKDB''
								,@TimeLimit = 600
								,@LogToTable = N''Y''
								,@Execute = N''Y'''
										  ,@database_name = N'DBA_Monitoring'
										  ,@flags = 0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId
										 ,@start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @jobId
											  ,@name = N'Weekly'
											  ,@enabled = 1
											  ,@freq_type = 8
											  ,@freq_interval = 1
											  ,@freq_subday_type = 1
											  ,@freq_subday_interval = 0
											  ,@freq_relative_interval = 0
											  ,@freq_recurrence_factor = 1
											  ,@active_start_date = 20190101
											  ,@active_end_date = 99991231
											  ,@active_start_time = 233000
											  ,@active_end_time = 235959;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
											,@server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
EndSave:
GO

/*********************Backup Solution*********************/
-- Backup Full
BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'Backup_Full'
									  ,@enabled = 1
									  ,@notify_level_eventlog = 0
									  ,@notify_level_email = 2
									  ,@notify_level_netsend = 0
									  ,@notify_level_page = 0
									  ,@delete_level = 0
									  ,@description = N'Full Database Backup'
									  ,@category_name = N'Database Maintenance'
									  ,@owner_login_name = N'DBA_sa'
									  ,@notify_email_operator_name = N'DBA'
									  ,@job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId
										  ,@step_name = N'Full_Backup'
										  ,@step_id = 1
										  ,@cmdexec_success_code = 0
										  ,@on_success_action = 1
										  ,@on_success_step_id = 0
										  ,@on_fail_action = 2
										  ,@on_fail_step_id = 0
										  ,@retry_attempts = 0
										  ,@retry_interval = 0
										  ,@os_run_priority = 0
										  ,@subsystem = N'TSQL'
										  ,@command = N'EXECUTE [DBA_Monitoring].[dbo].[DatabaseBackup] 
	@Databases = ''ALL_DATABASES''
	,@BackupType = ''FULL''
	,@Verify = ''Y''
	,@CleanupTime = 168
	,@CleanupMode = ''AFTER_BACKUP''
	,@Compress = ''Y''
	,@Description = ''Full Database Backup''
	,@FileExtensionFull = ''bak''
	,@DirectoryStructure = ''{ServerName}${InstanceName}{DirectorySeparator}{BackupType}{DirectorySeparator}{DatabaseName}''
	,@AvailabilityGroupDirectoryStructure = ''{AvailabilityGroupName}{DirectorySeparator}{BackupType}{DirectorySeparator}{DatabaseName}''
	,@FileName = ''{DatabaseName}_{BackupType}_{year}{Month}{Day}_{Hour}{Minute}.{FileExtension}''
	,@LogToTable = ''Y''
	,@Execute = ''Y'';'
										  ,@database_name = N'DBA_Monitoring'
										  ,@flags = 8;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId
										 ,@start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @jobId
											  ,@name = N'Daily'
											  ,@enabled = 1
											  ,@freq_type = 4
											  ,@freq_interval = 1
											  ,@freq_subday_type = 1
											  ,@freq_subday_interval = 0
											  ,@freq_relative_interval = 0
											  ,@freq_recurrence_factor = 0
											  ,@active_start_date = 20190101
											  ,@active_end_date = 99991231
											  ,@active_start_time = 193000
											  ,@active_end_time = 235959
											  ,@schedule_uid = N'876929a2-085e-4cd3-9b5d-8e9d142fcc02';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
											,@server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
EndSave:
GO

--Backup Diff
BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

IF NOT EXISTS
(
	SELECT name
FROM msdb.dbo.syscategories
WHERE name = N'Database Maintenance'
	AND category_class = 1
)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class = N'JOB'
											   ,@type = N'LOCAL'
											   ,@name = N'Database Maintenance';
	IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		GOTO QuitWithRollback;
END;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'Backup_Differential'
									  ,@enabled = 1
									  ,@notify_level_eventlog = 0
									  ,@notify_level_email = 2
									  ,@notify_level_netsend = 0
									  ,@notify_level_page = 0
									  ,@delete_level = 0
									  ,@description = N'No description available.'
									  ,@category_name = N'Database Maintenance'
									  ,@owner_login_name = N'DBA_sa'
									  ,@notify_email_operator_name = N'DBA'
									  ,@job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId
										  ,@step_name = N'Differential_Backup'
										  ,@step_id = 1
										  ,@cmdexec_success_code = 0
										  ,@on_success_action = 1
										  ,@on_success_step_id = 0
										  ,@on_fail_action = 2
										  ,@on_fail_step_id = 0
										  ,@retry_attempts = 0
										  ,@retry_interval = 0
										  ,@os_run_priority = 0
										  ,@subsystem = N'TSQL'
										  ,@command = N'EXECUTE [DBA_Monitoring].[dbo].[DatabaseBackup] 
	@Databases		= ''USER_DATABASES''
	,@backuptype		= ''DIFF''
	,@Verify			= ''Y''
	,@CleanupTime		= 26
	,@CleanupMode		= ''AFTER_BACKUP''
	,@Compress		= ''Y''
	,@Description		= ''Differential Database Backup''
	,@FileExtensionDiff		= ''bak''
	,@DirectoryStructure = ''{ServerName}${InstanceName}{DirectorySeparator}{BackupType}{DirectorySeparator}{DatabaseName}''
	,@AvailabilityGroupDirectoryStructure = ''{AvailabilityGroupName}{DirectorySeparator}{BackupType}{DirectorySeparator}{DatabaseName}''
	,@FileName = ''{DatabaseName}_{BackupType}_{year}{Month}{Day}_{Hour}{Minute}.{FileExtension}''
	,@LogToTable		= ''Y''
	,@execute		= ''Y'''
										  ,@database_name = N'DBA_Monitoring'
										  ,@flags = 0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId
										 ,@start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @jobId
											  ,@name = N'Every 2 Hours'
											  ,@enabled = 1
											  ,@freq_type = 4
											  ,@freq_interval = 1
											  ,@freq_subday_type = 8
											  ,@freq_subday_interval = 2
											  ,@freq_relative_interval = 0
											  ,@freq_recurrence_factor = 0
											  ,@active_start_date = 20190101
											  ,@active_end_date = 99991231
											  ,@active_start_time = 1000
											  ,@active_end_time = 235959
											  ,@schedule_uid = N'4c824aac-a733-4539-ac82-4e9b3d474338';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
											,@server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
EndSave:
GO

--Backup Transactional Log
BEGIN TRANSACTION;
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

DECLARE @jobId BINARY(16);
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name = N'Backup_Transaction'
									  ,@enabled = 1
									  ,@notify_level_eventlog = 0
									  ,@notify_level_email = 2
									  ,@notify_level_netsend = 0
									  ,@notify_level_page = 0
									  ,@delete_level = 0
									  ,@description = N'No description available.'
									  ,@category_name = N'[DBA_DB_Maintenance]'
									  ,@owner_login_name = N'DBA_sa'
									  ,@notify_email_operator_name = N'DBA'
									  ,@job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id = @jobId
										  ,@step_name = N'Transaction_Backup'
										  ,@step_id = 1
										  ,@cmdexec_success_code = 0
										  ,@on_success_action = 1
										  ,@on_success_step_id = 0
										  ,@on_fail_action = 2
										  ,@on_fail_step_id = 0
										  ,@retry_attempts = 0
										  ,@retry_interval = 0
										  ,@os_run_priority = 0
										  ,@subsystem = N'TSQL'
										  ,@command = N'EXECUTE [DBA_Monitoring].[dbo].[DatabaseBackup] 
	@Databases		= ''USER_DATABASES''
	,@backuptype		= ''LOG''
	,@Verify			= ''Y''
	,@CleanupTime		= 26
	,@CleanupMode		= ''AFTER_BACKUP''
	,@Compress		= ''Y''
	,@Description		= ''Transaction Log Backup''
	,@FileExtensionLog		= ''trn''
	,@DirectoryStructure = ''{ServerName}${InstanceName}{DirectorySeparator}{BackupType}{DirectorySeparator}{DatabaseName}''
	,@AvailabilityGroupDirectoryStructure = ''{AvailabilityGroupName}{DirectorySeparator}{BackupType}{DirectorySeparator}{DatabaseName}''
	,@FileName		= ''{DatabaseName}_{year}{Month}{Day}_{Hour}{Minute}.{FileExtension}''
	,@LogToTable		= ''Y''
	,@execute		= ''Y'''
										  ,@database_name = N'DBA_Monitoring'
										  ,@flags = 0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId
										 ,@start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id = @jobId
											  ,@name = N'Every 15 Minutes'
											  ,@enabled = 1
											  ,@freq_type = 4
											  ,@freq_interval = 1
											  ,@freq_subday_type = 4
											  ,@freq_subday_interval = 15
											  ,@freq_relative_interval = 0
											  ,@freq_recurrence_factor = 0
											  ,@active_start_date = 20190101
											  ,@active_end_date = 99991231
											  ,@active_start_time = 2500
											  ,@active_end_time = 235959
											  ,@schedule_uid = N'9504e7ff-0c84-4267-8d23-061050b3b1cf';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId
											,@server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0)
	GOTO QuitWithRollback;
COMMIT TRANSACTION;
GOTO EndSave;
QuitWithRollback:
IF (@@TRANCOUNT > 0)
	ROLLBACK TRANSACTION;
EndSave:
GO