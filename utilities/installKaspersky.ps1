<# This script is to update Kaspersky Network Agent installation, uninstall KESS 10.0 and Install simple KES 8.0. 
Script last updated on 26-01-2016 #>

Set-ExecutionPolicy Remotesigned -Force

Function Test-IsAdmin 
{ 
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
} 

    Function ReportDB ($Status)
    {
        $date = date
        $dbconn.Open()
        $dbwrite = $dbconn.CreateCommand()
        $dbwrite.CommandText="INSERT INTO dbo.KAV_Install_Report(ComputerName,StepDate,Domain,Result,AVServer) VALUES ('$computername','$date','$domainname','$Status','$sourceserver')"
        $dbwrite.ExecuteNonQuery()
        $dbconn.Close()
    }

If (!(Test-IsAdmin))
{
    Write-Warning "Please start the script with administrator privilige"
}
else
{
    Set-ExecutionPolicy Remotesigned -Force
    Add-Type -AssemblyName Microsoft.VisualBasic

    $KServiceStatus = Get-Service Kavfs -ErrorAction SilentlyContinue
    $KES10Service = Get-service avp -ErrorAction SilentlyContinue
    $KNAgent = Get-Service klnagent -ErrorAction SilentlyContinue
    $STask = Get-Service Schedule -ErrorAction SilentlyContinue

    #Identifying the domain and assign required server to be copied
    $domainname = (gwmi WIN32_ComputerSystem).Domain
    $computername = "$env:computername"    
    $ComputerNetworks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $computername -EA Stop | ? {$_.IPEnabled}
    $Computerip  = $ComputerNetworks.IpAddress[0] 

    $dbconn = New-Object System.Data.SqlClient.SqlConnection("Data Source=10.43.42.95\KAV_CS; Initial Catalog=KAV_Report; User ID=Reportw; Password=ef")


    switch ($domainname)
    {
        EF.COM {$sourceserver = "USB-SSAVKUS1";$copyserver="USB-SSAVKUS1"}
        EFDMZ.COM {$sourceserver = "USB-SSAVKDMZ1";$copyserver="USB-DMZSCCM1"}
        EFSECURE.COM {$sourceserver = "USB-SSAVKDMZ1";$copyserver="USB-EFSSCCM1"}
        EFTSD.COM {$sourceserver = "USB-SSAVKDMZ1";$copyserver="USB-TSDSCCM1"}
        EFDMZ2.COM {$sourceserver = "CNSDC1-SSAVKCN1";$copyserver="CNSDC1-DMZSCCM1"}
        EFSECURE2.COM {$sourceserver = "CNSDC1-SSAVKCN1";$copyserver="CNSDC1-EFSSCCM1"}
	    Language.com {$sourceserver = "10.160.64.181";$copyserver="10.160.64.181"}
	    LANGDMZ.com {$sourceserver = "10.160.59.8";$copyserver="10.160.59.8"}
        default {$sourceserver = "USB-SSAVKUS1";$copyserver="USB-SSAVKUS1"}
    }
    if ($domainname -eq "EF.COM" -and $computername -like "CN*")
    {
        $sourceserver = "CNSDC1-SSAVKCN1"
        $copyserver="CNSDC1-SSAVKCN1"
    }
    if ($domainname -eq "EF.COM" -and $computername -like "CT*")
    {
        $sourceserver = "CNSDC1-SSAVKCN1"
        $copyserver="CNSDC1-SSAVKCN1"
    }
	If ($domainname -eq "EFTSD.com" -and ($computerip -like "10.43.4*" -or $computerip -like "10.160.*" -or $computerip -like "10.162.2*"))
	{
		$sourceserver = "USB-SSAVKUS1.ef.com"
        $copyserver="USB-SSAVKUS1.ef.com"
		$Account=Read-Host -Prompt "Boston Admin Account"
		$AdministratorPassword = Read-Host -Prompt "Enter Boston Admin Password" -AsSecureString
		$AdministratorPasswordString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdministratorPassword))
		net use \\$copyserver\KAV8 /user:$Account "$AdministratorPasswordString"
	}
	If ($domainname -eq "TGDMZ.COM")
	{
		$sourceserver = "10.43.42.96"
   		$copyserver="10.43.42.96"
		$Account=Read-Host -Prompt "Boston Admin Account"
		$AdministratorPassword = Read-Host -Prompt "Enter Boston Admin Password" -AsSecureString
		$AdministratorPasswordString=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdministratorPassword))
		net use \\$copyserver\KAV8 /user:$Account "$AdministratorPasswordString"
	}
    
    if($KNAgent.Status -eq "Running" -or $KNAgent.Status -eq "Stopped")
    {
        Start-Process klmover.exe -workingdirectory "C:\Program Files (x86)\Kaspersky Lab\NetworkAgent" -ArgumentList "-address $sourceserver" -wait -Passthru

        If ($KServiceStatus -eq $null)
        {            
            #Initiate copy to the local server
            Robocopy "\\$copyserver\KAV8" "C:\Kaspersky\KAV8" /e /r:2 /w:0 /mir /np
            if($LASTEXITCODE -eq "0" -or $LASTEXITCODE -eq "1")
            {
                ReportDB -Status "Package Copy Completed"
                #Starting the Patch-D Installation

                Start-Process patch_10_2_434_nagent_d.exe -Workingdirectory "C:\Kaspersky\KAV8\patch_10_2_434_d" -ArgumentList "-s" -Wait -Passthru
                $NAInstall = Get-content C:\Kaspersky\KAV8\patch_10_2_434_d\setup.log
				If ($domainname -eq "EFTSD.com" -and ($computerip -like "10.43.4*" -or $computerip -like "10.160.*" -or $computerip -like "10.162.2*"))
				{
					net use \\$copyserver\KAV8 /del				
				}	
				
                If ($NAInstall -contains "Resultcode=0")
                {
                    ReportDB -Status "PatchD Installation Completed"
                    If ($KES10Service.Status -eq "Running" -or $KES10Service.Status -eq "Stopped")
                    {
                        $KEUninstall = (Start-Process "msiexec.exe" -Workingdirectory "C:\Kaspersky\KAV8\KES_uninstall" -ArgumentList "/x exec\kes10win.msi EULA=1 KSN=1 ALLOWREBOOT=0 KLPASSWD=K45p3r5ky! KLPASSWDAREA=UNINST /l*v C:\Kaspersky\kaspersky_endpoint.log /qn" -wait -passthru).Exitcode
                        If ($KEUninstall -eq 3010 -and $STask.Status -eq "Running")
                        {
                            ReportDB -Status "KES Uninstallation Completed and Pending reboot"
                            Schtasks /create /RU "NT AUTHORITY\SYSTEM" /tn "Kaspersky KAV8.0 Install" /tr "Powershell.exe -File c:\Kaspersky\KAV8\KAVFSEE_8.0.2.213\KAV8Install.ps1" /SC onstart /Z /V1
                            [Microsoft.VisualBasic.Interaction]::MsgBox('Kaspersky uninstallation is completed, please restart the server immediately to start Kaspersky installation', 'OkOnly,SystemModal,Information', 'Status')
                        }
                        elseif($KEUninstall -eq 3010 -and $STask.Status -eq "Stopped")
                        {
                            ReportDB -Status "Schedule Task not running and Manual install"
                            Write-Warning "Schedule task service on this computer not running, Please restart the computer and start the installation manually"
                            [Microsoft.VisualBasic.Interaction]::MsgBox('Uninstallation completed, Please restart and start the installation manually.  KAV8Install script can be found under C:\Kaspersky\KAV8\KAVFSEE_8.0.2.213', 'OkOnly,SystemModal,Exclamation', 'Status')
                        }
                        else
                        {
                            ReportDB -Status "KES Uninstallation failed and Script exited"
                            Write-Warning "KES Uninstallation failed and Script exited"
                            [Microsoft.VisualBasic.Interaction]::MsgBox('Uninstallation failure, please contact support', 'OkOnly,SystemModal,Exclamation', 'Status')
                        }
                    }
                    else
                    {
                        ReportDB -Status "KES Uninstallation Completed and Pending reboot"                        
                        Schtasks /create /RU "NT AUTHORITY\SYSTEM" /tn "Kaspersky KAV8.0 Install" /tr "Powershell.exe -File c:\Kaspersky\KAV8\KAVFSEE_8.0.2.213\KAV8Install.ps1" /SC onstart /Z /V1
                        Write-Host "KES Uninstallation completed, Please restart the server to start the new version installation"
                        [Microsoft.VisualBasic.Interaction]::MsgBox('Please restart the server to complete the Kaspersky installation', 'OkOnly,SystemModal,Information', 'Status')

                    }
                }
                else
                {
                    ReportDB -Status "PatchD Installation Failed and Script Exited"
                    Write-Warning "PatchD Installation Failed and Script Exited"
                    [Microsoft.VisualBasic.Interaction]::MsgBox('Network Agent update not completed, please contact support', 'OkOnly,SystemModal,Exclamation', 'Status')
                }
            }   
            else
            {
                ReportDB -Status "Package copy failed and Script Exited"
                Write-Warning "Package copy failed and Script Exited"
                [Microsoft.VisualBasic.Interaction]::MsgBox('Package copy failed, please contact support', 'OkOnly,SystemModal,Exclamation', 'Status')
            }
        }        
        else
        {
            ReportDB -Status "KAVWSEE Already installed"
            Write-Host "Kaspersky 8.0 Already installed and this doesn't require anymore"
        }
    }
    else
    {
        Report-DB -Status "No Kaspersky Installed, initiating installation"
        Write-Warning "No AV installed, proceeding with the installation"

        #Initiate copy to the local server
        Robocopy "\\$copyserver\KAV8" "C:\Kaspersky\KAV8" /e /r:2 /w:0 /mir /np

        if($LASTEXITCODE -eq "0" -or $LASTEXITCODE -eq "1")
        {
            ReportDB -Status "Package Copy Completed"
            
            $NA = (Start-Process "msiexec.exe" -Workingdirectory "C:\Kaspersky\KAV8\NetAgent" -ArgumentList "/i exec\KasperskyNetworkAgent.msi /l*v C:\Windows\Kaspersky_NetAgent.log /qn" -wait -passthru).Exitcode
            if ($NA -eq "0")
            {
                ReportDB -Status "Network Agent Installation completed"            
                #Starting the Patch-D Installation
                Start-Process patch_10_2_434_nagent_d.exe -Workingdirectory "C:\Kaspersky\KAV8\patch_10_2_434_d" -ArgumentList "-s" -Wait -Passthru
                $NAInstall = Get-content C:\Kaspersky\KAV8\patch_10_2_434_d\setup.log

                If ($NAInstall -contains "Resultcode=0")
                {
                    ReportDB -Status "PatchD Installation Completed"

                    Start-Process -FilePath "msiexec.exe" -Workingdirectory "C:\Kaspersky\KAV8\KAVFSEE_8.0.2.213" -ArgumentList "/i exec\kavws.msi EULA=1 KSN=1 ALLOWREBOOT=0 RUNRTP=1 CONFIGPATH=Config(KAV8).xml /l*v C:\Kaspersky\Kaspersky_KAV.log /qn /norestart" -wait –passthru

                    Start-Sleep -Seconds 60

                    $KServiceStatus = Get-Service Kavfs -ErrorAction SilentlyContinue

                    If (($KServiceStatus.Status) -eq "Running")
                    {
                        ReportDB -Status "KAVWSEE Installation Successful"
                        Remove-item C:\Kaspersky -Recurse
                        Start-Process kavshell.exe -WorkingDirectory "C:\Program Files (x86)\Kaspersky Lab\Kaspersky Anti-Virus 8.0 For Windows Servers Enterprise Edition" -ArgumentList "update /KL" -Wait -PassThru
                    }
                    else
                    {
                        ReportDB -Status "KAVWSEE Installation failed"
                    }
                }
                else
                {
                    ReportDB -Status "Patch-D Installation failed"
                    Write-Warning "Patch-D Installation failed"
                }
            }
            else
            {
                ReportDB -Status "Network Agent Installation failed"
                Write-Warning "Network Agent Installation failed"
            }
        }
        else
        {
            ReportDB -Status "Package copy failed, no AV installed"
            Write-Warning "Package copy failed locally"
        }     
    }
}