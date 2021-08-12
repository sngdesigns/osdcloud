##############################################
# :: Set Configuration ::
##############################################
$Param = @{
    OSBuild     = "20H2"
    OSEdition   = "Enterprise"
    Culture     = "en-us"
    SkipAutopilot = $true
    SkipODT     = $true
}

Start-OSDCloud @Param -ZTI

$OOBEDeployJson = @'
{
    "UpdateWindows":  {
                          "IsPresent":  true
                      }
}
'@
If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}
$OOBEDeployJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json" -Encoding ascii -Force

#================================================
#   PostOS
#   Audit Mode OOBEDeploy
#================================================
$AuditUnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize" wasPassProcessed="true">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>OSDCloud Specialize</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Invoke-OSDSpecialize -Verbose</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Reseal>
                <Mode>Audit</Mode>
            </Reseal>
        </component>
    </settings>
    <settings pass="auditUser">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Setting PowerShell ExecutionPolicy</Description>
                    <Path>PowerShell -WindowStyle Hidden -Command "Set-ExecutionPolicy RemoteSigned -Force"</Path>
                </RunSynchronousCommand>

                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Update OSD Module</Description>
                    <Path>PowerShell -Command "Install-Module OSD -Force"</Path>
                </RunSynchronousCommand>

                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Description>Update Windows</Description>
                    <Path>PowerShell -Command "Start-OOBEDeploy -AddNetFX3 -UpdateDrivers -UpdateWindows"</Path>
                </RunSynchronousCommand>

                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Description>Syspre</Description>
                    <Path>PowerShell -Command "Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList '/generalize /oobe /reboot /quiet'"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>5</Order>
                    <Description>Restart Computer</Description>
                    <Path>PowerShell -Command "Restart-Computer"</Path>
                </RunSynchronousCommand>        
            </RunSynchronous>
        </component>
    </settings>
</unattend>
'@
#================================================
#   Set Unattend.xml
#================================================
$PantherUnattendPath = 'C:\Windows\Panther\Unattend'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$AuditUnattendPath = Join-Path $PantherUnattendPath 'Unattend.xml'
$AuditUnattendXml | Out-File -FilePath $AuditUnattendPath -Encoding utf8
Use-WindowsUnattend -Path 'C:\' -UnattendPath $AuditUnattendPath -Verbose
Restart-Computer