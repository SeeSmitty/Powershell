#Variables
$thumb = {"thumbprint"}
$client = {"clientID"}
$tenant = {"tenantID"}
$org = {"PrimaryDomain"}
$Certificate = Get-ChildItem Cert:\CurrentUser\My\$thumb

#connection Strings
Connect-ExchangeOnline -CertificateThumbPrint $thumb -AppID $client -Organization $org
Connect-Graph -TenantId $tenant -AppId $client -Certificate $Certificate

#region Email Template
function Send-FailMail {
    $to = "email@domain.com"
    $from = "FromEmail@domain.com"
    $bcc = $from
    $subject = "Employee Photo - $photo - Failed to Update"
    $type = "html"
    $template = "C:\temp\PhotoFailMail.html"
    $params = @{
	    Message = @{
		    Subject = $subject
		    Body = @{
			    ContentType = $type
			    Content = $template
		    }
		    ToRecipients = @(
			    @{
				    EmailAddress = @{
					    Address = $to
				    }
			    }
		    )
		    BccRecipients = @(
			    @{
				    EmailAddress = @{
					    Address = $bcc
				    }
			    }
		    )
	    }
	    SaveToSentItems = "true"
    }  

Send-MgUserMail -UserId $from -BodyParameter $params
}


#EndRegion Email Template

#establishes the file paths for initial and final photo locations
$path = "C:\Temp\PhotosToUpload"
$finalPath = "C:\Temp\PhotosUploaded"
$pathWrong = "C:\temp\PhotosWrong"


#gets all the photos that exist in the target directory
$photoName = (Get-ChildItem "$path*").Name

#Loops to resize, upload and move photos
foreach($photo in $photoName){
    try {
        #Declare variables
        $username = (Get-ChildItem "$path\$photo").basename
        $userId = get-mguser -ConsistencyLevel eventual -Filter "startsWith(Mail, '$username')" | Select-Object Id

        if ($null -ne $userId) {
            #update photo in Azure with new photo
            Set-MgUserPhotoContent -UserId $userId.Id -InFile "$Path\$username-resized.jpg"
            Write-Host "$username photo has been updated!"                       

            #move original photo to final resting place
            Move-Item -Path $path\$photo -Destination $finalPath -Force -Confirm:$false
        }else {
            #manage photos with misspelled usernames
            Move-Item -Path $path\$photo -Destination $pathWrong -Force -Confirm:$false
            Send-FailMail
        }
    }
    catch {
       Write-Host $Error
    }
}

Disconnect-Graph
Disconnect-ExchangeOnline -Confirm:$false