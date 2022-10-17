#https://www.jonathanmedd.net/2019/07/returning-data-from-powershell-scripts-to-be-consumed-by-ansible-playbooks.html

# Check if module exists. If it does not, exit and return message
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) { return  "Module does not exist" }

# List of folders with user details
$listOfObj = New-Object -TypeName 'System.Collections.ArrayList';

# Max size of folder
$maxSize = 20000000

#Excluded folders. These folders will not be checked
$excludedFolders = @(
  "All Users",
  "Administrator",
  "Default",
  "Public",
  "Default User"
)

# This gets the current time as a string that can be compared to the time returned from AD
$dateTwoMonthsAgo = ((Get-Date).AddMonths(-2)).tofiletime()
echo $dateTwoMonthsAgo

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
  Get-ADUser -Filter "SamAccountName -eq '$($i.folderName)'" -Properties * <#-SearchBase "DC=AppNC"#> | % {
    $i.enabled = $_.Enabled
    $i.emailAddress = $_.mail
    $i.lastLogonDate = [string]$_.lastLogonDate
    # $i.lastLogonDateUnixTimeSeconds = $_.lastLogonDate.ToUnixTimeSeconds()
    $i.lastLogonTimestamp = $_.lastLogonTimestamp
    $i.too_large = "False"
  }
    
  # DELETES FILES IF THE USER IS DISABLED AND HAS NOT LOGGED ON IN TWO MONTHS
  # - Checks if last logon was longer than 2 months ago
  # - Checks last logon is not null (a number)
  # - Checks enabled is "False"
  if (($i.lastLogonTimestamp -lt $dateTwoMonthsAgo ) -and ($i.lastLogonTimestamp -eq $null) -and ($i.enabled -eq "False")) {
    # Remove - Item '$($i.fullAddress)' -Recurse
    Write-Host -NoNewline "Not to clear :" $i.folderName   
  }
  else
  {
       Write-Host -NoNewline "Clear :" $i.folderName  
  }
    
  # Check if folder is too large
  if($i.folderSize -gt $maxSize) { $i.too_large = "True" }
}

# Output response as json
# https://www.jonathanmedd.net/2019/07/returning-data-from-powershell-scripts-to-be-consumed-by-ansible-playbook
$vmJson = $listOfObj | ConvertTo-Json
Write-Output $vmJson
