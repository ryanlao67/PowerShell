$Computername = $env:COMPUTERNAME
$Username = 'LocalAdmin'
$ADSIComp = [adsi]"WinNT://$Computername/$UserName" 
$ADSIComp.SetPassword("@WSX3edc$RFV")