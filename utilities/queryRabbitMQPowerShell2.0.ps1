Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [string] $Tab,
    
    [Parameter(Mandatory = $True, Position = 1)]
    [string] $Val1,
    
    [Parameter(Mandatory = $False, Position = 2)]
    [string] $Val2
)

function ConvertTo-Json20([object] $item){
    add-type -assembly system.web.extensions
    $ps_js=new-object system.web.script.serialization.javascriptSerializer
    return $ps_js.Serialize($item)
}

$User = 'guest'
$PWord = ConvertTo-SecureString -String "guest" -AsPlainText -Force
$Cred = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord
if ($Tab -eq 'overview')
{
    $URL = "http://localhost:15672/api/overview"
}
Elseif ($Tab -eq 'nodes')
{
    $URL = "http://localhost:15672/api/nodes"
}
$WebRequest = [System.Net.WebRequest]::Create($URL)
$WebRequest.Method="Get"
$WebRequest.Credentials = $Cred
$WebResponse = $WebRequest.GetResponse()
$RequestStream = $WebResponse.GetResponseStream()
$readStream = New-Object System.IO.StreamReader $RequestStream
$rawdata=$readStream.ReadToEnd()
if($WebResponse.ContentType -match "application/xml") {
    $results = [xml]$rawdata
} elseif($WebResponse.ContentType -match "application/json") {
    $results = ConvertTo-Json20 $rawdata
} else {
    try {
        $results = [xml]$rawdata
    } catch {
        $results =ConvertTo-Json20 $rawdata
    }
}

if ($Val2 -eq "")
{
    Write-Output $results.$Val1
}
Else
{
    Write-Output $results.$Val1.$Val2
}