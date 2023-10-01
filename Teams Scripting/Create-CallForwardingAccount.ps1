<#
.SYNOPSIS
The purpose of this script is to provide a simplified way for creating a call forwarding account in teams and assigning the number. 

.DESCRIPTION
The purpose of this script is to provide a simplified way for creating a call forwarding account in teams and assigning the number. 
This script is meant to be used when an employee leaves the company, and someone is requesting the calls for that person be forwarded
in their absence. 

This REQUIRES that you are using Teams Voice as it is only designed to work with Teams Voice.  This call forwarding functionality is 
created through the use of a Call Queue in Teams Voice. 

This script configures the call queue with these settings:
Default Hold Music, Conference Mode Off, opt-Out Off
Presense based call routing configured for attendent routing
Timeout and Overflow get routed to the voicemail of the departing employees manager

.LINK
Source for information for this script located here
https://learn.microsoft.com/en-us/microsoftteams/create-a-phone-system-call-queue-via-cmdlets

Information about this script itself - From the Author
https://seesmitty.com/how-to-script-call-forwarding-in-microsoft-teams-voice/

.NOTES
Author: Smitty
Date: 7/23/2023
Version: 1.0.0

#>

#region Functions

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
#Function to Test whether or not to loop through for another termed user
function Test-Finished {
    $finished = Read-Host "Do Need to forward any more phone numbers? Y or N" 
    IF ($finished -like "Y") {
        New-TermCallForwarding
    }
    ELSE {
        Write-Host "Disconnecting from Teams Powershell" -ForegroundColor Blue
        Disconnect-MicrosoftTeams
        Disconnect-Graph
    }
}

#Function that performs the primary actions involved with reassigning a number 
function New-TermCallForwarding {
    #begin loop prompting script runner for information
    $formerEmployeeUsername = Read-Host "Please provide the username for the former employee: "
    $forwardingManagerUsername = Read-Host "Please provide the username for the manager to recieve calls: "

    #Generates the details for the call queue
    Write-Host "Generating UserPrincipalName and DisplayName" -ForegroundColor Yellow
    

    #Gather details about the former employee and manager for use later
    try {
        Write-Host "Gathering details about these accounts..." -ForegroundColor Yellow
        $formerEmployeeDetails = Get-MgUser -ConsistencyLevel eventual -Filter "startswith(mail, '$formerEmployeeUsername')" | Select-Object GivenName, Surname, DisplayName, UserPrincipalName, Id, BusinessPhones
        $forwardingMangerDetails = Get-MgUser -ConsistencyLevel eventual -Filter "startswith(mail, '$forwardingManagerUsername')" | Select-Object GivenName, Surname, DisplayName, UserPrincipalName, Id
        
        [String]$callQueueDN = "CallForwarding_" + $formerEmployeeDetails.GivenName + "_" + $formerEmployeeDetails.Surname
        [String]$callQueueUPN = $callQueueDN + $emailDomain
        Write-Host "DisplayName is:" $callQueueDN -ForegroundColor Cyan
        Write-Host "UserPrincipalName is:" $callQueueUPN -ForegroundColor Cyan
        
        #creates a cleaner variable for use later in the call queue creation step
        $forwardingManagerId = $forwardingMangerDetails.Id
        Write-Host "Details Gathered for use later" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to Gather details" -ForegroundColor Red
        $Error
    }

    #create a new resource account for the call queue
    try {
        Write-Host "Attempting to create a new Application Instance..." -ForegroundColor Yellow
        New-CsOnlineApplicationInstance -UserPrincipalName $callQueueUPN -DisplayName $callQueueDN -ApplicationID "11cd3e2e-fccb-42ad-ad00-878b93575e07"
        Write-Host "Account created successfully!" -ForegroundColor Green
        
        #Pause for Graph to sync new Account
        Write-Host "Pausing 20 seconds for Call Queue Account to be created before advancing" -ForegroundColor Yellow
        Start-Sleep -Seconds 20 
        #retrieves specific details about the new call queue account for use later
        $callQueueAccountID = (Get-MgUser -UserId $callQueueUPN).Id
    }
    catch {
        Write-Host "Failed to create Call Queue resource account" -ForegroundColor Red
        $Error
    }

    #creates a call queue for the term account we just created
    try {
        Write-Host "Creating New Call Queue..." -ForegroundColor Yellow
        New-CsCallQueue -Name $callQueueDN -UseDefaultMusicOnHold $true -RoutingMethod Attendant -OverflowAction Voicemail -OverflowActionTarget $forwardingManagerId -AllowOptOut $false -ConferenceMode $false -EnableTimeoutSharedVoicemailTranscription $true -TimeoutAction Voicemail -TimeoutActionTarget $forwardingManagerId -TimeoutThreshold 30 -Users @($forwardingManagerId)
        Write-Host "Call Queue Created Successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create Call Queue" -ForegroundColor Red
        $Error
    }

    #Get License details and assign a license
    try {
        Write-Host "Gathering license details and assigning to Resource Account..." -ForegroundColor Yellow
        $license = Get-MgSubscribedSku -All | Where-Object SkuPartNumber -eq 'PHONESYSTEM_VIRTUALUSER'  
    
        #Update the Usage location for our call queue account, and assign it a license. 
        Update-MgUser -UserId $callQueueAccountID -UsageLocation "US"
        Set-MgUserLicense -UserId $callQueueAccountID -AddLicenses @{SkuId = $license.SkuId } -RemoveLicenses @() 
        Write-Host "License assigned successfully!" -ForegroundColor Green

        #Pause for License assignment to sync
        Write-Host "Checking for license" -ForegroundColor Yellow
        Start-Sleep 15

        #While loop to confirm license is assigned before continuing
        $accountLicenseDetail = Get-MgUserLicenseDetail -UserId $callQueueUPN -ErrorAction SilentlyContinue
        while ($null -eq $accountLicenseDetail) {
            Write-Host "No License Found - Pausing to allow License to sync..." -ForegroundColor Yellow
            Start-Sleep -Seconds 15
            $accountLicenseDetail = Get-MgUserLicenseDetail -UserId $callQueueUPN -ErrorAction SilentlyContinue
        }
        
    }
    catch {
        Write-Host "Failed to Assign License to account" -ForegroundColor Red
        $Error
    }


    #Gather details about our call queue and resource account so be associated together
    try {
        $applicationInstanceID = (Get-CsOnlineUser -Identity $callQueueUPN).Identity 
        $callQueueID = (Get-CsCallQueue -NameFilter $callQueueDN).Identity 

        Write-Host "Assigning Resource Account to Call Queue and Assigning a Phone Number..." -ForegroundColor Yellow
        #associate the resource account to the call queue officially
        New-CsOnlineApplicationInstanceAssociation -Identities @($applicationInstanceID) -ConfigurationID $callQueueID -ConfigurationType CallQueue

        #specify Former employee business phone then convert it to the 10 digit number
        [String]$formerEmployeePhone = $formerEmployeeDetails.BusinessPhones
        $formerEmployeePhone = "+1" + $formerEmployeePhone.Replace("-", "")
        
        #assign the number to the resource account for the call queue
        Grant-CsOnlineVoiceRoutingPolicy -Identity $callQueueUPN -PolicyName $voicePolicyName 
        
        Start-Sleep 15
        #assign number to the account
        Set-CsPhoneNumberAssignment -Identity $callQueueUPN -PhoneNumber $formerEmployeePhone -PhoneNumberType DirectRouting
        Write-Host "Number assigned successfully!" -ForegroundColor Green


    }
    catch {
        Write-Host "Failed to finalize Call Forwarding Call Queue" -ForegroundColor Red
        $Error
    }
    
    #begin Loop to test if finished
    Test-Finished

}
#endRegion Functions

#Establish the variables for the script
$emailDomain = "@domain.com"
$voicePolicyName = "VoicePolicyName"

#clear previous errors to ensure clean error logging
$Error.Clear()

#Import Necessary modules
Get-PoshModules -ModuleName 'MicrosoftTeams'
Get-PoshModules -ModuleName 'Microsoft.Graph.Users'

#Create the connections to teams online
Connect-MicrosoftTeams
Connect-Graph -Scopes 'User.ReadWrite.All'

#begin Initial Loop
New-TermCallForwarding
