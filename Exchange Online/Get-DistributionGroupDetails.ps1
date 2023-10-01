<#
.SYNOPSIS
This script pulls all the relevant details from existing directory synced Distribution groups, and saves them to a file

.DESCRIPTION
The purpose here is to backup all the relevant informaiton for moving distribution groups from Directort Synced to being managed in Exchange Online only. 
Ideally, you can make it so these are managed exclusively through Exchange Online. This script is only half of the solution, and includes a separate script
for creating the new Distribution groups and applying all related settings

.EXAMPLE
PS C:\> Get-DistributionGroupsDetails.ps1
This is the basics of running the script. There are no additional parameters at this time. 

.OUTPUTS
As it is written, this can produce several files. Further expansion based on the details in the blog below will modify the number of possible files
being created.

.NOTES
The majority of information regarding this script can be found at the blog post. This provides best explanation of use and expectations
Version: 2.0
Date: 11/6/22

Special thanks to PMental on Reddit for the Export-clixml tip, saved this from being a crazy long script
https://www.reddit.com/user/PMental/

Version 1.0 can be found at the Part 1 link below. 

.LINK
Part 1 - https://seesmitty.com/how-to-move-distribution-lists-to-exchange-online/
Part 2 - https://seesmitty.com/how-to-move-distribution-lists-to-exchange-online-part-2/
#>


#connect to Exchange Online
Connect-ExchangeOnline

#define the path where all exports will be saved
$path = "C:\temp\DLs"

#gather our information about our distribution lists
$onPremDLs = Get-DistributionGroup | Where-Object { ($_.IsDirSynced -EQ $true -and $_.GroupType -ne "Universal, SecurityEnabled") }

#Export a list of the names of all groups that will be effected
$onPremDLs | Select-Object Name | Export-Csv "$path\AllDL-List.csv"

#Loop to create the CSV backup files, each in their own directory as well as a list of members
foreach ($op in $onPremDLs) {
    $foldername = $op.Name
    $folder = "$path\$foldername"
    $file = $op.Name

    if (test-path $folder) {
        Write-host "Folder Exists"
    }
    else {
        mkdir $folder
    }


    #Full backup of all settings related to the DL
    Get-DistributionGroup -Filter "DisplayName -eq '$op'" | Export-Clixml -Path "$folder\$file.xml"

    #Get all group members and save to a file - we only need PrimarySmtpAddress to add them back to the new group
    Get-DistributionGroupMember -Identity $op.PrimarySmtpAddress | select-object PrimarySmtpAddress | Export-Csv "$folder\$file-members.csv"

    #Get-delegation permissions for the distribution list in question
    $delegates = Get-RecipientPermission -Identity $op -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($delegates)) {
        Write-Host "No Delegates for group: $op"
    }
    else {
        $delegates | Export-Csv "$folder\$file-access.csv"
        Write-Host "Delegates Exist for group: $op"
    }
}

Disconnect-ExchangeOnline -Confirm:$false
