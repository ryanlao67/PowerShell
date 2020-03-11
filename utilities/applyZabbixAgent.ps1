Foreach($Servers in Get-Content "C:\Users\ryan.lao\Desktop\Cent.txt")
{
    Invoke-Command -ComputerName $Servers -ScriptBlock {
        New-NetFirewallRule -Group 'EF' -DisplayName "Zabbix Agent" -Action Allow -Description "Allow TCP 10050" -Direction Inbound -Enabled True -LocalPort 10050 -Profile Any -Protocol TCP | Out-Null
        New-Item D:\Zabbix -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Copy-Item \\10.163.25.64\Scripts\Zabbix_Agent\* D:\Zabbix -recurse
        $ZABXConf = Get-Content D:\Zabbix\zabbix_agentd.conf
        $SRVHost = Hostname
        $ZABXConf[125] = $ZABXConf[125].Replace($ZABXConf[125], "Hostname=$SRVHost")
        Set-Content D:\Zabbix\zabbix_agentd.conf $ZABXConf
        $ZABXAGTINSTALL = 'cmd.exe /c "D:\Zabbix\zabbix_agentd.exe" --config "D:\Zabbix\zabbix_agentd.conf" --install & if %errorlevel% neq 0 (@echo on)'
        $ZABXAGTSTART = 'cmd.exe /c "D:\Zabbix\zabbix_agentd.exe" --config "D:\Zabbix\zabbix_agentd.conf" --start & if %errorlevel% neq 0 (@echo on)'
        Invoke-Expression $ZABXAGTINSTALL
        Sleep 2
        Invoke-Expression $ZABXAGTSTART
    } -ArgumentList $Servers;
}