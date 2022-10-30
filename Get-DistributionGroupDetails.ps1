#Details about this script located at: https://seesmitty.com/how-to-move-distribution-lists-to-exchange-online/

#connect to Exchange Online
Connect-ExchangeOnline

#define the path where all exports will be saved
$path = "C:\temp\DLs"

#gather our information about our distribution lists
$onPremDLs = Get-DistributionGroup | Where-Object { ($_.IsDirSynced -EQ $true -and $_.GroupType -ne "Universal, SecurityEnabled")}

#Export a list of the names of all groups that will be effected
$onPremDLs | Select-Object Name | Export-Csv "$path\AllDL-List.csv"

#Loop to create the CSV backup files, each in their own directory as well as a list of members
foreach($op in $onPremDLs){
    $foldername = $op.Name
    $folder = "$path\$foldername"
    $file = $op.Name

    if (test-path $folder) {
    Write-host "Folder Exists"
    }else {
        mkdir $folder
    }
    #Full backup of all settings related to the DL
    Get-DistributionGroup $op | export-csv "$folder\$file-full.csv"

    #Partial backup pulling only the informaiton that we want for our exchange online DLs
    Get-DistributionGroup $op | Select-Object Name,Alias,Description,DisplayName,Managedby,MemberJoinRestriction,PrimarySmtpAddress,RequireSenderAuthenticationEnabled,GroupType | export-csv "$folder\$file.csv"
    
    #Get all group members and save to a file - we only need PrimarySmtpAddress to add them back to the new group
    Get-DistributionGroupMember $op | select-object PrimarySmtpAddress | Export-Csv "$folder\$file-members.csv"

}

