<#
.SYNOPSIS
This script uploads photos to Azure AD for user accounts, and sends an email for any failed uploads.

.DESCRIPTION
This script uploads photos to Azure AD for user accounts, and sends an email for any failed uploads. It is important to note
that these photos should already match the appropriate size and aspect ratio prior to being uploaded to ensure they don't look 
warped after being uploaded. 

This script assumes you are using certificate based authentication, though it could be modified to use any other authentication
as needed according to your preferences. 

Also, This script works on the assumption that user photos in a directory are named with the username (or samAccountName) 
of the person for whom the photo was taken.

.LINK
https://seesmitty.com/how-to-update-user-photos-in-azure-ad-with-powershell/

.NOTES
Author: Smitty
Date: 8/22/2022
Version: 1.1.0

#>

#Variables
$thumb = {"thumbprint"}
$client = {"clientID"}
$tenant = {"tenantID"}
$Certificate = Get-ChildItem Cert:\CurrentUser\My\$thumb

#connection Strings
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