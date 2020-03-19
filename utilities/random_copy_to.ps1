$srvIP = (Get-NetIPAddress -AddressFamily ipv4).ipaddress[0]
$tarFolder = 'Z:\test_' + $srvIP
robocopy "C:\share" $tarFolder -E -MT:255
