<#
Usage:
.\CheckPendingReboot.ps1 .\serverlist.txt
.\CheckPendingReboot.ps1 ServerName
.\CheckPendingReboot.ps1 ServerName1,ServerName2
#>

param(
	[Parameter(Position = 0)]
	[array] $paramServersM
)
$MaxThreads=10
$arrayServersM = @()
if(($paramServersM -ne $null) -and (Test-Path -LiteralPath $paramServersM[0]))
{
    #If the input is serverlist file.
    $arrayServersM1 = type $paramServersM[0]
    $arrayServersM+=$arrayServersM1
}
elseif($paramServersM -eq $null){
$arrayServersM1=$env:computername
$arrayServersM+=$arrayServersM1
}
else
{
    #If the input is the delimited servers or server name wildcard.
    $arrayServersM += $paramServersM
}

$CheckRebootTask={
param(
$paramServers
)
$arrayServers = @()
$arrayServers = $paramServers
$PendingRebootValue=$false;
function Get-PendingReboot($server = $env:computername) {
#open registry.
$hive=[Microsoft.Win32.RegistryHive]::LocalMachine
$reg=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($hive,$Server)
$path_server = 'SOFTWARE\Microsoft\ServerManager';
$path_control = 'SYSTEM\CurrentControlSet\Control';
$path_session = join-path $path_control 'Session Manager';
$path_name = join-path $path_control 'ComputerName';
$path_name_old = join-path $path_name 'ActiveComputerName';
$path_name_new = join-path $path_name 'ComputerName';
$path_wsus = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired';
$CBSkey='SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\'
$pending_rename = 'PendingFileRenameOperations';
$pending_rename_2 = 'PendingFileRenameOperations2';
$attempts = 'CurrentRebootAttempts';
$computer_name = 'ComputerName';
$num_attempts = 0;
$name_old = $null;
$name_new = $null;
$key_session = $reg.OpenSubKey($path_session);
if ($key_session -ne $null) {
$session_values = @($key_session.GetValueNames());
$key_session.Close() | out-null;
}
$key_server = $reg.OpenSubKey($path_server);
if ($key_server -ne $null) {
$num_attempts = $key_server.GetValue($attempts);
$key_server.Close() | out-null;
}
$key_name_old = $reg.OpenSubKey($path_name_old);
if ($key_name_old -ne $null) {
$name_old = $key_name_old.GetValue($computer_name);
$key_name_old.Close() | out-null;
$key_name_new = $reg.OpenSubKey($path_name_new);
if ($key_name_new -ne $null) {
$name_new = $key_name_new.GetValue($computer_name);
$key_name_new.Close() | out-null;
}
}
$key_wsus = $reg.OpenSubKey($path_wsus);
if ($key_wsus -ne $null) {
$wsus_values = @($key_wsus.GetValueNames());
if ($wsus_values) {
$wsus_rbpending = $true
} else {
$wsus_rbpending = $false
}
$key_wsus.Close() | out-null;
}
$CBSsubkey=$reg.OpenSubKey($CBSkey).GetSubKeyNames()
$CBSRebootPend = $CBSsubkey -contains "RebootPending"
If($CBSRebootPend)
{
	$CBS=$true
}
else {
    $CBS= $false
}
#Registry close
$reg.Close() | out-null;
#modified return section: 
IF ( `
(($session_values -contains $pending_rename) -or ($session_values -contains $pending_rename_2)) `
-or (($num_attempts -gt 0) -or ($name_old -ne $name_new)) `
-or ($wsus_rbpending) -or ($CBS) )
{
return $true;
}
else
{
return $false;
}
}
$Results=@{}
$ResultsOut=@()
Foreach($Server in $arrayServers)
{ 
try{
 $PendingRebootValue=Get-PendingReboot($Server);
 }
catch{
 $Results.Set_Item( $Server,"Error occured, need manually check")
 continue
}
 if( $PendingRebootValue){
 $Results.Set_Item( $Server,"NeedReboot-->YES")
 }
 }#End Foreach
foreach ($ResultsPair in $Results.GetEnumerator())
{
 $ResultsOut+=$ResultsPair.Key+"       "+$ResultsPair.value
}
 $ResultsOut
}


foreach ($server in $arrayServersM)
{
    While ($(Get-Job -state running).count -ge $MaxThreads){
        Start-Sleep -Milliseconds 500
        Get-Job | Receive-Job 
    }
    #$curdir = $(get-location).path
    $job = Start-Job $CheckRebootTask -ArgumentList $server 
    Get-Job | Receive-Job 
}
While ($(Get-Job -State Running).count -gt 0){

    Get-Job | Receive-Job 
    Start-Sleep -Milliseconds 100
}
Get-Job | wait-Job > $null
Get-Job | Receive-Job 
Get-Job | Remove-Job


