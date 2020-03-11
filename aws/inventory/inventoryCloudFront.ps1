
$teamNULL = "";
$teamBI = "";
$teamBSD = "";
$teamGDM = "";
$teamITIS = "";
$teamPD = "";
$teamSF = "";

$profileName = "awsglobal";

$cfDistributions = Get-CFDistributions -ProfileName $profileName

foreach($cf in $cfDistributions.Items)
{
    $htmlLine = "";
    if($cf.Enabled -eq 1)
    {
        $htmlLine = "<tr><td width=16px><img src=running.png height=16 width=16 title=Enabled /></td>"
    }
    else
    {
        $htmlLine = "<tr><td width=16px><img src=stopped.png height=16 width=16 title=Disabled /></td>"
    }

    $htmlLine = $($htmlLine + "<td><a href='./CF/" + $cf.ID + ".html'>" + $cf.ID + "</a></td>")
    $htmlLine = $($htmlLine + "<td>" + $cf.DomainName + "</td>")

    $cfOrigins="";
    foreach($origin in $cf.Origins.Items)
    {
        if($cfOrigins.Length)
        {
            $cfOrigins = $($cfOrigins + ", " + $origin.DomainName)
        }
        else
        {
            $cfOrigins = $origin.DomainName
        }
    }

    $htmlLine = $($htmlLine + "<td>" + $cfOrigins + "</td>")
    $htmlLine = $($htmlLine + "<td>" + ($cf.Aliases.Items -Join ", ") + "</td></tr>")

    $tags = (Get-CFResourceTag -ProfileName $profileName -Resource $cf.ARN).Items
    $tagTeam = ($tags | Where-Object {$_.Key -eq "TEAM"})
    if($tagTeam.Key.Length)
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


$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");

if($teamNULL.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM NULL</b>" + "</td></tr><tr><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamNULL + "<tr></tr>");
}

if($teamBI.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM BI</b>" + "</td></tr><tr bgcolor=Beige><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamBI + "<tr></tr>");
}

if($teamBSD.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM BSD</b>" + "</td></tr><tr bgcolor=Beige><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamBSD + "<tr></tr>");
}

if($teamGDM.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM GDM</b>" + "</td></tr><tr bgcolor=Beige><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamGDM + "<tr></tr>");
}

if($teamITIS.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM ITIS</b>" + "</td></tr><tr bgcolor=Beige><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamITIS + "<tr></tr>");
}

if($teamPD.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM PD</b>" + "</td></tr><tr bgcolor=Beige><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamPD + "<tr></tr>");
}

if($teamSF.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=8>" + "<b>TEAM SalesForce</b>" + "</td></tr><tr bgcolor=Beige><td></td><td><b>CF ID</b></td><td><b>Domain Name</b></td><td><b>Origin</b></td><td><b>CNAMEs</b></td></tr>");
    $html =  $($html + $teamSF + "<tr></tr>");
}

$html =  $($html + "</table></body></html>");

$html | Set-Content 'D:\aws-script\AWS-inventory-scripts\cloudfront.html';

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\aws-script\AWS-inventory-scripts\cloudfront.html" -ProfileName awsglobal  -Region ap-southeast-1
