/*********************Variables*********************/
DECLARE @MonitorPath		NVARCHAR(MAX)
		,@path				NVARCHAR(255)
		,@sql_cmd			NVARCHAR(MAX);

EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer',N'BackupDirectory', @path OUTPUT, 'no_output' 

SET @MonitorPath = SUBSTRING(@path,1,3) + 'SQL_Monitor\'

DECLARE @LongRunningQueryPath NVARCHAR(MAX) = @MonitorPath + N'LongRunningQuery.xel';
DECLARE @DeadlockPath		  NVARCHAR(MAX) = @MonitorPath + N'DeadlockMonitor.xel';
DECLARE @TempdbSpillPath	  NVARCHAR(MAX) = @MonitorPath + N'tempdb_spill.xel';

/*********************Extended Events*********************/
USE [master];

-- Waits + lock graph
SET @sql_cmd = N'
CREATE EVENT SESSION [LongRunningQuery]
ON SERVER
	ADD EVENT sqlserver.sql_statement_completed
	(SET collect_statement = (1)
	 ACTION
	 (
		 package0.callstack
		,package0.process_id
		,sqlos.task_time
		,sqlserver.client_app_name
		,sqlserver.client_hostname
		,sqlserver.client_pid
		,sqlserver.database_id
		,sqlserver.plan_handle
		,sqlserver.query_hash
		,sqlserver.query_plan_hash
		,sqlserver.session_id
		,sqlserver.sql_text
		,sqlserver.tsql_frame
		,sqlserver.tsql_stack
		,sqlserver.username
	 )
	 WHERE ([package0].[greater_than_int64]([duration], (10000)))
	)
	ADD TARGET package0.event_file
	(SET filename = N''' + @LongRunningQueryPath + N''', max_file_size = (10))
	WITH
	(
	MAX_MEMORY = 4096KB
   ,EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
   ,MAX_DISPATCH_LATENCY = 30 SECONDS
   ,MAX_EVENT_SIZE = 0KB
   ,MEMORY_PARTITION_MODE = NONE
   ,TRACK_CAUSALITY = OFF
   ,STARTUP_STATE = ON
);';

EXEC sp_executesql @statement = @sql_cmd;

-- Deadlocks + waits
SET @sql_cmd = N'CREATE EVENT SESSION [DeadlockMonitor]
ON SERVER
	ADD EVENT sqlserver.xml_deadlock_report
	(ACTION
	 (
		 package0.callstack
		,package0.event_sequence
		,package0.process_id
		,sqlos.task_time
		,sqlserver.client_app_name
		,sqlserver.client_connection_id
		,sqlserver.client_hostname
		,sqlserver.client_pid
		,sqlserver.context_info
		,sqlserver.database_id
		,sqlserver.database_name
		,sqlserver.nt_username
		,sqlserver.plan_handle
		,sqlserver.query_hash
		,sqlserver.query_plan_hash
		,sqlserver.request_id
		,sqlserver.session_id
		,sqlserver.session_nt_username
		,sqlserver.sql_text
		,sqlserver.transaction_id
		,sqlserver.transaction_sequence
		,sqlserver.tsql_frame
		,sqlserver.tsql_stack
		,sqlserver.username
	 )
	)
	ADD TARGET package0.event_file
	(SET filename = N''' + @DeadlockPath + N''', max_file_size = (10))
WITH
(
	MAX_MEMORY = 4096KB
   ,EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
   ,MAX_DISPATCH_LATENCY = 30 SECONDS
   ,MAX_EVENT_SIZE = 0KB
   ,MEMORY_PARTITION_MODE = NONE
   ,TRACK_CAUSALITY = OFF
   ,STARTUP_STATE = ON
);';

EXEC sp_executesql @statement = @sql_cmd;

-- TempDB spill + query plan
SET @sql_cmd = N'CREATE EVENT SESSION [tempdb_spill]
ON SERVER
	ADD EVENT sqlserver.hash_spill_details
	(SET collect_reserved1 = (1)
		,collect_reserved2 = (1)
		,collect_reserved3 = (1)
		,collect_reserved4 = (1)
	 ACTION
	 (
		 package0.collect_cpu_cycle_time
		,package0.last_error
		,sqlos.numa_node_id
		,sqlos.task_time
		,sqlserver.client_hostname
		,sqlserver.database_name
		,sqlserver.plan_handle
		,sqlserver.query_hash
		,sqlserver.query_hash_signed
		,sqlserver.query_plan_hash
		,sqlserver.query_plan_hash_signed
		,sqlserver.sql_text
		,sqlserver.username
	 )
	)
   ,ADD EVENT sqlserver.hash_warning
	(ACTION
	 (
		 package0.last_error
		,sqlos.task_elapsed_quantum
		,sqlos.task_time
		,sqlserver.client_hostname
		,sqlserver.client_pid
		,sqlserver.database_id
		,sqlserver.database_name
		,sqlserver.plan_handle
		,sqlserver.query_hash
		,sqlserver.query_hash_signed
		,sqlserver.query_plan_hash
		,sqlserver.query_plan_hash_signed
		,sqlserver.sql_text
		,sqlserver.tsql_frame
		,sqlserver.tsql_stack
		,sqlserver.username
	 )
	)
   ,ADD EVENT sqlserver.sort_warning
	(ACTION
	 (
		 package0.event_sequence
		,package0.process_id
		,sqlos.numa_node_id
		,sqlos.task_elapsed_quantum
		,sqlos.task_time
		,sqlos.worker_address
		,sqlserver.client_app_name
		,sqlserver.client_connection_id
		,sqlserver.client_hostname
		,sqlserver.client_pid
		,sqlserver.database_id
		,sqlserver.database_name
		,sqlserver.nt_username
		,sqlserver.plan_handle
		,sqlserver.query_hash
		,sqlserver.query_hash_signed
		,sqlserver.query_plan_hash
		,sqlserver.query_plan_hash_signed
		,sqlserver.request_id
		,sqlserver.server_instance_name
		,sqlserver.server_principal_name
		,sqlserver.session_id
		,sqlserver.session_nt_username
		,sqlserver.sql_text
		,sqlserver.transaction_id
		,sqlserver.transaction_sequence
		,sqlserver.tsql_stack
		,sqlserver.username
	 )
	)
	ADD TARGET package0.event_file
	(SET FILENAME = N''' + @TempdbSpillPath + N''', max_file_size = (10))
WITH
(
	MAX_MEMORY = 4096KB
   ,EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
   ,MAX_DISPATCH_LATENCY = 30 SECONDS
   ,MAX_EVENT_SIZE = 0KB
   ,MEMORY_PARTITION_MODE = NONE
   ,TRACK_CAUSALITY = OFF
   ,STARTUP_STATE = ON
);';

EXEC sp_executesql @statement = @sql_cmd;

ALTER EVENT SESSION LongRunningQuery ON SERVER STATE = START
GO
ALTER EVENT SESSION DeadlockMonitor ON SERVER STATE = START
GO
ALTER EVENT SESSION tempdb_spill ON SERVER STATE = START
GO
ALTER EVENT SESSION AlwaysOn_health ON SERVER STATE = START
GO