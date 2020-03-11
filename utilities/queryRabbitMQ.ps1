Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [string] $Feature
)

#$Overview = 'overview'
#$Connections = 'connection'
#$Channels = 'channels'
#$Exchanges = 'exchanges'
#$Queues = 'queues'
#$Admin = 'admin'
#$Nodes = 'nodes'

$User = 'guest'
$PWord = ConvertTo-SecureString -String "guest" -AsPlainText -Force
$Cred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord

$CurlOverview = Invoke-WebRequest -Uri http://localhost:15672/api/overview -Credential $Cred | ConvertFrom-Json
$CurlConnections = Invoke-WebRequest -Uri http://localhost:15672/api/connections -Credential $Cred | ConvertFrom-Json
$CurlChannels = Invoke-WebRequest -Uri http://localhost:15672/api/channels -Credential $Cred | ConvertFrom-Json
$CurlNodes = Invoke-WebRequest -Uri http://localhost:15672/api/nodes -Credential $Cred | ConvertFrom-Json
$CurlExtensions = Invoke-WebRequest -Uri http://localhost:15672/api/extensions -Credential $Cred | ConvertFrom-Json
$CurlQueues = Invoke-WebRequest -Uri http://localhost:15672/api/queues -Credential $Cred | ConvertFrom-Json

Switch($Feature)
{
    'overview' {$CurlOverview;break}
    'connections' {$CurlConnections;break}
    'channels' {$CurlChannels;break}
    'nodes' {$CurlNodes;break}
    'extensions' {$CurlExtensions;break}
    'queues' {$CurlQueues;break}
}

$Curl