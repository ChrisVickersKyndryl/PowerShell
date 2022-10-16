#https://www.jonathanmedd.net/2019/07/returning-data-from-powershell-scripts-to-be-consumed-by-ansible-playbooks.html

# Check if module exists. If it does not, exit
if (!(Get-Module -ListAvailable -Name ActiveDirectory))
{
  Write-Host "Module does not exist"
  return
}

# List of folders with user details
$listOfObj = New-Object -TypeName 'System.Collections.ArrayList';

# Max size of folder
$maxSize = 20000000

#Excluded folders. These folders will not be checked
$excludedFolders = @(
  "All Users",
  # "Administrator",
  "Default",
  "Public",
  "Default User"
)

# This gets the current time as a string that can be compared to the time returned from AD
$dateTwoMonthsAgo = ((Get-Date).AddMonths(-2)).tofiletime()

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

# Loop through list of folders
foreach ($i in $listOfObj) {
  # Get user that matches the folder name
  Get-ADUser -Filter "Name -eq '$($i.folderName)'" -Properties * <#-SearchBase "DC=AppNC"#> | % {
    $i.enabled = $_.Enabled
    $i.emailAddress = $_.mail
    $i.lastLogonDate = [string]$_.lastLogonDate
    # $i.lastLogonDateUnixTimeSeconds = $_.lastLogonDate.ToUnixTimeSeconds()
    $i.lastLogonTimestamp = $_.lastLogonTimestamp
  }
    
  # DELETES FILES IF THE USER IS DISABLED AND HAS NOT LOGGED ON IN TWO MONTHS
  #
  # if ($i.lastLogonTimestamp -lt $dateTwoMonthsAgo ) -and
  # ($i.enabled -eq "False") {
  #   Remove-Item '$($folder.fullAddress)' -Recurse
  # }
    
  # Check if folder is too large
  if($i.folderSize -gt $maxSize)
    { $i.too_large = "True" }
  else
    { $i.too_large = "False" }
}

# Empty recycle bin

# Output response as json
$vmJson = $listOfObj | ConvertTo-Json
Write-Output $vmJson
