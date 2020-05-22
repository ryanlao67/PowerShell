<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\deploy-main.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

.NOTES
    Author: Ryan Lao
#>

Param(
    [Parameter(Mandatory = $True, Position = 0)]
    [string] $configFile,

    [Parameter(Mandatory = $True, Position = 1)]
    [string] $component
)

$config = Get-Content -Raw -Path $configFile | Out-String | ConvertFrom-Json
$relDate = Get-Date -format 'yyMMddHHmm'

Function paramDefinition
{
    .\parameter-definition.ps1
}

Function buildCompression
{
    .\build-compression.ps1
}

Function buildUpload2S3
{
    .\build-upload2S3.ps1
}

Function determineTarget
{
    .\determine-targets.ps1
}

Function deployiis
{
    .\deploy-iis.ps1
}

Function purgeoldpkg
{
    .\purge-oldpkg.ps1
}

$paramSet = paramDefinition

If($paramSet -eq $NULL)
{
    Write-Host "Parameters loading failed, deployment won't be started."
    Exit 1
}

Try
{
    buildCompression
}
Catch
{
    $mainError = $Error[0].exception
}
If($mainError)
{
    Write-Host "Compress package failed, deployment won't be started."
    Exit 1
}

Try
{
    buildUpload2S3
}
Catch
{
    $mainError = $Error[0].exception
}
If($mainError)
{
    Write-Host "Upload package to S3 failed, deployment won't be started."
    Exit 1
}

Try
{
    $targetSrv = determineTarget
}
Catch
{
    $mainError = $Error[0].exception
}
If($mainError)
{
    Write-Host "Cannot determine target instances, deployment won't be started."
    Exit 1
}

If($component -eq 'iis')
{
    Try
    {
        deployiis
    }
    Catch
    {
        $mainError = $Error[0].exception
    }
    If($mainError)
    {
        Write-Host "Deployment failed, please investigate."
        Exit 1
    }
}

Try
{
    purgeoldpkg
}
Catch
{
    $mainError = $Error[0].exception
}
If($mainError)
{
    Write-Host "Purge old package failed, please check."
    Exit 1
}

$output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Deployment completed successfully."
Write-Host $output

$s3LogKey = $paramSet.s3LogKey

$iamRole = (Invoke-WebRequest -URI $config.aws.iamurl).Content
$iamRoleUrl = $config.aws.iamurl + "/" + $iamRole
$iamInfo = (Invoke-WebRequest -URI $iamRoleUrl).Content | ConvertFrom-Json

Write-S3Object -BucketName $config.aws.s3logbucket -File $paramSet.deployLogSlave -Key $s3LogKey `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region

Exit 0