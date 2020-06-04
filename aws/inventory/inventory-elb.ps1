# Define Parameters
$infoLine = ""
$regions = Get-AWSRegion -IncludeChina
$outFile = "C:\Users\ryanlao\Desktop\inventory\elb.html"

#GettingAllELBInfoFromAWS
foreach($region in $regions)
{
    Set-DefaultAWSRegion $region.region
    $profileName = "awsgbl";
    if($region.Region.StartsWith("cn-"))
    {
        $profileName = "awscn";
    }
    $elbs = Get-ELBLoadBalancer -ProfileName $profileName
    $htmlLine = "";
    foreach($elb in $elbs)
    {
        #GetHealthState
        $healthHostCount = 0;
        $instanceHealth = (Get-ELBInstanceHealth -LoadBalancerName $elb.LoadBalancerName -ProfileName $profileName)
        foreach($health in $instanceHealth)
        {
            if($health.State -eq “InService”)
            {
                $healthHostCount += 1;
            }
        }
        if($healthHostCount -ne $instanceHealth.Count)
        {
            $htmlLine = $(“<tr bgcolor=Beige><td colspan=2><img src=stopped.png height=16 width=16>” + $healthHostCount.ToString() + “ out of ” + $instanceHealth.Count.ToString() + “ healthy</td>”);
        }
        else
        {
            $htmlLine = $(“<tr bgcolor=Beige><td colspan=2><img src=running.png height=16 width=16>” + $healthHostCount.ToString() + “ out of ” + $instanceHealth.Count.ToString() + “ healthy</td>”);
        }
        $htmlLine = $($htmlLine + “<td>” + $elb.DNSName + ”</td>”);
        $htmlLine = $($htmlLine + “<td>” + $elb.Scheme + ”</td>”);
        #GetListenerInfo
        $htmlLineListener = “”;
        foreach($listenerdesc in $elb.ListenerDescriptions)
        {
            if($htmlLineListener.Length -gt 0)
            {
                $htmlLineListener = $($htmlLineListener + “ & ” + $($listenerdesc.Listener.LoadBalancerPort.ToString() + “->“ + $listenerdesc.Listener.InstancePort.ToString()));
            }
            else
            {
                $htmlLineListener = $($listenerdesc.Listener.LoadBalancerPort.ToString() + “->” + $listenerdesc.Listener.InstancePort.ToString());
            }
        }
        $htmlLine = $($htmlLine + “<td>Listeners: ” + $htmlLineListener + ”</td>”);
        $htmlLine = $($htmlLine + “<td>HealthCheckTarget: ” + $elb.HealthCheck.Target + ”</td>”);
        $htmlLine = $($htmlLine + "<td>" + $region.Name + "</td></tr>");
        #GetInstanceBehindInfo
        foreach($instance in $elb.Instances)
        {
            $instanceData = (Get-EC2Instance -ProfileName $profileName -InstanceId $instance.InstanceId).Instances[0]
            $healthy=$false;
            foreach($health in $instanceHealth)
            {
                if(($health.State -eq “InService”) -and ($health.InstanceId -eq $instance.InstanceId))
                {
                    $healthy=$true;
                }
            }
            if($healthy)
            {
                $htmlLine = $($htmlLine + "<tr><td><img src=running.png height=16 width=16 title=Healthy /></td>")
            }
            else
            {
                $htmlLine = $($htmlLine + "<tr><td><img src=stopped.png height=16 width=16 title=Unhealthy /></td>")
            }

            $htmlLine = $($htmlLine + "<td>" + $instanceData.Platform + "</td>");
            $tag = ($instanceData.Tags | Where-Object {$_.Key -eq "Name"})
            if($tag.Key.Length -gt 0)
            {
                $htmlLine = $($htmlLine + "<td>" + $tag.Value + "</td>");
            }
            else
            {
                $htmlLine = $($htmlLine + "<td></td>");
            }

            $htmlLine = $($htmlLine + "<td>" + $instanceData.InstanceType + "</td>");
            $volumes = "";
            foreach($blockDeviceMapping in $instanceData.BlockDeviceMappings)
            {
                $volume = (Get-EC2Volume -ProfileName $profileName -VolumeId $blockDeviceMapping.Ebs.VolumeId)
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
            $htmlLine = $($htmlLine + "<td>" + $instanceData.PrivateIPAddress + "</td>");
            $htmlLine = $($htmlLine + "<td>" + $instanceData.PublicIPAddress + "</td></tr>”);
        }
        $infoLine += $htmlLine
    }
}

#CombiningHtmlData
$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");
$html =  $($html + "<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
$html = $($html + $infoLine + "<tr></tr>");
$html =  $($html + "</table></body></html>");

#UploadFile
$html | Set-Content $outFile
Write-S3Object -BucketName inventory-ryanlao -File $outFile -ProfileName awsgbl -Region ap-northeast-1