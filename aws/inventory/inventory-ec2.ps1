# Define Parameters
$infoLine = ""
$regions = Get-AWSRegion -IncludeChina
$outFile = "C:\Users\ryanlao\Desktop\inventory\ec2.html"

#GettingAllEC2InfoFromAWS
foreach($region in $regions)
{
    $profileName = "awsgbl";
    if($region.Region.StartsWith("cn-"))
    {
        $profileName = "awscn";
    }
    $EIPs = Get-EC2Address -ProfileName $profileName -Region $region.Region
    $groups = Get-EC2Instance -ProfileName $profileName -Region $region.Region
    $ec2servers=@()
    foreach($group in $groups)
    {
        foreach($instance in $group.Instances)
        {
            $ec2servers+=$instance;
        }
    }
    $ec2servers = $ec2servers | sort-object @{Expression={($_.Tags | Where-Object{$_.Key -eq "Name"}).Value}; Ascending=$true}

    foreach($instance in $ec2servers)
    {
        $htmlLine = "";
        if($instance.State.Name -eq "running")
        {
            $htmlLine = "<tr><td><img src=running.png height=16 width=16 title=Running /></td>"
        }
        else
        {
            $htmlLine = "<tr><td><img src=stopped.png height=16 width=16 title=Stopped /></td>"
        }
        if($instance.Platform -ne "Windows")
        {
            $htmlLine = $($htmlLine + "<td>" + "Linux" + "</td>");
        }
        else
        {
            $htmlLine = $($htmlLine + "<td>" + $instance.Platform + "</td>");
        }
        $env =""
        $tagEnv = ($instance.Tags | Where-Object {$_.Key -ieq "ENV"})
        if($tagEnv.Key.Length -gt 0)
        {
            $env=$tagEnv.Value;
        }
        $purpose =""
        $tagPurpose = ($instance.Tags | Where-Object {$_.Key -ieq "PURPOSE"})
        if($tagPurpose.Key.Length -gt 0)
        {
            $purpose=$("<img src=Info.png height=16 width=16 title='" + $tagPurpose.Value + "'/>");
        }
        $tag = ($instance.Tags | Where-Object {$_.Key -ieq "Name"})
        if($tag.Key.Length -gt 0)
        {
            $htmlLine = $($htmlLine + "<td>" + $tag.Value + "<sup>" + $env + "</sup>" + $purpose + "</td>");
        }
        else
        {
            $htmlLine = $($htmlLine + "<td></td>");
        }
        $htmlLine = $($htmlLine + "<td>" + $instance.InstanceType + "</td>");
        $volumes = "";
        foreach($blockDeviceMapping in $instance.BlockDeviceMappings)
        {
            $volume = (Get-EC2Volume -ProfileName $profileName -Region $region.Region -VolumeId $blockDeviceMapping.Ebs.VolumeId)
            if($volumes.Length -gt 0)
            {
                $volumes = $($volumes + "," + $volume.Size.ToString() + "gb");
            }
            else
            {
                $volumes = $($volume.Size.ToString() + "gb");
            }
        }
        $htmlLine = $($htmlLine + "<td>" + $volumes + "</td>");
        $htmlLine = $($htmlLine + "<td>" + $instance.PrivateIPAddress + "</td>");
        if(($EIPs| Where-Object {$_.PublicIp -eq $instance.PublicIPAddress}).Count -gt 0)
        {
            $htmlLine = $($htmlLine + "<td><u>" + $instance.PublicIPAddress + "</u></td>");
        }
        else
        {
            $htmlLine = $($htmlLine + "<td>" + $instance.PublicIPAddress + "</td>");
        }
        $htmlLine = $($htmlLine + "<td>" + $region.Name + "</td></tr>");
        $infoLine += $htmlLine
    }
}

#CombiningHtmlData
$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");
$html = $($html + "<tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
$html = $($html + $infoLine + "<tr></tr>");
$html = $($html + "</table></body></html>");

#UploadFile
$html | Set-Content $outFile
Write-S3Object -BucketName inventory-ryanlao -File $outFile -ProfileName awsgbl
