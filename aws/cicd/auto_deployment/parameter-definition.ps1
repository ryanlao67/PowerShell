<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\parameter-definition.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

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
}

# Define parameters
$s3KeyPrefix = $config.aws.environment + `
    "/" + $config.aws.team + `
    "/" + $config.aws.project
$s3Key = $config.aws.environment + `
    "/" + $config.aws.team + `
    "/" + $config.aws.project + `
    "/" + "$relDate.zip"
$s3KeyPrefixLATEST = $config.aws.environment + `
    "/" + $config.aws.team + `
    "/" + $config.aws.project + `
    "/LATEST"
$s3KeyLATEST = $config.aws.environment + `
    "/" + $config.aws.team + `
    "/" + $config.aws.project + `
    "/LATEST/$relDate.zip"
$s3LogPrefix = $config.other.logPrefix + `
    "/" + $config.aws.environment + `
    "/" + $config.aws.team + `
    "/" + $config.aws.project
$s3LogKey = $config.other.logPrefix + `
    "/" + $config.aws.environment + `
    "/" + $config.aws.team + `
    "/" + $config.aws.project + `
    "/" + $config.aws.project + $relDate + ".log"
$srcPath = $config.jenkins.appPath + `
    "\" + $config.aws.environment + `
    "\" + $config.aws.project + `
    "\" + $config.jenkins.region + `
    "\*"
$dstPath = $config.jenkins.buildPath + `
    "\" + $config.aws.environment + `
    "\" + $config.aws.project + `
    "\" + $config.jenkins.region
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

# Conbime parameters
$paramSet = New-Object psobject
$paramSet | Add-Member NoteProperty "s3KeyPrefix" $s3KeyPrefix
$paramSet | Add-Member NoteProperty "s3Key" $s3Key
$paramSet | Add-Member NoteProperty "s3KeyPrefixLATEST" $s3KeyPrefixLATEST
$paramSet | Add-Member NoteProperty "s3KeyLATEST" $s3KeyLATEST
$paramSet | Add-Member NoteProperty "s3LogPrefix" $s3LogPrefix
$paramSet | Add-Member NoteProperty "s3LogKey" $s3LogKey
$paramSet | Add-Member NoteProperty "srcPath" $srcPath
$paramSet | Add-Member NoteProperty "dstPath" $dstPath
$paramSet | Add-Member NoteProperty "zipTgt" $zipTgt
$paramSet | Add-Member NoteProperty "deployLogSlave" $deployLogSlave

Return $paramSet