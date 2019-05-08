/*********************Mail Profile*********************/
-- Enable Database Mail extended sp
EXEC sp_configure 'show advanced options', '1';
RECONFIGURE;

EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;

EXEC sp_configure 'show advanced options', '0';
RECONFIGURE;

-- Change the max file size parameter to 35mb
EXEC msdb.dbo.sysmail_configure_sp 'MaxFileSize', '35000000';

-- Variables
DECLARE @huk_email_address	 NVARCHAR(64)  = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(50)) + N'@hachette.co.uk'
	   ,@huk_operator_name	 NVARCHAR(100) = N'DBA'
	   ,@huk_sending_address NVARCHAR(100) = N'HUK.DBA@hachette.co.uk'
	   ,@huk_profile_name	 NVARCHAR(64)  = N'HUK_Mail_Profile'
	   ,@huk_account_name	 NVARCHAR(32)  = N'HUK_Mail_Account'
	   ,@huk_description	 NVARCHAR(256) = N'Mail account for administrative e-mail'
	   ,@huk_display_name	 NVARCHAR(128) = CAST(@@SERVERNAME AS NVARCHAR(50)) + N' Automated Mailer'
	   ,@huk_mail_server	 NVARCHAR(64)  = CASE
												WHEN @@SERVERNAME LIKE 'DCS01%' THEN N'cas01.hachette.hluk.net'
												WHEN @@SERVERNAME LIKE 'GBDCS01%' THEN N'cas01.hachette.hluk.net'
												WHEN @@SERVERNAME LIKE 'DCS02%' THEN N'cas02.hachette.hluk.net'
												WHEN @@SERVERNAME LIKE 'GBDCS02%' THEN N'cas02.hachette.hluk.net'
												ELSE 'cas02.hachette.hluk.net'
											 END;

-- Create Mail Account
EXEC msdb.dbo.sysmail_add_account_sp @account_name = @huk_account_name
									,@description = @huk_description
									,@email_address = @huk_email_address
									,@display_name = @huk_display_name
									,@mailserver_name = @huk_mail_server;

-- Create Database Mail profile  
EXECUTE msdb.dbo.sysmail_add_profile_sp @profile_name = @huk_profile_name
									   ,@description = @huk_description;

-- Add the account to the profile  
EXECUTE msdb.dbo.sysmail_add_profileaccount_sp @profile_name = @huk_profile_name
											  ,@account_name = @huk_account_name
											  ,@sequence_number = 1;

-- Operator
EXEC msdb.dbo.sp_add_operator @name = @huk_operator_name
							 ,@enabled = 1
							 ,@email_address = @huk_sending_address
							 ,@category_name = N'[Uncategorized]';

-- Set Failsafe Operator
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator = @huk_operator_name
								 ,@notificationmethod = 1;

-- Set SQL Agent Mail Profile
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder = 1
										,@databasemail_profile = @huk_profile_name
										,@use_databasemail = 1;

-- Send test email
EXEC msdb.dbo.sp_notify_operator @profile_name = @huk_profile_name
								,@name = @huk_operator_name
								,@subject = N'Test Notification'
								,@body = N'This is a test notification.';

GO