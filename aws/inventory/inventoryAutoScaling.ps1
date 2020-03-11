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
    $profileName = "awsglobal";
    if($region.Region.StartsWith("cn-"))
    {
        $profileName = "awschina";
    }
    
    $asGroups = Get-ASAutoScalingGroup -ProfileName $profileName -Region $region.region
    
    $htmlLine = "";
    foreach($group in $asGroups)
    {
        $tagEnv = ($group.Tags | Where-Object {$_.Key -eq "ENV"})

        $env = "";
        if($tagEnv.Key.Length -gt 0)
        {
          if($tagEnv.Value -eq "POC")
          {
            $env = "POC";
          }
          elseif($tagEnv.Value -eq "QA")
          {
            $env = "QA";
          }
          elseif($tagEnv.Value -eq "STG")
          {
            $env = "STAGE";
          }
          elseif($tagEnv.Value -eq "PRD")
          {
            $env = "LIVE";
          }
        }
           
        $htmlLine = $("<tr bgcolor=Beige><td colspan=2>" + $group.AutoScalingGroupName + "<sup>" + $env + "</sup></td>");
        $htmlLine = $($htmlLine + "<td colspan=2>" + $group.LoadBalancerNames + "</td>");
        $htmlLine = $($htmlLine + "<td>" + $region.Name + "</td>");
        $htmlLine = $($htmlLine + "<td>Instances(" + $group.Instances.Count.ToString() + ") Desired(" + $group.DesiredCapacity.ToString() + ")</td>");
        $htmlLine = $($htmlLine + "<td>Min(" + $group.MinSize.ToString() + ") Max(" + $group.MaxSize.ToString() + ")</td></tr>");
        
        foreach($instance in $group.Instances)
        {
            $instanceData = (Get-EC2Instance -ProfileName $profileName -Region $region.region -InstanceId $instance.InstanceId).Instances[0]
            
            if($instanceData.State.Name -eq "running")
      {
        $htmlLine = $($htmlLine + "<tr><td width=16px><img src=running.png height=16 width=16 title=Running /></td>");
      }
      else
      {
        $htmlLine = $($htmlLine + "<tr><td width=16px><img src=stopped.png height=16 width=16 title=Stopped /></td>");
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
          $volume = (Get-EC2Volume -ProfileName $profileName -Region $region.region -VolumeId $blockDeviceMapping.Ebs.VolumeId)
          if($volumes.Length -gt 0)
          {$volumes = $($volumes + "," + $volume.Size.ToString() + "gb"); }
          else
          {$volumes = $($volume.Size.ToString() + "gb"); }
      }
      $htmlLine = $($htmlLine + "<td>" + $volumes + "</td>");
      $htmlLine = $($htmlLine + "<td>" + $instanceData.PrivateIPAddress + "</td>");
      $htmlLine = $($htmlLine + "<td>" + $instanceData.PublicIPAddress + "</td></tr>");
      }
                          
                          $tag = ($group.Tags | Where-Object {$_.Key -eq "TEAM"})
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
                          
                          $html | Set-Content 'D:\aws-script\AWS-inventory-scripts\autoscaling.html';
                          
                          Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\aws-script\AWS-inventory-scripts\autoscaling.html" -ProfileName awsglobal  -Region ap-southeast-1
