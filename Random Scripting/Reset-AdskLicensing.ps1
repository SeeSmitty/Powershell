<#
.SYNOPSIS
Uses the built in autodesk licensing tool to dynamically change the license to USER. This script now focuses on dynamically searching for 
all the products on the machine, and updating them to the correct license type.

.NOTES
Version 2.0
Written By: Curtis Smith

.LINK
Blog Post
https://seesmitty.com/how-to-dynamically-change-autodesk-license-type-with-powershell

Autodesk Documentation
https://knowledge.autodesk.com/support/autocad/learn-explore/caas/sfdcarticles/sfdcarticles/Use-Installer-Helper.html
#>

#required first step, starts by removing their current login state from the Desktop App
Get-ChildItem "$env:localappdata\Autodesk\Web Services\LoginState.xml" -ErrorAction SilentlyContinue | Remove-Item -Force 


#Function to reset the license model for each item in the list
function Reset-AdskCloudLicense($ar) {
    Start-Process -FilePath "${env:ProgramFiles(x86)}\Common Files\Autodesk Shared\AdskLicensing\Current\helper\AdskLicensingInstHelper.exe" -ArgumentList $ar | Out-Null
}

#set the location so we can run the file to get the list of products on the machine 
Set-Location "${env:ProgramFiles(x86)}\Common Files\Autodesk Shared\AdskLicensing\Current\helper\"
$list =  .\AdskLicensingInstHelper.exe list


#select the string to pull the keys out of the text that is generated
$Key = $list | Select-String def_prod_key
$key = foreach($l in $key){([String]$l).Trim('"def_prod_key": ')}
$key = foreach($l in $key){([String]$l).Trim('",')}

#select the string to pull the version out of the text that is generated
$ver = $list | Select-String def_prod_ver
$ver = foreach($l in $ver){([String]$l).Trim('"def_prod_ver": ')}
$ver = foreach($l in $ver){([String]$l).Trim('",')}

#creates a datatable to make it easier to process and parse the data
$Actiontable = New-Object System.Data.DataTable
$Actiontable.Columns.Add("def_prod_key", "System.String")
$Actiontable.Columns.Add("def_prod_ver", "System.String")

#adds a new key to the datatable while also adding the cooresponding version 
#it is incremented by one each time the loop is ran
#confirmation that the keys & versions are still lined up can be found with this command: $list | Select-String def_prod_key,def_prod_ver
$x = 0
foreach($k in $key){
    $arow = $Actiontable.NewRow()
    $arow.def_prod_key = $k
    $arow.def_prod_ver = $ver.split()[$x]
    $Actiontable.Rows.Add($aRow)
    $x += 1
}

#creates the final array of arguments we will use in the actual license type reset
#Should be one of (case insensitive): USER, STANDALONE, NETWORK or empty "" to reset LGS
$finalArray = @()
foreach($a in $Actiontable){
    $prodkey = $a.def_prod_key
    $prodVer = $a.def_prod_ver
    $finalArray += "change -pk $prodKey -pv $prodVer -lm USER"
}

#applys the actual reset
foreach($final in $finalArray){
    Reset-AdskCloudLicense -ar $final
}


#cleans up the license folder once all is said and done to remove any unwanted license items. 
#Primarily for Autodesk 2019 and older products
Get-ChildItem "$env:ProgramData\Autodesk\CLM\LGS" | Remove-Item -Recurse -Force
