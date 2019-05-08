Param(
    $Help                   = 0
    # directories
    ,$USERDBDIR             = "F:\SQL_Data"
    ,$INSTANCEDIR           = "C:\Program Files\Microsoft SQL Server"
    ,$USERDBLOGDIR          = "L:\SQL_Logs"
    ,$TEMPDBLOGDIR          = "L:\SQL_Logs"
    ,$TEMPDBDIR             = "T:\SQL_Tempdb"
    ,$BACKUPDIR             = "X:\SQL_Backup"
    ,$Monitor               = "X:\SQL_Monitor"
    # tempdb
    ,$TempDB_FileCount      = "8"
    ,$TempDB_FileSize       = "1024"
    ,$TempDB_FileGrowth     = "1024"
    ,$TempDB_LogFileSize    = "256"
    ,$TempDB_LogFileGrowth  = "64"
    # features
    ,$FeatureList           = "SQLENGINE,CONN,IS"
    ,$Collation             = "Latin1_General_CI_AS"
    ,$SysAdminAccounts      = "Hachette\SEC-DBA"
    # Networking
    ,$SQL_Port              = "1533"
    # Accounts
    ,$SA_Password           = ([char[]]([char]35..[char]95) + ([char]33) + ([char[]]([char]97..[char]126)) + 0..9 | Sort-Object {Get-Random})[0..19] -join ''
    # SSMS
    ,$Install_SSMS          = $False

    ,[Parameter(Mandatory=$True)][ValidateNotNullorEmpty()]
    $InstanceName
    
    ,[Parameter(Mandatory=$True)][ValidateNotNullorEmpty()]
    $ServiceAccount

    ,[Parameter(Mandatory=$True)][ValidateNotNullorEmpty()]
    $ServicePassword
)

Function Invoke-Help {
    Param(
        $Help
    )
    if ($Help -eq 1){
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host "Parameter List and the respective defaults:" -ForegroundColor Yellow

        Write-Host "# Accounts" -ForegroundColor Green
        Write-Host "    -SA_Password                Auto Generated"
        Write-Host "    -InstanceName               Mandatory Parameter, no Default" -ForegroundColor Cyan
        Write-Host "    -ServiceAccount             Mandatory Parameter, no Default" -ForegroundColor Cyan
        Write-Host "    -ServicePassword            Mandatory Parameter, no Default" -ForegroundColor Cyan

        Write-Host "# Directories" -ForegroundColor Green
        Write-Host "    -INSTANCEDIR                Default: 'C:\Program Files\Microsoft SQL Server'"
        Write-Host "    -USERDBDIR                  Default: 'F:\SQL_Data'"
        Write-Host "    -USERDBLOGDIR               Default: 'L:\SQL_Logs'"
        Write-Host "    -TEMPDBLOGDIR               Default: 'L:\SQL_Logs'"
        Write-Host "    -TEMPDBDIR                  Default: 'T:\SQL_Tempdb'"
        Write-Host "    -BACKUPDIR                  Default: 'X:\SQL_Backup'"
        Write-Host "    -Monitor                    Default: 'X:\SQL_Monitor'"

        Write-Host "# TempDB" -ForegroundColor Green
        Write-Host "    -TempDB_FileCount           Default: '8'"
        Write-Host "    -TempDB_FileSize            Default: '1024'"
        Write-Host "    -TempDB_FileGrowth          Default: '1024'"
        Write-Host "    -TempDB_LogFileSize         Default: '256'"
        Write-Host "    -TempDB_LogFileGrowth       Default: '64'"

        Write-Host "# Features" -ForegroundColor Green 
        Write-Host "    -FeatureList                Default: 'SQLENGINE,CONN,IS'"
        Write-Host "        -Options, comma seperated list - SQLENGINE,CONN,IS,FullText,RS"
        Write-Host "    -Collation                  Default: 'Latin1_General_CI_AS'"
        Write-Host "    -SysAdminAccounts           Default: 'Hachette\SEC-DBA'"

        Write-Host "# Networking" -ForegroundColor Green    
        Write-Host "    -SQL_Port                   Default: '1533'"

        Write-Host "# SSMS" -ForegroundColor Green
        Write-Host "    -Install_SSMS               Default: `$False"

        Write-Host "# Example" -ForegroundColor Green
        Write-Host ".\HUK_Install_SQL_V1.ps1 -InstanceName ""DBADEVSQL"" -ServiceAccount ""Hachette\DBA.dev.sqlsvc"" -ServicePassword ""Password"""
        Write-Host ".\HUK_Install_SQL_V1.ps1 -InstanceName ""ROYNONPRODPDB"" -ServiceAccount ""Hachette\royalty.np.sqlsvc"" -ServicePassword ""Password"" -Collation ""SQL_Latin1_General_CP1_CI_AS"""
        Write-Host ".\HUK_Install_SQL_V1.ps1 -InstanceName ""IVTPRODSQL"" -ServiceAccount ""hachette\ivt.prod.sqlsvc"" -ServicePassword ""Password"" -FeatureList ""SQLENGINE,CONN,IS,FullText,RS"""
        Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        exit
    }
}

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('INFO','WARN','ERR')]
        [String]$Severity = 'INFO'
    )

    $DateTime = (Get-Date -f G)

    "[$DateTime]" + " | " + "[$Severity]" + " - " + $Message | Out-File $LogFile -Append
    "[$DateTime]" + " | " + "[$Severity]" + " - " + $Message | Out-Host
} # Write-Log

Function New-Log {  
    Param(
        [string]$LogFile
    )
    try{
        if(Test-Path $LogFile){
            Write-Log -Message "Log file already exists $LogFile" -Severity INFO
        }
        Else{
            New-Item $LogFile -ItemType file
            Write-Log -Message "Created Log File $LogFile" -Severity INFO
        }
    }
    catch{
        Get-Error $_
    }
} # New-Log

function Get-Error {
    param(
        [CmdletBinding()]
        [Parameter(Mandatory=$true)] [System.Management.Automation.ErrorRecord]$PSError
    )

    if ($PSError) {
        #Process an error
        Write-Log -Message "Error Count: $($PSError.Count)" -Severity ERR
        Write-Log -Message $PSError.Exception.Message -Severity ERR

        $err = $PSError.Exception.InnerException
        while ($err.InnerException) {
            Write-Log -Message $err.InnerException.Message -Severity ERR
            $err = $err.InnerException
        }
        Throw
    }
} # Get-Error

Function Install-PreRequisite{
    Try{
        #install pre-requisite powershell modules
        Write-Log -Message "Attempting to install pre-requisite modules..."
        Install-Module -Name SqlServer -Force -SkipPublisherCheck

        Write-Log -Message "pre-requisites installed successfully."
    }
    catch{
        Get-Error $_
    }
} # Invoke-Install_PreRequisite

Function New-Directories{
    param(
        $DirectoryList
    )

    Try{
        # Loop through each of the directories
        Foreach($Directory in $DirectoryList){
            # Test if directory exists
            if((Test-Path -path $Directory) -eq $False){
                # if not, create it
                Write-Log -message "Creating Directory: $Directory" -severity INFO
                New-Item -path $Directory -ItemType directory -ErrorAction Stop
            }
            elseif(Test-Path -path $Directory){
                Write-Log -message "Directory Already Exists: $Directory, Deleting subfolders and files" -severity INFO
                
                # Delete subfolders and files, these will interfere with SQL Server instalation
                get-childitem -path $Directory -recurse | foreach-object{
                    Write-Log -message "Deleting file: $($_.Fullname)"  -severity INFO
                    Remove-item -path $_.Fullname -Recurse -force -ErrorAction Stop
                }
            }
        }
    }
    catch{
        Get-Error $_
    }
} # Invoke-Create_Directories

Function New-Configuration_File{
    Try{
        Write-Log -message "Creating SQL Server Configuration File..." -Severity INFO

        # replace each of the delimited entries with the respective parameter passed into the script
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_INSTANCEDIR>",$INSTANCEDIR)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_SA_Password>",$SA_Password)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<Feature_List>",$FeatureList)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<Instance_Name>",$InstanceName)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<Instance_ID>",$InstanceName)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_Collation>",$Collation)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<TempDB_FileCount>",$TempDB_FileCount)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<TempDB_FileSize>",$TempDB_FileSize)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<TempDB_FileGrowth>",$TempDB_FileGrowth)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<TempDB_LogFileSize>",$TempDB_LogFileSize)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<TempDB_LogFileGrowth>",$TempDB_LogFileGrowth)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_BACKUPDIR>",$BACKUPDIR)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_USERDBDIR>",$USERDBDIR)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_USERDBLOGDIR>",$USERDBLOGDIR)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_TEMPDBDIR>",$TEMPDBDIR)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_TEMPDBLOGDIR>",$TEMPDBLOGDIR)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_SysAdminAccounts>",$SysAdminAccounts)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_ServiceAccount>",$ServiceAccount)
        $Staging_ConfigurationData = $Staging_ConfigurationData.replace("<SQL_ServicePassword>",$ServicePassword)

        # Write altered configuration to file
        Write-Log -Message "Writing to File..." -severity INFO
        $Staging_ConfigurationData | Out-file "HUK_ConfigurationFile.ini"
        Write-Log -Message "File: HUK_ConfigurationFile.ini" -severity INFO
    }
    catch{
        Get-Error $_
    }
} # Invoke-Create_ConfigurationFile

Function Invoke-SQLServer_Setup{
    Try{
        # Find the .ISO file in the scripts directory and store the full path and name
        Write-Log -Message "Obtaining SQL Server Install ISO..." -Severity INFO
        $fullpath = (Get-childitem -path "." | Where-Object{$_.Name -like "*SQL*.iso"}).FullName
        
        # Test path of iso
        if (Test-Path -path $fullpath){
            # Mount the install media
            Write-Log -Message "Mounting SQL Server Install ISO: $fullpath" -Severity INFO
            Mount-DiskImage -imagePath $fullpath
        
            # Find the mounted medias drive letter path
            Write-Log -Message "Obtaining ISO Drive Letter..." -Severity INFO
            $driveLetter = (Get-Volume | Where-Object{($_.DriveType -eq "CD-ROM") -and ($_.FileSystemLabel -like "*SQL*")}).DriveLetter
            $SetupPath = "$Driveletter`:\setup.exe"

            # Test the install media setup.exe path
            Write-Log -Message "Testing SQL Server Setup.exe path: ""$SetupPath""" -Severity INFO

            if (Test-Path -path $SetupPath){
                # Start the setup with the argument configurationfile and wait for the process to finish before proceeding
                Write-Log -Message "Starting SQL Server Setup.exe with args: ""/ConfigurationFile=""HUK_ConfigurationFile.ini""""" -Severity INFO
                start-process -FilePath $SetupPath -ArgumentList "/ConfigurationFile=""HUK_ConfigurationFile.ini""" -Wait
                Write-Log -Message "Completed SQL Server Installation"

                # Print the sa password to the console, not writing it to the log file
                Write-Host "/************************************************/"
                Write-Host "sa password: $SA_Password"
                Write-Host "/************************************************/"

                # Dismount the install media
                Write-Log -Message "Dismounting SQL Server ISO: $Driveletter" -Severity INFO
                Dismount-DiskImage -imagePath $fullpath
            }
            else{
                Write-Log -Message "Failed to find setup.exe in the mounted media" -Severity ERR
                Read-Host "exiting"
                exit
            }
        }
        else{
            Write-Log -Message "Failed to obtain SQL Server ISO, check if it exists in the scripts directory" -Severity ERR
            Read-Host "exiting"
            exit
        }
    }
    catch{
        Get-Error $_
    }
} # Invoke-SQLServer_Setup

Function Set-SQLServerPort {
    Try{
        Write-Log -Message "Attempting to change port for ""$env:COMPUTERNAME\$InstanceName"" to $SQL_Port..." -Severity INFO
        # List of assemblies needed to perform port change
        $Assemblies = "Microsoft.SqlServer.Management.Common","Microsoft.SqlServer.Smo","Microsoft.SqlServer.SqlWmiManagement"
        
        # Loop through each assembly and load it
        Foreach ($Assembly in $Assemblies) {
            Write-Log -Message "Importing Assembly: $Assembly" -Severity INFO
            $Assembly = [Reflection.Assembly]::LoadWithPartialName($Assembly)
        }

        # Create Windows Management Instrumentation Objects for SQL Server and for tcp attributes
        $WMIObject = new-object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer')
        $tcp = $WMIObject.getsmoobject("ManagedComputer[@Name='" + $env:computername + "']/ServerInstance[@Name='$InstanceName']/ServerProtocol[@Name='Tcp']")
        $MachineObject = $WMIObject.getsmoobject("ManagedComputer[@Name='" + $env:computername + "']/ServerInstance[@Name='$InstanceName']/ServerProtocol[@Name='Tcp']/IPAddress[@Name='IPAll']")
        
        # Set dynamic port to empty string
        Write-Log -Message "Attempting to change TCP dynamic ports value to string::empty" -Severity INFO
        $MachineObject.IPAddressProperties[0].value = ""

        # Set Static port to the parameters value
        Write-Log -Message "Attempting to change TCP static port value to $SQL_Port" -Severity INFO
        $MachineObject.IPAddressProperties[1].value = $SQL_Port
        
        # Commit the above changes
        Write-Log -Message "Commiting changes..." -Severity INFO
        $tcp.Alter()
        
        # Restart SQL Server Service (and in turn the tcp service), this will allow the change to take effect.
        Write-Log -Message "Restarting SQL Service ""MSSQL`$$InstanceName""" -Severity INFO
        Restart-Service -Name "MSSQL`$$InstanceName" -Force
    }
    catch{
        Get-Error $_
    }
} # Invoke-Alter_SQLServerPort

Function Install-SQL_Scripts{
    param(
        [Parameter(Mandatory=$True)][ValidateNotNullorEmpty()]
        $directory
        ,[Parameter(Mandatory=$True)][ValidateNotNullorEmpty()]
        $database
    )

    Try{
        # Attempt to connect to SQL Server Instance
        Write-Log -message "Attemping to connect to ""$env:COMPUTERNAME\$InstanceName""" -severity INFO

        if (Invoke-sqlcmd -ServerInstance "$env:COMPUTERNAME\$InstanceName" -query "Select 1"){
            # Test the directory parameter passed in
            Write-Log -message "Getting Scripts from: $directory" -severity INFO
            if(Test-Path -path $directory){
                # Exclude any directories that we dont want to check
                if(($directory -like "*3PE*") -or ($directory -like "*HUK*")){
                    # Loop through each file (non recursive)
                    get-childitem -path $directory | Foreach-Object {
                        # Store the content of the file in a temporary variable
                        $sql_cmd = get-content -path $_.fullname | Out-String

                        # Execute the SQL under the database specified in the parameter
                        Write-Log -Message "Executing ""$($_.Name)"" under Database ""$database""..." -severity INFO
                        invoke-sqlcmd -ServerInstance "$env:COMPUTERNAME\$InstanceName" -Database $database -query $sql_cmd -QueryTimeout 65000 -ConnectionTimeout 65000
                    }
                }
                else{
                    Write-Log -Message "Unknown Folder: $($_.Fullname)" -severity WARN
                }
            }
            else{   
                Write-Log -Message "Scripts Directory Invalid: $directory" - ERR
                Read-Host "exiting"
                exit
            }
        }
        else{
            Write-Log -Message "Unable to connect to SQL Server" -Severity ERR
            Read-Host "exiting"
            exit
        }
    }
    catch{
        Get-Error $_
    }
} # Invoke-Install_Scripts

Function Install-SSMS {
    param(
        [bool]$install
    )
    Try{
        if ($install){
            Write-Log -Message "Attempting to install SQL Server Management Studio..." -severity INFO
            if(test-path ".\SSMS-Setup-ENU.exe")
            {
                Start-Process -FilePath ".\SSMS-Setup-ENU.exe" -argumentList "/install /passive /norestart" -wait
                Write-Log -Message "Completed install of SQL Server Management Studio" -severity INFO
            }
            else{
                Write-Log -Message "Unable to find SSMS install executable" -severity ERR
            }
        }
        else{
            Write-Log -Message "Skipping install of SQL Server Management Studio" -severity INFO
        }
    }
    catch{
        Get-Error $_
    }
} # Invoke-Install_SSMS

# Store unaltered configuration file with <> delimited for replacements later
$Staging_ConfigurationData = @"
[OPTIONS]
ACTION="Install"
SUPPRESSPRIVACYSTATEMENTNOTICE="True"
IACCEPTROPENLICENSETERMS="True"
IAcceptSQLServerLicenseTerms="True"
ENU="True"
QUIET="True"
QUIETSIMPLE="False"
UpdateEnabled="False"
USEMICROSOFTUPDATE="False"
INDICATEPROGRESS="True"
INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"
INSTANCEDIR="<SQL_INSTANCEDIR>"
FILESTREAMLEVEL="0"
ENABLERANU="False"
SQLSVCINSTANTFILEINIT="False"
ADDCURRENTUSERASSQLADMIN="False"
TCPENABLED="1"
NPENABLED="1"
SECURITYMODE="SQL"
SAPWD="<SQL_SA_Password>"
FEATURES=<Feature_List>
INSTANCENAME="<Instance_Name>"
INSTANCEID="<Instance_ID>"
SQLCOLLATION="<SQL_Collation>"
SQLTEMPDBFILECOUNT="<TempDB_FileCount>"
SQLTEMPDBFILESIZE="<TempDB_FileSize>"
SQLTEMPDBFILEGROWTH="<TempDB_FileGrowth>"
SQLTEMPDBLOGFILESIZE="<TempDB_LogFileSize>"
SQLTEMPDBLOGFILEGROWTH="<TempDB_LogFileGrowth>"
SQLBACKUPDIR="<SQL_BACKUPDIR>"
SQLUSERDBDIR="<SQL_USERDBDIR>"
SQLUSERDBLOGDIR="<SQL_USERDBLOGDIR>"
SQLTEMPDBDIR="<SQL_TEMPDBDIR>"
SQLTEMPDBLOGDIR="<SQL_TEMPDBLOGDIR>"
SQLSYSADMINACCOUNTS="<SQL_SysAdminAccounts>"
SQLSVCSTARTUPTYPE="Automatic"
SQLSVCACCOUNT="<SQL_ServiceAccount>"
SQLSVCPASSWORD="<SQL_ServicePassword>"
ISTELSVCSTARTUPTYPE="Automatic"
ISTELSVCACCT="NT Service\SSISTELEMETRY130"
ISSVCSTARTUPTYPE="Automatic"
ISSVCACCOUNT="NT Service\MsDtsServer130"
AGTSVCSTARTUPTYPE="Automatic"
AGTSVCACCOUNT="NT Service\SQLAgent$<Instance_Name>"
SQLTELSVCSTARTUPTYPE="Automatic"
SQLTELSVCACCT="NT Service\SQLTELEMETRY$<Instance_Name>"
BROWSERSVCSTARTUPTYPE="Automatic"
"@

# Set log file path
$LogFile = ".\log.txt"
# remove non unique entries
$DirectoryList = @($USERDBDIR,$USERDBLOGDIR,$TEMPDBLOGDIR,$TEMPDBDIR,$Monitor,$BACKUPDIR) | Select-Object -uniq

Invoke-Help -help $help
New-Log -LogFile $LogFile
Install-PreRequisite
New-Directories -DirectoryList $DirectoryList
New-Configuration_File
Invoke-SQLServer_Setup
Set-SQLServerPort
Install-SSMS -install $Install_SSMS

# Install HUK scripts e.g. Databases, Alerts, Extended Events, backups etc...
Install-SQL_Scripts -Directory ".\HUK" -Database "master"

# Install Third party script e.g. Ola, Brent Ozar, Adam Mechanic
Install-SQL_Scripts -Directory ".\3PE" -Database "DBA_Monitoring"

Write-Log -Message "Completed Installation" -severity INFO