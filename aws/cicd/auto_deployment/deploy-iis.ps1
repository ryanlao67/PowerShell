<#
.SYNOPSIS
    For CD automation

.DESCRIPTION
    This script is for continous deployment with specific configuration file

.PARAMETER Configfile
    Path to configuration file (config.json)

.EXAMPLE
    .\deploy-iis.ps1 -Configfile "D:\build\<ENV>\<PROJECT>\<REGION>\Config.json"

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

    $iamRole = (Invoke-WebRequest -URI $config.aws.iamurl).Content
    $iamRoleUrl = $config.aws.iamurl + "/" + $iamRole
    $iamInfo = (Invoke-WebRequest -URI $iamRoleUrl).Content | ConvertFrom-Json

    $deployLogSlave = $config.jenkins.deployLogPath + `
        "\" + $config.aws.environment + `
        "\" + $config.aws.project + `
        "\" + $config.jenkins.region + `
        "\" + $config.aws.project + $relDate + ".log"

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
    }
}
Else
{
    $deployLogSlave = $paramSet.deployLogSlave
    $tgtSrvName = $targetSrv
}

$output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Deployment target server is $tgtSrvName"
Write-Host $output
$output | Out-File -filepath $deployLogSlave -Append

$scriptBlock = {
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
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]$ec2TagName is invalid target, please manually check and try it again."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Return 1
        Exit 1
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "$ec2TagName is valid target, start deployment..."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
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
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Create temp folder $tempDir done."
    Write-Host $output
    $output | Out-File -filepath $logTgtPath -Append

    Try
    {
        Read-S3Object -BucketName $relBucket -Prefix $ec2TagEnv/$ec2TagTEAM/$tgtProj/LATEST `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $awsRegion `
            -Folder $tempDir | Out-Null
    }
    Catch
    {
        $downloadError = $Error[0].exception
    }
    If($downloadError)
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Download application package from S3 failed`r`n`t" + $downloadError
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Return 1
        Exit 1
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Download application package from S3 done."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
    }
        
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
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Application package size is OK."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Application package size check failed. Deployment won't be started."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Return 1
        Exit 1
    }

    $appFile = (Get-ChildItem $tempDir).FullName
    $tempTgt = "$tempDir\$tgtProj\"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Try
    {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($appFile, $tempTgt)
    }
    Catch
    {
        $extractError = $Error[0].exception
    }
    If($extractError)
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Extract application package failed. Deployment won't be started."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Return 1
        Exit 1
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Extract application package done."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
    }

    $longDate = (Get-Date).ToString("yyyyMMddhhmm")
    $rollBackFolder = $tgtProj + "_" + $longDate

    # Deploy new code
    If (Test-Path $appDir)
    {
        If (Test-Path "$appDir\$tgtProj")
        {
            $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Stopping $tgtProj now."
            Write-Host $output
            $output | Out-File -filepath $logTgtPath -Append
            Stop-WebSite $tgtProj
            While ($stopState -eq 'Stopped')
            {
                $stopState = (Get-WebSite $tgtProj).State
                $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Waiting $tgtProj stopped..."
                Write-Host $output
                $output | Out-File -filepath $logTgtPath -Append
                Start-Sleep 1
            }
            $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "$tgtProj on $ec2TagName is stopped, proceed to do deployment."
            Write-Host $output
            $output | Out-File -filepath $logTgtPath -Append
            Copy-Item "$appDir\$tgtProj\" "$appDir\$rollBackFolder\" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Create rollback foler done."
            Write-Host $output
            $output | Out-File -filepath $logTgtPath -Append
            Try
            {
                Copy-Item "$tempDir\$tgtProj\*" "$appDir\$tgtProj" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Catch
            {
                $copyError = $Error[0].exception
            }
            If($copyError)
            {
                $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Overwrite application folder failed. Deployment terminated."
                Write-Host $output
                $output | Out-File -filepath $logTgtPath -Append
                Return 1
                Exit 1
            }
            Else
            {
                $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Overwrite application folder done."
                Write-Host $output
                $output | Out-File -filepath $logTgtPath -Append
            }
        }
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[WARNING]No such application running on target server, please check. Deployment won't be started."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Return 1
        Exit 1
    }

    Start-Sleep 1
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Ready to start $tgtProj website."
    Write-Host $output
    $output | Out-File -filepath $logTgtPath -Append
    Start-WebSite $tgtProj
    $appPool = (Get-Item "IIS:\Sites\$tgtProj"| Select-Object applicationPool).applicationPool
    Restart-WebAppPool $appPool
    While ($startState -eq 'Started')
    {
        $startState = (Get-WebSite $tgtProj).State
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Waiting $tgtProj started..."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Start-Sleep 1
    }
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "$tgtProj is started on $ec2TagName now."
    Write-Host $output
    $output | Out-File -filepath $logTgtPath -Append
    Remove-Item "$tempDir\" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Remove temp folder done."
    Write-Host $output
    $output | Out-File -filepath $logTgtPath -Append

    # Basic health check
    $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Start to do basic health check against $ec2TagName now."
    Write-Host $output
    $output | Out-File -filepath $logTgtPath -Append
    $basicCheck = Invoke-WebRequest -uri $healthPage
    If($basicCheck.StatusCode -lt 400 -and $basicCheck.Content -eq 'ok')
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Basic health check passed."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append

        # Purge old rollback folders on target servers
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Purge rollback folder..."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Get-ChildItem  $appDir | `
            Where {$_.Name -ne $tgtProj -and $_.Name -match $tgtProj} | `
            Sort-Object CreationTime -Descending | `
            Select-Object -Skip 1 | `
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue | `
            Out-Null
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Purge rollback folder on $ec2TagName done."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Deployment successfully on $ec2TagName."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
    }
    Else
    {
        # Rollback step
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Basic health check failed."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Deployment completed on $ec2TagName with issue, please investigate."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Rollback website now."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Stop-WebSite $tgtProj
        While ($stopState -eq 'Stopped')
        {
            $stopState = (Get-WebSite $tgtProj).State
            $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Waiting $tgtProj stopped..."
            Write-Host $output
            $output | Out-File -filepath $logTgtPath -Append
            Start-Sleep 1
        }
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "$tgtProj on $ec2TagName is stopped."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Copy-Item "$appDir\$rollBackFolder\*" "$appDir\$tgtProj\" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep 3
        Start-WebSite $tgtProj
        While ($startState -eq 'Started')
        {
            $startState = (Get-WebSite $tgtProj).State
            $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Waiting $tgtProj started..."
            Write-Host $output
            $output | Out-File -filepath $logTgtPath -Append
            Start-Sleep 1
        }
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "$tgtProj is started on $ec2TagName now."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Rollback website done."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
        Return 1
        Exit 1
    }

    # Upload Deployment Log to S3
    Try
    {
        Write-S3Object -BucketName $logBucket -File $logTgtPath -Key $logS3Path `
            -AccessKey $iamInfo.AccessKeyId `
            -SecretKey $iamInfo.SecretAccessKey `
            -SessionToken $iamInfo.Token `
            -Region $awsRegion
    }
    Catch
    {
        $uploadError = $Error[0].exception
    }
    If($uploadError)
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "[ERROR]Upload deployment log failed, please check it locally if needed."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
    }
    Else
    {
        $output = "[" + (Get-Date).ToString("yyyyMMddhhmmss") + "]" + "Upload deployment log successfully."
        Write-Host $output
        $output | Out-File -filepath $logTgtPath -Append
    }
}

If($config.aws.environment -eq 'PRD')
{
    $credSet = Get-Content -Raw -Path $config.jenkins.credPath | Out-String | ConvertFrom-Json
    $deployUsername = $credSet.cred.username
    $deployPassword = $credSet.cred.password
    $deployDecodedPwd = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($deployPassword)) | ConvertTo-SecureString -asPlainText -Force
    $deployCred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $deployUsername, $deployDecodedPwd

    Foreach($tgtServer in $tgtSrvName)
    {
        Invoke-Command -ComputerName $tgtServer -Credential $deployCred -ScriptBlock $scriptBlock -ArgumentList `
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
}
Else
{
    Foreach($tgtServer in $tgtSrvName)
    {
        Invoke-Command -ComputerName $tgtServer -ScriptBlock $scriptBlock -ArgumentList `
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
}