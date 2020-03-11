function Trace-Route {
    [CmdletBinding()]
    param (
          [int] $Timeout = 1000
        , [Parameter(Mandatory = $true)]
          [string] $TargetHost
        , [int] $StartingTtl = 1
        , [int] $EndingTtl = 128
        , [switch] $ResolveDns
    )

    # Create Ping and PingOptions objects
    $Ping = New-Object -TypeName System.Net.NetworkInformation.Ping;
    $PingOptions = New-Object -TypeName System.Net.NetworkInformation.PingOptions;
    Write-Debug -Message ('Created Ping and PingOptions instances');

    # Assign initial Time-to-Live (TTL) to the PingOptions instance
    $PingOptions.Ttl = $StartingTtl;

    # Assign starting TTL to the 
    $Ttl = $StartingTtl;

    # Assign a random array of bytes as data to send in the datagram's buffer
    $DataBuffer = [byte[]][char[]]'aa';

    # Loop from StartingTtl to EndingTtl
    while ($Ttl -le $EndingTtl) {

        # Set the TTL to the current
        $PingOptions.Ttl = $Ttl;

        # Ping the target host using this Send() override: http://msdn.microsoft.com/en-us/library/ms144956.aspx
        $PingReply = $Ping.Send($TargetHost, $Timeout, $DataBuffer, $PingOptions);

        # Get results of trace
        $TraceHop = New-Object -TypeName PSObject -Property @{
                TTL           = $PingOptions.Ttl;
                Status        = $PingReply.Status;
                Address       = $PingReply.Address;
                RoundTripTime = $PingReply.RoundtripTime;
                HostName      = '';
            };

        # If DNS resolution is enabled, and $TraceHop.Address is not null, then resolve DNS
        # TraceHop.Address can be $null if 
        if ($ResolveDns -and $TraceHop.Address) {
            Write-Debug -Message ('Resolving host entry for address: {0}' -f $TraceHop.Address); 
            try {
                # Resolve DNS and assign value to HostName property of $TraceHop instance
                $TraceHop.HostName = [System.Net.Dns]::GetHostEntry($TraceHop.Address).HostName;
            }
            catch {
                Write-Debug -Message ('Failed to resolve host entry for address {0}' -f $TraceHop.Address);
                Write-Debug -Message ('Exception: {0}' -f $_.Exception.InnerException.Message);
            }
        }

        # Once we get our first, succesful reply, we have hit the target host and 
        # can break out of the while loop.
        if ($PingReply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            Write-Debug -Message ('Successfully pinged target host: {0}' -f $TargetHost);
            Write-Output -InputObject $TraceHop;
            break;
        }
        # If we get a TtlExpired status, then ping the device directly and get response time
        elseif ($PingReply.Status -eq [System.Net.NetworkInformation.IPStatus]::TtlExpired) {
            $PingReply = $Ping.Send($TraceHop.Address, $Timeout, $DataBuffer, $PingOptions);
            $TraceHop.RoundTripTime = $PingReply.RoundtripTime;

            Write-Output -InputObject $TraceHop;
        }
        else {
            # $PingReply | select *;
        }

        # Increment the Time-to-Live (TTL) by one (1) 
        $Ttl++;
        Write-Debug -Message ('Incremented TTL to {0}' -f $Ttl);
    }
}

# Test #1: Call the function with DNS resolution enabled
#Trace-Route -TargetHost 8.8.8.8 -ResolveDns;

# Test #2: Try calling the function and assigning the results to a variable, for later exploration
#$TraceResults = Trace-Route -TargetHost 4.2.2.2 -ResolveDns;

# Test #3: Try calling the function without DNS resolution enabled
#Trace-Route -TargetHost www.google.com;

# Test #4: Call the function with a custom Timeout value (500ms)
#Trace-Route -TargetHost www.google.com -Timeout 500 -ResolveDns;

# Test #5: Try enabling debugging to get more information
#Trace-Route -TargetHost www.google.com -Debug;

