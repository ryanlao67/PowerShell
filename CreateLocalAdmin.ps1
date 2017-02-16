$Computername = $env:COMPUTERNAME
$ADSIComp = [adsi]"WinNT://$Computername" 
$Username = 'LocalAdmin'
$NewUser = $ADSIComp.Create('User',$Username)
$Password = '!QAZ2wsx#EDC' | ConvertTo-SecureString -asPlainText -Force
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