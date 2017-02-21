Function CreateAMI
{
    Param (
        [Parameter(Mandatory = $True, Position = 0)]
        [string] $ec2InstanceID,
    
        [Parameter(Mandatory = $True, Position = 1)]
        [string] $useRegion,
    
        [Parameter(Mandatory = $True, Position = 2)]
        [string] $awsRegion,
    
        [Parameter(Mandatory = $False, Position = 3)]
        [string] $changeType
    )
    
    $rawAMIDate = (Get-Date).ToString("yyyyMMdd")
    $rawAMIName = ((Get-EC2Instance -ProfileName $useRegion -Region $awsRegion -InstanceID $ec2InstanceID).Instances.Tags | Where {$_.Key -eq "Name"}).Value
    $finalAMIName = $rawAMIName + '-' + $rawAMIDate
    
    If($changeType)
    {
        $imageDescription = "Create AMI for $rawAMIName on $rawAMIDate after $changeType"
    }
    Else
    {
        $imageDescription = "Create AMI for $rawAMIName on $rawAMIDate"
    }
    
    Write-Host "--------------------------------------------------"
    Write-Host "New AMI information:"
    Write-Host "--------------------------------------------------"
    Write-Host "AMI name: $finalAMIName"
    Write-Host "Description: $imageDescription"
    
    $createdAMIID = New-EC2Image -Description $imageDescription -InstanceId $ec2InstanceID -Name $finalAMIName -NoReboot $True -ProfileName $useRegion -Region $awsRegion
    
    New-EC2Tag -Resources $createdAMIID -Tags @(@{Key = "Name"; Value = $finalAMIName}, @{Key = "Description"; Value = $imageDescription}) -ProfileName $useRegion -Region $awsRegion
    
    Return $createdAMIID
}