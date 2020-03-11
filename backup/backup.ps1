################################################
# Example: .\NC_Win_Backup.ps1 config.xml C
################################################
# Change Log
# May 25, 2016 RL: * Initial Create
# June 27, 2016 RL: Main function done
# June 29, 2016 RL:  Add function PurgeOldBak
################################################

Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [string] $Config,
    
    [Parameter(Mandatory = $False, Position = 1)]
    [string] $Feature
)

# Load Configuration File
[XML]$Setting = Get-Content $Config

# Global Parameters
$BakDate = Get-Date
$SrvName = hostname
$Date4Folder = $BakDate.ToString("yyyyMMdd")
$Date4File = $BakDate.ToString("HHmmss")

$BakLog = $Setting.Configuration.General.LogFolder + "\Backup.log"
$LocalBak = $Setting.Configuration.General.LocalBackup

$files = @($Setting.Configuration.Fileset.FilesetInclude.Parameter.value)
$filesxlu = @($Setting.Configuration.Fileset.FilesetExclude.Parameter.value)

$Obj = $Setting.Configuration.Compression.Objective
$Dest = $Setting.Configuration.Compression.Destination
$RemObj = $Setting.Configuration.Compression.RemoveObjective

$EncryptObj = $Setting.Configuration.Encryption.Objective
$EncryptDest = $Setting.Configuration.Encryption.Destination
$EncryptRemObj = $Setting.Configuration.Encryption.RemoveObjective

$Bucket = $Setting.Configuration.Storage.BucketName
$AccInfo = Get-Content $Setting.Configuration.Storage.StorageKey

# Define backup file name and full path
$Bakfolder = $Dest + '\' + $Date4Folder
New-Item $Bakfolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$zipfileraw = 
$zipfile = $Bakfolder + '\BAK_' + $Date4File + '.zip'
$zipfile_encrypt = $EncryptDest + '\BAK_' + $Date4File + '_encrypted.zip'

# 7-Zip parameters
## Add files to zip archive
$7zcmd = '7z.exe'
$7zadd2zip = 'a -tzip'
## Compress method: extract files with full paths, recurse subdirectories
$7zparam = '-mx0 -r0'
## Exclude parameter
$7zxlu = '-x!'
## Split size
$7zSplit = '-v100M'
# Encryption AES256
$EncryptAES = '-mem=AES256'
# Key for encryption
$EncryptPwd = '-p' + (Get-Content $Setting.Configuration.Encryption.EncryptionKey)

# Initial zip command
$zipcmd = 'Start-Process -wait ' + $7zcmd + " -ArgumentList "
$ziparg = $7zadd2zip + " " + $zipfile + " " + $7zSplit + " "

Function FilesetBak
{
    # Fileset include
    for($i=0; $i -lt $files.Count; $i++)
    {
        $inclucmd = $inclucmd + '`"' + $files[$i] + '`"' + " "
    }

    # Fileset exclude
    for($j=0; $j -lt $filesxlu.Count; $j++)
    {
        $xlucmd = $xlucmd + $7zxlu + $filesxlu[$j] + " "
    }
    
    # Generate backup command
    $ziparg = $ziparg + $inclucmd + $7zparam + " " + $xlucmd + " " + $EncryptAES + " " + $EncryptPwd
    $zipcmd = $zipcmd + '"' + $ziparg + '"'

    # Print execute command
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Below is backup command which will be executed:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    $zipcmd
    
    # Print fileset include
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "File set will be backed up:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    $files
    
    # Print fileset exclude
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "File type will be excluded:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    $filesxlu

    # Execute backup command
    Invoke-Expression "& $zipcmd"
}

Function CompressionBak
{
    # Generate backup command
    $ziparg = $ziparg + $Obj + " " + $7zparam
    $zipcmd = $zipcmd + '"' +$ziparg+ '"'
    
    # Print commpression command
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Commpression command:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host $zipcmd
    
    # Execute commpression command
    Invoke-Expression "& $zipcmd"

    # Remove objective file
    If ($RemObj -eq $TRUE)
    {
        Get-ChildItem $Obj | Remove-Item -Force -Recurse
    }
}

Function EncryptionBak
{
    # Encryption argument list
    $EncryptArg = $7zadd2zip + " " + $zipfile_encrypt + " " + $7zSplit+ " " + $EncryptObj + " " + $7zparam + " " + $EncryptAES + " " + $EncryptPwd
    
    # Generate encryption command
    $zipcmd = $zipcmd + '"' +$EncryptArg+ '"'
    
    # Print encryption command
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Encryption command:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host $zipcmd
    
    # Execute commpression command
    Invoke-Expression "& $zipcmd"
    
    # Remove objective file
    If ($EncryptRemObj -eq $TRUE)
    {
        Get-ChildItem $EncryptObj | Remove-Item -Force -Recurse
    }
}

Function StorageBak
{
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Upload local backup to S3:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green

    # Generate upload command on the server
    $KeyPrefix = $SrvName + '\' + $Date4Folder + '\'
    $UploadFolder = $LocalBak + '\' + $Date4Folder + '\'
    Write-S3Object -BucketName $Bucket -Folder $UploadFolder -KeyPrefix $KeyPrefix -AccessKey $AccInfo[1] -SecretKey $AccInfo[2] -Region $AccInfo[0] -Recurse
    If ($? -eq $TRUE)
    {
        Write-Host "Upload local backup to S3 successfully."
    }
    Else
    {
        Write-Host "Upload local backup to S3 Failed." -Foregroundcolor Yellow
    }
}

Function UploadBRT
{
    $size = [Math]::Round(((Get-ChildItem $Bakfolder | Measure-Object -Sum Length).Sum / 1MB), 2)
    $SizeBRT = [String]$size + " MB"
    $postParams = @{srvname=$SrvName; result='OK'; size=$SizeBRT; bckmethod="nc-win-backup"; destination="Customer S3"}
    $Wget = Invoke-WebRequest -Uri "https://backupreporter.service.chinanetcloud.com/backup_report_service/backup_service.php" -Method POST -Body $postParams
    $Wget | Out-Null
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Upload status to Backup Report System:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Upload status:" $Wget.StatusDescription "| Status Code:" $Wget.StatusCode 
}

Function PurgeOldBak
{
    $PurgeDaily = (Get-Date).AddDays(-1).ToString("yyyyMMdd")
    $PurgeWeekly = (Get-Date).AddDays(-7).ToString("yyyyMMdd")
    $PurgeMonthly = (Get-Date).AddDays(-30).ToString("yyyyMMdd")
    $S3Key = $SrvName + "\" + $Date4Folder
    $S3BakSize = ((Get-S3Object -BucketName $Bucket -KeyPrefix $S3Key -AccessKey $AccInfo[1] -SecretKey $AccInfo[2] -Region $AccInfo[0] | Where {$_.Size -ne 0}).size | Measure-Object -Sum).Sum

    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    Write-Host "Ready to purge old backup data:" -Foregroundcolor Green
    Write-Host "-----------------------------------------------" -Foregroundcolor Green
    
    If ($S3BakSize -eq (Get-ChildItem $Bakfolder | Measure-Object -Sum Length).Sum)
    {
        If (Test-Path $LocalBak\$PurgeDaily)
        {
            Remove-Item $LocalBak\$PurgeDaily\ -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Local backup folder"$LocalBak\$PurgeDaily "has been removed due to purge old data."
        }
        Else
        {
            Write-Host "Local backup folder"$LocalBak\$PurgeDaily "doesn't exist on the server." -Foregroundcolor Yellow
        }
    }
    Else
    {
        Write-Host "The size of backup files on public cloud storage is different with local backup! Please check!" -Foregroundcolor Yellow
    }
}

# Main Script
If ($Feature -eq "")
{
    FilesetBak
    StorageBak
    UploadBRT
    PurgeOldBak
}
Else
{
    Switch($Feature)
    {
        'C' {CompressionBak;break}
        'E' {EncryptionBak;break}
        'S' {StorageBak;break}
        'P' {PurgeOldBak;break}
    }
}