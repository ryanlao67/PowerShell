<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\deployment_conf.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

.NOTES
    Author: Ryan Lao
#>

Param(
    [Parameter(Mandatory = $True, Position = 0)]
    [string] $configFile
)

# Variable definition
$config = Get-Content -Raw -Path $configFile | Out-String | ConvertFrom-Json
$relDate = Get-Date -format 'yyMMddHHmm'
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
    "\$relDate"
$deployLogSlave = $config.jenkins.deployLogPath + `
    "\" + $config.aws.environment + `
    "\" + $config.aws.project + `
    "\" + $config.jenkins.region + `
    "\" + $config.aws.project + $relDate + ".log"

# Build Compression
Compress-Archive -Path $srcPath -DestinationPath $zipTgt
Write-Host "Compression completed as $zipTgt.zip"
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Compression completed as $zipTgt.zip" | `
    Out-File -filepath $deployLogSlave -Append

# S3 Upload
$iamRole = (Invoke-WebRequest -URI $config.aws.iamurl).Content
$iamRoleUrl = $config.aws.iamurl + "/" + $iamRole
$iamInfo = (Invoke-WebRequest -URI $iamRoleUrl).Content | ConvertFrom-Json

Write-S3Object -BucketName $config.aws.s3bucket -File "$zipTgt.zip" -Key $s3Key `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region
Write-Host "Upload application package to S3 from Jenkins slave done."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Upload application package to S3 from Jenkins slave done." | `
    Out-File -filepath $deployLogSlave -Append

# Verify Upload
$buildSizeS3 = (Get-S3Object -BucketName $config.aws.s3bucket -Key $s3Key `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region).Size
$buildSizeLocal = (Get-ChildItem "$zipTgt.zip").Length
If($buildSizeS3 -eq $buildSizeLocal)
{
    Write-Host "Application package size is OK."
    "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
        "Application package size is OK." | `
        Out-File -filepath $deployLogSlave -Append
}
Else
{
    Write-Host "Application package size check failed."
    "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
        "[ERROR]" + `
        "Application package size check failed." | `
        Out-File -filepath $deployLogSlave -Append
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
    Write-Host "Ready to clear latest folder in S3 release bucket."
    "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
        "Ready to clear latest folder in S3 release bucket." | `
        Out-File -filepath $deployLogSlave -Append
    Start-Sleep 1
    Remove-S3Object -BucketName $config.aws.s3bucket -Key $s3ObjectLATEST `
        -AccessKey $iamInfo.AccessKeyId `
        -SecretKey $iamInfo.SecretAccessKey `
        -SessionToken $iamInfo.Token `
        -Region $config.aws.region `
        -Force | Out-Null
    Write-Host "Clear latest folder done."
    "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
        "Clear latest folder done." | `
        Out-File -filepath $deployLogSlave -Append
}
# Copy new application package into latest folder
Copy-S3Object -BucketName $config.aws.s3bucket -Key $s3Key -DestinationKey $s3KeyLATEST `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region | Out-Null
Write-Host "Copy new application package into latest folder done."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Copy new application package into latest folder done." | `
    Out-File -filepath $deployLogSlave -Append

# Figure out target instances
$tgtSrv = (Get-EC2Instance -Region $config.aws.region).instances `
    | Where {$_.Tags.Key -eq 'TEAM' -and $_.Tags.Value -eq $config.aws.team} `
    | Where {$_.Tags.Key -eq 'ENV' -and $_.Tags.Value -eq $config.aws.environment} `
    | Where {$_.Tags.Key -eq 'PROJECT' -and $_.Tags.Value -match $config.aws.project} `
    | Where {$_.State.Name -eq 'running'}
$tgtSrvName = ($tgtSrv.Tags | Where {$_.Key -eq 'Name'}).Value
Write-Host "Deployment target server is $tgtSrvName"
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Deployment target server is $tgtSrvName" | `
    Out-File -filepath $deployLogSlave -Append

# Start deployment
Foreach($tgtServer in $tgtSrvName)
{
    Invoke-Command -ComputerName $tgtServer -ScriptBlock {
        Param($awsRegion, $relBucket, $logBucket, $ec2IAM, $tgtProj, $tempDir, $appDir, $healthPage, $deployLog, $s3deployLogPrefix)
        $curTime = (Get-Date).ToString("yyMMddHHmm")

        # Load informtion
        $instanceId = (Invoke-WebRequest -uri "http://169.254.169.254/latest/meta-data/instance-id").Content
        $ec2TagName = (Get-EC2Tag | Where-Object {$_.ResourceId -eq $instanceId -and $_.Key -eq 'Name'}).Value
        $ec2TagEnv = (Get-EC2Tag | Where-Object {$_.ResourceId -eq $instanceId -and $_.Key -eq 'ENV'}).Value
        $ec2TagTEAM = (Get-EC2Tag | Where-Object {$_.ResourceId -eq $instanceId -and $_.Key -eq 'TEAM'}).Value
        $ec2TagProj = (Get-EC2Tag | Where-Object {$_.ResourceId -eq $instanceId -and $_.Key -eq 'PROJECT'}).Value
        $logLocal = $ec2TagName + "-" + $tgtProj + $curTime + ".log"
        $logTgtPath = $deployLog + "\" + $logLocal
        $logS3Path = $s3deployLogPrefix + `
            "/" + $ec2TagEnv + `
            "/" + $ec2TagTEAM + `
            "/" + $tgtProj + `
            "/" + $logLocal

        If($ec2TagProj -notmatch $tgtProj)
        {
            Write-Host "$ec2TagName is invalid target, please check it again."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "[ERROR]" + `
                "$ec2TagName is invalid target, please check it again." | `
                Out-File -filepath $logTgtPath -Append
            Exit 1
        }
        Else
        {
            Write-Host "$ec2TagName is valid target, start deployment..."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "$ec2TagName is valid target, start deployment..." | `
                Out-File -filepath $logTgtPath -Append
        }
        $iamRole = (Invoke-WebRequest -URI $ec2IAM).Content
        $iamInfo = (Invoke-WebRequest -URI "$ec2IAM/$iamRole").Content | ConvertFrom-Json

        # Download and extract application package
        If (Test-Path $tempDir)
        {
            Remove-Item "$tempDir\" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        }
        Start-Sleep 1
        New-Item $tempDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Create temp folder $tempDir done."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "Create temp folder $tempDir done." | `
            Out-File -filepath $logTgtPath -Append

        Read-S3Object -BucketName $relBucket -Prefix $ec2TagEnv/$ec2TagTEAM/$tgtProj/LATEST `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $awsRegion `
            -Folder $tempDir | Out-Null
        Write-Host "Download application package from S3 done."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "Download application package from S3 done." | `
            Out-File -filepath $logTgtPath -Append

        # Verify Download
        $sizeS3 = (Get-S3Object -BucketName $relBucket `
            -Prefix $ec2TagEnv/$ec2TagTEAM/$tgtProj/LATEST `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $awsRegion | Where {$_.Key -match '.zip'}).Size
        $sizeLocal = (Get-ChildItem $tempDir).Length
        If($sizeS3 -eq $sizeLocal)
        {
            Write-Host "Application package size is OK."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "Application package size is OK." | `
                Out-File -filepath $logTgtPath -Append
        }
        Else
        {
            Write-Host "Application package size check failed."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "[ERROR]" + `
                "Application package size check failed." | `
                Out-File -filepath $logTgtPath -Append
            Exit 1
        }

        $appFile = (Get-ChildItem $tempDir).FullName
        $tempTgt = "$tempDir\$tgtProj\"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($appFile, $tempTgt)
        Write-Host "Unzip application package done."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "Unzip application package done." | `
            Out-File -filepath $logTgtPath -Append

        $longDate = (Get-Date).ToString("yyyyMMddhhmm")
        $rollBackFolder = $tgtProj + "_" + $longDate

        # Deploy new code
        If (Test-Path $appDir)
        {
            If (Test-Path "$appDir\$tgtProj")
            {
                Write-Host "Stopping $tgtProj now."
                "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                    "Stopping $tgtProj now." | `
                    Out-File -filepath $logTgtPath -Append
                Stop-WebSite $tgtProj
                While ($stopState -eq 'Stopped')
                {
                    $stopState = (Get-WebSite $tgtProj).State
                    Write-Host "Waiting $tgtProj stopped..."
                    "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                        "Waiting $tgtProj stopped..." | `
                        Out-File -filepath $logTgtPath -Append
                    Start-Sleep 1
                }
                Write-Host "$tgtProj on $ec2TagName is stopped, proceed to do deployment."
                "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                    "$tgtProj on $ec2TagName is stopped, proceed to do deployment." | `
                    Out-File -filepath $logTgtPath -Append
                Copy-Item "$appDir\$tgtProj\" "$appDir\$rollBackFolder\" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Host "Create rollback foler done."
                "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                    "Create rollback foler done." | `
                    Out-File -filepath $logTgtPath -Append
                Copy-Item "$tempDir\$tgtProj\*" "$appDir\$tgtProj" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Host "Overwrite application folder done."
                "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                    "Overwrite application folder done." | `
                    Out-File -filepath $logTgtPath -Append
            }
        }
        Else
        {
            Write-Host "No such application running on target server, please check."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "[WARNING]" + `
                "No such application running on target server, please check." | `
                Out-File -filepath $logTgtPath -Append
            Exit 1
        }

        Start-Sleep 1
        Write-Host "Ready to start $tgtProj website."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "Ready to start $tgtProj website." | `
            Out-File -filepath $logTgtPath -Append
        Start-WebSite $tgtProj
        $appPool = (Get-Item "IIS:\Sites\$tgtProj"| Select-Object applicationPool).applicationPool
        Restart-WebAppPool $appPool
        While ($startState -eq 'Started')
        {
            $startState = (Get-WebSite $tgtProj).State
            Write-Host "Waiting $tgtProj started..."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "Waiting $tgtProj started..." | `
                Out-File -filepath $logTgtPath -Append
            Start-Sleep 1
        }
        Write-Host "$tgtProj is started on $ec2TagName now."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "$tgtProj is started on $ec2TagName now." | `
            Out-File -filepath $logTgtPath -Append
        Remove-Item "$tempDir\" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Remove temp folder done."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "Remove temp folder done." | `
            Out-File -filepath $logTgtPath -Append

        # Basic health check
        Write-Host "Start to do basic health check against $ec2TagName now."
        "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
            "Start to do basic health check against $ec2TagName now." | `
            Out-File -filepath $logTgtPath -Append
        $basicCheck = Invoke-WebRequest -uri $healthPage
        If($basicCheck.StatusCode -lt 400 -and $basicCheck.Content -eq 'ok')
        {
            Write-Host "Basic health check passed."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "Basic health check passed." | `
                Out-File -filepath $logTgtPath -Append

            # Purge old rollback folders on target servers
            Write-Host "Purge rollback folder..."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "Purge rollback folder..." | `
                Out-File -filepath $logTgtPath -Append
            Get-ChildItem  $appDir | `
                Where {$_.Name -ne $tgtProj -and $_.Name -match $tgtProj} | `
                Sort-Object CreationTime -Descending | `
                Select-Object -Skip 1 | `
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue | `
                Out-Null
            Write-Host "Purge rollback folder on $ec2TagName done."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "Purge rollback folder on $ec2TagName done." | `
                Out-File -filepath $logTgtPath -Append
            Write-Host "Deployment successfully on $ec2TagName."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "Deployment successfully on $ec2TagName." | `
                Out-File -filepath $logTgtPath -Append
        }
        Else
        {
            # Rollback step
            Write-Host "Basic health check failed."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "[ERROR]" + `
                "Basic health check failed." | `
                Out-File -filepath $logTgtPath -Append
            Write-Host "Deployment completed on $ec2TagName with issue, please investigate."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "[ERROR]" + `
                "Deployment completed on $ec2TagName with issue, please investigate." | `
                Out-File -filepath $logTgtPath -Append
            Write-Host "Rollback website now."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "[ERROR]" + `
                "Rollback website now." | `
                Out-File -filepath $logTgtPath -Append
            Stop-WebSite $tgtProj
            While ($stopState -eq 'Stopped')
            {
                $stopState = (Get-WebSite $tgtProj).State
                Write-Host "Waiting $tgtProj stopped..."
                "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                    "Waiting $tgtProj stopped..." | `
                    Out-File -filepath $logTgtPath -Append
            Stop-WebSite $tgtProj
                Start-Sleep 1
            }
            Write-Host "$tgtProj on $ec2TagName is stopped."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "$tgtProj on $ec2TagName is stopped." | `
                Out-File -filepath $logTgtPath -Append
            Copy-Item "$appDir\$rollBackFolder\*" "$appDir\$tgtProj\" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Start-Sleep 3
            Start-WebSite $tgtProj
            While ($startState -eq 'Started')
            {
                $startState = (Get-WebSite $tgtProj).State
                Write-Host "Waiting $tgtProj started..."
                "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                    "Waiting $tgtProj started..." | `
                    Out-File -filepath $logTgtPath -Append
                Start-Sleep 1
            }
            Write-Host "$tgtProj is started on $ec2TagName now."
            "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
                "$tgtProj is started on $ec2TagName now." | `
                Out-File -filepath $logTgtPath -Append
            Exit 1
        }

        # Upload Deployment Log to S3
        Write-S3Object -BucketName $logBucket -File $logTgtPath -Key $logS3Path `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $awsRegion

    } -ArgumentList `
        $config.aws.region, `
        $config.aws.s3bucket, `
        $config.aws.s3logbucket, `
        $config.aws.iamurl, `
        $config.aws.project, `
        $config.target.temp, `
        $config.target.appPath, `
        $config.target.healthURL, `
        $config.target.logPath, `
        $config.other.logPrefix
}

# Purge old package on S3 bucket
Write-Host "Ready to clean up old packages on S3..."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Ready to clean up old packages on S3..." | `
    Out-File -filepath $deployLogSlave -Append

$purgeKeys = (Get-S3Object -BucketName $config.aws.s3bucket `
    -KeyPrefix $s3KeyPrefix `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region | `
    Where {$_.Size -ne 0 -and `
        $_.LastModified -lt (Get-Date).AddDays($config.other.purge) -and `
        $_.Key -notmatch 'LATEST'}).Key
Foreach($purgeKey in $purgeKeys)
{
    Remove-S3Object -BucketName $config.aws.s3bucket -Key $purgeKey `
        -AccessKey $iamInfo.AccessKeyId `
        -SecretKey $iamInfo.SecretAccessKey `
        -SessionToken $iamInfo.Token `
        -Region $config.aws.region `
        -Force | Out-Null
}
Write-Host "Clean up S3 old package done."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Clean up S3 old package done." | `
    Out-File -filepath $deployLogSlave -Append

# Purge old package on Jenkins Slave
Write-Host "Ready to clean up old packages on Jenkins Slave..."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Ready to clean up old packages on Jenkins Slave..." | `
    Out-File -filepath $deployLogSlave -Append
Get-ChildItem $dstPath | `
    Where {$_.Name -notmatch 'Config'} | `
    Sort-Object CreationTime -Descending | `
    Select-Object -Skip 10 | `
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue | `
    Out-Null
Write-Host "Clean up Jenkins Slave old packages done."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Clean up Jenkins Slave old packages done." | `
    Out-File -filepath $deployLogSlave -Append

Write-Host "Deployment completed."
"[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + `
    "Deployment completed." | `
    Out-File -filepath $deployLogSlave -Append

# Upload Deployment Log to S3
Write-S3Object -BucketName $config.aws.s3logbucket -File $deployLogSlave -Key $s3LogKey `
    -AccessKey $iamInfo.AccessKeyId `
    -SecretKey $iamInfo.SecretAccessKey `
    -SessionToken $iamInfo.Token `
    -Region $config.aws.region

Exit 0