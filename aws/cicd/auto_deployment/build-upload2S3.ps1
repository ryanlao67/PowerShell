<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\build-upload2S3.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

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
    $keyName = Get-ChildItem $dstPath | `
        Where {$_.Name -notmatch 'Config'} | `
        Sort-Object CreationTime -Descending | `
        Select-Object -First 1
    $s3Key = $config.aws.environment + `
        "/" + $config.aws.team + `
        "/" + $config.aws.project + `
        "/" + $keyName.name
    $s3KeyPrefixLATEST = $config.aws.environment + `
        "/" + $config.aws.team + `
        "/" + $config.aws.project + `
        "/LATEST"
    $s3KeyLATEST = $config.aws.environment + `
        "/" + $config.aws.team + `
        "/" + $config.aws.project + `
        "/LATEST/" + $keyName.name
    $zipTgt = $keyName.Fullname
}
Else
{
    $deployLogSlave = $paramSet.deployLogSlave
    $s3Key = $paramSet.s3Key
    $s3KeyPrefixLATEST = $paramSet.s3KeyPrefixLATEST
    $s3KeyLATEST = $paramSet.s3KeyLATEST
    $srcPath = $paramSet.srcPath
    $zipTgt = $paramSet.zipTgt
}

$iamRole = (Invoke-WebRequest -URI $config.aws.iamurl).Content
$iamRoleUrl = $config.aws.iamurl + "/" + $iamRole
$iamInfo = (Invoke-WebRequest -URI $iamRoleUrl).Content | ConvertFrom-Json

# Upload package
Try
{
    Write-S3Object -BucketName $config.aws.s3bucket -File $zipTgt -Key $s3Key `
        -AccessKey $iamInfo.AccessKeyId `
        -SecretKey $iamInfo.SecretAccessKey `
        -SessionToken $iamInfo.Token `
        -Region $config.aws.region
}
Catch
{
    $uploadError = $Error[0].exception
}
If($uploadError)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Upload application package to S3 from Jenkins slave failed`r`n`t" + $uploadError
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
    Exit 1
}
Else
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Upload application package as $s3Key to S3 from Jenkins slave done."
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
}

# Verify package
$buildSizeS3 = (Get-S3Object -BucketName $config.aws.s3bucket -Key $s3Key `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region).Size
$buildSizeLocal = (Get-ChildItem "$zipTgt").Length
If($buildSizeS3 -eq $buildSizeLocal)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Application package size is OK."
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
}
Else
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Application package size check failed. Deployment won't be started."
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
    Exit 1
}

# Clear LATEST folder on S3
$s3ObjectLATEST = (Get-S3Object -BucketName $config.aws.s3bucket -Prefix $s3KeyPrefixLATEST `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region | Where {$_.Key -match '.zip'}).Key
If ($s3ObjectLATEST)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Ready to clear latest folder in S3 release bucket."
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
    Start-Sleep 1
    Try
    {
        Remove-S3Object -BucketName $config.aws.s3bucket -Key $s3ObjectLATEST `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $config.aws.region `
            -Force | Out-Null
    }
    Catch
    {
        $removeError = $Error[0].exception
    }
    If($removeError)
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Remove latest folder failed with below exception, please manually check and try it again.`r`n`t" + $removeError
        Write-Host $output
        $output | Out-File -filepath $deployLogSlave -Append
        Exit 1
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Clear latest folder done."
        Write-Host $output
        $output | Out-File -filepath $deployLogSlave -Append
    }
    
}
# Copy new application package into latest folder
Try
{
    Copy-S3Object -BucketName $config.aws.s3bucket -Key $s3Key -DestinationKey $s3KeyLATEST `
        -AccessKey $iamInfo.AccessKeyId `
        -SecretKey $iamInfo.SecretAccessKey `
        -SessionToken $iamInfo.Token `
        -Region $config.aws.region | Out-Null
}
Catch
{
    $copyError = $Error[0].exception
}
If($copyError)
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Copy package to latest folder failed with below exception, please manually check and try it again.`r`n`t" + $copyError
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
    Exit 1
}
Else
{
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Copy new application package into latest folder done."
    Write-Host $output
    $output | Out-File -filepath $deployLogSlave -Append
}