# SQL_Setup

Install pre-requisite modules
    -   sqlserver

Create SQL dependancy Directories
    - DATA
    - LOG
    - Tempdb
    - Monitor
    - Backup

Create SQL Server Install Configuration File
    - Paramaters will determine install process

Install SQL Server
    - Mount install media
    - start setup.exe with configuration file parameter
    - Display sa password
    - dismount install media
    - change sql server port from 1433
    - execute HUK scripts
    - execute 3PE scripts
    - Install ssms