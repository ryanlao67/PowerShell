<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\purge-oldpkg.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

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

    $dstPath = $config.jenkins.buildPath + `
        "\" + $config.aws.environment + `
        "\" + $config.aws.project + `
        "\" + $config.jenkins.region

    $deployLogSlave = $config.jenkins.deployLogPath + `
        "\" + $config.aws.environment + `
        "\" + $config.aws.project + `
        "\" + $config.jenkins.region + `
        "\" + $config.aws.project + $relDate + ".log"    
}
Else
{
    $dstPath = $paramSet.srcPath
    $deployLogSlave = $paramSet.deployLogSlave
}

$iamRole = (Invoke-WebRequest -URI $config.aws.iamurl).Content
$iamRoleUrl = $config.aws.iamurl + "/" + $iamRole
$iamInfo = (Invoke-WebRequest -URI $iamRoleUrl).Content | ConvertFrom-Json

# Purge old package on S3 bucket
$output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Ready to clean up old packages on S3..."
Write-Host $output
$output | Out-File -filepath $deployLogSlave -Append

Try
{
    $purgeKeys = (Get-S3Object -BucketName $config.aws.s3bucket `
        -KeyPrefix $s3KeyPrefix `
        -AccessKey $iamInfo.AccessKeyId `
        -SecretKey $iamInfo.SecretAccessKey `
        -SessionToken $iamInfo.Token `
        -Region $config.aws.region | `
        Where {$_.Size -ne 0 -and `
            $_.LastModified -lt (Get-Date).AddDays($config.other.purge) -and `
            $_.Key -notmatch 'LATEST'}).Key
}
Catch
{
    $fetchError = $Error[0].exception
}
If($fetchError)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Fetch package information failed from S3" + $fetchError
    Write-Host $output
    $output | Out-File -filepath $logTgtPath -Append
    Return 1
    Exit 1
}
Else
{
    Foreach($purgeKey in $purgeKeys)
    {
        Remove-S3Object -BucketName $config.aws.s3bucket -Key $purgeKey `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $config.aws.region `
            -Force | Out-Null
    }
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Clean up S3 old package done."
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
}

$output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Ready to clean up old packages on Jenkins Slave..."
Write-Host $output
$output | Out-File -filepath $deployLogSlave -Append
Get-ChildItem $dstPath | `
    Where {$_.Name -notmatch 'Config'} | `
    Sort-Object CreationTime -Descending | `
    Select-Object -Skip 10 | `
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue | `
    Out-Null
$output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Clean up Jenkins Slave old packages done."
Write-Host $output
$output | Out-File -filepath $deployLogSlave -Append