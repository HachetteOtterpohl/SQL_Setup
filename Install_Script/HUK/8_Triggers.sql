/*********************Trigger*********************/
USE [msdb];
-- Job Change Monitor
GO
CREATE TRIGGER [dbo].[tr_SysJobs_enabled] ON [dbo].[sysjobs]
FOR UPDATE
AS
SET NOCOUNT ON;

DECLARE @UserName	 VARCHAR(50)
	   ,@HostName	 VARCHAR(50)
	   ,@JobName	 VARCHAR(100)
	   ,@New_Enabled INT
	   ,@Old_Enabled INT
	   ,@Bodytext	 VARCHAR(200)
	   ,@SubjectText VARCHAR(200)
	   ,@Servername	 VARCHAR(50);

SELECT @UserName = SYSTEM_USER;
SELECT @HostName = HOST_NAME();
SELECT @New_Enabled = enabled FROM Inserted;
SELECT @Old_Enabled = enabled FROM Deleted;
SELECT @JobName = name FROM Inserted;
SELECT @Servername = @@SERVERNAME;

IF @New_Enabled <> @Old_Enabled
BEGIN

	IF @New_Enabled = 1
	BEGIN
		SET @Bodytext = 'ServerName: ' + @Servername + CHAR(13) + 'User: ' + @UserName + CHAR(13) + 'Hostname: ' + @HostName + CHAR(13) + 'ENABLED SQL Job [' + @JobName + ']' + CHAR(13) + 'Time: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
		SET @SubjectText = @Servername + ' : [' + @JobName + '] has been ENABLED at ' + CONVERT(VARCHAR(20), GETDATE(), 120);
	END;

	IF @New_Enabled = 0
	BEGIN
		SET @Bodytext = 'ServerName: ' + @Servername + CHAR(13) + 'User: ' + @UserName + CHAR(13) + 'Hostname: ' + @HostName + CHAR(13) + 'DISABLED SQL Job [' + @JobName + ']' + CHAR(13) + 'Time: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
		SET @SubjectText = @Servername + ' : [' + @JobName + '] has been DISABLED at ' + CONVERT(VARCHAR(20), GETDATE(), 120);
	END;

	SET @SubjectText = 'SQL Job on ' + @SubjectText;

	EXEC msdb.dbo.sp_send_dbmail @recipients = 'HUK.DBA@hachette.co.uk'
								,@body = @Bodytext
								,@subject = @SubjectText;

END;

ALTER TABLE [dbo].[sysjobs] ENABLE TRIGGER [tr_SysJobs_enabled];
