# Folder list
$listOfObj = New-Object -TypeName 'System.Collections.ArrayList';

# Get folder size and output as a table
gci -force 'C:\Users'-ErrorAction SilentlyContinue | ? { $_ -is [io.directoryinfo] } | % {
  $len = 0
  gci -recurse -force $_.fullname -ErrorAction SilentlyContinue | % { $len += $_.length }
  $folder = @{}
  $folder.name = $_.name
  $folder.fullname = $_.fullname
  $folder.size = $len
  [void]$listOfObj.Add($folder)
}

foreach ($i in $array){
  Get-ADUser -Filter "Name -eq $i.name" -SearchBase "DC=AppNC" | foreach { $i.enabled = $_.Enabled }
}

echo $listOfObj

# Get user details for each folder
for($i=1; $i -lt $listOfObj.Count; $i++) {
  Get-ADUser -Filter "Name -eq $listOfObj[i].name" -SearchBase "DC=AppNC" | foreach { $listOfObj[i].enabled = $_.Enabled }
}

$person = @{}
$person.city = 'Austin'
$person.state = 'TX'

$listOfObj.Add($person)

echo $listOfObj[0].city


# Get folder size and output as a table
$list = New-Object Collections.Generic.List[string]
gci -force 'C:\Users'-ErrorAction SilentlyContinue | ? { $_ -is [io.directoryinfo] } | % {
  $len = 0
  gci -recurse -force $_.fullname -ErrorAction SilentlyContinue | % { $len += $_.length }
  $list.Add([string]$len)
  $list.Add($_.fullname) 
  $list.Add($_.name) 
}
$list | Format-Wide -Property {$_} -Column 3 -Force

# echo $list.Count

# Get user details for each folder
for($i=2; $i -lt $list.Count; $i+=3) {
  echo $list[$i]
  # Name probably needs to be changed
  # Get-ADUser -Filter "Name -eq 'ChewDavid'" -SearchBase "DC=AppNC" | foreach { $_.Enabled }
  # | Select-Object -Property SamAccountName,Enabled
  # | foreach { $_.Name }
}
