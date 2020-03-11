
Function GetHtmlLine($reserved, $instanceCount, $region)
{
	$html = “<tr>”;
	if($reserved.State -eq “active”)
	{
		$html = $($html + ”<td><img src=running.png height=16 width=16/></td>”);
	}
	else
	{
		$html = $($html + ”<td><img src=stopped.png height=16 width=16/></td>”);
	}

	$html = $($html + ”<td>” + $reserved.ReservedInstancesId + ”</td>”);

	$html = $($html + ”<td>” + $reserved.ProductDescription + ”</td>”);

	$html = $($html + ”<td>” + $instanceCount + ”</td>”);

	$html = $($html + ”<td>” + $reserved.InstanceType + ”</td>”);

	$html = $($html + ”<td>” + $region.Name + “ - ” + $reserved.AvailabilityZone + ”</td>”);

	$html = $($html + ”<td>” + $reserved.CurrencyCode + “ “ + $reserved.FixedPrice.ToString() + ”</td>”);

	$html = $($html + ”<td>” + $reserved.CurrencyCode + “ “ + $reserved.UsagePrice.ToString() + ”</td>”);

	$html = $($html + ”<td>” + $reserved.End.ToString() + ”</td>”);

	$ts = New-TimeSpan -Seconds $reserved.Duration
	
	$html = $($html + ”<td>” + $ts.TotalDays.ToString() + ” days</td>”);

	$html = $($html + ”</tr>”);

	return $html;
}

$reservationHashTableBI = New-Object System.Collections.Hashtable

$reservationHashTableBSD = New-Object System.Collections.Hashtable

$reservationHashTableGDM = New-Object System.Collections.Hashtable

$reservationHashTableITIS = New-Object System.Collections.Hashtable
$reservationHashTableITIS.Add(“2503537f-b00c-48a5-b7c1-683c0a64761d”,3)
$reservationHashTableITIS.Add(“1b115be5-f54f-4e49-b6ee-e9c0af583cc7”,2)
$reservationHashTableITIS.Add(“3d163b90-6037-4255-8bcf-d477586f8414”,1)

$reservationHashTablePD = New-Object System.Collections.Hashtable
$reservationHashTablePD.Add(“24e982ec-593b-4687-8709-565fc09a2fbe”,1)
$reservationHashTablePD.Add(“a91787f7-75c2-4446-8b47-8acae1963103”,1)
$reservationHashTablePD.Add(“5db9495d-6dd1-45ce-891b-fe2833c532d2”,4)
$reservationHashTablePD.Add(“ac84708e-534e-414a-a21f-5966253887d7”,14)
$reservationHashTablePD.Add("83884a07-8307-48bc-8325-02bfadcee9a1",6)
$reservationHashTablePD.Add("ff7c1e6b-c2a0-4d08-baeb-08c42ab4fbfd",6)


$reservationHashTableSF = New-Object System.Collections.Hashtable

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
	
   $reservedList = (Get-EC2ReservedInstance -ProfileName $profileName)

   foreach($reserved in $reservedList)
   {
	$instanceCount = $reserved.InstanceCount;

	if($reservationHashTableBI.ContainsKey($reserved.ReservedInstancesId) -and $instanceCount -gt 0)
	{
		if($reservationHashTableBI.Item($reserved.ReservedInstancesId) -ge $instanceCount)
		{
			$htmlLine = GetHtmlLine $reserved $instanceCount $region;
			$instanceCount = 0;
		}	
		else
		{
			$htmlLine = GetHtmlLine $reserved $reservationHashTableBI.Item($reserved.ReservedInstancesId) $region;
			$instanceCount -= $reservationHashTableBI.Item($reserved.ReservedInstancesId);
		}
		$teamBI = $($teamBI + $htmlLine);
		$reservationHashTableBI.Remove($reserved.ReservedInstancesId);
	}
	if($reservationHashTableBSD.ContainsKey($reserved.ReservedInstancesId) -and $instanceCount -gt 0)
	{
		if($reservationHashTableBSD.Item($reserved.ReservedInstancesId) -ge $instanceCount)
		{
			$htmlLine = GetHtmlLine $reserved $instanceCount $region;
			$instanceCount = 0;
		}	
		else
		{
			$htmlLine = GetHtmlLine $reserved $reservationHashTableBSD.Item($reserved.ReservedInstancesId) $region;
			$instanceCount -= $reservationHashTableBSD.Item($reserved.ReservedInstancesId);
		}
		$teamBSD = $($teamBSD + $htmlLine);
		$reservationHashTableBSD.Remove($reserved.ReservedInstancesId);
	}
	if($reservationHashTableGDM.ContainsKey($reserved.ReservedInstancesId) -and $instanceCount -gt 0)
	{
		if($reservationHashTableGDM.Item($reserved.ReservedInstancesId) -ge $instanceCount)
		{
			$htmlLine = GetHtmlLine $reserved $instanceCount $region;
			$instanceCount = 0;
		}	
		else
		{
			$htmlLine = GetHtmlLine $reserved $reservationHashTableGDM.Item($reserved.ReservedInstancesId) $region;
			$instanceCount -= $reservationHashTableGDM.Item($reserved.ReservedInstancesId);
		}
		$teamGDM = $($teamGDM + $htmlLine);
		$reservationHashTableGDM.Remove($reserved.ReservedInstancesId);	
	}
	if($reservationHashTableITIS.ContainsKey($reserved.ReservedInstancesId) -and $instanceCount -gt 0)
	{
		if($reservationHashTableITIS.Item($reserved.ReservedInstancesId) -ge $instanceCount)
		{
			$htmlLine = GetHtmlLine $reserved $instanceCount $region;
			$instanceCount = 0;
		}	
		else
		{
			$htmlLine = GetHtmlLine($reserved, $reservationHashTableITIS.Item($reserved.ReservedInstancesId));
			$instanceCount -= $reservationHashTableITIS.Item($reserved.ReservedInstancesId);
		}
		$teamITIS = $($teamITIS + $htmlLine);
		$reservationHashTableITIS.Remove($reserved.ReservedInstancesId);				
	}
	if($reservationHashTablePD.ContainsKey($reserved.ReservedInstancesId) -and $instanceCount -gt 0)
	{
		if($reservationHashTablePD.Item($reserved.ReservedInstancesId) -ge $instanceCount)
		{
			$htmlLine = GetHtmlLine $reserved $instanceCount $region;
			$instanceCount = 0;
		}	
		else
		{
			$htmlLine = GetHtmlLine $reserved $reservationHashTablePD.Item($reserved.ReservedInstancesId) $region;
			$instanceCount -= $reservationHashTablePD.Item($reserved.ReservedInstancesId);
		}
		$teamPD = $($teamPD + $htmlLine);
		$reservationHashTablePD.Remove($reserved.ReservedInstancesId);							
	}
	if($reservationHashTableSF.ContainsKey($reserved.ReservedInstancesId) -and $instanceCount -gt 0)
	{
		if($reservationHashTableSF.Item($reserved.ReservedInstancesId) -ge $instanceCount)
		{
			GetHtmlLine $reserved $instanceCount;
			$instanceCount = 0;
		}	
		else
		{
			$htmlLine = GetHtmlLine $reserved $reservationHashTableSF.Item($reserved.ReservedInstancesId) $region;
			$instanceCount -= $reservationHashTableSF.Item($reserved.ReservedInstancesId);
		}
		$teamSF = $($teamSF + $htmlLine);
		$reservationHashTableSF.Remove($reserved.ReservedInstancesId);										
	}
	if($instanceCount -gt 0)
	{
		$htmlLine = GetHtmlLine $reserved $instanceCount $region;
		$teamNULL = $($teamNULL + $htmlLine);
	}
   }
}

$html = $("<html><body>Last Updated (UTC) - " + (Get-Date).ToUniversalTime() + "<table border=1 width=100%>");

if($teamNULL.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM NULL</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamNULL + "<tr></tr>");
}

if($teamBI.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM BI</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamBI + "<tr></tr>");
}

if($teamBSD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM BSD</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamBSD + "<tr></tr>");
}

if($teamGDM.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM GDM</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamGDM + "<tr></tr>");
}

if($teamITIS.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM ITIS</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamITIS + "<tr></tr>");
}

if($teamPD.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM PD</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamPD + "<tr></tr>");
}

if($teamSF.Length -gt 0)
{
  $html =  $($html + "<tr bgcolor=silver><td colspan=10>" + "<b>TEAM SalesForce</b>" + "</td></tr><tr><td></td><td><b>RI Id</b></td><td><b>Platform</b></td><td><b>Instance Count</b></td><td><b>Instance Type</b></td><td><b>Zone</b></td><td><b>Upfront price</b></td><td><b>Usage price</b></td><td><b>Expires on</b></td><td><b>Term</b></td></tr>");
  $html =  $($html + $teamSF + "<tr></tr>");
}

$html =  $($html + "</table></body></html>");

$html | Set-Content 'D:\aws-script\AWS-inventory-scripts\reserved-ec2.html';

Write-S3Object -BucketName "e1aws-inventory.ef.com" -File "D:\aws-script\AWS-inventory-scripts\reserved-ec2.html" -ProfileName awsglobal -Region ap-southeast-1
