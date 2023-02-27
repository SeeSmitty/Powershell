<#
.SYNOPSIS
The purpose of this script is to allow for the creation of a scheduled task. This script is broken down into 3 main parts. 
This particular script ensures that files required for the ODOT State Kit will be copied to AppData at Logon

If Deploying with Intune, be sure to deploy script as system, not as user. Standard users cannot create scheduled tasks via PowerShell

.DESCRIPTION
The three main parts of this script include:
1. Creating the script that the scheduled task will run
2. Creating the scheduled task to run at start up
3. Running the Scheduled Task to begin the process

.NOTES
Author: Smitty
Date: 2/26/2023
Version: 1.0

#>

#############################################################
# Set Script Values and create the script
#############################################################
$scriptPath = "C:\temp"
$scriptName = "ScheduleTaskTest.ps1"
$script = '
$origin = "C:\Program Files\Autodesk\AutoCAD 2018\Support"
$destination = "$env:APPDATA\Autodesk\C3D 2018\enu\Support"
$Filenames = @("OhDOT.mnl","ohdot.mnr","OhDOT.cuix")

foreach($f in $Filenames){ 
    if (!(Test-Path "$destination\$f")) { 
        if (Test-Path "$origin\$f") { 
            Copy-Item -Path "$origin\$f" -Destination "$destination\$f" -Confirm:$false 
        }else {
            Write-Host "Computer missing $f"
        }
    }else {
        Write-Host "Files Exist already"
    }
}
'

Set-Content -Path $scriptPath\$scriptName -Value $script

#############################################################
#Set Values of Scheduled Task 
#############################################################

$TaskName = "Start Copy Process"
Get-ScheduledTask | Where-Object {$_.TaskName -eq "$TaskName"} | Unregister-ScheduledTask -confirm:$false
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle hidden -File $scriptPath\$scriptName"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = (Get-CimInstance -ClassName Win32_ComputerSystem).Username
$settings = New-ScheduledTaskSettingsSet
Register-ScheduledTask -TaskName $TaskName -Trigger $trigger -User $principal -Action $action -Settings $settings


#############################################################
# Run Scheduled Task
#############################################################
try {
    Start-ScheduledTask -TaskName $TaskName
}
catch {
    Write-Host $Error
    Exit 2000
}
