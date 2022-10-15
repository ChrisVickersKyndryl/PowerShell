# Check if module exists
if (Get-Module -ListAvailable -Name ActiveDirectory) {
  # Get list variable
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
    Get-ADUser -Filter "Name -eq $i.name" -SearchBase "DC=AppNC" | foreach {
      $i.enabled = $_.Enabled
    
      # DELETES FILES IF THE USER IS DISABLED
      # if ($i.enabled -eq "False") {
      #   Remove-Item 'D:\temp\Test Folder' -Recurse
      #}
    }
  }
} 
else {
    Write-Host "Module does not exist"
}
