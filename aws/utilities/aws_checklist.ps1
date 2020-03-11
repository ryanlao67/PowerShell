################################################
# NC_Windows_PreAccess_QA.ps1
################################################
# Change Log
# May 16, 2016 RL: * Initial Create
# June 12, 2016 RL: Main function done
# June 15, 2016 RL: Add local account checking
# June 15, 2016 RL: Fix some algorithms
################################################

# Define log types
$ERROR_LOG = "C:\temp\qa_error.log"
$INFO_LOG = "C:\temp\qa_info.log"

# Create a temp folder and Remove it first if exists
if (Test-Path "C:\Temp")
{
    Remove-Item C:\Temp\ -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
}
Sleep 2
New-Item C:\Temp -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# Check Server information
Function chksrvinfo
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "Server Information" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    
    #Get FQDN information
    $sysinfo = Get-WmiObject -Class Win32_ComputerSystem
    If ($sysinfo.Domain -eq 'WORKGROUP')
    {
        $FQDN = $sysinfo.Name
    }
    Else
    {
        $FQDN = “{0}.{1}” -f $sysinfo.Name, $sysinfo.Domain
    }
    "-Server Name: " + $FQDN | Out-File -filepath $INFO_LOG -Append
    
    If ($FQDN -notmatch 'srv-' -OR $FQDN -notmatch 'SRV-')
    {
        "The server name '" + $FQDN + "' does not match our naming convention standard." |  Out-File -filepath $ERROR_LOG -Append
        Write-Host "The server name '" $FQDN "' does not match our naming convention standard." -Foregroundcolor Yellow
    }
    
    # Get OS information
    $OSinfo = Get-CimInstance Win32_OperatingSystem
    "-OS Name: " + $OSinfo.Caption | Out-File -filepath $INFO_LOG -Append
    "-OS Version: " + $OSinfo.Version | Out-File -filepath $INFO_LOG -Append
    
    # Get CPU information
    $CPUInfo = Get-WmiObject -class win32_processor
    "-Number of CPU cores: " + $CPUInfo.numberofcores | Out-File -filepath $INFO_LOG -Append
    "-Number of Logical Processors: " + $CPUInfo.numberoflogicalprocessors | Out-File -filepath $INFO_LOG -Append
    
    # Get Memory information
    $MemInfo = Get-WMIObject -class win32_physicalmemory | `
    Select-Object -Property @{Name='Total Physical Memory(GB)'; Expression={$_.capacity/1GB}}
    "-Total Physical Memory: " + $MemInfo.'Total Physical Memory(GB)' + " GB" | out-file -filepath $INFO_LOG -Append
    $PageFileSize = Get-WmiObject -Class "Win32_PageFileUsage" -namespace "root\CIMV2" | `
    Select-Object -Property @{Name='Total PageFile Size(GB)'; Expression={$_.AllocatedBaseSize/1024}}
    "-Total Pagefile Size: " + $PageFileSize.'Total PageFile Size(GB)' + " GB" | out-file -filepath $INFO_LOG -Append

    # Get IP Information
    $IPInfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE
    $IPv4 = $IPInfo | Select-Object -Property IPAddress | Where {$_.IPAddress -notmatch "::"}
    "-IP Address: " + $IPInfo.IPAddress | out-file -filepath $INFO_LOG -Append
    "-Default Gateway: " + $IPInfo.DefaultIPGateway | out-file -filepath $INFO_LOG -Append
    "-DNS Server: " + $IPInfo.DNSServerSearchOrder | out-file -filepath $INFO_LOG -Append

    # Print Result
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Server Information" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "-Server Name:" $FQDN
    Write-Host "-OS Name:" $OSinfo.Caption
    Write-Host "-OS Version:" $OSinfo.Version
    Write-Host "-Number of CPU cores:" $CPUInfo.numberofcores
    Write-Host "-Number of Logical Processors:" $CPUInfo.numberoflogicalprocessors
    Write-Host "-Total Physical Memory:" $MemInfo.'Total Physical Memory(GB)' "GB"
    Write-Host "-Total Pagefile Size:" $PageFileSize.'Total PageFile Size(GB)' "GB"
    If ($PageFileSize.'Total PageFile Size(GB)' -lt $MemInfo.'Total Physical Memory(GB)')
    {
        "Current pagefile size(" + $PageFileSize.'Total PageFile Size(GB)' + " GB) is smaller than physical memory(" + $MemInfo.'Total Physical Memory(GB)' + " GB) which does not match our setup standard." |  Out-File -filepath $ERROR_LOG -Append
        Write-Host "Current pagefile size("$PageFileSize.'Total PageFile Size(GB)' "GB ) is smaller than physical memory("$MemInfo.'Total Physical Memory(GB)' "GB ) which does not match our setup standard." -Foregroundcolor Yellow
    }
    Write-Host "-IP Address:" $IPInfo.IPAddress
    Write-Host "-Default Gateway:" $IPInfo.DefaultIPGateway
    Write-Host "-DNS Server:" $IPInfo.DNSServerSearchOrder
    
    # Get disk information
    "-Disk Information: " | out-file -filepath $INFO_LOG -Append
    Write-Host "-Disk Information: "
    $VolumeInfo = Get-WmiObject win32_logicaldisk
    For ($i=0; $i -lt $VolumeInfo.Count; $i++)
    {
        $Size = [Math]::round($VolumeInfo[$i].Size / 1GB)
        "--Volume: " + $VolumeInfo[$i].DeviceID + " | Size: " + $Size + " GB" | out-file -filepath $INFO_LOG -Append
        Write-Host "--Volume:" $VolumeInfo[$i].DeviceID"| Size:"$Size"GB"
    }
    
    # Get local account information
    "-Local Account Information: " | out-file -filepath $INFO_LOG -Append
    Write-Host "-Local Account Information: "
    $Lusr = @(Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'")
    For ($j=0; $j -lt $Lusr.Count; $j++)
    {
        "--Account Name: " + $Lusr[$j].Name + " | Disabled: " + $Lusr[$j].Disabled | out-file -filepath $INFO_LOG -Append
        Write-Host "--Account Name:"$Lusr[$j].Name"| Disabled:"$Lusr[$j].Disabled
    }
}

# Check AWS Information
Function chkAWS
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "AWS EC2 Information" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    
    #AMI Information
    $AMIINFO = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/ami-id"
    "-AMI ID: " + $AMIINFO.Content | Out-File -filepath $INFO_LOG -Append
    
    #Instance Type
    $InstanceType = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/instance-type"
    "-Instance Type: " + $InstanceType.Content | Out-File -filepath $INFO_LOG -Append
    
    #IP Information
    $PrivateIP = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/local-ipv4"
    $PublicIP = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/public-ipv4"
    "-Private IP: " + $PrivateIP.Content | Out-File -filepath $INFO_LOG -Append
    If($PublicIP.Content -eq $NULL)
    {
        "-Public IP: No public IP address assigned to this instance" | Out-File -filepath $INFO_LOG -Append
        $PublicIPInfo = "-Public IP: No public IP address assigned to this instance"
    }
    Else
    {
        "-Public IP: " + $PublicIP.Content | Out-File -filepath $INFO_LOG -Append
        $PublicIPInfo = "-Public IP: " + $PublicIP.Content
    }
    
    #Public DNS
    $PublicDNS = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/public-hostname"
    If($PublicDNS.Content -eq "")
    {
        "-Public DNS: No public DNS mapping to this instance" | Out-File -filepath $INFO_LOG -Append
        $PublicDNSInfo = "-Public DNS: No public DNS mapping to this instance"
    }
    Else
    {
        "-PublicDNS: " + $PublicDNS.Content | Out-File -filepath $INFO_LOG -Append
        $PublicDNSInfo = "-PublicDNS: " + $PublicDNS.Content
    }
    
    #Instance Region
    $Region = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/placement/availability-zone"
    "-Region: " + $Region.Content | Out-File -filepath $INFO_LOG -Append
    
    #Security Group
    $SG = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/security-groups"
    "-Security Group: " + $SG.Content | Out-File -filepath $INFO_LOG -Append

    # Print Result
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "AWS EC2 Information" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "-AMI ID:" $AMIINFO.Content
    Write-Host "-Instance Type:" $InstanceType.Content
    Write-Host "-Private IP:" $PrivateIP.Content
    Write-Host $PublicIPInfo
    Write-Host $PublicDNSInfo
    Write-Host "-Region:" $Region.Content
    Write-Host "-Security Group:" $SG.Content
    
    #EBS Information
    "-EBS Information: " | out-file -filepath $INFO_LOG -Append
    Write-Host "-EBS Information:"
    $EBSRaw = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/block-device-mapping/"
    $EBSInfo = $EBSRaw.Content
    $EBS = @($EBSInfo.split("`r`n"))
    For ($i=0; $i -lt $EBS.Count; $i++)
    {
        $EBSP = $EBS[$i]
        $EBSR = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/block-device-mapping/$EBSP"
        "--EBS mount point: " + $EBS[$i] + " - " + $EBSR.Content | Out-File -filepath $INFO_LOG -Append
        Write-Host "--EBS mount point:"$EBS[$i]"-"$EBSR.Content
    }
}

# Check Windows update
Function chkUpdate
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "Windows Update" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Windows Update" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    $WinUS = Get-WmiObject Win32_Service -Filter 'Name="wuauserv"'
    If ($WinUS.State -eq 'Running')
    {
        $winup = New-Object -com “Microsoft.Update.AutoUpdate”
        $Notify0 = "0.Not configured"
        $Notify1 = "1.Disabled"
        $Notify2 = "2.Notify before download"
        $Notify3 = "3.Notify before installation"
        $Notify4 = "4.Scheduled installation"
        $NotifyLvl = $(Switch ($winup.Settings.NotificationLevel)
        {
            0 {$Notify0; break}
            1 {$Notify1; break}
            2 {$Notify2; break}
            3 {$Notify3; break}
            4 {$Notify4; break}
        })
        $Day0 = "Every day"
        $Day1 = "Every Sunday"
        $Day2 = "Every Monday"
        $Day3 = "Every Tuesday"
        $Day4 = "Every Wednesday"
        $Day5 = "Every Thursday"
        $Day6 = "Every Friday"
        $Day7 = "Every Saturday"
        $DaySW = $(Switch ($winup.Settings.ScheduledInstallationDay)
        {
            0 {$Day0; break}
            1 {$Day1; break}
            2 {$Day2; break}
            3 {$Day3; break}
            4 {$Day4; break}
            5 {$Day5; break}
            6 {$Day6; break}
            7 {$Day7; break}
        })
        $ScheduleTime = $winup.Settings.ScheduledInstallationTime
        "Windows Update is running on the server." | Out-File -filepath $INFO_LOG -Append
        "The notification level is: " + $NotifyLvl | Out-File -filepath $INFO_LOG -Append
        "Schedule to install update on: " + $DaySW | Out-File -filepath $INFO_LOG -Append
        "Schedule to install update at: " + $ScheduleTime + "O'Clock" | Out-File -filepath $INFO_LOG -Append
        
        # Print Result
        Write-Host "Windows Update is running on the server."
        Write-Host "The notification level is:" $NotifyLvl
        Write-Host "Schedule to install update on:" $DaySW
        Write-Host "Schedule to install update at:" $ScheduleTime "O'Clock"
    }
    Else
    {
        "Windows Update is not running on the server." | Out-File -filepath $ERROR_LOG -Append
        "Windows Update is not running on the server." | Out-File -filepath $INFO_LOG -Append
        Write-Host "Windows Update is not running on the server." -ForegroundColor Yellow
    }
}

# Check Windows Firewall
Function chkFW
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "Windows Firewall" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Windows Firewall" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan

    # Get Firewall profile Status
    $FWPro = netsh advfirewall show allprofiles
    If ($domprofile = $FWPro | Select-String 'Domain Profile', '域配置文件' -Context 2 | Out-String)
    {
        $domainpro = ($domprofile.Substring($domprofile.Length - 9)).Trim()
    }
    Else
    {
        $domainpro = $NULL
    }
    If ($priprofile = $FWPro | Select-String 'Private Profile', '专用配置文件' -Context 2 | Out-String)
    {
        $privatepro = ($priprofile.Substring($priprofile.Length - 9)).Trim()
    }
    Else
    {
        $privatepro = $NULL
    }
    If ($pubprofile = $FWPro | Select-String 'Public Profile', '公用配置文件' -Context 2 | Out-String)
    {
        $publicpro = ($pubprofile.Substring($pubprofile.Length - 9)).Trim()
    }
    Else
    {
        $publicpro = $NULL
    }
    $FirewallObject = New-Object PSObject
    Add-Member -inputObject $FirewallObject -memberType NoteProperty -name "FirewallDomain" -value $domainpro
    Add-Member -inputObject $FirewallObject -memberType NoteProperty -name "FirewallPrivate" -value $privatepro
    Add-Member -inputObject $FirewallObject -memberType NoteProperty -name "FirewallPublic" -value $publicpro

    # Get Custom firewall rules
    $FWRules = Get-NetFirewallRule | Where {$_.Group -eq 'ChinaNetCloud' -or $_.Group -eq $NULL} | `
    Select-Object -Property DisplayName, Direction, @{Name="Protocol";Expression={$_ | Get-NetFirewallPortFilter | `
    Select-Object -ExpandProperty Protocol}}, @{Name="Service";Expression={$_ | Get-NetFirewallServiceFilter | `
    Select-Object -ExpandProperty Service}}, @{Name="RemotePort";Expression={$_ | Get-NetFirewallPortFilter | `
    Select-Object -ExpandProperty RemotePort}}, @{Name="LocalPort";Expression={$_ | Get-NetFirewallPortFilter | `
    Select-Object -ExpandProperty Localport}}

    "-Domain Profile Status: " + $FirewallObject.FirewallDomain | Out-File -filepath $INFO_LOG -Append
    "-Public Profile Status: " + $FirewallObject.FirewallPublic | Out-File -filepath $INFO_LOG -Append
    "-Private Profile Status: " + $FirewallObject.FirewallPrivate | Out-File -filepath $INFO_LOG -Append
    Write-Host "-Domain Profile Status:" $FirewallObject.FirewallDomain
    Write-Host "-Public Profile Status:" $FirewallObject.FirewallPublic
    Write-Host "-Private Profile Status:" $FirewallObject.FirewallPrivate
    If ($FirewallObject.FirewallDomain -eq "OFF" -or $FirewallObject.FirewallPublic -eq "OFF" -or $FirewallObject.FirewallPrivate -eq "OFF" `
    -or $FirewallObject.FirewallDomain -eq "关闭" -or $FirewallObject.FirewallPublic -eq "关闭" -or $FirewallObject.FirewallPrivate -eq "关闭")
    {
        "One or more profiles in OFF state of Windows Firewall" | Out-File -filepath $ERROR_LOG -Append
        Write-Host "One or more profiles in OFF state of Windows Firewall" -ForegroundColor Yellow
    }
    
    "-Custom firewall rules:" | Out-File -filepath $INFO_LOG -Append
    Write-Host "-Custom firewall rules:"
    
    For ($i=0; $i -lt $FWRules.Count; $i++)
    {
        "--Display Name: " + $FWRules[$i].DisplayName + "`r`n" + `
        "---Direction: " + $FWRules[$i].Direction + "`r`n" + `
        "---Service: " + $FWRules[$i].Service + "`r`n" + `
        "---Remote Port: " + $FWRules[$i].RemotePort + "`r`n" + `
        "---Local Port: " + $FWRules[$i].LocalPort + "`r" | `
        Out-File -filepath $INFO_LOG -Append
        Write-Host -NoNewline "--Display Name: "
        Write-Host $FWRules[$i].DisplayName -Backgroundcolor DarkGray
        Write-Host "---Direction:"$FWRules[$i].Direction"`n---Service:"$FWRules[$i].Service"`n---Remote Port:"$FWRules[$i].RemotePort"`n---Local Port:"$FWRules[$i].LocalPort"`r"
    }
}

# Check IIS Information
Function chkIIS
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "Internet Information Service (IIS)" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Internet Information Service (IIS)" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan

    # Import IIS Module
    Import-Module WebAdministration

    # Application pools information
    "-Application pools:" | Out-File -filepath $INFO_LOG -Append
    Write-Host "-Application pools:"
    $IISAppPool = @(Get-ChildItem IIS:\AppPools)
    For($i=0; $i -lt $IISAppPool.Count; $i++)
    {
        "--" + $IISAppPool[$i].Name + ":" + $IISAppPool[$i].State | Out-File -filepath $INFO_LOG -Append
        Write-Host "--"$IISAppPool[$i].Name":"$IISAppPool[$i].State
        If ($IISAppPool[$i].State -ne "Started")
        {
            "The application pool " + $IISAppPool[$i].Name + " is not started. Please check." | Out-File -filepath $ERROR_LOG -Append
            Write-Host "The application pool"$IISAppPool[$i].Name"is not started. Please check." -ForegroundColor Red
        }
    }
    
    # Website information
    "-Websites:" | Out-File -filepath $INFO_LOG -Append
    Write-Host "-Websites:"
    $IISSite = @(Get-Website)
    For($j=0; $j -lt $IISSite.Count; $j++)
    {
        "--Web Site:" + $IISSite[$j].Name | Out-File -filepath $INFO_LOG -Append
        "---State:" + $IISSite[$j].State | Out-File -filepath $INFO_LOG -Append
        "---Physical Path:" + $IISSite[$j].physicalpath | Out-File -filepath $INFO_LOG -Append
        "---Binding:" + $IISSite[$j].bindings.Collection.bindingInformation | Out-File -filepath $INFO_LOG -Append
        Write-Host "--Web Site:"$IISSite[$j].Name
        Write-Host "---State:"$IISSite[$j].State
        Write-Host "---Physical Path:"$IISSite[$j].physicalpath
        Write-Host "---Binding:"$IISSite[$j].bindings.Collection.bindingInformation
        If ($IISSite[$j].State -ne "Started")
        {
            "The web site " + $IISSite[$j].Name + " is not started. Please check." | Out-File -filepath $ERROR_LOG -Append
            Write-Host "The web site"$IISSite[$j].Name"is not started. Please check." -ForegroundColor Red
        }
    }
}

# Check SQL Server Information
Function chkMSSQL
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "SQL Server" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "SQL Server" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    
    # Instance Name
    $Instance = @(Get-item "hklm:\software\microsoft\Microsoft SQL Server\Instance Names\SQL")
    "-SQL instance name: " + $Instance.Property | Out-File -filepath $INFO_LOG -Append
    Write-Host "-SQL instance name:" $Instance.Property

    # SQL Server Service List
    "-Service Status:" | Out-File -filepath $INFO_LOG -Append
    Write-Host "-Service Status:"
    $SQLSVC = Get-Service | Where {$_.name -match "SQL"}
    For ($i=0; $i -lt $SQLSVC.Count; $i++)
    {
        "--" + $SQLSVC[$i].DisplayName + ": " + $SQLSVC[$i].Status + " | " + $SQLSVC[$i].StartType | Out-File -filepath $INFO_LOG -Append
        Write-Host "--"$SQLSVC[$i].DisplayName":" $SQLSVC[$i].Status"|"$SQLSVC[$i].StartType
        If ($SQLSVC[$i].Status -ne "Running")
        {
            $SQLSVC[$i].DisplayName + " is not running, please check." | Out-File -filepath $ERROR_LOG -Append
            Write-Host $SQLSVC[$i].DisplayName "is not running, please check." -ForegroundColor Yellow
        }
        If ($SQLSVC[$i].StartType -ne "Automatic")
        {
            $SQLSVC[$i].DisplayName + " is not set as auto-start, please check." | Out-File -filepath $ERROR_LOG -Append
            Write-Host $SQLSVC[$i].DisplayName "is not set as auto-start, please check." -ForegroundColor Yellow
        }
    }
    
    # Import SQL Server Module
    Import-Module sqlps -DisableNameChecking
    
    # SQL Server settings
    $SQLSVR = New-Object ('Microsoft.SqlServer.Management.Smo.Server') Localhost
    "-DB file location: " + $SQLSVR.DefaultFile | Out-File -filepath $INFO_LOG -Append
    "-Log file location: " + $SQLSVR.DefaultLog | Out-File -filepath $INFO_LOG -Append
    "-Backup BackupDirectory: " + $SQLSVR.BackupDirectory | Out-File -filepath $INFO_LOG -Append
    $SQLAccount  = $SQLSVR.Logins | where {$_.name -notmatch "##" -and $_.name -notmatch "NT "}
    "-SQL Acccount Information: " | Out-File -filepath $INFO_LOG -Append
    Write-Host "-DB file location:"$SQLSVR.DefaultFile
    Write-Host "-Log file location:"$SQLSVR.DefaultLog
    Write-Host "-Backup BackupDirectory:"$SQLSVR.BackupDirectory
    Write-Host "-SQL Acccount Information:"
    For ($j=0; $j -lt $SQLAccount.Count; $j++)
    {
        "--Account Name: " + $SQLAccount[$j].name + " | Login Type: " + $SQLAccount[$j].LoginType | Out-File -filepath $INFO_LOG -Append
        Write-Host "--Account Name:"$SQLAccount[$j].name"| Login Type:"$SQLAccount[$j].LoginType
    }
}

# Get Service Status Information
Function chkSVC
{
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    "Service Status" | Out-File -filepath $INFO_LOG -Append
    "--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Service Status" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    
    # Get Service List
    $SVCList = Get-Service
    For ($i=0; $i -lt $SVCList.Count; $i++)
    {
        If ($SVCList[$i].Status -eq "Running")
        {
            Write-Host -NoNewline "-Service Name: "
            Write-Host -NoNewline $SVCList[$i].Name -Backgroundcolor DarkGray
            Write-Host -NoNewline " | "
            Write-Host $SVCList[$i].Status -Backgroundcolor Green -ForegroundColor Black
            Write-Host "--Display Name:"$SVCList[$i].DisplayName
            Write-Host "--Start Type:"$SVCList[$i].StartType
        }
        Else
        {
            Write-Host -NoNewline "-Service Name: "
            Write-Host -NoNewline $SVCList[$i].Name -Backgroundcolor DarkGray
            Write-Host -NoNewline " | "
            Write-Host $SVCList[$i].Status -Backgroundcolor Yellow -ForegroundColor Black
            Write-Host "--Display Name:"$SVCList[$i].DisplayName
            Write-Host "--Start Type:"$SVCList[$i].StartType
        }
    }
}

# Main Function
Function chkMAIN
{
    chksrvinfo
    chkSVC
    If ((Get-Service | Where {$_.Name -eq "AWSLiteAgent"}) -ne $NULL)
    {
        chkAWS
    }
    Else
    {
        Write-Host "--------------------------------------------------" -Foregroundcolor Yellow
        Write-Host "This instance is not an EC2 instance on AWS" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -Foregroundcolor Yellow
    }
    chkUpdate
    chkFW
    If ((Get-Service | Where {$_.Name -eq "W3SVC"}) -ne $NULL)
    {
        chkIIS
    }
    Else
    {
        Write-Host "--------------------------------------------------" -Foregroundcolor Yellow
        Write-Host "This instance is not a web server" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -Foregroundcolor Yellow
    }
    If ((Get-Service | Where {$_.Name -match "SQL"}) -ne $NULL)
    {
        chkMSSQL
    }
    Else
    {
        Write-Host "--------------------------------------------------" -Foregroundcolor Yellow
        Write-Host "This instance is not a database server" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------" -Foregroundcolor Yellow
    }
}

# Main script
$DateBegin = Get-Date
"--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
"Pre-access QA on " + $DateBegin | Out-File -filepath $INFO_LOG -Append
"--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
Write-Host "--------------------------------------------------" -Foregroundcolor Green
Write-Host "Pre-access QA on"$DateBegin -Foregroundcolor Green
Write-Host "--------------------------------------------------" -Foregroundcolor Green

# Invoke Functions
chkMAIN

$DateEnd = Get-Date
$QAPeriod = [math]::Round(($DateEnd - $DateBegin).TotalSeconds,2)
"--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
"Pre-access QA ended on " + $DateEnd | Out-File -filepath $INFO_LOG -Append
"--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
"--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
"Script takes " + $QAPeriod + "s" | Out-File -filepath $INFO_LOG -Append
"--------------------------------------------------" | Out-File -filepath $INFO_LOG -Append
Write-Host "--------------------------------------------------" -Foregroundcolor Green
Write-Host "Pre-access QA ended on"$DateEnd -Foregroundcolor Green
Write-Host "--------------------------------------------------" -Foregroundcolor Green
Write-Host "--------------------------------------------------" -Foregroundcolor Magenta
Write-Host "Script takes"$QAPeriod"s" -Foregroundcolor Magenta
Write-Host "--------------------------------------------------" -Foregroundcolor Magenta

################################################
# Script end
################################################