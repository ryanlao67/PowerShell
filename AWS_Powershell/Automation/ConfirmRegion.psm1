Function ConfirmRegion ($useRegion)
{
    if ($useRegion -eq 'awssg')
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
    Return $awsRegion
}