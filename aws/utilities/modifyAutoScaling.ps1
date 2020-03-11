#----------------------------------------------------------------------------------------------------
#ApplyAutoScaling.ps1
#----------------------------------------------------------------------------------------------------
#Created by Ryan Lao
#
#Description: This script is used for creating new launch configuration and updating in auto scaling group automatically.
#
#Usage: .\ApplyAutoScaling.ps1 awssg 10.160.114.146 hotfix
#----------------------------------------------------------------------------------------------------

# Parameters definition
Param (
    [Parameter(Mandatory = $False, Position = 0)]
    [string] $useRegion,
    
    [Parameter(Mandatory = $False, Position = 1)]
    [string] $ec2PrivateIP,
    
    [Parameter(Mandatory = $False, Position = 2)]
    [string] $changeType
)

# Define user data
$userDataString = @"
<powershell>  
    $Computername = $env:COMPUTERNAME
    $ADSIComp = [adsi]"WinNT://$Computername" 
    $Username = 'pdadmin'
    $NewUser = $ADSIComp.Create('User',$Username)
    $Password = 'E1@awspd17q1!' | ConvertTo-SecureString -asPlainText -Force
    $BSTR = [system.runtime.interopservices.marshal]::SecureStringToBSTR($Password)
    $_password = [system.runtime.interopservices.marshal]::PtrToStringAuto($BSTR)
    $NewUser.SetPassword(($_password))
    $NewUser.SetInfo()
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) 
    Remove-Variable Password,BSTR,_password
    $userGroup = 'Administrators'
    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$userGroup,group"
    $group.Add("WinNT://$env:COMPUTERNAME/$UserName,user")
    $User = [adsi]"WinNT://$env:computername/$Username"
    $User.UserFlags.value = $user.UserFlags.value -bor 0x10000
    $User.CommitChanges()
</powershell>
"@
$encodeUserData = [System.Text.Encoding]::UTF8.GetBytes($userDataString)
$userData = [System.Convert]::ToBase64String($encodeUserData)

# Confirm AWS region
If ($useRegion -eq 'awssg')
{
    $credProfile = $useRegion
    $awsRegion = 'ap-southeast-1'
}
Elseif ($useRegion -eq 'awscn')
{
    $credProfile = $useRegion
    $awsRegion = 'cn-north-1'
}
Else
{
    Write-Host 'Profile cannot be found, please run the script and enter a valid value again.' -Foregroundcolor Yellow
    Break;
}

# Confirm instance
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
    $ec2InstanceID = $useEC2Server.InstanceId
}
Else
{
    Write-Host "No such instance exists in current region, please check on the management console." -Foregroundcolor Yellow
    Break;
}

# Create EC2 AMI
$rawAMIDate = (Get-Date).ToString("yyyyMMddHH")
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

#$createdAMIID = New-EC2Image -Description $imageDescription -InstanceId $ec2InstanceID -Name $finalAMIName -NoReboot $True -ProfileName $useRegion -Region $awsRegion
    
#New-EC2Tag -Resources $createdAMIID -Tags @(@{Key = "Name"; Value = $finalAMIName}, @{Key = "Description"; Value = $imageDescription}) -ProfileName $useRegion -Region $awsRegion

#Start-Sleep -Seconds 120

# Collect instance information
$ec2InstanceType = $useEC2Server.InstanceType.value
$ec2SecurityGroups = @($useEC2Server.SecurityGroups)
for($i=0;$i -lt $ec2SecurityGroups.count; $i++)
    {
        $ec2SecurityGroupsID +=  $ec2SecurityGroups[$i].GroupId + ', '
    }
$ec2SecurityGroupsID = $ec2SecurityGroupsID.Remove($ec2SecurityGroupsID.Length -2)
$ec2AMIID = $createdAMIID
$ec2ASGName = (Get-ASAutoScalingInstance -ProfileName $useRegion -Region $awsRegion -InstanceId $ec2InstanceID).AutoScalingGroupName

Write-Host "--------------------------------------------------"
Write-Host "EC2 information for Launch Configuration:"
Write-Host "--------------------------------------------------"
Write-Host $ec2InstanceType
Write-Host $ec2SecurityGroupsID
Write-Host $ec2AMIID
Write-Host $ec2ASGName
Write-Host "--------------------------------------------------"

# Create new launch configuration
$lcName = $finalAMIName + '-LaunchConfiguration'
#New-ASLaunchConfiguration -LaunchConfigurationName $lcName -ImageId $ec2AMIID -InstanceType $ec2InstanceType -SecurityGroup $ec2SecurityGroupsID -KeyName $useEC2Servername -UserData $userData -AssociatePublicIpAddress $True -ProfileName $useRegion -Region $awsRegion

# Update auto scaling with new launch configuration
#Update-ASAutoScalingGroup -AutoScalingGroupName $ec2ASGName -LaunchConfigurationName $lcName -ProfileName $useRegion -Region $awsRegion