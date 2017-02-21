# Setup AWS Credential with AWS Powershell
Set-AWSCredentials -AccessKey {AccessKey} -SecretKey {SecretKey} -StoreAs {ProfileName}

# Setup default profile with region
Initialize-AWSDefaults -ProfileName {ProfileName} -Region {Region}

# Verify current profile
Get-AWSCredentials -ListStoredCredentials