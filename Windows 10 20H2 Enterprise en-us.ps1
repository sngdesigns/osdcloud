##############################################
# :: Set Configuration ::
##############################################
$Param - @{
    OSBuild     = "20H2"
    OSEdition   = "Enterprise"
    Culture     = "en-us"
    SkipAutopilot = $true
    SkipODT     = $true
}

Install-Module OSD -Force
Start-OSDCloud @Param -ZTI
Restart-Computer
