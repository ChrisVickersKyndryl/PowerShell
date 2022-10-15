#https://www.jonathanmedd.net/2019/07/returning-data-from-powershell-scripts-to-be-consumed-by-ansible-playbooks.html

# Check if module exists
if (Get-Module -ListAvailable -Name ActiveDirectory) {
  # List of folders with user details
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
    # Delete deactivated users
    Get-ADUser -Filter "Name -eq $i.name" -SearchBase "DC=AppNC" | foreach {
      $i.enabled = $_.Enabled
      $i.email = $_.Email
      $i.name = $_.Name
    
      # DELETES FILES IF THE USER IS DISABLED
      # if ($i.enabled -eq "False") {
      #   Remove-Item 'D:\temp\Test Folder' -Recurse
      #}
    }
    
    # Check if folder is too large
    $i.too_large = ($i.size -lt 20000000) ? "True" : "False"
  }
  
  
} 
else {
    Write-Host "Module does not exist"
}
