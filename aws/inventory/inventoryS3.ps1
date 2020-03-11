Function Get-Size-Calculated ($size)
{ 
	 if($size -lt 1024)
                                            {
                                                      $sizeCalculated = $($size.ToString() + ' b');
                                            }
                                    elseif($size -lt 1048576)
                                    {
                                                $sizeCalculated = $(($size/1024).ToString() + ' kb');
                                            }
                                    elseif($size -lt 1073741824)
                                    {
                                                $sizeCalculated = $(($size/1048576).ToString() + ' mb');
                                            }
                                    elseif($size -lt 1099511627776)
                                            {
                                                        $sizeCalculated = $(($size/1073741824).ToString() + ' gb');
                                            }
			  else
				{
					$sizeCalculated = $(($size/1099511627776).ToString() + ' tb');
				}
	return $sizeCalculated;
}


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
    $bucketSizeTeamNULL = 0;
    $bucketSizeTeamBI = 0;
    $bucketSizeTeamBSD = 0;
    $bucketSizeTeamGDM = 0;
    $bucketSizeTeamITIS = 0;
    $bucketSizeTeamPD = 0;
    $bucketSizeTeamSF = 0;

	  $bucketSizeTeamNULL_RR = 0;
    $bucketSizeTeamBI_RR = 0;
    $bucketSizeTeamBSD_RR = 0;
    $bucketSizeTeamGDM_RR = 0;
    $bucketSizeTeamITIS_RR = 0;
    $bucketSizeTeamPD_RR = 0;
    $bucketSizeTeamSF_RR = 0;
    
    $profileName = "awsglobal";
    if($region.Region.StartsWith("cn-"))
    {
        $profileName = "awschina";
    }
    
    $dimension1 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension1.set_Name("BucketName")
    $dimension2 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension2.set_Name("StorageType")
    $dimension2.set_Value("StandardStorage")
    $dimension3 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension3.set_Name("StorageType")
    $dimension3.set_Value("ReducedRedundancyStorage")
    
    $dimensionSets = (@($dimension1,$dimension2),@($dimension1,$dimension3))
    
    $s3Buckets = Get-S3Bucket -ProfileName $profileName -Region $region.Region
    
    foreach($s3Bucket in $s3Buckets)
    {
        $dimension1.set_Value($s3Bucket.BucketName)

        
        foreach($dimensionSet in $dimensionSets)
        {
            $metrics = (Get-CWMetricStatistics -Dimension $dimensionSet -EndTime (Get-Date).ToUniversalTime() -MetricName BucketSizeBytes -Namespace AWS/S3 -Period 1200 -ProfileName $profileName -Region $region.Region -StartTime (Get-Date).ToUniversalTime().AddDays(-1) -Statistic Maximum -Unit Bytes);
            
            $bucketSize = 0
            
            if($metrics.datapoints.count -gt 0)
            {
                $bucketSize = $metrics.datapoints[0].Maximum;
            }

            
            if($bucketSize -gt 0)
            {
                
                if ($dimensionSets.IndexOf($dimensionSet) -eq 0)
                {
                    $storageType = "StandardStorage";
                }
                else
                {
                    $storageType = "ReducedRedundancyStorage";
                }
                $team = "NULL"
                $tag = (Get-S3BucketTagging -BucketName $s3Bucket.BucketName -ProfileName $profileName -Region $region.Region | Where-Object {$_.Key -eq "TEAM"})
                
                if($tag.Key.Length -gt 0)
                {
                    $team = $tag.Value;
                }
                $sizeCalculated = Get-Size-Calculated($bucketSize);
                $htmlData = $(" <tr>" + "<td>" + $s3Bucket.BucketName + "</td>" + "<td>" + $storageType + "</td>" + "<td>" + $sizeCalculated + "</td>" + "<td>" + $region.Name + "</td>" + "</tr>");
                
                if($team -eq "NULL")
                {$teamNULL = $($teamNULL + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamNULL += $bucketSize; } else { $bucketSizeTeamNULL_RR += $bucketSize; }}
                elseif($team -eq "BI")
                {$teamBI = $($teamBI + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamBI += $bucketSize; } else { $bucketSizeTeamBI_RR += $bucketSize; }}
                elseif($team -eq "BSD")
                {$teamBSD = $($teamBSD + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamBSD += $bucketSize; } else { $bucketSizeTeamBSD_RR += $bucketSize; }}
                elseif($team -eq "GDM")
                {$teamGDM = $($teamGDM + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamGDM += $bucketSize; } else { $bucketSizeTeamGDM_RR += $bucketSize; }}
                elseif($team -eq "ITIS")
                {$teamITIS = $($teamITIS + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamITIS += $bucketSize; } else { $bucketSizeTeamITIS_RR += $bucketSize; }}
                elseif($team -eq "PD")
                {$teamPD = $($teamPD + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamPD += $bucketSize; } else { $bucketSizeTeamPD_RR += $bucketSize; }}
                elseif($team -eq "SF")
                {$teamSF = $($teamSF + $htmlData + ' '); if($dimensionSets.IndexOf($dimensionSet) -eq 0) { $bucketSizeTeamSF += $bucketSize; } else { $bucketSizeTeamSF_RR += $bucketSize; }}
            }
        }
    }

    
    if($bucketSizeTeamNULL -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamNULL);
        $htmlData = $(" <tr bgcolor=Beige><td><b>NULL - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamNULL = $($teamNULL + $htmlData);
    }
    if($bucketSizeTeamBI -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamBI);
        $htmlData = $(" <tr bgcolor=Beige><td><b>NULL - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamBI = $($teamBI + $htmlData);
    }
    if($bucketSizeTeamBSD -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamBSD);
        $htmlData = $(" <tr bgcolor=Beige><td><b>BSD - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamBSD = $($teamBSD + $htmlData);
    }
    if($bucketSizeTeamGDM -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamGDM);
        $htmlData = $(" <tr bgcolor=Beige><td><b>GDM - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamGDM = $($teamGDM + $htmlData);
    }
    if($bucketSizeTeamITIS -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamITIS);
        $htmlData = $(" <tr bgcolor=Beige><td><b>ITIS - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamITIS= $($teamITIS + $htmlData);
    }
    if($bucketSizeTeamPD -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamPD);
        $htmlData = $(" <tr bgcolor=Beige><td><b>PD - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamPD = $($teamPD + $htmlData);
    }
    if($bucketSizeTeamSF -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamSF);
        $htmlData = $(" <tr bgcolor=Beige><td><b>SF - Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamSF = $($teamSF + $htmlData);
    }
    if($bucketSizeTeamNULL_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamNULL_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>NULL - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamNULL = $($teamNULL + $htmlData);
    }
    if($bucketSizeTeamBI_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamBI_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>BI - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamBI = $($teamBI + $htmlData);
    }
    if($bucketSizeTeamBSD_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamBSD_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>BSD - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamBSD = $($teamBSD + $htmlData);
    }
    if($bucketSizeTeamGDM_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamGDM_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>GDM - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamGDM = $($teamGDM + $htmlData);
    }
    if($bucketSizeTeamITIS_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamITIS_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>ITIS - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamITIS= $($teamITIS + $htmlData);
    }
    if($bucketSizeTeamPD_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamPD_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>PD - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamPD = $($teamPD + $htmlData);
    }
    if($bucketSizeTeamSF_RR -gt 0)
    {
        $sizeCalculated = Get-Size-Calculated($bucketSizeTeamSF_RR);
        $htmlData = $(" <tr bgcolor=Beige><td><b>SF - Total Size</b></td><td><b>ReducedRedundancyStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
        $teamSF = $($teamSF + $htmlData);
    }
}


$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");

if($teamNULL.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "<b>TEAM NULL</b>" + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
    $html =  $($html + $teamNULL + "<tr></tr>");
}

if($teamBSD.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "<b>TEAM BSD</b>" + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
    $html =  $($html + $teamBSD + "<tr></tr>");
}

if($teamGDM.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "<b>TEAM GDM</b>" + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
    $html =  $($html + $teamGDM + "<tr></tr>");
}

if($teamITIS.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "<b>TEAM ITIS</b>" + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
    $html =  $($html + $teamITIS + "<tr></tr>");
}

if($teamPD.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "<b>TEAM PD</b>" + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
    $html =  $($html + $teamPD + "<tr></tr>");
}

if($teamSF.Length -gt 0)
{
    $html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "<b>TEAM SalesForce</b>" + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
    $html =  $($html + $teamSF + "<tr></tr>");
}

$html =  $($html + "</table></body></html>");

if(($teamNULL.Length -gt 0) -or ($teamBI.Length -gt 0) -or ($teamBSD.Length -gt 0) -or ($teamGDM.Length -gt 0) -or ($teamITIS.Length -gt 0) -or ($teamPD.Length -gt 0) -or ($teamSF.Length -gt 0))
{

$html | Set-Content 'D:\aws-script\AWS-inventory-scripts\s3.html';

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\aws-script\AWS-inventory-scripts\s3.html" -ProfileName awsglobal -Region ap-southeast-1
}
else
{
    exit 0
}