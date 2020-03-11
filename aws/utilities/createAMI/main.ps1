Param (
    [Parameter(Mandatory = $False, Position = 0)]
    [string] $useRegion,
    
    [Parameter(Mandatory = $False, Position = 1)]
    [string] $ec2PrivateIP
)

Import-Module .\confirmRegion.psm1
Import-Module .\confirmServerInfo.psm1
Import-Module .\createAMI.psm1

$awsRegion = confirmRegion $useRegion

$ec2InstanceID = confirmServerInfo $useRegion $awsRegion $ec2PrivateIP

$newAMIID = createAMI $ec2InstanceID $useRegion $awsRegion
