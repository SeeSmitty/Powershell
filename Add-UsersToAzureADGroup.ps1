# Courtesy of SeeSmitty - https://github.com/SeeSmitty/Powershell/blob/main/Add-UsersToAzureADGroup.ps1

#connect to azure ad
Connect-AzureAD

#import a CSv with the list of users to be added to the group
$list = Import-Csv "C:\Users\SeeSmitty\Downloads\UserList.csv"
#Name of the group being added
$group = "Group Name"


#get the object ID from Azure
$GroupObjectID = Get-AzureADGroup -SearchString $group | Select -Property ObjectID


#roll through the list to look up each user and add to the group. 
foreach ($y in $list){
    $y2 = Get-AzureADUser -ObjectId $y.userPrincipalName | Select -Property ObjectID
    $members = Get-AzureADGroupMember -ObjectId $GroupObjectID.ObjectID
   
    if ($y2.ObjectID -in $members.ObjectID) {
        Write-Host $y.userPrincipalName'is already in the Group' -ForegroundColor Blue
    }else{
        Add-AzureADGroupMember -ObjectId $GroupObjectID.ObjectID -RefObjectId $y2.ObjectId -InformationAction SilentlyContinue
        Write-Host $y.userPrincipalName'has been added to the Group' -ForegroundColor Green
    }
   
}

#Disconnect Azure AD
Disconnect-AzureAD
