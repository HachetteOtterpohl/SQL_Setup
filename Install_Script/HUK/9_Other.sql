/*********************Other*********************/
-- Enable logging of deadlock event
IF((SELECT is_event_logged FROM master.sys.messages WHERE message_id = 1205 AND language_id = 1033) = 0)
	EXEC master..sp_altermessage 1205, 'WITH_LOG', true;

-- Enable Query store for compatible databases
DECLARE @name NVARCHAR(MAX)
	   ,@cmd  NVARCHAR(MAX);

DECLARE my_cursor CURSOR FOR
SELECT name FROM sys.sysdatabases WHERE name NOT IN ( 'master', 'model', 'msdb', 'tempdb' ) AND name NOT LIKE '%ReportServer%' AND cmptlevel >= 130;

OPEN my_cursor;
FETCH NEXT FROM my_cursor INTO @name;

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @cmd = N'ALTER DATABASE ' + @name + N' SET QUERY_STORE = ON';

	EXEC sp_executesql @statement = @cmd;

	FETCH NEXT FROM my_cursor INTO @name;
END;

CLOSE my_cursor;
DEALLOCATE my_cursor;

-- sp_configure settings, comment out as needed  
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
GO

-- Determine memory allocation depending on CPU Count and Total RAM
DECLARE @OS_TotalMemory INT
	   ,@OS_CPUCount	INT
	   ,@OS_Reserved	INT
	   ,@SQL_Malloc		INT;

SELECT @OS_TotalMemory = CAST(total_physical_memory_kb AS INT) / 1024 / 1024 FROM sys.dm_os_sys_memory;
SELECT @OS_CPUCount = cpu_count FROM sys.dm_os_sys_info;
SELECT @OS_Reserved = 4;
SELECT @SQL_Malloc = ((@OS_TotalMemory - (@OS_CPUCount * 0.5) - @OS_Reserved) - (@OS_TotalMemory - (@OS_CPUCount * 0.5) - @OS_Reserved) % 4) * 1024;
EXEC sp_configure 'max server memory', @SQL_Malloc;

-- change parallelism depending on core count
IF @OS_CPUCount >= 8
BEGIN
	EXEC sp_configure 'max degree of parallelism', 8;
END
ELSE
BEGIN
	EXEC sp_configure 'max degree of parallelism', @OS_CPUCount;
END

EXEC sp_configure 'cost threshold for parallelism', 50;

-- default to backup compression
EXEC sp_configure 'backup compression default', 1;

GO
RECONFIGURE WITH OVERRIDE;
GO
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE WITH OVERRIDE;
GO

--Alter Model Database log file initial size and growth
IF (SELECT SUBSTRING(CAST(SERVERPROPERTY('productversion') AS NVARCHAR), 1, CHARINDEX('.', CAST(SERVERPROPERTY('productversion') AS NVARCHAR)) - 1)) >= 12 --SQL Server 2014
BEGIN
	ALTER DATABASE model MODIFY FILE(NAME = modellog, SIZE = 4500MB, FILEGROWTH = 1000MB);
END
ELSE
BEGIN
	ALTER DATABASE model MODIFY FILE(NAME = modellog, SIZE = 1000MB, FILEGROWTH = 1000MB);
END

-- Change retention Policy for SQL Server Agent History
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=100000, @jobhistory_max_rows_per_job=10000

-- Execute Backup jobs to prevent transaction log backup errors
EXEC msdb.dbo.sp_start_job N'Backup_Full'
