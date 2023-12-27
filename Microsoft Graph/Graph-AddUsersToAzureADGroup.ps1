<#
.SYNOPSIS
Ths intent behind this script is to make it easier to bulk add users to Azure AD Groups via PowerShell

.DESCRIPTION
Ths intent behind this script is to make it easier to bulk add users to Azure AD Groups via PowerShell. This leverages the 
Microsoft Graph PowerShell SDK to do this. 

This script assumes certificate based authentication though, it can be changed relatively easily to an alternate approved 
authentication method. 

.LINK
https://seesmitty.com/how-to-use-microsoft-graph-powershell-sdk/

.NOTES
Author: Smitty
Date: 8/13/2022
Version: 1.1
#>

#Details to get you connected to Azure Tenant
Connect-Graph -NoWelcome


#import a CSv with the list of users to be added to the group
$users = Import-Csv "FilePath\FileName.csv"
#Name of the group being added
$group = "Group Display Name Here"


#Get the ObjectID for the group in question
$GroupObjectID = Get-MgGroup -Search "DisplayName:$group" -ConsistencyLevel eventual | select-object Id, DisplayName

#Loop to confirm everyone in the list is added to the group
ForEach ($u in $users) {
    $members = Get-MgGroupMember -GroupId $GroupObjectID.Id
    $u2 = Get-MgUser -UserId $u.userPrincipalName | Select-Object Id

    #Check if user is a member; add if they are not
    If ($u2.Id -in $members.id) {
        Write-Host $u.userPrincipalName"is already in the group" -ForegroundColor Blue
    }
    Else {
        New-MgGroupMember -GroupId $GroupObjectID.Id -DirectoryObjectId $u2.Id
        Write-Host $u.userPrincipalName"has been added to the group" -ForegroundColor Green

    }
}

Disconnect-Graph
