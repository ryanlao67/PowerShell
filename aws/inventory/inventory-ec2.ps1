# Define Parameters
$awsRegions = Get-AWSRegion -IncludeChina
$outFile = "C:\Users\ryanlao\Desktop\inventory\ec2.html"

$ec2Final = @()
Foreach ($awsRegion in $awsRegions)
{
	$awsProfile = 'awsgbl'
	If($awsRegion.Region -match 'cn-')
	{
		$awsProfile = 'awscn'
	}
	$ec2Raw = Get-EC2Instance -ProfileName $awsProfile -Region $awsRegion
	$ec2Instances = @()

	Foreach($ec2 in $ec2Raw)
	{
		Foreach($ec2Instance in $ec2.Instances)
		{
			$ec2Instances += $ec2Instance
		}
	}
	$ec2Sort = $ec2Instances | Sort-Object @{Expression={($_.Tags | Where {$_.Key -eq "TEAM"}).Value}; Ascending=$TRUE}
	$ec2InfoAll = @()

	Foreach($ec2Detail in $ec2sort)
	{
		$ec2Info = New-Object psobject
		If($ec2Detail.Platform -eq $NULL)
		{
			$ec2Platform = 'Linux'
		}
		Else
		{
			$ec2Platform = $ec2Detail.Platform
		}
		$ec2Volume = $NULL
		Foreach($ec2EBS in $ec2Detail.BlockDeviceMappings)
		{
			$ec2Volumes = (Get-EC2Volume -ProfileName $awsProfile -Region $awsRegion -VolumeId $ec2EBS.Ebs.VolumeId)
			If($ec2Volume.Length -gt 0)
			{
				$ec2Volume = $($ec2Volume + "," + $ec2Volumes.Size.ToString() + "GB")
			}
			Else
			{
				$ec2Volume = $($ec2Volumes.Size.ToString() + "GB")
			}
		}
		$ec2Region = $awsRegion.Region
		$ec2State = $ec2Detail.State.Name
		$ec2Name = ($ec2Detail.Tags | Where {$_.Key -ieq 'Name'}).Value
		$ec2Team = ($ec2Detail.Tags | Where {$_.Key -ieq 'TEAM'}).Value
		$ec2ENV = ($ec2Detail.Tags | Where {$_.Key -ieq 'ENV'}).Value
		$ec2Purpose = ($ec2Detail.Tags | Where {$_.Key -ieq 'PURPOSE'}).Value
		$ec2Type = $ec2Detail.InstanceType
		$ec2PriIP = $ec2Detail.PrivateIpAddress
		$ec2PubIP = $ec2Detail.PublicIpAddress
		$ec2InstanceID = $ec2Detail.InstanceId
		$ec2LaunchTime = $ec2Detail.LaunchTime

		$ec2CPUUtilAVG = (Get-CWMetricStatistics `
            -Dimension @{Name = "InstanceId"; Value = $ec2Detail.InstanceId} `
            -MetricName CPUUtilization `
            -ProfileName $awsProfile `
            -Region $awsRegion `
            -UtcStartTime (Get-Date).AddDays(-30) `
            -UtcEndTime (Get-Date) `
            -Namespace "AWS/EC2" `
            -Period 2592000 `
            -Statistic Average)
		If($ec2CPUUtilAVG.Datapoints.Average -eq "")
		{
			$ec2CPUAVG = "N/A"
		}
		Else
		{
			$ec2CPUAVG = [Math]::Round($ec2CPUUtilAVG.Datapoints.Average[-1],2)
		}

        $ec2CPUUtilMAX = (Get-CWMetricStatistics `
            -Dimension @{Name = "InstanceId"; Value = $ec2Detail.InstanceId} `
            -MetricName CPUUtilization `
            -ProfileName $awsProfile `
            -Region $awsRegion `
            -UtcStartTime (Get-Date).AddDays(-30) `
            -UtcEndTime (Get-Date) `
            -Namespace "AWS/EC2" `
            -Period 2592000 `
            -Statistic Maximum)
		If($ec2CPUUtilMAX.Datapoints.Average -eq "")
		{
			$ec2CPUMAX = "N/A"
		}
		Else
		{
			$ec2CPUMAX = [Math]::Round($ec2CPUUtilMAX.Datapoints.Maximum[-1],2)
		}

		$ec2Info | Add-Member NoteProperty "ENV" $ec2ENV
		$ec2Info | Add-Member NoteProperty "TEAM" $ec2Team
		$ec2Info | Add-Member NoteProperty "EC2Name" $ec2Name
		$ec2Info | Add-Member NoteProperty "PURPOSE" $ec2Purpose
		$ec2Info | Add-Member NoteProperty "InstanceID" $ec2InstanceID
		$ec2Info | Add-Member NoteProperty "PrivateIP" $ec2PriIP

		If($ec2PubIP)
		{
			$ec2Info | Add-Member NoteProperty "PublicIP" $ec2PubIP
		}
		Else
		{
			$ec2Info | Add-Member NoteProperty "PublicIP" "N/A"
		}
		
		$ec2Info | Add-Member NoteProperty "InstanceType" $ec2Type
		$ec2Info | Add-Member NoteProperty "Platform" $ec2Platform
		$ec2Info | Add-Member NoteProperty "Region" $ec2Region
		$ec2Info | Add-Member NoteProperty "Status" $ec2State
		$ec2Info | Add-Member NoteProperty "LaunchTime(UTC)" $ec2LaunchTime
		$ec2Info | Add-Member NoteProperty "CPU Avg(%)" $ec2CPUAVG
        $ec2Info | Add-Member NoteProperty "CPU Peak(%)" $ec2CPUMAX

		$ec2InfoAll += $ec2Info
	}
	$ec2Final += $ec2InfoAll
}
$ec2Final = $ec2Final | Sort-Object ENV, TEAM, PURPOSE, EC2Name, Region

# Inventory Format
$htmlFormat = "<style>"
$htmlFormat = $htmlFormat + "BODY{font-family: Sans-serif; font-size: 15px;}"
$htmlFormat = $htmlFormat + "TABLE{border-width: 2px; border-style: solid; border-color: black; border-collapse: collapse; width: 100%;}"
$htmlFormat = $htmlFormat + "TH{border-width: 2px; padding: 2px; border-style: solid; border-color: black;}"
$htmlFormat = $htmlFormat + "TD{border-width: 2px; padding: 2px; border-style: solid; border-color: orange; white-space:nowrap;}"
$htmlFormat = $htmlFormat + "</style>"

# Upload File
$updateTime = Get-Date
$ec2HTML = $ec2Final | ConvertTo-HTML -Head $htmlFormat -Body "<H2>Updated on $updateTime</H2>"
$ec2HTML | Set-Content $outFile
Write-S3Object -BucketName inventory-ryanlao -File $outFile -ProfileName awsgbl -Region ap-northeast-1