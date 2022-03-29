
#connect to azure ad
Connect-AzureAD

#import a CSv with the list of users to be added to the group
$list = Import-Csv "C:\Users\SeeSmitty\Downloads\UserList.csv"
#Name of the group being added
$group = "All Employees"


#get the object ID from Azure
$GroupObjectID = Get-AzureADGroup -SearchString $group | Select -Property ObjectID


#roll through the list to look up each user and add to the group. 
foreach ($y in $list){
    $y2 = Get-AzureADUser -ObjectId $y.userPrincipalName | Select -Property ObjectID
    try {
        Add-AzureADGroupMember -ObjectId $GroupObjectID.ObjectID -RefObjectId $y2.ObjectId -InformationAction SilentlyContinue
    }
    catch {
        Write-Host $y.userPrincipalName "is already a member"
    }
}

#Disconnect Azure AD
Disconnect-AzureAD
