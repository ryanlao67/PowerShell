# Define Parameters
$infoLine = ""
$regions = Get-AWSRegion -IncludeChina
$outFile = "C:\Users\ryanlao\Desktop\inventory\s3.html"

Function Get-Size-Calculated ($size)
{ 
	 if($size -lt 1024)
     {
         $sizeCalculated = $($size.ToString() + " B");
     }
     elseif($size -lt 1048576)
     {
         $sizeCalculated = [math]::round($size/1KB, 3) + " KB"
     }
     elseif($size -lt 1073741824)
     {
         $sizeCalculated = [math]::round($size/1MB, 3) + " MB"
     }
     elseif($size -lt 1099511627776)
     {
         $sizeCalculated = [math]::round($size/1GB, 3) + " GB"
     }
     else
     {
         $sizeCalculated = [math]::round($size/1TB, 3) + " TB"
     }
     return $sizeCalculated;
}

foreach($region in $regions)
{
    $totalsize = 0
    $totalsizeRR = 0
    
    $profileName = "awsgbl";
    if($region.Region.StartsWith("cn-"))
    {
        $profileName = "awscn";
    }
    
    $dimension1 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension1.set_Name("BucketName")
    $dimension2 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension2.set_Name("StorageType")
    $dimension2.set_Value("Standard")
    $dimension3 = New-Object Amazon.CloudWatch.Model.Dimension
    $dimension3.set_Name("StorageType")
    $dimension3.set_Value("ReducedRedundancy")
    $dimensionSets = (@($dimension1,$dimension2),@($dimension1,$dimension3))
    
    $s3Buckets = Get-S3Bucket -ProfileName $profileName -Region $region.Region
    
    foreach($s3Bucket in $s3Buckets)
    {
        $dimension1.set_Value($s3Bucket.BucketName)
        foreach($dimensionSet in $dimensionSets)
        {
            $metrics = (Get-CWMetricStatistics -Dimension $dimensionSet `
                            -UtcEndTime (Get-Date).ToUniversalTime() `
                            -MetricName BucketSizeBytes `
                            -Namespace AWS/S3 `
                            -Period 1200 `
                            -ProfileName $profileName `
                            -Region $region.Region `
                            -UtcStartTime (Get-Date).ToUniversalTime().AddDays(-1) `
                            -Statistic Maximum -Unit Bytes);
            $bucketSize = 0
            if($metrics.datapoints.count -gt 0)
            {
                $bucketSize = $metrics.datapoints[0].Maximum;
            }
            if($bucketSize -gt 0)
            {
                Write-Host $s3Bucket.BucketName
                Write-Host $bucketSize
                if ($dimensionSets.IndexOf($dimensionSet) -eq 0)
                {
                    $storageType = "StandardStorage";
                }
                else
                {
                    $storageType = "ReducedRedundancyStorage";
                }
                $sizeCalculated = Get-Size-Calculated($bucketSize);
                $htmlData = $(" <tr>" + "<td>" + $s3Bucket.BucketName + "</td>" + "<td>" + $storageType + "</td>" + "<td>" + $sizeCalculated + "</td>" + "<td>" + $region.Name + "</td>" + "</tr>");
                $infoLine += $($htmlData + " ")
                Write-Host $infoLine
                if($dimensionSets.IndexOf($dimensionSet) -eq 0)
                {
                    $totalsize += $bucketSize
                }
                else
                {
                    $totalsizeRR += $bucketSize
                }
            }
        }
    }


    $htmlData = $(" <tr bgcolor=Beige><td><b>Total Size</b></td><td><b>StandardStorage</b></td><td><b>" + $sizeCalculated + "</b></td>" + "<td><b>" + $region.Name + "</b></td>" + "</tr>");
    $infoLine = $($infoLine + $htmlData)

}

#CombiningHtmlData
$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");
$html =  $($html + "<tr bgcolor=silver><td colspan=4>” + "</td></tr><tr bgcolor=silver><td><b>Bucket Name</b></td><td><b>Storage Type</b></td><td><b>Size</b></td><td><b>Region</b></td></tr>");
$html =  $($html + $infoLine + "<tr></tr>");
$html =  $($html + "</table></body></html>");

#UploadFile
$html | Set-Content $outFile
Write-S3Object -BucketName inventory-ryanlao -File $outFile -ProfileName awsgbl -Region ap-northeast-1