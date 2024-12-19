#================================================================================================
#   Date:       January 30, 2024
#   Purpose:    This script set the needed configuration to install the base image 
#               for Windows 11 22H2 and also install drivers and Windows updates to latest as needed.
#================================================================================================

#================================================================================================
#   Set Configuration
#   DO NOT MODIFY BELOW UNLESS INSTRUCTED
#================================================================================================
$Global:OSBuild = "23H2"
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
        #Write-Host "Expanding $Update"
        #expand -f:* $Update.FullName .
        Write-Host "Installing Latest Cumulative Update - please wait while it finish installing"
        Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
        #Start-Process wusa.exe -ArgumentList 'C:\MSupdates\LCU\Windows11-22H2-LCU.msu /quiet /norestart' -Wait
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

Write-Host "Downloading Latest Cumulative Update for Windows 11 23H2 - Dec 10, 2024"
curl.exe -L -o "C:\MSupdates\LCU\Windows11-23H2-LCU.msu" "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/d2584a30-89ea-4236-af04-2585566deaa6/public/windows11.0-kb5048685-x64_f1967f623976c41d20deab623317c4855e9d111a.msu"

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
Restart-Computer