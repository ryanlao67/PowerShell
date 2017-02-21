Param (
    [Parameter(Mandatory = $False, Position = 0)]
    [string] $useRegion,
    
    [Parameter(Mandatory = $False, Position = 1)]
    [string] $ec2PrivateIP
)

Import-Module .\ConfirmRegion.psm1
Import-Module .\ConfirmServerInfo.psm1
Import-Module .\CreateAMI.psm1

$awsRegion = ConfirmRegion $useRegion

$ec2InstanceID = ConfirmServerInfo $useRegion $awsRegion $ec2PrivateIP

$newAMIID = CreateAMI $ec2InstanceID $useRegion $awsRegion