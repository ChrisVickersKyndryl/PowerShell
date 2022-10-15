#https://www.jonathanmedd.net/2019/07/returning-data-from-powershell-scripts-to-be-consumed-by-ansible-playbooks.html

# List of folders with user details
$listOfObj = New-Object -TypeName 'System.Collections.ArrayList';

# Max size of folder
$maxSize = 20000000

#Excluded folders
$excludedFolders = @(
  "All Users",
  "Administrator",
  "Default",
  "Public",
  "Default User"
)

# Check if module exists. If it does not, exit
if (!(Get-Module -ListAvailable -Name ActiveDirectory))
{
  Write-Host "Module does not exist"
  return
}

# Get folder size and name
gci -force 'C:\Users'-ErrorAction SilentlyContinue |
Where-Object { $_.Name -notin $excludedFolders } |
? { $_ -is [io.directoryinfo] } | % {
  $len = 0
  gci -recurse -force $_.fullname -ErrorAction SilentlyContinue | % { $len += $_.length }
  $folder = @{}
  $folder.folderName = $_.Name
  $folder.Name = $_.Name
  $folder.fullAddress = $_.fullname
  $folder.folderSize = $len
  [void]$listOfObj.Add($folder)
}

echo $listOfObj

# Loop through list of folders
foreach ($i in $array) {
  # Get user that matches the folder name
  Get-ADUser -Filter "Name -eq $i.folderName" <#-SearchBase "DC=AppNC"#> | foreach {
    $i.enabled = $_.Enabled
    $i.emailAddress = $_.EmailAddress
    $i.lastLogonDate = $_.LastLogonDate
    $i.name = $_.Name
  }
    
  # DELETES FILES IF THE USER IS DISABLED
  # if ($i.enabled -eq "False") {
  #   Remove-Item 'D:\temp\Test Folder' -Recurse
  #}
    
  # Check if folder is too large
  if($i.folderSize -gt $maxSize)
    { $i.too_large = "True" }
  else
    { $i.too_large = "False" }
}

# Output response as json
$vmJson = $listOfObj | ConvertTo-Json
Write-Output $vmJson
