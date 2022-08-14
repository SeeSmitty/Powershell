#Details on usage of this script located here: https://seesmitty.com/how-to-use-microsoft-graph-powershell-sdk/

#Details to get you connected to Azure Tenant
$client = '{cliendId}'
$tenant = '{tenantID}'
$Certificate = Get-ChildItem Cert:\CurrentUser\My\('thumbprint for self-signed cert'}
Connect-Graph -TenantId $tenant -AppId $client -Certificate $Certificate


#import a CSv with the list of users to be added to the group
$users = Import-Csv "%pathToFile%\FileName.csv"
#Name of the group being added
$group = "Group Display Name Here"


#Get the ObjectID for the group in question
$GroupObjectID = Get-MgGroup -Search "DisplayName:$group" -ConsistencyLevel eventual | select-object Id,DisplayName

#Loop to confirm everyone in the list is added to the group
ForEach ($u in $users) {
    $members = Get-MgGroupMember -GroupId $GroupObjectID.Id
    $u2 = Get-MgUser -UserId $u.userPrincipalName | select Id

    #Check if user is a member; add if they are not
    If ($u2.Id -in $members.id) {
        Write-Host $u.userPrincipalName"is already in the group" -ForegroundColor Blue
    }Else{
        New-MgGroupMember -GroupId $GroupObjectID.Id -DirectoryObjectId $u2.Id
        Write-Host $u.userPrincipalName"has been added to the group" -ForegroundColor Green

    }
}

Disconnect-Graph
