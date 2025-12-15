#================================================================================================
#   Date:       January 30, 2024
#   Purpose:    This script set the needed configuration to install the base image 
#               for Windows 11 25H2 and also install drivers and Windows updates to latest as needed.
#================================================================================================

#================================================================================================
#   Set Configuration
#   DO NOT MODIFY BELOW UNLESS INSTRUCTED
#================================================================================================

$OSDCloudPath = Get-OSDCloudModulePath

Write-Host "OSDCloudPath = $OSDCloudPath"

$steppreinstallcleardisk = @'
function step-preinstall-cleardisk {
    [CmdletBinding()]
    param (
        # We should always confirm to Clear-Disk as this is destructive
        [System.Boolean]
        $Confirm = $false
    )
    #=================================================
    # Start the step
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] Start"
    Write-Debug -Message $Message; Write-Verbose -Message $Message

    # Get the configuration of the step
    $Step = $global:OSDCloudWorkflowCurrentStep
    #=================================================
    #region Main
    # If Confirm is set to false, we need to check if there are multiple disks
    if (($Confirm -eq $false) -and (($global:OSDCloudWorkflowInvokeSettings.GetDiskFixed | Measure-Object).Count -ge 2)) {
        Write-Warning "[$(Get-Date -format G)] OSDCloud has detected more than 1 Fixed Disk is installed. Clear-Disk with Confirm is required"
        $Confirm = $false
    }

    Clear-LocalDisk -Force -NoResults -Confirm:$false -ErrorAction Stop
    #endregion
    #=================================================
    # End the function
    $Message = "[$(Get-Date -format G)] [$($MyInvocation.MyCommand.Name)] End"
    Write-Verbose -Message $Message; Write-Debug -Message $Message
    #=================================================
}
'@

$steppreinstallcleardisk | Out-File -FilePath "$OSDCloudPath\private\steps\3-preinstall\step-preinstall-cleardisk.ps1" -Encoding ascii -Force

$osadm64json = @'
{
    "OSActivation.default": "Volume",
    "OSActivation.values": [
        "Retail",
        "Volume"
    ],
    "OSEdition.default": "Enterprise",
    "OSEditionId.default": "Enterprise",
    "OSEdition.values": [
        {
            "Edition": "Home",
            "EditionId": "Core"
        },
        {
            "Edition": "Home N",
            "EditionId": "CoreN"
        },
        {
            "Edition": "Education",
            "EditionId": "Education"
        },
        {
            "Edition": "Education N",
            "EditionId": "EducationN"
        },
        {
            "Edition": "Pro",
            "EditionId": "Professional"
        },
        {
            "Edition": "Pro N",
            "EditionId": "ProfessionalN"
        },
        {
            "Edition": "Enterprise",
            "EditionId": "Enterprise"
        },
        {
            "Edition": "Enterprise N",
            "EditionId": "EnterpriseN"
        }
    ],
    "OSLanguageCode.default": "en-us",
    "OSLanguageCode.values": [
        "ar-sa",
        "bg-bg",
        "cs-cz",
        "da-dk",
        "de-de",
        "el-gr",
        "en-gb",
        "en-us",
        "es-es",
        "es-mx",
        "et-ee",
        "fi-fi",
        "fr-ca",
        "fr-fr",
        "he-il",
        "hr-hr",
        "hu-hu",
        "it-it",
        "ja-jp",
        "ko-kr",
        "lt-lt",
        "lv-lv",
        "nb-no",
        "nl-nl",
        "pl-pl",
        "pt-br",
        "pt-pt",
        "ro-ro",
        "ru-ru",
        "sk-sk",
        "sl-si",
        "sr-latn-rs",
        "sv-se",
        "th-th",
        "tr-tr",
        "uk-ua",
        "zh-cn",
        "zh-tw"
    ],
    "OSName.default": "Win11-25H2-amd64",
    "OSName.values": [
        "Win11-25H2-amd64",
        "Win11-24H2-amd64",
        "Win11-23H2-amd64"
    ]
}
'@

$osadm64json | Out-File -FilePath "$OSDCloudPath\workflow\default\os-amd64.json" -Encoding ascii -Force

# Remove and reimport module to due to configuration change after module is installed
Remove-Module OSDCloud -Force -ErrorAction SilentlyContinue
Import-Module  "$OSDCloudPath\OSDCloud.psm1"

# Kickoff OSDCloudWorkflow
Start-OSDCloudWorkflow -CLI -Verbose


#================================================================================================
#   WinPE PostOS
#   Set Install-Updates.ps1
#================================================================================================
$SetCommand = @'
Function Install-MSUpdates{
    param (
        $LocationLCU = 'C:\MSUpdates\LCU',

        $LocationDotNet = 'C:\MSUpdates\DotNet'
    )

    $UpdatesLCU = (Get-ChildItem $LocationLCU -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.msu'} | Sort-Object {$_.LastWriteTime} )
    $UpdatesDotNet = (Get-ChildItem $LocationDotNet -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.msu'} | Sort-Object {$_.LastWriteTime} )

    Set-Location -Path $LocationLCU

    Write-Host "Installing Latest Cumulative Update - please wait while it finish installing"
    Add-WindowsPackage -Online -PackagePath $LocationLCU -NoRestart -ErrorAction SilentlyContinue

    foreach ($Update in $UpdatesLCU)
    {
        #Write-Host "Expanding $Update"
        #expand -f:* $Update.FullName .
        # Write-Host "Installing Latest Cumulative Update - please wait while it finish installing"
        # Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
        #Start-Process wusa.exe -ArgumentList 'C:\MSupdates\LCU\Windows11-23H2-LCU.msu /quiet /norestart' -Wait
        #Start-Sleep 10
        #Invoke-oobeUpdateWindows
    }  

    $UpdatesLCU = (Get-ChildItem $LocationLCU -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.cab'} | Sort-Object {$_.LastWriteTime} )
    foreach ($Update in $UpdatesLCU)
    {
        #Write-Host "Installing $Update"
        #Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
    }  

    Set-Location -Path $LocationDotNet
    foreach ($Update in $UpdatesDotNet)
    {
        #Write-Host "Expanding $Update"
        #expand -f:* $Update.FullName .
    }  

    $UpdatesDotNet = (Get-ChildItem $LocationDotNet -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.cab'} | Sort-Object {$_.LastWriteTime} )
    foreach ($Update in $UpdatesDotNet)
    {
        #Write-Host "Installing $Update"
        #Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
    }     
}

Install-MSUpdates
'@
$SetCommand | Out-File -FilePath "C:\Windows\Install-Updates.ps1" -Encoding ascii -Force

#================================================================================================
#   Download latest Windows update from Microsoft
#================================================================================================

# To bypass IE first launch
New-Item "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main" -Force -EA SilentlyContinue | Out-Null
New-ItemProperty -LiteralPath "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 1 -PropertyType Dword -Force -EA SilentlyContinue | Out-Null

#Save-MsUpCatUpdate -Arch x64 -Build $Global:OSBuild -OS "Windows 10" -Category DotNetCU -Latest -DestinationDirectory C:\MSUpdates\DotNet
# Save-MsUpCatUpdate -Arch x64 -Build $Global:OSBuild -OS "Windows 11" -Category LCU -Latest -DestinationDirectory C:\MSUpdates\LCU

New-Item "C:\MSUpdates\LCU" -ItemType Directory -Force

# Write-Host "Downloading Latest Cumulative Update for Windows 11 25H2 - Dec 9, 2025"
curl.exe -L -o "C:\MSupdates\LCU\Windows11-25H2-LCU.msu" "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/9d6e2b81-b755-4e68-af73-9f4ee41cd758/public/windows11.0-kb5072033-x64_a62291f0bad9123842bf15dcdd75d807d2a2c76a.msu"
curl.exe -L -o "C:\MSupdates\LCU\Windows11-25H2-LCU2.msu" "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/d8b7f92b-bd35-4b4c-96e5-46ce984b31e0/public/windows11.0-kb5043080-x64_953449672073f8fb99badb4cc6d5d7849b9c83e8.msu"

$product = Get-WmiObject Win32_ComputerSystemProduct
$vendor = $product.Vendor
if($vendor -like "Dell Inc."){
    $model = $product.Name
    if($model -eq "Dell Pro Max 16 MC16250"){
        $driverpack = (Get-DellDriverPackCatalog | Where-Object {$_.Name -like "*Dell Pro Max 16 MC16250*Win11*"})
        $driverpackurl = $driverpack.DriverPackUrl
        $driverpackexe = $driverpack.FileName
        Write-Host "Downloading Dell Pro Max 16 MC16250 Driver Pack"
        Save-WebFile -SourceUrl $driverpackurl -DestinationDirectory C:\Drivers 

        Write-Host "Expanding the driver pack to C:\Drivers"
        Start-Process C:\Drivers\$driverpackexe -ArgumentList "/s /e=C:\Drivers\MC16250" -Wait
    }
}


# Use old unattended method instead of Provisioning ppkg to install drivers
Set-OSDCloudUnattendSpecialize

#================================================================================================
#   PostOS
#   Installing driver and update Microsoft patches
#   during specialize phase
#================================================================================================
$UnattendXml = @'
<?xml version='1.0' encoding='utf-8'?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Install Windows Update</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -File C:\Windows\Install-Updates.ps1</Path>
                </RunSynchronousCommand>   
            </RunSynchronous>           
        </component>
    </settings>    
</unattend>
'@
#================================================================================================
#   Set Unattend.xml
#================================================================================================
$PantherUnattendPath = 'C:\Windows\Panther'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$UnattendPath = Join-Path $PantherUnattendPath 'Invoke-OSDSpecialize.xml'
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8

Write-Verbose "Setting Unattend in Offline Registry"
Invoke-Exe reg load HKLM\TempSYSTEM "C:\Windows\System32\Config\SYSTEM"
Invoke-Exe reg add HKLM\TempSYSTEM\Setup /v UnattendFile /d "C:\Windows\Panther\Invoke-OSDSpecialize.xml" /f
Invoke-Exe reg unload HKLM\TempSYSTEM

#================================================================================================
#   WinPE PostOS
#   Restart Computer
#================================================================================================
Restart-Computer