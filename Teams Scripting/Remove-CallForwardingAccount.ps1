<#
.SYNOPSIS
Thie purpose of this script is to remove a call forwarding account created by the Create-CallForwardingAccount.ps1 script.

.DESCRIPTION
Thie purpose of this script is to remove a call forwarding account created by the Create-CallForwardingAccount.ps1 script.
Like any good script that adds or changes things, it is important to have a way to undo those changes. This script will reverse
the changes created by that script, removing the Call Queue, reclaiming the license, and deleting the Resource Account. 

.LINK
https://seesmitty.com/how-to-script-call-forwarding-in-microsoft-teams-voice/

.NOTES
Author: Smitty
Date: 7/23/2023
Version: 1.0.0

#>

#Function to Test whether or not to loop through for another termed user
function Test-Finished {
    $finished = Read-Host "Do Need to forward any more phone numbers? Y or N" 
    IF ($finished -like "Y") {
        Remove-CallForwardingAccount
    }
    ELSE {
        Write-Host "Disconnecting from Teams Powershell" -ForegroundColor Blue
        Disconnect-MicrosoftTeams
        Disconnect-Graph
    }
}

#Function for updating PowerShell Modules
function Get-PoshModules {
    param (
        [Parameter(Mandatory)]$ModuleName
    )

    if (Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue) {
        Write-Host "Checking $ModuleName for updates..." -ForegroundColor Yellow
        Update-Module $ModuleName -Confirm:$false
        Write-Host $ModuleName "Updated Successfully" -ForegroundColor Green
        Import-Module -Name $ModuleName -ErrorAction SilentlyContinue
    
    }
    else {
        try {
            Write-Host "$ModuleName not Found - Installing for current user..." -ForegroundColor Yellow
            Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Host "$ModuleName installed for current user" -ForegroundColor Green
        }
        catch {
            Write-Host $ModuleName "Not Found in Remote Repository - Please check the name and try again" -ForegroundColor Red 
        }
        
    }
}
function Remove-CallForwardingAccount {

    #gather initial details about the accounts in question
    $callQueueUPN = Read-Host "What is the UPN for the Call Forwarding Resource Account: "
    $callQueueDN = Read-Host "What is the EXACT DisplayName for the Call Forwarding Call Queue: "

    #remove the Association of the Resource Account from the Call Queue
    try {
        Write-Host "Removing the Call Queue Association..." -ForegroundColor Yellow
        $applicationInstanceID = (Get-CsOnlineUser -Identity $callQueueUPN).Identity
        Remove-CsOnlineApplicationInstanceAssociation -Identities @($applicationInstanceID)
        Write-Host "Association removed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not remove association" -ForegroundColor Red
        Write-Host $Error
    }
    
    #remove all phone numbers assigned to the Call forwarding account
    try {
        Write-Host "Attempting to remove all phone numbers from account..." -ForegroundColor Yellow
        Remove-CsPhoneNumberAssignment -Identity $callQueueUPN -RemoveAll -ErrorAction Stop
        Write-Host "Number removed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not remove phone numbers" -ForegroundColor Red
        Write-Host $Error
    }

    #Get License details and Remove the license from our Call Queue Account 
    try {
        Write-Host "Attempting to remove License from Resource Account..." -ForegroundColor Yellow
        $license = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq 'PHONESYSTEM_VIRTUALUSER'
        $callQueueAccountID = (Get-MgUser -UserId $callQueueUPN).Id
        Set-MgUserLicense -UserId $callQueueAccountID -AddLicenses @() -RemoveLicenses @($license.SkuId) -ErrorAction Stop
        Write-Host "License removed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not remove resource account license" -ForegroundColor Red
        Write-Host $Error
    }
    
    #remove the Call Queue from Teams Voice
    try {
        Write-Host "Removing Call Queue from Teams Voice..." -ForegroundColor Yellow
        $callQueueID = (Get-CsCallQueue -NameFilter $callQueueDN).Identity
        Remove-CsCallQueue -Identity $callQueueID
        Write-Host "Call Queue removed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not remove call queue" -ForegroundColor Red
        Write-Host $Error
    }

    #Removes the call queue resource Account from the tenant
    try {
        Write-Host "Attempting to remove Resource Account..." -ForegroundColor Yellow
        Remove-MgUser -UserId $callQueueAccountID -Confirm:$false -ErrorAction Stop
        Write-Host "Account Removed Successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not remove resource account" -ForegroundColor Red
        Write-Host $Error
    }
    

    #test whether another loop is needed
    Test-Finished
}

#Import Necessary modules
Get-PoshModules -ModuleName 'MicrosoftTeams'
Get-PoshModules -ModuleName 'Microsoft.Graph.Users'

#Clear previous errors for cleaner error logging
$Error.Clear()

#Create the connections to teams online
Connect-MicrosoftTeams
Connect-Graph -Scopes 'User.ReadWrite.All'

#begin Initial loop
Remove-CallForwardingAccount
