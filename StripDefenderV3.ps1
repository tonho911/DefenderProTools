#strip defender by zoic
#this script will use dism and trusted installer to remove windows defender from an iso file

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}


function Run-Trusted([String]$command) {

    Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue
    #get bin path to revert later
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='TrustedInstaller'"
    $DefaultBinPath = $service.PathName
    #convert command to base64 to avoid errors with spaces
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $base64Command = [Convert]::ToBase64String($bytes)
    #change bin to command
    sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
    #run the command
    sc.exe start TrustedInstaller | Out-Null
    #set bin back to default
    sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
    Stop-Service -Name TrustedInstaller -Force -ErrorAction SilentlyContinue

}


function Show-ModernFilePicker {
    param(
        [ValidateSet('Folder', 'File')]
        $Mode,
        [string]$fileType

    )

    if ($Mode -eq 'Folder') {
        $Title = 'Select Folder'
        $modeOption = $false
        $Filter = "Folders|`n"
    }
    else {
        $Title = 'Select File'
        $modeOption = $true
        if ($fileType) {
            $Filter = "$fileType Files (*.$fileType) | *.$fileType|All files (*.*)|*.*"
        }
        else {
            $Filter = 'All Files (*.*)|*.*'
        }
    }
    #modern file dialog
    #modified code from: https://gist.github.com/IMJLA/1d570aa2bb5c30215c222e7a5e5078fd
    $AssemblyFullName = 'System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'
    $Assembly = [System.Reflection.Assembly]::Load($AssemblyFullName)
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.AddExtension = $modeOption
    $OpenFileDialog.CheckFileExists = $modeOption
    $OpenFileDialog.DereferenceLinks = $true
    $OpenFileDialog.Filter = $Filter
    $OpenFileDialog.Multiselect = $false
    $OpenFileDialog.Title = $Title
    $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

    $OpenFileDialogType = $OpenFileDialog.GetType()
    $FileDialogInterfaceType = $Assembly.GetType('System.Windows.Forms.FileDialogNative+IFileDialog')
    $IFileDialog = $OpenFileDialogType.GetMethod('CreateVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null)
    $null = $OpenFileDialogType.GetMethod('OnBeforeVistaDialog', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $IFileDialog)
    if ($Mode -eq 'Folder') {
        [uint32]$PickFoldersOption = $Assembly.GetType('System.Windows.Forms.FileDialogNative+FOS').GetField('FOS_PICKFOLDERS').GetValue($null)
        $FolderOptions = $OpenFileDialogType.GetMethod('get_Options', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($OpenFileDialog, $null) -bor $PickFoldersOption
        $null = $FileDialogInterfaceType.GetMethod('SetOptions', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $FolderOptions)
    }
  
  

    $VistaDialogEvent = [System.Activator]::CreateInstance($AssemblyFullName, 'System.Windows.Forms.FileDialog+VistaDialogEvents', $false, 0, $null, $OpenFileDialog, $null, $null).Unwrap()
    [uint32]$AdviceCookie = 0
    $AdvisoryParameters = @($VistaDialogEvent, $AdviceCookie)
    $AdviseResult = $FileDialogInterfaceType.GetMethod('Advise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdvisoryParameters)
    $AdviceCookie = $AdvisoryParameters[1]
    $Result = $FileDialogInterfaceType.GetMethod('Show', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, [System.IntPtr]::Zero)
    $null = $FileDialogInterfaceType.GetMethod('Unadvise', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $AdviceCookie)
    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        $FileDialogInterfaceType.GetMethod('GetResult', @('NonPublic', 'Public', 'Static', 'Instance')).Invoke($IFileDialog, $null)
    }

    return $OpenFileDialog.FileName
}




#remove file function edited from
#https://www.powershellgallery.com/packages/RemoveFileZ/0.0.1
function Remove-File([string]$path) {

    $Global:path = $path
    $command = "Remove-Item -Path '$path' -Recurse -Force"
    Run-Trusted -command $command

}


function Disable-Defender($edition) {
    $disableDefendContent = @'
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtectionSource" /t REG_DWORD /d "2" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender\Signature Updates" /v "FirstAuGracePeriod" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender\UX Configuration" /v "DisablePrivacyMode" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "SecurityHealth" /t REG_BINARY /d "030000000000000000000000" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\MRT" /v "DontOfferThroughWUAU" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\MRT" /v "DontReportInfectionInformation" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v "HideSystray" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender" /v "PUAProtection" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "MpEnablePus" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableOnAccessProtection" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRoutinelyTakingAction" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableScanOnRealtimeEnable" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableScriptScanning" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" /v "DisableEnhancedNotifications" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableArchiveScanning" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableCatchupFullScan" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableCatchupQuickScan" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableRemovableDriveScanning" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableRestorePoint" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableScanningMappedNetworkDrivesForFullScan" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableScanningNetworkFiles" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "ScanParameters" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "ScheduleDay" /t REG_DWORD /d 8 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "ScheduleTime" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "DisableUpdateOnStartupWithoutEngine" /t REG_DWORD /d 1 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "ScheduleDay" /t REG_DWORD /d 8 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "ScheduleTime" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates" /v "SignatureUpdateCatchupInterval" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d "1" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "LocalSettingOverrideSpynetReporting" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SpyNetReporting" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\EventLog\System\Microsoft-Antimalware-ShieldProvider" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\EventLog\System\WinDefend" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\MsSecFlt" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\Sense" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\WdBoot" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\WdFilter" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\WdNisDrv" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\WdNisSvc" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\WinDefend" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\wscsvc" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\webthreatdefsvc" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Services\webthreatdefusersvc" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\WMI\Autologger\DefenderApiLogger" /v "Start" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\WMI\Autologger\DefenderAuditLogger" /v "Start" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "PreventOverride" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_DEFAULT\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "EnableWebContentEvaluation" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "PreventOverride" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_NTUSER\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Security Health\State" /v "AppAndBrowser_StoreAppsSmartScreenOff" /t REG_DWORD /d 0 /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControl" /t REG_SZ /d "Anywhere" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControlEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v "CaptureThreatWindow" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v "NotifyMalicious" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v "NotifyPasswordReuse" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v "NotifyUnsafeApp" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v "ServiceEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender" /v "VerifiedAndReputableTrustModeEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender" /v "SmartLockerMode" /t REG_DWORD /d "0" >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" /v "EnableControlledFolderAccess" /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Edge\SmartScreenEnabled" /ve /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Edge\SmartScreenPuaEnabled" /ve /t REG_DWORD /d "0" /f >nul 2>&1
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t REG_SZ /d "hide:windowsdefender;" /f >nul 2>&1
'@

    #disable smart app control on win 11
    if ($edition -like '*Windows 11*') {

        $win11 = 'Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\CI\Policy" /v "VerifiedAndReputablePolicyState" /t REG_DWORD /d "0" /f >nul 2>&1'
        $disableDefendContent += "`n" + $win11
    }

    #run bat with trusted installer to apply reg keys properly
    $dPath = New-Item -Path "$PSScriptRoot\disableDefend.bat" -ItemType File -Force
 
    Set-Content -Path $dPath.FullName -Value $disableDefendContent -Force

    $command = "Start-Process `'$($dPath.FullName)`'"

    Run-Trusted -command $command 
    Start-Sleep 1
    Remove-Item -Path $dPath.FullName -Force
   

}






function install-adk {

    $testP = Test-Path -Path 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe'  

    if (!($testP)) {
        Write-Host 'Installing Windows ADK'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2196127' -UseBasicParsing -OutFile "$PSScriptRoot\adksetup.exe"
        &"$PSScriptRoot\adksetup.exe" /quiet /features OptionId.DeploymentTools | Wait-Process 
        Remove-Item -Path "$PSScriptRoot\adksetup.exe" -Force
    }

    #check if adk installed correctly
    $testP = Test-Path -Path 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe'  

    if ($testP) {
        Write-Host 'ADK Installed'
        return $true
    }
    else {
        return $false
    }

}



function remove-Defender([String]$folderPath, [String]$edition, [String]$removeDir, $index) {
    #check for file explorer open
    $explorerCount = (New-Object -ComObject Shell.Application).Windows().Count
    if ($explorerCount -ne 0) {
        [System.Windows.Forms.MessageBox]::Show('Please Make Sure File Explorer is Closed While Removing Defender.', 'Strip Defender', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }

    Write-Host "Removing Defender from $edition..."
    Mount-WindowsImage -ImagePath "$tempDir\sources\install.wim" -Index $index -Path $removeDir

    Write-Host 'Removing Defender Files...'

    Remove-File -path "$removeDir\Program Files\Windows Defender"
    Remove-File -path "$removeDir\Program Files (x86)\Windows Defender"
    Remove-File -path "$removeDir\Program Files\Windows Defender Advanced Threat Protection"
    Remove-File -path "$removeDir\ProgramData\Microsoft\Windows Defender"
    Remove-File -path "$removeDir\ProgramData\Microsoft\Windows Defender Advanced Threat Protection"
    Remove-File -path "$removeDir\Windows\System32\SecurityHealth*"
    Remove-File -path "$removeDir\Windows\System32\SecurityCenter*"
    Remove-File -path "$removeDir\Windows\System32\smartscreen.exe" 
    Remove-File -path "$removeDir\Windows\System32\CodeIntegrity\CiPolicies\Active\*" 

    Write-Host 'Disabling Defender and Smart Screen...'

    #load offline registry 
    reg load HKLM\OFFLINE_SOFTWARE "$removeDir\Windows\System32\config\SOFTWARE"
    reg load HKLM\OFFLINE_SYSTEM "$removeDir\Windows\System32\config\SYSTEM"
    reg load HKLM\OFFLINE_NTUSER "$removeDir\Users\Default\ntuser.dat"
    reg load HKLM\OFFLINE_DEFAULT "$removeDir\Windows\System32\config\default"

    Disable-Defender -edition $edition

    #additional sec options
    if ($tpmReq) {
        Write-Host 'Disabling TPM Requirements...'
        Reg add 'HKLM\OFFLINE_DEFAULT\Control Panel\UnsupportedHardwareNotificationCache' /v 'SV1' /t REG_DWORD /d 0 /f >$null
        Reg add 'HKLM\OFFLINE_DEFAULT\Control Panel\UnsupportedHardwareNotificationCache' /v 'SV2' /t REG_DWORD /d 0 /f >$null
        Reg add 'HKLM\OFFLINE_NTUSER\Control Panel\UnsupportedHardwareNotificationCache' /v 'SV1' /t REG_DWORD /d 0 /f >$null
        Reg add 'HKLM\OFFLINE_NTUSER\Control Panel\UnsupportedHardwareNotificationCache' /v 'SV2' /t REG_DWORD /d 0 /f >$null
        Reg add 'HKLM\OFFLINE_SYSTEM\Setup\LabConfig' /v 'BypassCPUCheck' /t REG_DWORD /d 1 /f >$null
        Reg add 'HKLM\OFFLINE_SYSTEM\Setup\LabConfig' /v 'BypassRAMCheck' /t REG_DWORD /d 1 /f >$null
        Reg add 'HKLM\OFFLINE_SYSTEM\Setup\LabConfig' /v 'BypassSecureBootCheck' /t REG_DWORD /d 1 /f >$null
        Reg add 'HKLM\OFFLINE_SYSTEM\Setup\LabConfig' /v 'BypassStorageCheck' /t REG_DWORD /d 1 /f >$null
        Reg add 'HKLM\OFFLINE_SYSTEM\Setup\LabConfig' /v 'BypassTPMCheck' /t REG_DWORD /d 1 /f >$null
        Reg add 'HKLM\OFFLINE_SYSTEM\Setup\MoSetup' /v 'AllowUpgradesWithUnsupportedTPMOrCPU' /t REG_DWORD /d 1 /f >$null
    }

    if ($disableMitigations) {
        Write-Host 'Disabling Mitigation Options...'
        $disableContent = @'
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\Session Manager\kernel" /v "MitigationOptions" /t REG_BINARY /d "222022000002000000020000000000000000000000000000" /f
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d "0" /f
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\DeviceGuard" /v "HypervisorEnforcedCodeIntegrity" /t REG_DWORD /d "0" /f
Reg add "HKLM\OFFLINE_SOFTWARE\Microsoft\PolicyManager\default\DeviceGuard\RequirePlatformSecurityFeatures" /v "value" /t REG_DWORD /d "0" /f
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d "0" /f
Reg add "HKLM\OFFLINE_SYSTEM\ControlSet001\Control\DeviceGuard\Scenarios\CredentialGuard" /v "Enabled" /t REG_DWORD /d "0" /f
'@ 
        $dPath = New-Item "$env:TEMP\disableMitigations.bat" -Value $disableContent -Force

        $command = "Start-Process `'$($dPath.FullName)`'"
        Run-Trusted -command $command 
        Start-Sleep 1
        Remove-Item $dPath.FullName -Force -ErrorAction SilentlyContinue
    }

    if ($stripBitlocker) {
        Write-Host 'Stripping Bitlocker...'
        $command = "
        Reg add 'HKLM\OFFLINE_SYSTEM\ControlSet001\Services\BDESVC' /v 'Start' /t REG_DWORD /d '4' /f
        Reg add 'HKLM\OFFLINE_SYSTEM\ControlSet001\Control\BitLocker' /v 'PreventDeviceEncryption' /t REG_DWORD /d '1' /f
        Reg add 'HKLM\OFFLINE_SYSTEM\ControlSet001\Control\BitlockerStatus' /v 'BootStatus' /t REG_DWORD /d '0' /f
        "
        Run-Trusted -command $command
        #remove files
        $bitlockerfiles = @(
            'Windows\BitLockerDiscoveryVolumeContents\BitLockerToGo.exe',
            'Windows\SysWOW64\BitLockerCsp.dll',
            'Windows\System32\BitLockerCsp.dll',
            'Windows\System32\BitLockerWizard.exe',
            'Windows\System32\BitLockerWizardElev.exe',
            'Windows\System32\BitLockerDeviceEncryption.exe',
            'Windows\System32\en-US\BitLockerWizardElev.exe.mui',
            'Windows\System32\en-US\BitLockerWizard.exe.mui'
        )


        foreach ($file in $bitlockerfiles) {
            Remove-File -path "$removeDir\$file"
        }
        

    }

    reg unload HKLM\OFFLINE_SOFTWARE
    reg unload HKLM\OFFLINE_SYSTEM
    reg unload HKLM\OFFLINE_NTUSER
    reg unload HKLM\OFFLINE_DEFAULT

    Write-Host 'Compressing WinSXS Folder...'
    dism /image:$removeDir /Cleanup-Image /StartComponentCleanup /ResetBase

    Write-Host "Unmounting $edition..."
    dism /unmount-image /mountdir:$removeDir /commit


}


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Windows 10 & 11 Defender Remover'
$form.Size = New-Object System.Drawing.Size(500, 250)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.AllowDrop = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

# Create controls for choosing ISO file
$isoLabel = New-Object System.Windows.Forms.Label
$isoLabel.Location = New-Object System.Drawing.Point(10, 20)
$isoLabel.Size = New-Object System.Drawing.Size(120, 20)
$isoLabel.Text = 'Choose ISO File:'
$isoLabel.ForeColor = 'White'
$form.Controls.Add($isoLabel)

$additionalLabel = New-Object System.Windows.Forms.Label
$additionalLabel.Location = New-Object System.Drawing.Point(10, 100)
$additionalLabel.Size = New-Object System.Drawing.Size(200, 20)
$additionalLabel.Text = 'Strip Additional Security Features:'
$additionalLabel.ForeColor = 'White'
$form.Controls.Add($additionalLabel)

$checkbox1 = New-Object System.Windows.Forms.CheckBox
$checkbox1.Location = new-object System.Drawing.Size(15, 120)
$checkbox1.Size = new-object System.Drawing.Size(140, 20)
$checkbox1.Text = 'TPM Requirements'
$checkbox1.ForeColor = 'White'
$checkbox1.Checked = $false
$Form.Controls.Add($checkbox1) 

$checkbox2 = New-Object System.Windows.Forms.CheckBox
$checkbox2.Location = new-object System.Drawing.Size(160, 120)
$checkbox2.Size = new-object System.Drawing.Size(120, 20)
$checkbox2.Text = 'Mitigation Options'
$checkbox2.ForeColor = 'White'
$checkbox2.Checked = $false
$Form.Controls.Add($checkbox2) 

$checkbox3 = New-Object System.Windows.Forms.CheckBox
$checkbox3.Location = new-object System.Drawing.Size(300, 120)
$checkbox3.Size = new-object System.Drawing.Size(120, 20)
$checkbox3.Text = 'Bitlocker'
$checkbox3.ForeColor = 'White'
$checkbox3.Checked = $false
$Form.Controls.Add($checkbox3) 

$isoTextBox = New-Object System.Windows.Forms.TextBox
$isoTextBox.Location = New-Object System.Drawing.Point(130, 20)
$isoTextBox.Size = New-Object System.Drawing.Size(200, 20)
$isoTextBox.Text = $null
$form.Controls.Add($isoTextBox)

$isoBrowseButton = New-Object System.Windows.Forms.Button
$isoBrowseButton.Location = New-Object System.Drawing.Point(340, 20)
$isoBrowseButton.Size = New-Object System.Drawing.Size(40, 20)
$isoBrowseButton.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$isoBrowseButton.ForeColor = [System.Drawing.Color]::White
$isoBrowseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$isoBrowseButton.FlatAppearance.BorderSize = 0
$isoBrowseButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
$isoBrowseButton.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(27, 27, 28)
$isoBrowseButton.Text = '...'
$isoBrowseButton.Add_Click({
        
        $selectedFile = Show-ModernFilePicker -Mode File -fileType 'iso'
        $isoTextBox.Text = $selectedFile
        
    })
$form.Controls.Add($isoBrowseButton)

# Create controls for choosing destination directory
$destLabel = New-Object System.Windows.Forms.Label
$destLabel.Location = New-Object System.Drawing.Point(10, 60)
$destLabel.Size = New-Object System.Drawing.Size(120, 25)
$destLabel.Text = 'Choose Destination Directory:'
$destLabel.ForeColor = 'White'
$form.Controls.Add($destLabel)

$destTextBox = New-Object System.Windows.Forms.TextBox
$destTextBox.Location = New-Object System.Drawing.Point(130, 60)
$destTextBox.Size = New-Object System.Drawing.Size(200, 20)
$destTextBox.Text = $null
$form.Controls.Add($destTextBox)

$destBrowseButton = New-Object System.Windows.Forms.Button
$destBrowseButton.Location = New-Object System.Drawing.Point(340, 60)
$destBrowseButton.Size = New-Object System.Drawing.Size(40, 20)
$destBrowseButton.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$destBrowseButton.ForeColor = [System.Drawing.Color]::White
$destBrowseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$destBrowseButton.FlatAppearance.BorderSize = 0
$destBrowseButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
$destBrowseButton.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(27, 27, 28)
$destBrowseButton.Text = '...'
$destBrowseButton.Add_Click({
        
        $selectedFolder = Show-ModernFilePicker -Mode Folder
        $destTextBox.Text = $selectedFolder
        
    })
$form.Controls.Add($destBrowseButton)


$removeButton = New-Object System.Windows.Forms.Button
$removeButton.Location = New-Object System.Drawing.Point(130, 160)
$removeButton.Size = New-Object System.Drawing.Size(120, 30)
$removeButton.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$removeButton.ForeColor = [System.Drawing.Color]::White
#$removeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
#$removeButton.FlatAppearance.BorderSize = 0
#$removeButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
#$removeButton.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(27, 27, 28)
$removeButton.Text = 'Remove Defender'
$removeButton.Add_Click({

        #check additional options
        $Global:tpmReq = $false
        $Global:disableMitigations = $false
        $Global:stripBitlocker = $false
        if ($checkbox1.Checked) {
            $tpmReq = $true
        }
        if ($checkbox2.Checked) {
            $disableMitigations = $true
        }
        if ($checkbox3.Checked) {
            $stripBitlocker = $true
        }
        
        if ($isoTextBox.Text -eq '' -or $destTextBox.Text -eq '') {
            Write-Host 'Please Select an ISO file and Destination folder'

        }
        else {
            $form.Visible = $false
            $selectedFile = $isoTextBox.Text
            $selectedFolder = $destTextBox.Text 
            # clear any mount points
            [Void](Clear-WindowsCorruptMountPoint)
            Write-Host 'Mounting ISO...'
            # Mount the ISO
            try {
                $mountResult = (Mount-DiskImage -ImagePath $selectedFile -StorageType ISO -PassThru -ErrorAction Stop | Get-Volume).DriveLetter + ':\'

            }
            catch {
                Write-Host 'Unable to Mount ISO...'
                Write-Error $Error[0]
                $form.Dispose()
                $null = Read-Host 'Press Enter to EXIT...'
                exit
            }

            # Create a temporary directory to copy the ISO contents
            $tempDir = "$selectedFolder\TEMP"
            New-Item -ItemType Directory -Force -Path $tempDir
            $removeDir = New-Item -Path $selectedFolder -Name 'RemoveDir' -ItemType Directory 

            Write-Host 'Moving files to TEMP directory...'
            # Copy the ISO contents to the temporary directory
            Copy-Item -Path "$mountResult*" -Destination $tempDir -Recurse -Force

            # Dismount the ISO
            Dismount-DiskImage -ImagePath $selectedFile 

            # Get all files in the folder and its subfolders
            $files = Get-ChildItem -Path $tempDir -Recurse -File -Force

            # Loop through each file
            foreach ($file in $files) {
                # Remove the read-only attribute
                $file.Attributes = 'Normal'
            }

            # Get all directories in the folder and its subfolders
            $directories = Get-ChildItem -Path $tempDir -Recurse -Directory -Force

            # Loop through each directory
            foreach ($directory in $directories) {
                # Remove the read-only attribute
                $directory.Attributes = 'Directory'
            }
    
            
    
            #get editions
            $editions = Get-WindowsImage -ImagePath "$tempDir\sources\install.wim" 
            $Script:index = $null

            

            #create a hashtable with key = edition name value = index
            $editionTable = @{}
            foreach ($edition in $editions) {
                $editionTable.Add($edition.ImageName, $edition.ImageIndex)
            } 
            # Create the form

            $form2 = New-Object System.Windows.Forms.Form
            $form2.Text = 'Choose Edition'
            $form2.Size = New-Object System.Drawing.Size(400, (50 * $editionTable.Count + 100))
            $form2.StartPosition = 'CenterScreen'
            $form2.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)

            $buttonTable = @{}
            $i = 0
            foreach ($edition in $editions) {
                # Create the button
                $button = New-Object System.Windows.Forms.Button
                $button.Location = [System.Drawing.Point]::new(90, 20 + $i * 40)
                $button.Size = [System.Drawing.Size]::new(200, 30)
                $button.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
                $button.ForeColor = [System.Drawing.Color]::White
                #  $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
                #  $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
                #  $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(27, 27, 28)
                $button.Text = $edition.ImageName
                $button.add_Click({
                        # Reset all buttons to original color
                        $buttonTable.Values | ForEach-Object {
                            $_.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
                            #  $_.FlatAppearance.BorderColor = [System.Drawing.Color]::White
                        }
                        # Set the clicked button's color to black
                        $this.BackColor = [System.Drawing.Color]::Black
                        # $this.FlatAppearance.BorderColor = [System.Drawing.Color]::Black

                    }.GetNewClosure())  
                $button.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
                $form2.Controls.Add($button)
                $buttonTable.Add($edition.ImageName, $button)
                $i++
            }


            # Create the OK button
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Location = [System.Drawing.Point]::new(130, (50 * $editionTable.Count) + 20)
            $okButton.Size = [System.Drawing.Size]::new(120, 30)
            $okButton.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
            $okButton.ForeColor = [System.Drawing.Color]::White
            #  $okButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            #  $okButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(62, 62, 64)
            #  $okButton.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(27, 27, 28)
            $okButton.Text = 'OK'
            $okButton.Add_Click({
                    $buttonTable.GetEnumerator() | ForEach-Object {
                        $key = $_.Key
                        $value = $_.Value
                        if ($value.BackColor -eq [System.Drawing.Color]::Black) {
                            $Script:selectedEdition = $key
                        }
                    }
                    $form2.Close()
                    $form2.Dispose()
                })
            $form2.Controls.Add($okButton)

            # Show the form
            $form2.ShowDialog() | Out-null


        }
            
        #get index of selected edition
        #loop through hastable to get edition index
        $editionTable.GetEnumerator() | ForEach-Object {
            $editionName = $_.key
            if ($editionName -eq $selectedEdition) {
                $Script:index = $_.value
                $Script:editionNameR = $editionName
            }
        }

        if ($index -eq $null) {
            Write-Host 'Windows Version not Supported!'
            $null = Read-Host 'Press Enter to EXIT...'
            exit
        }

        if (install-adk) {
            $oscdimg = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe'
        }
        else {
            Write-Host 'ADK Not Found'
            $null = Read-Host 'Press Enter to EXIT...'
            exit
        }

        remove-Defender -folderPath $tempDir -edition $editionNameR -index $index -removeDir $removeDir

        Write-Host 'Compressing ISO File'
        Export-WindowsImage -SourceImagePath "$tempDir\sources\install.wim" -SourceIndex $index -DestinationImagePath "$tempDir\sources\install2.wim" -CompressionType 'max'
        Remove-Item "$tempDir\sources\install.wim"
        Rename-Item "$tempDir\sources\install2.wim" -NewName 'install.wim' -Force

        Write-Host 'Creating ISO File in Destination Directory'
        $title = [System.IO.Path]::GetFileNameWithoutExtension($selectedFile) 
        $path = "$selectedFolder\$title(ND).iso"
        Start-Process -FilePath $oscdimg -ArgumentList "-m -o -u2 -udfver102 -bootdata:2#p0,e,b$tempDir\boot\etfsboot.com#pEF,e,b$tempDir\efi\microsoft\boot\efisys.bin $tempDir `"$path`"" -NoNewWindow -Wait  

        if (!(Test-Path -Path "$selectedFolder\$title(ND).iso")) {
            Write-Host 'ISO File Not Found, Something Went Wrong'
            $null = Read-Host 'Press Enter to EXIT...'
            exit
        }
        else {
            # Delete the temporary directory
            Get-ChildItem -Path $tempDir -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $removeDir -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -Path $removeDir -Recurse -Force -ErrorAction SilentlyContinue

        }

        

    })
$form.Controls.Add($removeButton)

#add drop config feature
$form.Add_DragEnter({
        param($sender, $e)
        if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        }
        else {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    })

$form.Add_DragDrop({
        param($sender, $e)
        $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        if ($files -ne $null) {
            $isoTextBox.Text = $files[0]
        }
    })

# Show the form
$form.ShowDialog() | Out-Null

