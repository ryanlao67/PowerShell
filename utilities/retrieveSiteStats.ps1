#requires -Version 2

    Param(     
        [Parameter(HelpMessage = 'Enter the numer of samples you want to ather.')] 
        [Alias('MaxSample')]  
        [ValidateRange(0,99)]     
        [int]$Samples = 5,
        [Parameter(HelpMessage = 'Enter the interval in seconds between the samples.')] 
        [ValidateRange(0,999)]     
        [int]$Interval = 2,
        [Parameter(HelpMessage = 'Enter the Server running IIS.')] 
        [Alias('ComputerName')]    
        [string]$Server = $env:COMPUTERNAME
    )

    $Counters = @('\Web Service(*)\Bytes Received/sec', '\Web Service(*)\Bytes Sent/sec', '\Web Service(*)\Connection Attempts/sec', '\Web Service(*)\Current Connections')
    
    $Waittime = $Samples * $Interval

    "Collecting samples for $Waittime seconds, processing could take longer based on the number of sites ...."

    $result = Get-Counter -ComputerName $Server -Counter $Counters -MaxSamples $Samples -SampleInterval $Interval

    $hashreceived = @{}
    $hashsent = @{}
    $hashConAttempts = @{}
    $hashcurrent = @{}

    write-host 'Processing samples ...' 

    $result |
    ForEach-Object -Process {
        $_.countersamples 
    } |
    ForEach-Object -Process {
        $Path = $_.path
        $Value = $_.CookedValue
		
        # processing Proc samples
        if ($Path -match '\\\\(.*)\\Web Service\((.*)\)(.*)' -eq $True) 
        {
            $counter = $Matches[3]
            [string]$site = $Matches[2]

            switch ($counter){
                '\Bytes Received/sec' 
                {
                    $hashreceived[$site] += $Value
                    break
                }
                '\Bytes Sent/sec' 
                {
                    $hashsent[$site] += $Value
                    break
                }
                '\Connection Attempts/sec' 
                {
                    $hashConAttempts[$site] += $Value
                    break
                }
                '\Current Connections' 
                {
                    $hashcurrent[$site] += $Value
                    break
                }
            }
        } # end foreach countersamples
    } # end foreach result


    $global:SitePerfData = @()

    $hashreceived.keys | ForEach-Object -Process {
        $site = $_

        $received = [math]::round($hashreceived[$site] / $Samples / 1kb,0)
        $Sent = [math]::round($hashsent[$site] / $Samples / 1kb,0)
        $ConAttempts = [math]::round($hashConAttempts[$site] / $Samples,0)
        $Current = [math]::Round($hashcurrent[$site] / $Samples)


        $ObjectProperties = @{
             WebSite        = $site
            'Received (kb)'    = $received
            'Sent (kb)'        = $Sent
            'ConnectionAttempts (/sec)' = $ConAttempts
            'CurrentConnections'    = $Current
        }
 
        $Obj = New-Object -TypeName PSObject -Property $ObjectProperties
        $SitePerfData += $Obj
    }

 $global:SitePerfData = $SitePerfData | Sort-Object 'CurrentConnections' 
 $SitePerfDataSelect = $SitePerfData | Select-Object WebSite,CurrentConnections,'ConnectionAttempts (/sec)','Sent (kb)','Received (kb)'
# Output array to gridview
Try { 
  $SitePerfDataSelect | Sort-Object 'CurrentConnections' -Descending |  Out-GridView -Title "$Server : WebSite Performance Statistics"
 } catch {
  $global:SitePerfDataTable = $SitePerfData | Sort-Object 'CurrentConnections' -Descending | Format-table WebSite,'CurrentConnections','ConnectionAttempts (/sec)','Sent (kb)','Received (kb)' 
  $SitePerfDataTable
   write-error $_.exception.message
 ''
  write-warning 'Oops, something went wrong displaying the data in Out-GridView! Use global re-usable $SitePerfDataTable variable for table output or use $SitePerfData to filter and sort yourself. '

 }
 
 write-host 'Use ''$SitePerfData | Export-Csv c:\your.csv -NoTypeInformation'' for a CSV export.'