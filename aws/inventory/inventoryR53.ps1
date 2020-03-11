$teamNULL = "";
$teamBI = "";
$teamBSD = "";
$teamGDM = "";
$teamITIS = "";
$teamPD = "";
$teamSF = "";

$profileName = "awsglobal";

$route53HostedZones = Get-R53HostedZones -ProfileName $profileName
$htmlLine=""
foreach($hostedZone in $route53HostedZones)
{
  $tags = @()
  if($hostedZone.Id.StartsWith("/hostedzone/"))
  {
    $tags = Get-R53TagsForResources -ProfileName $profileName -ResourceId $hostedZone.Id.SubString(12) -ResourceType hostedzone
  }
  $tagTeam = ($tags.Tags | Where-Object {$_.Key -eq "TEAM"})
  $team=""
  if($tagTeam.Key.Length -gt 0)
  {
    $team = $tagTeam.Value
  }
  $tagEnv = ($tags.Tags | Where-Object {$_.Key -eq "ENV"})
  $env=""
  if($tagEnv.Key.Length -gt 0)
  {
    $env = $tagEnv.Value
  }

  $htmlLine = $("<tr><td>" + $hostedZone.Name + "<sup>"+ $env + "</sup></td>")
  $htmlLine = $($htmlLine + "<td>" + (@("Public","Private")[$hostedZone.Config.PrivateZone]) + "</td>")
  $htmlLine = $($htmlLine + "<td>" + $hostedZone.ResourceRecordSetCount.ToString() + "</td>")
  $htmlLine = $($htmlLine + "<td>" + $hostedZone.Config.Comment + "</td>")
  $htmlLine = $($htmlLine + "<td>" + $hostedZone.Id.SubString(12) + "</td></tr>")

  switch($team)
  {
    "BI" {$teamBI = $($teamBI + $htmlLine)}
    "BSD" {$teamBSD = $($teamBSD + $htmlLine)}
    "GDM" {$teamGDM = $($teamGDM + $htmlLine)}
    "ITIS" {$teamITIS = $($teamITIS + $htmlLine)}
    "PD" {$teamPD = $($teamPD + $htmlLine)}
    default {$teamNULL = $($teamNULL + $htmlLine)}
  }
}

$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");

if($teamNULL.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM NULL</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamNULL + "<tr></tr>");
}

if($teamBI.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM BI</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamBI + "<tr></tr>");
}

if($teamBSD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM BSD</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamBSD + "<tr></tr>");
}

if($teamGDM.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM GDM</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamGDM + "<tr></tr>");
}

if($teamITIS.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM ITIS</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamITIS + "<tr></tr>");
}

if($teamPD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM PD</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamPD + "<tr></tr>");
}

if($teamSF.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=5>" + "<b>TEAM SalesForce</b>" + "</td></tr><tr><td><b>Domain Name</b></td><td><b>Type</b></td><td><b>Record Set Count</b></td><td><b>Comment</b></td><td><b>Hosted Zone ID</b></td></tr>");
  $html =  $($html + $teamSF + "<tr></tr>");
}

$html =  $($html + "</table></body></html>");

$filename = 'r53hostedzones.html'
$filepath = $('D:\aws-script\AWS-inventory-scripts\' + $filename)

$html | Set-Content $filepath;

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File $filepath -Key $filename -ProfileName awsglobal  -Region ap-southeast-1
