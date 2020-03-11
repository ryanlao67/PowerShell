$regions = Get-AWSRegion -IncludeChina
$teamNULL = "";
$teamBI = "";
$teamBSD = "";
$teamGDM = "";
$teamITIS = "";
$teamPD = "";
$teamSF = "";

foreach($region in $regions)
{
   Set-DefaultAWSRegion $region.region

   echo $region;

   $profileName = "awsglobal";
   if($region.Region.StartsWith("cn-"))
   {
     $profileName = "awschina";
   }

   $elbs = Get-ELBLoadBalancer -ProfileName $profileName

   $htmlLine = "";
   foreach($elb in $elbs)
   { 
     
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
        {$volumes = $($volumes + "," + $volume.Size.ToString() + "gb"); }
        else
        {$volumes = $($volume.Size.ToString() + "gb"); }
    }
    $htmlLine = $($htmlLine + "<td>" + $volumes + "</td>");
    $htmlLine = $($htmlLine + "<td>" + $instanceData.PrivateIPAddress + "</td>");
    $htmlLine = $($htmlLine + "<td>" + $instanceData.PublicIPAddress + "</td></tr>”);
   }

    $tag = ((Get-ELBTags -LoadBalancerName $elb.LoadBalancerName -ProfileName $profileName).Tags | Where-Object {$_.Key -eq "TEAM"})
    if($tag.Key.Length -gt 0)
    {
        if($tag.Value -eq "BI")
        {
            $teamBI = $($teamBI + $htmlLine);
        }
        elseif($tag.Value -eq "BSD")
        {
            $teamBSD = $($teamBSD + $htmlLine);
        }
        elseif($tag.Value -eq "GDM")
        {
            $teamGDM = $($teamGDM + $htmlLine);
        }
        elseif($tag.Value -eq "ITIS")
        {
            $teamITIS = $($teamITIS + $htmlLine);
        }
        elseif($tag.Value -eq "PD")
        {
            $teamPD = $($teamPD + $htmlLine);
        }
        elseif($tag.Value -eq "SF")
        {
            $teamSF = $($teamSF + $htmlLine);
        }
        else
        {
            $teamNULL = $($teamNULL + $htmlLine);
        }
    }
    else
    {
        $teamNULL = $($teamNULL + $htmlLine);
    }

   }
}

$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");

if($teamNULL.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM NULL</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamNULL + "<tr></tr>");
}

if($teamBI.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM BI</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamBI + "<tr></tr>");
}

if($teamBSD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM BSD</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamBSD + "<tr></tr>");
}

if($teamGDM.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM GDM</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamGDM + "<tr></tr>");
}

if($teamITIS.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM ITIS</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamITIS + "<tr></tr>");
}

if($teamPD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM PD</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamPD + "<tr></tr>");
}

if($teamSF.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=7>" + "<b>TEAM SalesForce</b>" + "</td></tr>”); #<tr><td colspan=2><b>Health</b></td><td><b>DNS Name</b></td><td><b>Scheme</b></td><td colspan=2><b>Listeners</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamSF + "<tr></tr>");
}

$html =  $($html + "</table></body></html>");

$html | Set-Content 'D:\aws-script\AWS-inventory-scripts\elb.html';

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\aws-script\AWS-inventory-scripts\elb.html" -ProfileName awsglobal  -Region ap-southeast-1
