# Inventory Format
$IVTYFormat = "<style>"
$IVTYFormat = $IVTYFormat + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$IVTYFormat = $IVTYFormat + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$IVTYFormat = $IVTYFormat + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$IVTYFormat = $IVTYFormat + "</style>"

# Inventory information
$ResultAll = Foreach($Servers in Get-Content "C:\Users\ryan.lao\Desktop\CN_STG.txt")
{
   	Invoke-Command -ComputerName $Servers -ScriptBlock {
        param($Servers)
        $SRVName = hostname
        $KAV = Get-WmiObject -Class win32_product | where {$_.Name -match 'Kaspersky' -and $_.Name -match 'for Windows'}
        $KasAgent = Get-WmiObject -Class win32_product | where {$_.Name -match 'Kaspersky' -and $_.Name -match 'Agent'}
        $Result = new-object psobject
        $Result | Add-Member noteproperty "Server_Name" $SRVName
        $Result | Add-Member noteproperty "KAV_Name" $KAV.Name
        $Result | Add-Member noteproperty "KAV_Version" $KAV.Version
        $Result | Add-Member noteproperty "Agent_Name" $KasAgent.Name
        $Result | Add-Member noteproperty "Agent_Version" $KasAgent.Version
        $Result1+=$Result
        $Result1
    } -ArgumentList $Servers;
}
$ResultAll | ConvertTo-HTML -Head $IVTYFormat | Out-file C:\users\ryan.lao\desktop\KasperskyResult.html