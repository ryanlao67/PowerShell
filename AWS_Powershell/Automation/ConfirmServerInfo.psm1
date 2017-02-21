Function ConfirmServerInfo ($ec2PrivateIP)
{
    $ec2Servers = @((Get-EC2Instance -ProfileName awscn -Region cn-north-1).Instances | sort-object @{Expression={($_.Tags | Where-Object{$_.Key -eq "Name"}).Value}; Ascending=$true})
    $useEC2Server = $ec2Servers | where {$_.PrivateIpAddress -eq $ec2PrivateIP}
    $useEC2Servername = ($useEC2Server.Tags | Where {$_.Key -eq "Name"}).Value
    Write-Host "Below server involved:"
    Write-Host $useEC2Servername -Foregroundcolor Green
    Write-Host $ec2PrivateIP -Foregroundcolor Green
}