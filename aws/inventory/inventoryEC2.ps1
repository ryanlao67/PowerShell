$regions = Get-AWSRegion -IncludeChina

$teamNULL = "";
$teamBI = "";
$teamBSD = "";
$teamGDM = "";
$teamITIS = "";
$teamPD = "";
$teamSF = "";

#GettingAllResourcesFromAWS
foreach($region in $regions)
{
    $profileName = "aws-global";
    if($region.Region.StartsWith("cn-"))
    {
      $profileName = "aws-china";
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

        $htmlLine = $($htmlLine + "<td>" + $instance.Platform + "</td>");

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
            {$volumes = $($volumes + "," + $volume.Size.ToString() + "gb"); }
            else
            {$volumes = $($volume.Size.ToString() + "gb"); }
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

        $tagTeam = ($instance.Tags | Where-Object {$_.Key -ieq "TEAM"})
        if($tagTeam.Key.Length -gt 0)
        {
        if($tagTeam.Value -eq "BI")
        {
          $teamBI = $($teamBI + $htmlLine);
        }
        elseif($tagTeam.Value -eq "BSD")
          {
            $teamBSD = $($teamBSD + $htmlLine);
          }
          elseif($tagTeam.Value -eq "GDM")
          {
            $teamGDM = $($teamGDM + $htmlLine);
          }
          elseif($tagTeam.Value -eq "ITIS")
          {
            $teamITIS = $($teamITIS + $htmlLine);
          }
          elseif($tagTeam.Value -eq "PD")
          {
            $teamPD = $($teamPD + $htmlLine);
          }
          elseif($tagTeam.Value -eq "SF")
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

#CombiningHtmlData
$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");

if($teamNULL.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM NULL</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamNULL + "<tr></tr>");
}

if($teamBI.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM BI</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamBI + "<tr></tr>");
}

if($teamBSD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM BSD</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamBSD + "<tr></tr>");
}

if($teamGDM.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM GDM</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamGDM + "<tr></tr>");
}

if($teamITIS.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM ITIS</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamITIS + "<tr></tr>");
}

if($teamPD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM PD</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamPD + "<tr></tr>");
}

if($teamSF.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM SalesForce</b>" + "</td></tr><tr><td></td><td><b>Platform</b></td><td><b>Name</b></td><td><b>Instance Type</b></td><td><b>Volumes</b></td><td><b>Private IP</b></td><td><b>Public IP</b></td><td><b>Region</b></td></tr>");
  $html =  $($html + $teamSF + "<tr></tr>");
}

$html =  $($html + "</table></body></html>");

#UploadFile

$html | Set-Content 'D:\aws-script\AWS-inventory-scripts\ec2.html';

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\aws-script\AWS-inventory-scripts\ec2.html" -ProfileName awsglobal  -Region ap-southeast-1
