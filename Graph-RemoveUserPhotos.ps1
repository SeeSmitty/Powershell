#Variables
$thumb = {"thumbprint"}
$client = {"clientID"}
$tenant = {"tenantID"}
$org = {"PrimaryDomain"}
$Certificate = Get-ChildItem Cert:\CurrentUser\My\$thumb

#connection Strings
Connect-ExchangeOnline -CertificateThumbPrint $thumb -AppID $client -Organization $org
Connect-Graph -TenantId $tenant -AppId $client -Certificate $Certificate

#Used to remove photos via the same import method used to upload photos
function Remove-PhotosDirectory {
    $finalPath = "C:\temp\PicturesFinal"
    $names = (Get-ChildItem -Path $finalPath).BaseName
    foreach($n in $names){
        $username = get-mguser -ConsistencyLevel eventual -Filter "startsWith(Mail, '$n')"
        Remove-UserPhoto -Identity $username.UserPrincipalName  -ClearMailboxPhotoRecord -Confirm:$false
        Write-Host "Removed photo for" $username.DisplayName
    }
    
}


#Used to Remove photos in bulk from a CSV List
function Remove-PhotosCSV {
    $users = Import-csv "C:\temp\removephotos.csv"  
    foreach($u in $users){
        $u2 = $u.username
        $username = get-mguser -ConsistencyLevel eventual -Filter "startsWith(Mail, '$u2')"
        Remove-UserPhoto -Identity $username.UserPrincipalName  -ClearMailboxPhotoRecord -Confirm:$false
        Write-Host "Removed photo for" $username.DisplayName
    }
}

#Uncomment the version you want to use
#Remove-PhotosCSV
#Remove-PhotosDirectory


Disconnect-Graph
Disconnect-ExchangeOnline -Confirm:$false
