<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\build-compression.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

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

    $srcPath = $config.jenkins.appPath + `
    "\" + $config.aws.environment + `
    "\" + $config.aws.project + `
    "\" + $config.jenkins.region + `
    "\*"
    $zipTgt = $config.jenkins.buildPath + `
    "\" + $config.aws.environment + `
    "\" + $config.aws.project + `
    "\" + $config.jenkins.region + `
    "\$relDate.zip"
    $deployLogSlave = $config.jenkins.deployLogPath + `
    "\" + $config.aws.environment + `
    "\" + $config.aws.project + `
    "\" + $config.jenkins.region + `
    "\" + $config.aws.project + $relDate + ".log"
}
Else
{
    $srcPath = $paramSet.srcPath
    $zipTgt = $paramSet.zipTgt
    $deployLogSlave = $paramSet.deployLogSlave
}

# Build Compression
Try
{
    Compress-Archive -Path $srcPath -DestinationPath $zipTgt
}
Catch
{
    $compressError = $Error[0].exception
}
If($compressError)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]" + $compressError
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
    Exit 1
}
Else
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Compression completed as $zipTgt"
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
}