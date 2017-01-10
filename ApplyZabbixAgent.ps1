#Get server list
$Serverlist = Read-Host "Please enter full path of server list file"

$LocalHost = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration).IPAddress | Where-Object {$_ -Notlike "*:*"}
$LocalHost = ([String]$LocalHost).Trim("")

#Remote deploy zabbix agent
Foreach($Servers in Get-Content $Serverlist)
{
    If(Test-Path \\$Servers\c$\temp\Zabbix)
    {
        Copy-Item "\\$LocalHost\Scripts\Zabbix_Agent\*" "\\$Servers\c$\temp\Zabbix" -Recurse -ErrorAction SilentlyContinue | Out-Null
    }
    Else
    {
        New-Item "\\$Servers\c$\temp\Zabbix" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Copy-Item "\\$LocalHost\Scripts\Zabbix_Agent\*" "\\$Servers\c$\temp\Zabbix" -Recurse -ErrorAction SilentlyContinue | Out-Null
    }

    Invoke-Command -ComputerName $Servers -ScriptBlock {
        Param (
        [string] $FileLocation,
        
        [string] $ZABXSRV
        )
        
        #Server infomation
        $CNCentral = '10.163.25.64'
        $SGCentral = '10.160.114.146'
        $ZABXCN = '10.163.13.99'
        $ZABXSG = '10.160.114.182'
        
        #Confirm file location
        $SRVFQDN = [System.Net.DNS]::GetHostByName('').HostName
        If($SRVFQDN -match 'E1EF.COM')
        {
            $FileLocation = $CNCentral
        }
        Elseif($SRVFQDN -match 'E1SD.COM')
        {
            $FileLocation = $SGCentral
        }
        Else
        {
            Break
        }
        
        #Confirm Zabbix server
        $SRVIP = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration).IPAddress | Where-Object {$_ -Notlike "*:*"}
        If($SRVIP -match '10.163')
        {
            $ZABXSRV = $ZABXCN
        }
        Elseif($SRVIP -match '10.160')
        {
            $ZABXSRV = $ZABXSG
        }
        Else
        {
            Break
        }
                
        #All firewall rule
        New-NetFirewallRule -Group 'EF' -DisplayName "Zabbix" -Action Allow -Description "Allow TCP 10050" -Direction Inbound -Enabled True -LocalPort 10050 -Profile Any -Protocol TCP | Out-Null
        
        #Install and config Zabbix agent
        If(Test-Path 'D:\')
        {
            $ZABXLocation = 'D:\Zabbix'
        }
        Else
        {
            $ZABXLocation = 'C:\Zabbix'
        }
        If (Test-Path $ZABXLocation)
        {
            Break
        }
        Else
        {
            New-Item $ZABXLocation -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
            Move-Item C:\temp\Zabbix\* $ZABXLocation | Out-Null
            Sleep 5
            $SRVHost = Hostname
            $ZABXLog = "$ZABXLocation\zabbix_agentd.log"
            $ZABXConf = Get-Content "$ZABXLocation\zabbix_agentd.conf"
            $ZABXConf[13] = $ZABXConf[13].Replace($ZABXConf[13], "LogFile=$ZABXLog")
            $ZABXConf[73] = $ZABXConf[73].Replace($ZABXConf[73], "Server=$ZABXSRV")
            $ZABXConf[125] = $ZABXConf[125].Replace($ZABXConf[125], "Hostname=$SRVHost")
            Set-Content "$ZABXLocation\zabbix_agentd.conf" $ZABXConf
            Invoke-WmiMethod -Class Win32_process -Name Create -ArgumentList ("cmd.exe /C $ZABXLocation\zabbix_agentd.exe --config $ZABXLocation\zabbix_agentd.conf --install") | Out-Null
            Sleep 3
            Invoke-WmiMethod -Class Win32_process -Name Create -ArgumentList ("cmd.exe /C $ZABXLocation\zabbix_agentd.exe --config $ZABXLocation\zabbix_agentd.conf --start") | Out-Null
        }
    } -ArgumentList $Servers;
}