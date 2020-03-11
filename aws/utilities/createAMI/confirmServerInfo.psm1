Function ConfirmServerInfo
{
    Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [string] $useRegion,
    
    [Parameter(Mandatory = $True, Position = 1)]
    [string] $awsRegion,
    
    [Parameter(Mandatory = $False, Position = 2)]
    [string] $ec2PrivateIP
    )

    $ec2Servers = @((Get-EC2Instance -ProfileName $useRegion -Region $awsRegion).Instances | sort-object @{Expression={($_.Tags | Where-Object{$_.Key -eq "Name"}).Value}; Ascending=$True})
    $useEC2Server = $ec2Servers | where {$_.PrivateIpAddress -eq $ec2PrivateIP}
    If ($useEC2Server)
    {
        $useEC2Servername = ($useEC2Server.Tags | Where {$_.Key -eq "Name"}).Value
        If ($useEC2Servername)
        {
            Write-Host "--------------------------------------------------"
            Write-Host "Below server involved:"
            Write-Host "--------------------------------------------------"
            Write-Host $useEC2Servername
            Write-Host $ec2PrivateIP
        }
        Else
        {
            Write-Host "This EC2 instance is running without tag, please add later." -Foregroundcolor Yellow
            Write-Host "--------------------------------------------------"
            Write-Host "Below server involved:"
            Write-Host "--------------------------------------------------"
            Write-Host $ec2PrivateIP
        }
        Return $useEC2Server.InstanceId
    }
    Else
    {
        Write-Host "No such instance exists in current region, please check on the management console." -Foregroundcolor Yellow
        Break;
    }

}