<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\determine-targets.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

.NOTES
    Author: Ryan Lao
#>

If(!$relDate)
{
    $relDate = Get-Date -format 'yyMMddHHmm'
}

If(!$config)
{
    $configFile = Read-Host -Prompt "Please input a configuration file which will be used for deployment" | `
        Foreach {$_ -replace '^"(.*)"$', '$1'}
    $config = Get-Content -Raw -Path $configFile | Out-String | ConvertFrom-Json
    $deployLogSlave = $config.jenkins.deployLogPath + `
        "\" + $config.aws.environment + `
        "\" + $config.aws.project + `
        "\" + $config.jenkins.region + `
        "\" + $config.aws.project + $relDate + ".log"
}
Else
{
    $deployLogSlave = $paramSet.deployLogSlave
}

$iamRole = (Invoke-WebRequest -URI $config.aws.iamurl).Content
$iamRoleUrl = $config.aws.iamurl + "/" + $iamRole
$iamInfo = (Invoke-WebRequest -URI $iamRoleUrl).Content | ConvertFrom-Json

# Figure out target instances
Try
{
    $tgtSrv = (Get-EC2Instance -Region $config.aws.region).instances `
        | Where {$_.Tags.Key -eq 'TEAM' -and $_.Tags.Value -eq $config.aws.team} `
        | Where {$_.Tags.Key -eq 'ENV' -and $_.Tags.Value -eq $config.aws.environment} `
        | Where {$_.Tags.Key -eq 'PROJECT' -and $_.Tags.Value -match $config.aws.project} `
        | Where {$_.State.Name -eq 'running'}
}
Catch
{
    $fetchError = $Error[0].exception
}
If($fetchError)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Cannot get target EC2 instances for deployment with below exception, please manually check and try it again.`r`n`t" + $fetchError
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
    Exit 1
}
Else
{
    $tgtSrvName = ($tgtSrv.Tags | Where {$_.Key -eq 'Name'} | Sort-Object).Value
    #$output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Deployment target server is $tgtSrvName"
    #Write-Host $output
    #$output | Out-File -filepath $deployLogSlave -Append
    Return $tgtSrvName
}