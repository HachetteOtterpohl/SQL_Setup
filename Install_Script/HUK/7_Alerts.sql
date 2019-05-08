/***************************************************************Alerts***************************************************************/

-- Long Running Transaction alert
USE [msdb];
IF (EXISTS(SELECT name FROM msdb.dbo.sysalerts WHERE name = N'LongRunnningQuery'))
	EXEC msdb.dbo.sp_delete_alert @name = N'LongRunnningQuery';

EXEC msdb.dbo.sp_add_alert @name = N'LongRunnningQuery'
						  ,@message_id = 0
						  ,@severity = 0
						  ,@enabled = 1
						  ,@delay_between_responses = 300
						  ,@include_event_description_in = 1
						  ,@notification_message = N'Longest Transaction Running Time'
						  ,@category_name = N'[Uncategorized]'
						  ,@performance_condition = N'Transactions|Longest Transaction Running Time||>|300 seconds';
GO

-- Tempdb usage alert
USE [msdb];
IF (EXISTS(SELECT name FROM msdb.dbo.sysalerts WHERE name = N'TempDB Usage'))
	EXEC msdb.dbo.sp_delete_alert @name = N'TempDB Usage';

EXEC msdb.dbo.sp_add_alert @name = N'TempDB Usage'
							,@message_id = 0
							,@severity = 0
							,@enabled = 1
							,@delay_between_responses = 0
							,@include_event_description_in = 1
							,@category_name = N'[Uncategorized]'
							,@performance_condition = N'Databases|Data File(s) Size (KB)|tempdb|>|52428800';


EXEC msdb.dbo.sp_add_notification @alert_name = N'TempDB Usage'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 1;

-- Deadlock Alert
USE [msdb];
IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'Deadlock')) 
	EXEC msdb.dbo.sp_delete_alert @name = N'Deadlock';

EXEC msdb.dbo.sp_add_alert @name = N'Deadlock'
							,@message_id = 1205
							,@severity = 0
							,@enabled = 1
							,@delay_between_responses = 0
							,@include_event_description_in = 1
							,@category_name = N'[Uncategorized]';


EXEC msdb.dbo.sp_add_notification @alert_name = N'Deadlock'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 1;

-- Transaction Log Error Alert
USE [msdb];
IF (EXISTS(SELECT name FROM msdb.dbo.sysalerts WHERE name = N'Transaction Log Error'))
	EXEC msdb.dbo.sp_delete_alert @name = N'Transaction Log Error';

EXEC msdb.dbo.sp_add_alert @name = N'Transaction Log Error'
							,@message_id = 0
							,@severity = 0
							,@enabled = 1
							,@delay_between_responses = 600
							,@include_event_description_in = 1
							,@category_name = N'[Uncategorized]'
							,@performance_condition = N'Databases|Percent Log Used|_Total|>|90';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Transaction Log Error'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 1;

-- CPU Usage Threshold Exceeded
USE [msdb];
IF (EXISTS(SELECT name FROM msdb.dbo.sysalerts WHERE name = N'CPU Usage Threshold Exceeded'))
	EXEC msdb.dbo.sp_delete_alert @name = N'Transaction Log Error';

EXEC msdb.dbo.sp_add_alert @name = N'CPU Usage Threshold Exceeded'
						  ,@message_id = 0
						  ,@severity = 0
						  ,@enabled = 1
						  ,@delay_between_responses = 0
						  ,@include_event_description_in = 1
						  ,@category_name = N'[Uncategorized]'
						  ,@performance_condition = N'Resource Pool Stats|CPU usage %|internal|>|95'
						  ,@job_name = 'HUK_GetQueryPerformance';

EXEC msdb.dbo.sp_add_notification @alert_name=N'CPU Usage Threshold Exceeded'
								 ,@operator_name=N'DBA'
								 ,@notification_method = 1

--Alert for Severe Errors
EXEC msdb.dbo.sp_add_alert @name = N'Severity 016'
						  ,@message_id = 0
						  ,@severity = 16
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 016'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 017'
						  ,@message_id = 0
						  ,@severity = 17
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 017'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 018'
						  ,@message_id = 0
						  ,@severity = 18
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 018'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 019'
						  ,@message_id = 0
						  ,@severity = 19
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 019'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 020'
						  ,@message_id = 0
						  ,@severity = 20
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 020'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 021'
						  ,@message_id = 0
						  ,@severity = 21
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 021'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 022'
						  ,@message_id = 0
						  ,@severity = 22
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 022'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 023'
						  ,@message_id = 0
						  ,@severity = 23
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 023'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 024'
						  ,@message_id = 0
						  ,@severity = 24
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 024'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;

EXEC msdb.dbo.sp_add_alert @name = N'Severity 025'
						  ,@message_id = 0
						  ,@severity = 25
						  ,@enabled = 1
						  ,@delay_between_responses = 60
						  ,@include_event_description_in = 1
						  ,@job_id = N'00000000-0000-0000-0000-000000000000';

EXEC msdb.dbo.sp_add_notification @alert_name = N'Severity 025'
								 ,@operator_name = N'DBA'
								 ,@notification_method = 7;