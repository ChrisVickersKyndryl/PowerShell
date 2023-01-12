# Gets the most recent user list from all domain controllers. This assumes that the user list is the same on all servers,
# but last Logon date may be different

#Create class of a user from AD
class User {
  [string]$dc = ""

  [string]$FirstName = ""
  [string]$LastName = ""
  [string]$DisplayName = ""
  [string]$EmailAddress = ""
  [string]$SID = ""
  [string]$DistinguishedName = ""
  [string]$Manager = ""
  [string]$ManagerDisplayName = ""
  [string]$ManagerEmail = ""
  [string]$LastLogonDate = ""
  
  [string]$Office = ""
  [string]$Title = ""
  [string]$logonCount = ""
  [string]$lastLogonTimestamp = ""
  [string]$Enabled = ""
  [string]$PasswordExpired = ""
  [string]$PasswordLastSet = ""
  [string]$PasswordNeverExpires = ""
  [string]$mail = ""
 
  [Int64]$lastLogon = 0
}

# All domain controllers
$global:dcs = @()

# List of dictionaries used to store the users from each domain controller
$global:allUsers = @{}

# Single list of all users, created from the multiple lists of users recieved from all servers
$global:condensedUsers = @{}

#Return a list of domain controllers
function Get-AllDomainControllers {
    # Get all domain controllers and export list
    Get-ADDomainController -Filter * | select hostname | Select-Object -first 2 | % {
        $global:dcs += $_.Hostname
    }
}

#Query a single domain controller and get all user data from it
function Get-UserFromSingleServer{
    param (
        $dc
    )

    # Create dictionary to store data
    $usersFromDC = @{}

    # Get all users from DC and add to list
    Get-ADUser -Server $dc -Filter * -Properties * | % {
        $ind = [User]::new()
        # Distinguished name is used as the Key in the dictionary
        $ind.DistinguishedName = $_.DistinguishedName

        #Standard values
        $ind.DisplayName = [string]$_.DisplayName
        $ind.FirstName = [string]$_.Name
        $ind.Sid = [string]$_.Sid
        $ind.Manager = [string]$_.Manager
        $ind.lastLogon = [Int64]$_.lastLogon
        $ind.LastLogonDate = [string]$_.LastLogonDate
        $ind.EmailAddress = [string]$_.EmailAddress
        $ind.dc = [string]$dc # Domain controller this value was taken from

        # Just added
        #$ind.Office = [string]$_.Office
        #$ind.Title = [string]$_.Title
        #$ind.logonCount = [string]$_.logonCount
        #$ind.lastLogonTimestamp = [string]$_.lastLogonTimestamp
        #$ind.Enabled = [string]$_.Enabled
        #$ind.PasswordExpired = [string]$_.PasswordExpired
        #$ind.PasswordLastSet = [string]$_.PasswordLastSet
        #$ind.PasswordNeverExpires = [string]$_.PasswordNeverExpires
        #$ind.mail = [string]$_.mail

        # Add the user to the main dictionary
        $usersFromDC.Add($ind.DistinguishedName, $ind)
    }

    # Add all users to the list of restuls
    $global:allUsers.Add($dc, $usersFromDC)
}

# Run a number of jobs in parallel to get all AD users values from all the domain controllers
function Get-UsersFromAllServers {
    # Go through each server and crate a job to get the information
    foreach ($dc in $global:dcs) {
        # Check connectivity to the server. If no connection, go to next server
        if (-Not (Test-Connection -ComputerName $dc -Quiet)) { continue }

        # Get users from each server
        Get-UserFromSingleServer -dc $dc
    }
}

# Combine all the records received from all the domain controllers and condense it to a single list of records
function Set-CondensedUser{
    # Go through each server
    foreach ($singleServer in $global:allUsers.Values)
    {
        # Go through each file from that server
        foreach ($usr in $singleServer.Values)
        {
            # If value doesnt exist add it
            if(-Not ($global:condensedUsers.ContainsKey($usr.DistinguishedName)))
            {
                # If the value doesnt exist, add it
                $global:condensedUsers.Add($usr.DistinguishedName, $usr)
                continue
            }

            # Check if the user data is more recent, if so, replace the current value
            if($condensedUsers[$usr.DistinguishedName].lastLogon -lt $usr.lastLogon)
            {
                $global:condensedUsers[$usr.DistinguishedName] = $usr.Value
            }
        }
    }
}

# Set the manager values by extracting them from the 
function Set-ManagerValues{
  # Popullate manager display name and email address
 

  # Go through each server
  foreach ($usr in $global:condensedUsers.Values)
  {
    # If the manager is null, set values to show no manager listed and then skip it 
    if ($usr.Manager -ne "") {
      $usr.ManagerDisplayName = "No manager listed"
      $usr.ManagerEmail = "No manager listed"
      continue 
    }

    # Check if manager exists
    if($global:condensedUsers.ContainsKey($usr.Manager))
    {
      # Get managers values
      $usr.ManagerDisplayName = $global:condensedUsers[$usr.Manager].DisplayName
      $usr.ManagerEmail = $global:condensedUsers[$usr.Manager].EmailAddress
    }
  }
}

# Check if module exists. If it does not, exit and return message
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) { return  "Module does not exist" }

# Get all the domain controllers
Get-AllDomainControllers

# Get the users from each domain controller
Get-UsersFromAllServers

# Combine the users into a summary file
Set-CondensedUser

# Set the manager name and email address
Set-ManagerValues

# Output CSV Value
$condensedUsers.Values | ConvertTo-csv -NoTypeInformation

# $condensedUsers.Values | ConvertTo-Json
