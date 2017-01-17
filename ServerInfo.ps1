$PSResult = New-Object PSObject
$sysinfo = Get-WmiObject -Class Win32_ComputerSystem
$OSinfo = Get-WmiObject -class Win32_OperatingSystem
$KAV = Get-WmiObject -Class win32_product | where {$_.Name -match 'Kaspersky' -and $_.Name -match 'for Windows'}
$KAGT = Get-WmiObject -Class win32_product | where {$_.Name -match 'Kaspersky' -and $_.Name -match 'Agent'}
$PatchDate = (Get-WmiObject -Class Win32_QuickFixEngineering | Sort-Object -Property Installedon -Descending | Select-Object -Property Installedon | Select-Object -First 1).Installedon.ToString('yyyyMMdd')
If($KAV)
{
    $KAVVersion = $KAV.Version
}
Else
{
    $KAVVersion = 'N/A'
}
If($KAGT)
{
    $KAGTVersion = $KAGT.Version
}
Else
{
    $KAGTVersion = 'N/A'
}
If((Get-Service | Where {$_.Name -eq 'W3SVC'}) -ne $NULL)
{
    $IISVersion = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp\).setupstring
    $SRVROLE = 'Web Server'
}
Else
{
    $IISVersion = 'N/A'
}
$SQLCustom = 'MSSQL\$'
If((Get-Service | Where {($_.Name -eq "MSSQLSERVER" -or $_.Name -match $SQLCustom) -and $_.DisplayName -match "SQL Server"}) -ne $NULL)
{
    $SQLVersion = (Get-wmiobject -class win32_product | where {$_.name -match 'sql server' -and $_.name -match 'Database Engine Services'} | Select-Object -Property Name | Sort-Object -unique).name.TrimEnd(' Database Engine Services')
    $SRVROLE = 'DB Server'
}
Else
{
    $SQLVersion = 'N/A'
}
If($SRVROLE -eq $NULL)
{
    $SRVROLE = 'App Server'
}

Add-Member -inputObject $PSResult -memberType NoteProperty -name 'Server Name' -Value $sysinfo.Name
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'Domain' -Value $sysinfo.Domain
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'OS Type' -Value $OSinfo.Caption
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'KAV Version' -Value $KAVVersion
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'Klagent Version' -Value $KAGT.Version
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'IIS Version' -Value $IISVersion
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'SQL Version' -Value $SQLVersion
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'Server Role' -Value $SRVROLE
Add-Member -inputObject $PSResult -memberType NoteProperty -name 'Patching Date' -Value $PatchDate

$PSResult