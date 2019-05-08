/*********************Accounts*********************/
USE [master];

-- Disable sa
ALTER LOGIN [sa] DISABLE;

-- Create new sa account
CREATE LOGIN [DBA_sa] WITH PASSWORD=N'Change_me', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF

ALTER SERVER ROLE [sysadmin] ADD MEMBER [DBA_sa]

-- Change Owner of DBA_Monitoring
ALTER AUTHORIZATION ON DATABASE::[DBA_Monitoring] TO [DBA_sa]
GO