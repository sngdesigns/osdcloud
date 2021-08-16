##############################################
# :: Set Configuration ::
##############################################
$Global:OSBuild = "20H2"

$Params = @{
    OSBuild     = $Global:OSBuild
    OSEdition   = "Enterprise"
    Culture     = "en-us"
    SkipAutopilot = $true
    SkipODT     = $true
}

Start-OSDCloud @Params -ZTI

#================================================
#   WinPE PostOS
#   Set Install-WindowsUpdate.ps1
#================================================
$SetCommand = @'
$Location = "$env:SystemDrive\MSCatUpdates\May2021LCU"
$Updates = (Get-ChildItem $Location | Where-Object {$_.Extension -eq '.msu'} | Sort-Object {$_.LastWriteTime} )
$Qty = $Updates.count

cd $Location
foreach ($Update in $Updates)
  {
    Write-Host "Expanding $Update"
    expand -f:* $Update.FullName .
  }  

$Updates = (Get-ChildItem $Location | Where-Object {$_.Extension -eq '.cab'} | Sort-Object {$_.LastWriteTime} )
foreach ($Update in $Updates)
  {
    Write-Host "Installing $Update"
    Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
  }  
'@
$SetCommand | Out-File -FilePath "C:\Windows\Install-Updates.ps1" -Encoding ascii -Force

$SetCommand = @'
$Location = "$env:SystemDrive\MSCatUpdates"
$Updates = (Get-ChildItem $Location | Where-Object {$_.Extension -eq '.msu'} | Sort-Object {$_.LastWriteTime} )
$Qty = $Updates.count

cd $Location
foreach ($Update in $Updates)
  {
    Write-Host "Expanding $Update"
    expand -f:* $Update.FullName .
  }  

$Updates = (Get-ChildItem $Location | Where-Object {$_.Extension -eq '.cab'} | Sort-Object {$_.LastWriteTime} )
foreach ($Update in $Updates)
  {
    Write-Host "Installing $Update"
    Add-WindowsPackage -Online -PackagePath $Update.FullName -NoRestart -ErrorAction SilentlyContinue
  }  
  pause
'@
$SetCommand | Out-File -FilePath "C:\Windows\Install-Updates.ps1" -Encoding ascii -Force

#================================================
#   Download latest Windows update from Microsoft
#================================================
#New-Item -Path C:\MSCatUpdates\May2021LCU -ItemType Directory -Force | Out-Null
#Save-MSCatalogUpdate -Guid 34a1f7a5-12d3-4cae-b279-73b2cb29760f -Destination C:\MSCatUpdates\May2021LCU

#Save-MsUpCatUpdate -Arch x64 -Build $Global:OSBuild -Category SSU -Latest -DestinationDirectory C:\MSCatUpdates
#Save-MsUpCatUpdate -Arch x64 -Build $Global:OSBuild -Category DotNetCU -Latest -DestinationDirectory C:\MSCatUpdates
Save-MsUpCatUpdate -Arch x64 -Build $Global:OSBuild -Category LCU -Latest -DestinationDirectory C:\MSCatUpdates

#================================================
#   PostOS
#================================================
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
            </RunSynchronous>
        </component>
    </settings> 
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Install Windows Update</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -File C:\Windows\Install-Updates2.ps1</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>     
</unattend>
'@
#================================================
#   Set Unattend.xml
#================================================
$PantherUnattendPath = 'C:\Windows\Panther'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$UnattendPath = Join-Path $PantherUnattendPath 'Invoke-OSDSpecialize.xml'
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8
#Use-WindowsUnattend -Path 'C:\' -UnattendPath $UnattendPath -Verbose

Restart-Computer