# *********************************************************
# *********************************************************
# ***                                                   ***
# ***  Windows 11 Image Cleaner Script by S.H.E.I.K.H   ***
# ***                                                   ***
# ***         Version 1.0.0 (Update 6/12/2025)          ***
# ***                                                   ***
# ***            Based on Tiny11 by NTDEV               ***
# ***                                                   ***
# *********************************************************
# *********************************************************

# Uncomment the line below to enable debugging
# Set-PSDebug -Trace 1

# *********************************************************
# * Part 1 = Scratch disk *********************************
# *********************************************************

param (
    [string]$ScratchDisk
)

if (-not $ScratchDisk) {
    $ScratchDisk = $PSScriptRoot
}
Write-Output "Scratch disk set to $ScratchDisk"

# *********************************************************
# * Part 2 = Check if PowerShell execution is restricted **
# *********************************************************

if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Write-Host "Your current PowerShell Execution Policy is set to Restricted, which prevents scripts from running. Do you want to change it to RemoteSigned? (yes/no)"
    $response = Read-Host
    if ($response -eq 'yes') {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false
    } else {
        Write-Host "The script cannot be run without changing the execution policy. Exiting..."
        exit
    }
}

# *********************************************************
# * Part 3 = Check admin privileges ***********************
# *********************************************************

$adminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$adminGroup = $adminSID.Translate([System.Security.Principal.NTAccount])
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if (! $myWindowsPrincipal.IsInRole($adminRole))
{
    Write-Host "Restarting Win11 image creator as admin in a new window, you can close this one."
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.Arguments = $myInvocation.MyCommand.Definition;
    $newProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($newProcess);
    exit
}

# *********************************************************
# * Part 4 = Start the transcript and prepare the window **
# *********************************************************

Start-Transcript -Path "$($ScratchDisk)\Win11.log" 

$Host.UI.RawUI.WindowTitle = "Windows 11 image cleaner by S.H.E.I.K.H"
Clear-Host
Write-Host "Welcome to the Windows 11 image cleaner! Release: 2025-06-11"

$hostArchitecture = $Env:PROCESSOR_ARCHITECTURE
New-Item -ItemType Directory -Force -Path "$($ScratchDisk)\Win11\sources" | Out-Null
do {
    $DriveLetter = Read-Host "Please enter the drive letter for the Windows 11 image"
    if ($DriveLetter -match '^[c-zC-Z]$') {
        $DriveLetter = $DriveLetter + ":"
        Write-Output "Drive letter set to $DriveLetter"
    } else {
        Write-Output "Invalid drive letter. Please enter a letter between C and Z."
    }
} while ($DriveLetter -notmatch '^[c-zC-Z]:$')

$askForImageIndex = $true
if ((Test-Path "$($DriveLetter)\sources\boot.wim") -eq $false -or (Test-Path "$($DriveLetter)\sources\install.wim") -eq $false) {
    if ((Test-Path "$($DriveLetter)\sources\install.esd") -eq $true) {
        $askForImageIndex = $false
        Write-Host "Found install.esd!"
        & 'DISM' /English /Get-WimInfo /WimFile:"$($DriveLetter)\sources\install.esd"
        $index = Read-Host "Please enter the image index"
        Write-Host ' '
        Write-Host 'Converting install.esd to install.wim. This may take a while...'
        & 'DISM' /English /Export-Image /SourceImageFile:"$($DriveLetter)\sources\install.esd" /SourceIndex:$index /DestinationImageFile:"$($ScratchDisk)\Win11\sources\install.wim" /Compress:max /CheckIntegrity
    } else {
        Write-Host "Can't find Windows OS Installation files in the specified Drive Letter..."
        Write-Host "Please enter the correct DVD Drive Letter..."
        exit
    }
}

# *********************************************************
# * Part 5 = Copying Windows Image ************************
# *********************************************************

Write-Host "Copying Windows image..."
Copy-Item -Path "$($DriveLetter)\*" -Destination "$($ScratchDisk)\Win11" -Recurse -Force | Out-Null
Set-ItemProperty -Path "$($ScratchDisk)\Win11\sources\install.esd" -Name IsReadOnly -Value $false > $null 2>&1
Remove-Item "$($ScratchDisk)\Win11\sources\install.esd" > $null 2>&1
Write-Host "Copy complete!"
Start-Sleep -Seconds 2
Clear-Host

# *********************************************************
# * Part 6 = Getting image information ********************
# *********************************************************

$index = 1
if ($askForImageIndex) {
    Write-Host "Getting image information:"
    & 'DISM' /English /Get-WimInfo /WimFile:"$($ScratchDisk)\Win11\sources\install.wim"
    $index = Read-Host "Please enter the image index"
}

# *********************************************************
# * Part 7 = Mounting Windows image ***********************
# *********************************************************

Write-Host "Mounting Windows image. This may take a while."
$wimFilePath = "$($ScratchDisk)\Win11\sources\install.wim"
& 'takeown' '/f' $wimFilePath 
& 'icacls' $wimFilePath "/grant" "$($adminGroup.Value):(F)"
try {
    Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false -ErrorAction Stop
} catch {
    # This block will catch the error and suppress it.
    Write-Host ' '
}
New-Item -ItemType Directory -Force -Path "$($ScratchDisk)\scratchdir" > $null
& 'DISM' /English /Mount-Image /ImageFile:"$($ScratchDisk)\Win11\sources\install.wim" /Index:$index /MountDir:"$($ScratchDisk)\scratchdir"

$imageIntl = & 'DISM' /English /Get-Intl /Image:"$($ScratchDisk)\scratchdir"
$languageLine = $imageIntl -split '\n' | Where-Object { $_ -match 'Default system UI language : ([a-zA-Z]{2}-[a-zA-Z]{2})' }

if ($languageLine) {
    $languageCode = $Matches[1]
    Write-Host "Default system UI language code: $languageCode"
} else {
    Write-Host "Default system UI language code not found."
}

$imageInfo = & 'DISM' /English /Get-WimInfo /WimFile:"$($ScratchDisk)\Win11\sources\install.wim" /Index:$index
$lines = $imageInfo -split '\r?\n'

foreach ($line in $lines) {
    if ($line -like '*Architecture : *') {
        $architecture = $line -replace 'Architecture : ',''
        # If the architecture is x64, replace it with amd64
        if ($architecture -eq 'x64') {
            $architecture = 'amd64'
        }
        Write-Host "Architecture: $architecture"
        break
    }
}

if (-not $architecture) {
    Write-Host "Architecture information not found."
}

# *********************************************************
# * Part 8 = Removing applications ************************
# *********************************************************

Write-Host "Mounting complete! Performing removal of applications..."

$packages = & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Get-ProvisionedAppxPackages |
    ForEach-Object {
        if ($_ -match 'PackageName : (.*)') {
            $matches[1]
        }
    }
$packagePrefixes = 'Clipchamp.Clipchamp_', 'Microsoft.SecHealthUI_', 'Microsoft.Windows.PeopleExperienceHost_', 'Windows.CBSPreview_', 'Microsoft.BingNews_', 'Microsoft.BingWeather_', 'Microsoft.GamingApp_', 'Microsoft.GetHelp_', 'Microsoft.Getstarted_', 'Microsoft.MicrosoftOfficeHub_', 'Microsoft.MicrosoftSolitaireCollection_', 'Microsoft.People_', 'Microsoft.PowerAutomateDesktop_', 'Microsoft.Todos_', 'Microsoft.WindowsAlarms_', 'microsoft.windowscommunicationsapps_', 'Microsoft.WindowsFeedbackHub_', 'Microsoft.WindowsMaps_', 'Microsoft.WindowsSoundRecorder_', 'Microsoft.Xbox.TCUI_', 'Microsoft.XboxGamingOverlay_', 'Microsoft.XboxGameOverlay_', 'Microsoft.XboxSpeechToTextOverlay_', 'Microsoft.YourPhone_', 'Microsoft.ZuneMusic_', 'Microsoft.ZuneVideo_', 'MicrosoftCorporationII.MicrosoftFamily_', 'MicrosoftCorporationII.QuickAssist_', 'MicrosoftTeams_', 'Microsoft.549981C3F5F10_'

$packagesToRemove = $packages | Where-Object {
    $packageName = $_
    $packagePrefixes -contains ($packagePrefixes | Where-Object { $packageName -like "$_*" })
}
foreach ($package in $packagesToRemove) {
    Write-Host "Removing application: $package"
    & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Remove-ProvisionedAppxPackage /PackageName:"$package"
}

Write-Host "Removing of system apps completed!"



# *********************************************************
# * Part 9 = Removing system packages *********************
# *********************************************************

Write-Host "Removing system packages..."
Start-Sleep -Seconds 1

$packagePatterns = @(
    "Windows-Defender-Client-Package~31bf3856ad364e35~"
	##### Uncomment each pack you want to remove and add a comma after defender package name above
	#"Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35",
    #"Microsoft-Windows-Kernel-LA57-FoD-Package~31bf3856ad364e35~amd64",
    #"Microsoft-Windows-LanguageFeatures-Handwriting-$languageCode-Package~31bf3856ad364e35",
    #"Microsoft-Windows-LanguageFeatures-OCR-$languageCode-Package~31bf3856ad364e35",
    #"Microsoft-Windows-LanguageFeatures-Speech-$languageCode-Package~31bf3856ad364e35",
    #"Microsoft-Windows-LanguageFeatures-TextToSpeech-$languageCode-Package~31bf3856ad364e35",
    #"Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35",
    #"Microsoft-Windows-Wallpaper-Content-Extended-FoD-Package~31bf3856ad364e35",
    #"Microsoft-Windows-WordPad-FoD-Package~",
    #"Microsoft-Windows-TabletPCMath-Package~",
    #"Microsoft-Windows-StepsRecorder-Package~"
)

# Use NTLite to remove other packages!

# Get all packages
$allPackages = & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Get-Packages /Format:Table
$allPackages = $allPackages -split "`n" | Select-Object -Skip 1

foreach ($packagePattern in $packagePatterns) {
    # Filter the packages to remove
    $packagesToRemove = $allPackages | Where-Object { $_ -like "$packagePattern*" }

    foreach ($package in $packagesToRemove) {
        # Extract the package identity
        $packageIdentity = ($package -split "\s+")[0]

        Write-Host "Removing package: $packageIdentity"
        & 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Remove-Package /PackageName:$packageIdentity 
    }
}

# *********************************************************
# * Part 10 = Removing Edge Browser ***********************
# *********************************************************

Write-Host "Removing Edge Browser..."
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files (x86)\Microsoft\Edge" -Recurse -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force | Out-Null


# *********************************************************
# * Part 11 = Removing OneDrive ***************************
# *********************************************************

Write-Host "Removing OneDrive..."
& 'takeown' '/f' "$($ScratchDisk)\scratchdir\Windows\System32\OneDriveSetup.exe" > $null 2>&1
& 'icacls' "$($ScratchDisk)\scratchdir\Windows\System32\OneDriveSetup.exe" '/grant' "$($adminGroup.Value):(F)" '/T' '/C' > $null 2>&1
Remove-Item -Path "$($ScratchDisk)\scratchdir\Windows\System32\OneDriveSetup.exe" -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir\Program Files\Microsoft\OneDrive" -Recurse -Force | Out-Null
Write-Host "Removal completed!"
Start-Sleep -Seconds 2

# *********************************************************
# * Part 12 = Loading Registry ****************************
# *********************************************************

Write-Host "Loading registry..."
& 'reg' 'load' 'HKLM\zCOMPONENTS' '$($ScratchDisk)\scratchdir\Windows\System32\config\COMPONENTS' > $null 2>&1
& 'reg' 'load' 'HKLM\zDEFAULT' '$($ScratchDisk)\scratchdir\Windows\System32\config\default' > $null 2>&1
& 'reg' 'load' 'HKLM\zNTUSER' '$($ScratchDisk)\scratchdir\Users\Default\ntuser.dat' > $null 2>&1
& 'reg' 'load' 'HKLM\zSOFTWARE' '$($ScratchDisk)\scratchdir\Windows\System32\config\SOFTWARE' > $null 2>&1
& 'reg' 'load' 'HKLM\zSYSTEM' '$($ScratchDisk)\scratchdir\Windows\System32\config\SYSTEM' > $null 2>&1

# *********************************************************
# * Part 13 = Bypassing system requirements ***************
# *********************************************************

Write-Host "Bypassing system requirements(on the system image)..."
& 'reg' 'add' 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV1' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV2' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV1' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV2' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassCPUCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassRAMCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassSecureBootCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassStorageCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassTPMCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\MoSetup' '/v' 'AllowUpgradesWithUnsupportedTPMOrCPU' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1

# *********************************************************
# * Part 14 = Disabling Sponsored Apps ********************
# *********************************************************

Write-Host "Disabling Sponsored Apps..."
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'OemPreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'PreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SilentInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' '/v' 'DisableWindowsConsumerFeatures' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'ContentDeliveryAllowed' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start' '/v' 'ConfigureStartPins' '/t' 'REG_SZ' '/d' '{"pinnedList": [{}]}' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'ContentDeliveryAllowed' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'ContentDeliveryAllowed' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'FeatureManagementEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'OemPreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'PreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'PreInstalledAppsEverEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SilentInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SoftLandingEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContentEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-310093Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-338388Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-338389Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-338393Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-353694Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-353696Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContentEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SystemPaneSuggestionsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\PushToInstall' '/v' 'DisablePushToInstall' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\MRT' '/v' 'DontOfferThroughWUAU' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'delete' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions' '/f' > $null 2>&1
& 'reg' 'delete' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' '/v' 'DisableConsumerAccountStateContent' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' '/v' 'DisableCloudOptimizedContent' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1

# *********************************************************
# * Part 15 = Enabling Local Accounts on OOBE *************
# *********************************************************

Write-Host "Enabling Local Accounts on OOBE..."
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' '/v' 'BypassNRO' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1

# *********************************************************
# * Part 16 = Disabling Reserved Storage ******************
# *********************************************************

Write-Host "Disabling Reserved Storage..."
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager' '/v' 'ShippedWithReserves' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1

# *********************************************************
# * Part 17 = Disabling BitLocker *************************
# *********************************************************

Write-Host "Disabling BitLocker Device Encryption..."
& 'reg' 'add' 'HKLM\zSYSTEM\ControlSet001\Control\BitLocker' '/v' 'PreventDeviceEncryption' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1

# *********************************************************
# * Part 18 = Disabling Chat icon *************************
# *********************************************************

Write-Host "Disabling Chat icon..."
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat' '/v' 'ChatIcon' '/t' 'REG_DWORD' '/d' '3' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' '/v' 'TaskbarMn' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1

# *********************************************************
# * Part 19 = Disabling Telemetry *************************
# *********************************************************

Write-Host "Disabling Telemetry..."
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' '/v' 'Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy' '/v' 'TailoredExperiencesWithDiagnosticDataEnabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' '/v' 'HasAccepted' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Input\TIPC' '/v' 'Enabled' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization' '/v' 'RestrictImplicitInkCollection' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization' '/v' 'RestrictImplicitTextCollection' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore' '/v' 'HarvestContacts' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Personalization\Settings' '/v' 'AcceptedPrivacyPolicy' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\DataCollection' '/v' 'AllowTelemetry' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\ControlSet001\Services\dmwappushservice' '/v' 'Start' '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\Windows Chat' '/v' 'ChatIcon' '/t' 'REG_DWORD' '/d' '3' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' '/v' 'TaskbarMn' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1

# *********************************************************
# * Part 20 = Disabling OneDrive folder backup ************
# *********************************************************

Write-Host "Disabling OneDrive folder backup..."
& 'reg' 'add' "HKLM\zSOFTWARE\Policies\Microsoft\Windows\OneDrive" '/v' 'DisableFileSyncNGSC' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1

# *********************************************************
# * Part 21 = Removing Edge related registries ************
# *********************************************************

Write-Host "Removing Edge related registries..."
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" '/f' > $null 2>&1
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update" '/f' > $null 2>&1

# *********************************************************
# * Part 22 = Disabling bing in Start Menu ****************
# *********************************************************

Write-Host "Disabling bing in Start Menu..."
& 'reg' 'add' 'HKLM\zNTUSER\Software\Policies\Microsoft\Windows\Explorer' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Policies\Microsoft\Windows\Explorer' '/v' 'ShowRunAsDifferentUserInStart' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Software\Policies\Microsoft\Windows\Explorer' '/v' 'DisableSearchBoxSuggestions' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1

# *********************************************************
# * Part 23 = Prevention of DevHome and Outlook ***********
# *********************************************************

Write-Host "Prevention of DevHome and Outlook installation..."
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate' '/v' 'workCompleted' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate' '/v' 'workCompleted' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'delete' 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' '/f' > $null 2>&1
& 'reg' 'delete' 'HKLM\zSOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate' '/f' > $null 2>&1

# *********************************************************
# * Part 24 = Taking ownership of Scheduled Tasks *********
# *********************************************************

# This function allows PowerShell to take ownership of the Scheduled Tasks registry key from TrustedInstaller. Based on Jose Espitia's script.
function Enable-Privilege {
 param(
  [ValidateSet(
   "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
   "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
   "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
   "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
   "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
   "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
   "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
   "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
   "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
   "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
   "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
  $Privilege,
  ## The process on which to adjust the privilege. Defaults to the current process.
  $ProcessId = $pid,
  ## Switch to disable the privilege, rather than enable it.
  [Switch] $Disable
 )
 $definition = @'
 using System;
 using System.Runtime.InteropServices;
  
 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }
  
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

 $processHandle = (Get-Process -id $ProcessId).Handle
 $type = Add-Type $definition -PassThru
 $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

Write-Host "Ownership of the Scheduled Tasks registry:"
Enable-Privilege SeTakeOwnershipPrivilege

try {
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership)
    $regACL = $regKey.GetAccessControl()
    $regACL.SetOwner($adminGroup)
    $regKey.SetAccessControl($regACL)
    $regKey.Close()
    Write-Host "Owner changed to Administrators."
} catch {
    Write-Host "Warning: failed to change owner to Administrators."
}

try {
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::ChangePermissions)
    $regACL = $regKey.GetAccessControl()
    $regRule = New-Object System.Security.AccessControl.RegistryAccessRule ($adminGroup,"FullControl","ContainerInherit","None","Allow")
    $regACL.SetAccessRule($regRule)
    $regKey.SetAccessControl($regACL)
    $regKey.Close()
    Write-Host "Permissions modified for Administrators group."
} catch {
    Write-Host "Warning: failed to modify permissions for Administrators group."
}

Write-Host "Registry key permissions updated."

# *********************************************************
# * Part 25 = Deleting App Compatibility Appraiser ********
# *********************************************************

Write-Host 'Deleting Application Compatibility Appraiser...'
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{0600DD45-FAF2-4131-A006-0B17509B9F78}" '/f' > $null 2>&1

# *********************************************************
# * Part 26 = Deleting Customer Exp. Improvement Program **
# *********************************************************

Write-Host 'Deleting Customer Experience Improvement Program...'
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{4738DE7A-BCC1-4E2D-B1B0-CADB044BFA81}" '/f' > $null 2>&1
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{6FAC31FA-4A85-4E64-BFD5-2154FF4594B3}" '/f' > $null 2>&1
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{FC931F16-B50A-472E-B061-B6F79A71EF59}" '/f' > $null 2>&1

# *********************************************************
# * Part 27 = Deleting Program Data Updater ***************
# *********************************************************

Write-Host 'Deleting Program Data Updater...'
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{0671EB05-7D95-4153-A32B-1426B9FE61DB}" '/f' > $null 2>&1

# *********************************************************
# * Part 28 = Deleting autochk proxy **********************
# *********************************************************

Write-Host 'Deleting autochk proxy...'
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{87BF85F4-2CE1-4160-96EA-52F554AA28A2}" '/f' > $null 2>&1
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{8A9C643C-3D74-4099-B6BD-9C6D170898B1}" '/f' > $null 2>&1

# *********************************************************
# * Part 29 = Deleting QueueReporting *********************
# *********************************************************

Write-Host 'Deleting QueueReporting...'
& 'reg' 'delete' "HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{E3176A65-4E44-4ED3-AA73-3283660ACB9C}" '/f' > $null 2>&1

# *********************************************************
# * Part 30 = Disabling Defender **************************
# *********************************************************

Write-Host "Disabling Windows Defender"
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' '/v' 'SettingsPageVisibility' '/t' 'REG_SZ' '/d' 'hide:virus;windowsupdate' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSOFTWARE\Microsoft\Windows Defender\Features' '/v' 'TamperProtection' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSOFTWARE\Policies\Microsoft\Windows Defender' '/v' 'DisableAntiSpyware' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSOFTWARE\Policies\Microsoft\Windows Defender' '/v' 'DisableRealtimeMonitoring' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSOFTWARE\Policies\Microsoft\Windows Defender' '/v' 'DisableAntiVirus' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\CurrentControlSet\Services\WdFilter' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\CurrentControlSet\Services\WdNisDrv' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\CurrentControlSet\Services\WdNisSvc' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\CurrentControlSet\Services\WinDefend' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\ControlSet001\Services\WinDefend' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\ControlSet001\Services\WdNisSvc' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\ControlSet001\Services\WdNisDrv' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\ControlSet001\Services\WdFilter' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\ControlSet001\Services\Sense' '/v' 'Start'  '/t' 'REG_DWORD' '/d' '4' '/f' > $null 2>&1

$servicePaths = @(
    "WinDefend",
    "WdNisSvc",
    "WdNisDrv",
    "WdFilter",
    "Sense"
)

foreach ($path in $servicePaths) {
    Set-ItemProperty -Path 'HKLM:\zSYSTEM\ControlSet001\Services\$path' -Name 'Start' -Value 4
}

# *********************************************************
# * Part 30 = Unmounting Registry *************************
# *********************************************************

Write-Host "Unmounting Registry..."
& 'reg' 'unload' 'HKLM\zCOMPONENTS' > $null 2>&1
& 'reg' 'unload' 'HKLM\zDEFAULT' > $null 2>&1
& 'reg' 'unload' 'HKLM\zNTUSER' > $null 2>&1
& 'reg' 'unload' 'HKLM\zSOFTWARE' > $null 2>&1
& 'reg' 'unload' 'HKLM\zSYSTEM' > $null 2>&1
Write-Host "Tweaking completed!"

# *********************************************************
# * Part 31 = Cleaning up image ***************************
# *********************************************************

Write-Host "Cleaning up image..."
& 'DISM' /English /Image:"$($ScratchDisk)\scratchdir" /Cleanup-Image /StartComponentCleanup /ResetBase
Write-Host "Cleanup completed!"
Write-Host ' '

# *********************************************************
# * Part 32 = Unmounting image ****************************
# *********************************************************

Write-Host "Unmounting image..."
& 'DISM' /English /Unmount-Image /MountDir:"$($ScratchDisk)\scratchdir" /Commit

# *********************************************************
# * Part 33 = Exporting image *****************************
# *********************************************************

Write-Host "Exporting image..."
& 'DISM' /English /Export-Image /SourceImageFile:"$($ScratchDisk)\Win11\sources\install.wim" /SourceIndex:"$index" /DestinationImageFile:"$($ScratchDisk)\Win11\sources\install2.wim" /Compress:max
Remove-Item -Path "$($ScratchDisk)\Win11\sources\install.wim" -Force | Out-Null
Rename-Item -Path "$($ScratchDisk)\Win11\sources\install2.wim" -NewName "install.wim" | Out-Null
Write-Host "Windows image completed!"
Start-Sleep -Seconds 2

# *********************************************************
# * Part 34 = Modifying boot image ************************
# *********************************************************

Write-Host "Mounting boot image..."
$wimFilePath = "$($ScratchDisk)\Win11\sources\boot.wim" 
& 'takeown' "/f" $wimFilePath > $null 2>&1
& 'icacls' $wimFilePath "/grant" "$($adminGroup.Value):(F)" > $null 2>&1
Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false
& 'DISM' /English /Mount-Image /ImageFile:"$($ScratchDisk)\Win11\sources\boot.wim" /Index:2 /MountDir:"$($ScratchDisk)\scratchdir"

Write-Host "Loading registry..."
& 'reg' 'load' 'HKLM\zDEFAULT' '$($ScratchDisk)\scratchdir\Windows\System32\config\default' > $null 2>&1
& 'reg' 'load' 'HKLM\zNTUSER' '$($ScratchDisk)\scratchdir\Users\Default\ntuser.dat' > $null 2>&1
& 'reg' 'load' 'HKLM\zSYSTEM' '$($ScratchDisk)\scratchdir\Windows\System32\config\SYSTEM' > $null 2>&1
Write-Host "Bypassing system requirements(on the setup image)..."
& 'reg' 'add' 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV1' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV2' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV1' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV2' '/t' 'REG_DWORD' '/d' '0' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassCPUCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassRAMCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassSecureBootCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassStorageCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassTPMCheck' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\MoSetup' '/v' 'AllowUpgradesWithUnsupportedTPMOrCPU' '/t' 'REG_DWORD' '/d' '1' '/f' > $null 2>&1
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\zSYSTEM\Setup' '/v' 'CmdLine' '/t' 'REG_SZ' '/d' 'X:\sources\setup.exe' '/f' > $null 2>&1

Write-Host "Tweaking complete!"
Write-Host "Unmounting Registry..."
& 'reg' 'unload' 'HKLM\zDEFAULT' > $null 2>&1
& 'reg' 'unload' 'HKLM\zNTUSER' > $null 2>&1
& 'reg' 'unload' 'HKLM\zSYSTEM' > $null 2>&1

Write-Host "Unmounting image..."
& 'DISM' /English /Unmount-Image /MountDir:"$($ScratchDisk)\scratchdir" /Commit

Write-Host "Exporting ESD. This may take a while..."
& 'DISM' /English /Export-Image /SourceImageFile:"$($ScratchDisk)\Win11\sources\install.wim" /SourceIndex:1 /DestinationImageFile:"$($ScratchDisk)\Win11\sources\install.esd" /Compress:recovery
Remove-Item "$($ScratchDisk)\Win11\sources\install.wim" > $null 2>&1

# *********************************************************
# * Part 35 = Creating ISO image **************************
# *********************************************************

Write-Host "The Win11 image is now completed. Proceeding with the making of the ISO..."
Write-Host "Creating ISO image..."
$ADKDepTools = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$hostarchitecture\Oscdimg"
$localOSCDIMGPath = "$($PSScriptRoot)\oscdimg.exe"

if ([System.IO.Directory]::Exists($ADKDepTools)) {
    Write-Host "Will be using oscdimg.exe from system ADK."
    $OSCDIMG = "$ADKDepTools\oscdimg.exe"
} else {
    Write-Host "ADK folder not found. Will be using bundled oscdimg.exe."
    
    $url = "https://msdl.microsoft.com/download/symbols/oscdimg.exe/3D44737265000/oscdimg.exe"

    if (-not (Test-Path -Path $localOSCDIMGPath)) {
        Write-Host "Downloading oscdimg.exe..."
        Invoke-WebRequest -Uri $url -OutFile $localOSCDIMGPath

        if (Test-Path $localOSCDIMGPath) {
            Write-Host "oscdimg.exe downloaded successfully."
        } else {
            Write-Error "Failed to download oscdimg.exe."
            exit 1
        }
    } else {
        Write-Host "oscdimg.exe already exists locally."
    }

    $OSCDIMG = $localOSCDIMGPath
}

& "$OSCDIMG" '-m' '-o' '-u2' '-udfver102' "-bootdata:2#p0,e,b$($ScratchDisk)\Win11\boot\etfsboot.com#pEF,e,b$($ScratchDisk)\Win11\efi\microsoft\boot\efisys.bin" "$($ScratchDisk)\Win11" "$($PSScriptRoot)\Win11.iso"

# *********************************************************
# * Part 36 = Cleaning up Temporary files *****************
# *********************************************************

Write-Host "Performing Cleanup..."
Remove-Item -Path "$($ScratchDisk)\Win11" -Recurse -Force | Out-Null
Remove-Item -Path "$($ScratchDisk)\scratchdir" -Recurse -Force | Out-Null

# *********************************************************
# * Part 37 = Finishing up ********************************
# *********************************************************

Write-Host "Creation completed!"
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# *********************************************************
# * Part 38 = Stop the transcript *************************
# *********************************************************

Write-Host "Press any key to close ..."
Stop-Transcript
pause
exit
