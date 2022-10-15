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
  # Get-ADUser -Filter "Name -eq 'ChewDavid'" -SearchBase "DC=AppNC" -Properties "mail" -Server lds.Fabrikam.com:50000
  # | Select-Object -Property SamAccountName,Enabled
}
