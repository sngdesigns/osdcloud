#================================================================================================
#   Date:       January 30, 2024
#   Purpose:    This script set the needed configuration to install the base image 
#               for Windows 11 22H2 and also install drivers and Windows updates to latest as needed.
#================================================================================================

#================================================================================================
#   Set Configuration
#   DO NOT MODIFY BELOW UNLESS INSTRUCTED
#================================================================================================
$Global:OSBuild = "24H2"
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

Write-Host "Downloading Latest Cumulative Update for Windows 11 24H2 - April 8, 2025"
curl.exe -L -o "C:\MSupdates\LCU\Windows11-24H2-LCU.msu" "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/d8b7f92b-bd35-4b4c-96e5-46ce984b31e0/public/windows11.0-kb5043080-x64_953449672073f8fb99badb4cc6d5d7849b9c83e8.msu"
curl.exe -L -o "C:\MSupdates\LCU\Windows11-24H2-LCU2.msu" "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/beae415c-d56f-477c-9a3a-3aa4336890f6/public/windows11.0-kb5055523-x64_b1df8c7b11308991a9c45ae3fba6caa0e2996157.msu"

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
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Remove Windows Update Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\MSUpdates -Recurse</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Description>Remove OSDCloud Temp Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\OSDCloud -Recurse</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Description>Remove Drivers Temp Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\Drivers -Recurse</Path>
                </RunSynchronousCommand>         
                <RunSynchronousCommand wcm:action="add">
                    <Order>5</Order>
                    <Description>Remove Provisioning Package</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\Recovery -Recurse</Path>
                </RunSynchronousCommand>    
                <RunSynchronousCommand wcm:action="add">
                    <Order>6</Order>
                    <Path>reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v "VerifiedAndReputablePolicyState" /t REG_DWORD /d 0 /f</Path>
                    <Description>Disable Smart App Control</Description>
                </RunSynchronousCommand>   
                <RunSynchronousCommand wcm:action="add">
                    <Order>7</Order>
                    <Path>reg add "HKEY_USERS\.DEFAULT\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "C:\Windows\Web\Wallpaper\Windows\img0.jpg" /f</Path>
                    <Description>Set Desktop Wallpaper</Description>
                </RunSynchronousCommand>                                                        
            </RunSynchronous>
        </component>
    </settings>    
</unattend>
'@

                # <RunSynchronousCommand wcm:action="add">
                #     <Order>1</Order>
                #     <Description>OSDCloud Specialize</Description>
                #     <Path>Powershell -ExecutionPolicy Bypass -Command Invoke-OSDSpecialize -Verbose</Path>
                # </RunSynchronousCommand>
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