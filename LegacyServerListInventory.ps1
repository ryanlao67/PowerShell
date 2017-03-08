# Inventory Format
$IVTYFormat = "<style>"
$IVTYFormat = $IVTYFormat + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$IVTYFormat = $IVTYFormat + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$IVTYFormat = $IVTYFormat + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$IVTYFormat = $IVTYFormat + "</style>"

$Result1=@()

$RawCSV = Get-Content "D:\Legacy\LegacyServerList.csv" | ConvertFrom-CSV

For ($i=0; $i -lt $RawCSV.Count; $i++)
{
    $Result = new-object psobject
    $Result | Add-Member noteproperty "Server Name" $RawCSV[$i].ServerName
    $Result | Add-Member noteproperty "Owner" $RawCSV[$i].Owner
    $Result | Add-Member noteproperty "ENV" $RawCSV[$i].ENV
    $Result | Add-Member noteproperty "IP Address" $RawCSV[$i].IPAddress
    $Result | Add-Member noteproperty "Location" $RawCSV[$i].Location
    $Result | Add-Member noteproperty "Application" $RawCSV[$i].Application
    $Result | Add-Member noteproperty "Desired decomm date" $RawCSV[$i].DesiredDecommDate
    $Result | Add-Member noteproperty "OS Info" $RawCSV[$i].OSInfo
    $Result | Add-Member noteproperty "KAV Version" $RawCSV[$i].KAVVersion
    $Result | Add-Member noteproperty "Klagent Version" $RawCSV[$i].KlagentVersion
    $Result | Add-Member noteproperty "IIS Version" $RawCSV[$i].IISVersion
    $Result | Add-Member noteproperty "SQL Version" $RawCSV[$i].SQLVersion
    $Result | Add-Member noteproperty "Server Role" $RawCSV[$i].ServerRole
    $Result | Add-Member noteproperty "Patching Date" $RawCSV[$i].PatchingDate
    $Result1+=$Result
}

$Result1 | ConvertTo-HTML -Head $IVTYFormat | Out-file "D:\Legacy\legacyservers.html"

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\Legacy\legacyservers.html" -ProfileName awsglobal  -Region ap-southeast-1
