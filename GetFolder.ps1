#https://www.jonathanmedd.net/2019/07/returning-data-from-powershell-scripts-to-be-consumed-by-ansible-playbooks.html

# List of folders with user details
$listOfObj = New-Object -TypeName 'System.Collections.ArrayList';

# Max size of folder
$maxSize = 20000000

#Excluded folders
$excludedFolders = @(
  "All Users",
  # "Administrator",
  "Default",
  "Public",
  "Default User"
)

# Set
$cutoffDate = $(Get-Date -Date "2020-01-01T00:00:00")
echo $cutoffDate

#Get date time now as unix seconds
$timeNow = ([DateTimeOffset]$(Get-Date)).ToUnixTimeSeconds()
echo $timeNow

$secondsPast = ([DateTimeOffset]$(Get-Date).AddMonths(-2)).ToUnixTimeSeconds()
echo $secondsPast

if($timeNow -lt $secondsPast)
{
  echo "Was bigger"
}
else
{
  echo "Was not bigger"
}

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

# Loop through list of folders
foreach ($i in $listOfObj) {
  # Get user that matches the folder name
  Get-ADUser -Filter "Name -eq '$($i.folderName)'" -Properties * <#-SearchBase "DC=AppNC"#> | % {
    $i.enabled = $_.Enabled
    $i.emailAddress = $_.mail
    $i.lastLogonDate = [string]$_.lastLogonDate
    $i.lastLogonDateDateObject = $_.lastLogonDate
    $i.lastLogonTimestamp = $_.lastLogonTimestamp
  }
    
  # DELETES FILES IF THE USER IS DISABLED AND LAST LOGGED ON LONGER THAN 2 MONTHS AGO
  # if ($i.lastLogonTimestamp - lt ([DateTimeOffset]$(Get-Date).AddMonths(-2)).ToUnixTimeSeconds() ) -and
  # ($i.enabled -eq "False") {
  #   Remove-Item 'D:\temp\Test Folder' -Recurse
  # }
    
  # Check if folder is too large
  if($i.folderSize -gt $maxSize)
    { $i.too_large = "True" }
  else
    { $i.too_large = "False" }
}

# Output response as json
$vmJson = $listOfObj | ConvertTo-Json
Write-Output $vmJson
