#================================================================================================
#   Date:       February 8, 2022
#   Purpose:    This script set the needed configuration to install the base image 
#               for 21H2 and also install drivers and Windows updates to latest as needed.
#================================================================================================

#================================================================================================
#   Set Configuration
#   DO NOT MODIFY BELOW UNLESS INSTRUCTED
#================================================================================================
$Global:OSBuild = "22H2"
#$Global:OSDCloudUnattend = $true

$Params = @{
    OSBuild     = $Global:OSBuild
    OSEdition   = "Enterprise"
    OSVersion   = "Windows 11"
    Culture     = "en-us"
    SkipAutopilot = $true
    SkipODT     = $true
    ZTI         = $true
}

Start-OSDCloud @Params

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
    foreach ($Update in $UpdatesLCU)
    {
        Write-Host "Expanding $Update"
        expand -f:* $Update.FullName .
    }  

    $UpdatesLCU = (Get-ChildItem $LocationLCU -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.cab'} | Sort-Object {$_.LastWriteTime} )
    foreach ($Update in $UpdatesLCU)
    {
        Write-Host "Installing $Update"
        Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
    }  

    Set-Location -Path $LocationDotNet
    foreach ($Update in $UpdatesDotNet)
    {
        Write-Host "Expanding $Update"
        expand -f:* $Update.FullName .
    }  

    $UpdatesDotNet = (Get-ChildItem $LocationDotNet -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.cab'} | Sort-Object {$_.LastWriteTime} )
    foreach ($Update in $UpdatesDotNet)
    {
        Write-Host "Installing $Update"
        Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
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

function Save-MsUpCatUpdateWin11 {
    [CmdLetBinding()]
    param (
        [ValidateSet('Windows 11','Windows 10','Windows Server','Windows Server 2016','Windows Server 2019')]
        [Alias('OperatingSystem')]
        [string]$OS = 'Windows 11',

        [ValidateSet('x64','x86')]
        [Alias('Architecture')]
        [string]$Arch = 'x64',

        [ValidateSet('22H2','21H2','21H1','20H2',2004,1909,1903,1809,1803,1709,1703,1607,1511,1507)]
        [string]$Build = '22H2',

        [ValidateSet('LCU','SSU','DotNetCU')]
        [string]$Category = 'LCU',

        [ValidateSet('Preview')]
        [string[]]$Include,

        [string]$DestinationDirectory = "$env:TEMP\MsUpCat",

        [System.Management.Automation.SwitchParameter]$Latest
    )
    #=================================================
    #	MSCatalog PowerShell Module
    #   Ryan-Jan
    #   https://github.com/ryan-jan/MSCatalog
    #   This excellent work is a good way to gather information from MS
    #   Catalog
    #=================================================
    if (!(Get-Module -ListAvailable -Name MSCatalog)) {
        Install-Module MSCatalog -Force
    }
    #=================================================
    #	Make sure the Module was installed first
    #=================================================
    if (Test-MicrosoftUpdateCatalog) {
        if (Get-Module -ListAvailable -Name MSCatalog -ErrorAction Ignore) {
            #=================================================
            #	Details
            #=================================================
            Write-Verbose -Verbose "OperatingSystem: $OS"
            Write-Verbose -Verbose "Architecture: $Arch"
            Write-Verbose -Verbose "Category: $Category"
            #=================================================
            #	Category
            #=================================================
            if ($Category -eq 'LCU') {
                $SearchString = "Cumulative Update $OS"
            }
            if ($Category -eq 'SSU') {
                $SearchString = "Servicing Stack Update $OS"
            }
            if ($Category -eq 'DotNetCU') {
                $SearchString = "Framework $OS"
            }
            if ($OS -eq 'Windows 10') {
                Write-Verbose -Verbose "Build: $Build"
                $SearchString = "$SearchString $Build $Arch"
            }
            if ($OS -eq 'Windows 11') {
                Write-Verbose -Verbose "Build: $Build"
                $SearchString = "$SearchString $Build $Arch"
            }
            elseif ($OS -eq 'Windows Server') {
                Write-Verbose -Verbose "Build: $Build"
                $SearchString = "$SearchString $Build $Arch"
            }
            else {
                $SearchString = "$SearchString $Arch"
            }
            #=================================================
            #	Go
            #=================================================
            $CatalogUpdate = Get-MSCatalogUpdate -Search $SearchString -SortBy "Title" -AllPages -Descending | Sort-Object LastUpdated -Descending | Select-Object LastUpdated,Classification,Title,Size,Products,Guid
            #=================================================
            #	Exclude
            #=================================================
            $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -notmatch 'arm64'}
            $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -notmatch 'Dynamic'}
            #=================================================
            #	OperatingSystem
            #=================================================
            if ($OS -eq 'Windows 10') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match 'Windows 10'}
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Products -notmatch 'Windows Server'}
                if ($Category -eq 'LCU') {
                    #$CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match "Cumulative Update for Windows 10 Version $Build"}
                }
                if ($Category -eq 'SSU') {
                    #$CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match "Servicing Stack Update for Windows 10 Version $Build"}
                }
            }
            if ($OS -eq 'Windows 11') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match 'Windows 11'}
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Products -notmatch 'Windows Server'}
                if ($Category -eq 'LCU') {
                    #$CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match "Cumulative Update for Windows 10 Version $Build"}
                }
                if ($Category -eq 'SSU') {
                    #$CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match "Servicing Stack Update for Windows 10 Version $Build"}
                }
            }
            if ($OS -eq 'Windows Server') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Products -eq 'Windows Server, version 1903 and later'}
            }
            if ($OS -eq 'Windows Server 2016') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Products -eq 'Windows Server 2016'}
            }
            if ($OS -eq 'Windows Server 2019') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Products -eq 'Windows Server 2019'}
            }
            #=================================================
            #	Category
            #=================================================
            if ($Category -eq 'LCU') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -notmatch '.NET'}
            }
            if ($Category -eq 'DotNetCU') {
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -match "Framework"}
            }
            if ($Include -contains 'Preview') {
                Write-Verbose -Verbose "Include Preview Updates: True"
            }
            else {
                Write-Verbose -Verbose "Include Preview Updates: False"
                $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Title -notmatch 'Preview'}
            }
            $CatalogUpdate = $CatalogUpdate | Where-Object {$_.Products -notmatch 'Insider'}
            #=================================================
            #	Select
            #=================================================
            if ($Latest.IsPresent) {
                $CatalogUpdate = $CatalogUpdate | Select-Object -First 1
            }
            else {
                $CatalogUpdate = $CatalogUpdate | Out-GridView -Title 'Select a Microsoft Update to download' -PassThru
            }

            $CatalogUpdate
            #=================================================
            #	Download
            #=================================================
            foreach ($Update in $CatalogUpdate) {
                Save-MSCatalogUpdate -Guid $Update.Guid -Destination $DestinationDirectory
            }
            #=================================================
        }
        else {
            Write-Warning "Save-MsUpCatUpdate: Could not install required PowerShell Module MSCatalog"
        }
    }
    else {
        Write-Warning "Save-MsUpCatUpdate: Could not reach https://www.catalog.update.microsoft.com/"
    }
    #=================================================
}

Save-MsUpCatUpdateWin11 -Arch x64 -Build "22H2" -OS "Windows 11" -Category LCU -Latest -DestinationDirectory C:\MSUpdates\LCU

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
                    <Description>OSDCloud Specialize</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Invoke-OSDSpecialize -Verbose</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Install Windows Update</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -File C:\Windows\Install-Updates.ps1</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Description>Remove Windows Update Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\MSUpdates -Recurse</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Description>Remove OSDCloud Temp Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\OSDCloud -Recurse</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>5</Order>
                    <Description>Remove Drivers Temp Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\Drivers -Recurse</Path>
                </RunSynchronousCommand>         
                <RunSynchronousCommand wcm:action="add">
                    <Order>6</Order>
                    <Description>Remove Provisioning Package</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\Recovery -Recurse</Path>
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
#Restart-Computer