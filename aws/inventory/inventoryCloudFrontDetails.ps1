$profileName = "awsglobal";

$cfDistributions = Get-CFDistributions -ProfileName $profileName

foreach($cf in $cfDistributions.Items)
{
    $cfDetail = Get-CFDistribution -Id $cf.ID.ToString() -ProfileName $profileName

    $html = Get-Content 'D:\aws-script\AWS-inventory-scripts\CF\CfDistributionTemplate.html';
    $html = $html -replace "{Date_Time}",(Get-Date).ToUniversalTime();
    $html = $html -replace "{Distribution_ID}",$cf.ID.ToString();
    $html = $html -replace "{ARN}",$cf.ARN.ToString();
    $html = $html -replace "{Log_Prefix}",@("-",$cfDetail.DistributionConfig.Logging.Prefix)[$cfDetail.DistributionConfig.Logging.Prefix]
    $html = $html -replace "{Delivery_Method}","Web"
    $html = $html -replace "{Cookie_Logging}",@("Off","On")[$cfDetail.DistributionConfig.Logging.IncludeCookies]
    $html = $html -replace "{Distribution_Status}",$cfDetail.Status
    $html = $html -replace "{Comment}",("-",$cf.Comment)[$cf.Comment]
    $html = $html -replace "{Price_Class}",$cf.PriceClass
    $html = $html -replace "{State}", @("Disabled","Enabled")[$cf.Enabled]
    $html = $html -replace "{CNAMEs}",($cf.Aliases.Items -Join ", ")
    $html = $html -replace "{SSL_Certificate}",$cf.ViewerCertificate.Certificate
    $html = $html -replace "{Domain_Name}",$cf.DomainName
    $html = $html -replace "{Supported_HTTP_Versions}",@("HTTP/1.1, HTTP/1.0","HTTP/2, HTTP/1.1, HTTP/1.0")[$cfDetail.DistributionConfig.HttpVersion.Value -eq "http2"]
    $html = $html -replace "{Default_Root_Object}",@("-","$cfDetail.DistributionConfig.DefaultRootObject")[$cfDetail.DistributionConfig.DefaultRootObject]
    $html = $html -replace "{Last_Modified}",$cfDetail.LastModifiedTime.ToString()
    $html = $html -replace "{Log_Bucket}",@("-",$cfDetail.DistributionConfig.Logging.Bucket)[$cfDetail.DistributionConfig.Logging.Bucket]

    foreach($origin in $cfDetail.DistributionConfig.Origins.Items)
    {
      if($origin.S3OriginConfig)
      {
        $htmlLine = "<table width=100%>"
        $htmlLine = $($htmlLine + "<tr bgcolor=Beige><td colspan=4>S3 Origin</td></tr>")
        $htmlLine = $($htmlLine + "<tr><td><b>Domain Name</b></td><td><b>Origin Path</b></td><td><b>Origin ID</b></td><td><b>Restrict Bucket Access</b></td></tr>")
        $htmlLine = $($htmlLine + "<tr><td>" + $origin.DomainName + "</td>")
        $htmlLine = $($htmlLine + "<td>" + (@("-",$origin.OriginPath)[$origin.OriginPath]) + "</td>")
        $htmlLine = $($htmlLine + "<td>" + $origin.Id + "</td>")
        $htmlLine = $($htmlLine + "<td>" + (@("No","Yes")[$origin.S3OriginConfig.OriginAccessIdentity.Length -gt 0]) + "</td></tr>")
      }
      else
      {
        $htmlLine = "<table width=100%>"
        $htmlLine = $($htmlLine + "<tr bgcolor=Beige><td colspan=7>Custom Origin</td></tr>")
        $htmlLine = $($htmlLine + "<tr><td><b>Domain Name</b></td><td><b>Origin Path</b></td><td><b>Origin ID</b></td><td><b>SSL Protocols</b></td><td><b>HTTP Port</b></td><td><b>HTTPS Port</b></td></tr>")
        $htmlLine = $($htmlLine + "<tr><td>" + $origin.DomainName + "</td>")
        $htmlLine = $($htmlLine + "<td>" + (@("-",$origin.OriginPath)[$origin.OriginPath]) + "</td>")
        $htmlLine = $($htmlLine + "<td>" + $origin.Id + "</td>")
        $htmlLine = $($htmlLine + "<td>" + ($origin.CustomOriginConfig.OriginSslProtocols.Items -join ", ") + "</td>")
        $htmlLine = $($htmlLine + "<td>" + $origin.CustomOriginConfig.HTTPPort + "</td>")
        $htmlLine = $($htmlLine + "<td>" + $origin.CustomOriginConfig.HTTPSPort + "</td></tr>")
      }

      if($origin.CustomHeaders.Items.Count)
        {
          $htmlLine = $($htmlLine + "<tr><td><b>Header Name</b></td><td><b>Value</b></td></tr>")
          foreach($headers in $origin.CustomHeaders.Items)
          {
            $htmlLine = $($htmlLine + "<tr><td>" + $headers.HeaderName + "</td><td>" + $headers.HeaderValue + "</td></tr>")
          }
      }
      $htmlLine = $($htmlLine + "</table>")
    }

    $html = $html -replace "{Origins_Table}",$htmlLine

    $precedence=0;
    $htmlLine = "<table width=100%>"
    foreach($cache in $cfDetail.DistributionConfig.CacheBehaviors.Items)
    {
      $htmlLine = $($htmlLine + "<tr bgcolor=Beige><td colspan=2><b>Precedence - " + $precedence.ToString() + "</b></td></tr>")
      $precedence+=1;
      $htmlLine = $($htmlLine + "<tr><td><b>Path Pattern</b></td><td>" + $cache.PathPattern + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Origin ID</b></td><td>" + $cache.TargetOriginId + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Viewer Protocol Policy</b></td><td>" + (@((@("HTTPS Only","Redirect HTTP to HTTPS")[$cache.ViewerProtocolPolicy -eq "redirect-to-https"]),"HTTP and HTTPS")[$cache.ViewerProtocolPolicy -eq "allow-all"]) + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Allowed HTTP Methods</b></td><td>" + ($cache.AllowedMethods.Items -join ", ") + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Cached HTTP Methods</b></td><td>" + ($cache.AllowedMethods.CachedMethods.Items -join ", ") + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Forward Headers</b></td><td>" + (@("No(Improves Caching)","Yes")[$cache.ForwardedValues.Headers.Items.Count]) + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Min TTL</b></td><td>" + $cache.MinTTL.ToString() + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Max TTL</b></td><td>" + $cache.MaxTTL.ToString() + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Default TTL</b></td><td>" + $cache.DefaultTTL.ToString() + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Query String Forwarding & Caching</b></td><td>" + (@("No","Yes")[$cache.ForwardedValues.QueryString]) + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Smooth Streaming</b></td><td>" + (@("No","Yes")[$cache.SmoothStreaming]) + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>Restrict Viewer Access</b></td><td>" + (@("Yes","No")[$cache.ViewerProtocolPolicy -eq "allow-all"]) + "</td></tr>")
      $htmlLine = $($htmlLine + "<tr><td><b>GZip compressing</b></td><td>" + (@("No","Yes")[$cache.Compress -eq "compress"]) + "</td></tr>")
    }

    $cache = $cfDetail.DistributionConfig.DefaultCacheBehavior
    $htmlLine = $($htmlLine + "<tr bgcolor=Beige><td colspan=2><b>Precedence - " + $precedence.ToString() + "</b></td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Path Pattern</b></td><td>Default (*)</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Origin ID</b></td><td>" + $cache.TargetOriginId + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Viewer Protocol Policy</b></td><td>" + (@((@("HTTPS Only","Redirect HTTP to HTTPS")[$cache.ViewerProtocolPolicy -eq "redirect-to-https"]),"HTTP and HTTPS")[$cache.ViewerProtocolPolicy -eq "allow-all"]) + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Allowed HTTP Methods</b></td><td>" + ($cache.AllowedMethods.Items -join ", ") + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Cached HTTP Methods</b></td><td>" + ($cache.AllowedMethods.CachedMethods.Items -join ", ") + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Forward Headers</b></td><td>" + (@("No(Improves Caching)","Yes")[$cache.ForwardedValues.Headers.Items.Count]) + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Min TTL</b></td><td>" + $cache.MinTTL.ToString() + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Max TTL</b></td><td>" + $cache.MaxTTL.ToString() + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Default TTL</b></td><td>" + $cache.DefaultTTL.ToString() + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Query String Forwarding & Caching</b></td><td>" + (@("No","Yes")[$cache.ForwardedValues.QueryString]) + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Smooth Streaming</b></td><td>" + (@("No","Yes")[$cache.SmoothStreaming]) + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>Restrict Viewer Access</b></td><td>" + (@("Yes","No")[$cache.ViewerProtocolPolicy -eq "allow-all"]) + "</td></tr>")
    $htmlLine = $($htmlLine + "<tr><td><b>GZip compressing</b></td><td>" + (@("No","Yes")[$cache.Compress -eq "compress"]) + "</td></tr>")
    $htmlLine = $($htmlLine + "</table>")
    $html = $html -replace "{Behaviors_Table}",$htmlLine

    $htmlLine = "<table width=100%>"
    $htmlLine = $($htmlLine + "<tr bgcolor=Beige><td><b>Error Caching Min TTL</b></td><td><b>Error Code</b></td><td><b>Response Code</b></td><td><b>Response Page Path</b></td></tr>")
    foreach($customError in $cfDetail.DistributionConfig.CustomErrorResponses.Items)
    {
      $htmlLine = $($htmlLine + "<tr><td>" + $customError.ErrorCachingMinTTL.ToString() + "</td><td>" + $customError.ErrorCode.ToString() + "</td><td>" + $customError.ResponseCode.ToString() + "</td><td>" + $customError.ResponsePagePath + "</td></tr>")
    }
    $htmlLine = $($htmlLine + "</table>")
    $html = $html -replace "{ErrorPages_Table}",$htmlLine

    $html = $html -replace "{GeoRestriction_Enabled}",(@("Disabled","Enabled")[$cfDetail.DistributionConfig.Restrictions.GeoRestriction.Quantity -gt 0])
    $html = $html -replace "{GeoRestriction_Type}",$cfDetail.DistributionConfig.Restrictions.GeoRestriction.RestrictionType
    $html = $html -replace "{GeoRestriction_Countries}",($cfDetail.DistributionConfig.Restrictions.GeoRestriction.Items -join ", ")

    $invalidations = (Get-CFInvalidations -DistributionId $cf.ID.ToString() -ProfileName $profileName).Items
    $htmlLine = "<table width=100%>"
    $htmlLine = $($htmlLine + "<tr bgcolor=Beige><td><b>Invalidation ID</b></td><td><b>Status</b></td><td><b>Date</b></td></tr>")
    foreach($invalidation in $invalidations)
    {
      $htmlLine = $($htmlLine + "<tr><td>" + $invalidation.Id + "</td><td>" + $invalidation.Status + "</td><td>" + $invalidation.CreateTime.ToString() + "</td></tr>")
    }
    $htmlLine = $($htmlLine + "</table>")

    $html = $html -replace "{Invalidations_Table}",$htmlLine

    $filename = $($cf.ID.ToString() + '.html')
    $filepath = $('D:\aws-script\AWS-inventory-scripts\CF\' + $filename)

    $html | Set-Content $filepath;

    Write-S3Object -BucketName "e1aws-inventory.ef.com" -File $filepath -Key CF/$filename -ProfileName awsglobal  -Region ap-southeast-1
}
