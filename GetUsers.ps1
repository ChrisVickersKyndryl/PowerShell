# Gets the most recent user list from all domain controllers. This assumes that the user list is the same on all servers,
# but last Logon date may be different

# This script can be sped up using parrallel jobs, however that is currently outside the scope of this project
# https://stackoverflow.com/questions/4016451/can-powershell-run-commands-in-parallel

#Create class of a user from AD
class User {
  [string]$dc = ""

  [string]$FirstName = ""
  [string]$LastName = ""
  [string]$DisplayName = ""
  [string]$SID = ""
  [string]$DistinguishedName = ""
  [string]$Manager = ""
  [string]$ManagerDisplayName = ""
  [string]$ManagerEmail = ""
  [string]$LastLogonDate = ""

  [Int64]$lastLogon = 0
}

# Create credentials to run the command as. Username and password - THESE ARE REPLACED IN ANSIBLE
$username = '$USERNAME$'
$password = ConvertTo-SecureString -String '$PASSWORD$' -AsPlainText -Force

# All domain controllers
$dcs = @()

# List of dictionaries used to store the users from each domain controller
$allUsers = @()

# Single list of all users, created from the multiple lists of users recieved from all servers
$condensedUsers = New-Object System.Collections.Generic.Dictionary"[String,User]"

# Check if module exists. If it does not, exit and return message
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) { return  "Module does not exist" }

function Get-AllDomainControllers {
    # Create credential to run the Get-ADUser command as.
    $credGetDcs = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $password

    # Get all domain controllers and export list
    $dcs = @()
    Get-ADDomainController -Filter * -Credential $credGetDcs | select hostname | % {
        $dcs += $_.Hostname
    }
    return $dcs
}

function Get-UsersFromAllServers {
    param (
        $dcs
    )
    $allUsers = @{}
    foreach ($dc in $dcs) {
        # Check connectivity to the server. If no connection, go to next server
        if (-Not (Test-Connection -ComputerName $dc -Quiet)) { continue }

        # Create dictionary to store data
        $usersFromDC = @{}

        # Create credential to run the Get-ADUser command as.
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $password

        # Get all users from DC and add to list
        Get-ADUser -Server $dc -Filter * -Credential $credential | Select-Object -Property * | % {
            $ind = [User]::new()
            # Distinguished name is used as the Key in the dictionary
            $ind.DistinguishedName = $_.DistinguishedName

            #Standard values
            $ind.DisplayName = $_.DisplayName
            $ind.FirstName = $_.Name
            $ind.Sid = $_.Sid
            $ind.Manager = $_.Manager
            $ind.lastLogon = [Int64]$_.lastLogon
            $ind.LastLogonDate = $_.LastLogonDate

            # Domain controller this value was taken from
            $ind.dc = $dc

            # Add the user to the main dictionary
            $usersFromDC.Add($ind.DistinguishedName, $ind)
        }

        # Add all users to the list of restuls
        $allUsers.Add($dc, $usersFromDC)
    }
    return $allUsers
}

function Set-CondensedUser{
    param (
        $allUsers
    )

    # Create a summary list of all users
    $condensedUsers = @{}

    # Go through each server
    foreach ($singleServer in $allUsers.GetEnumerator())
    {
        # Go through each file from that server
        foreach ($usr in $singleServer.GetEnumerator())
        {
            # If value doesnt exist add it
            if(-Not ($condensedUsers.ContainsKey($usr.DistinguishedName)))
            {
                # If the value doesnt exist, add it
                $condensedUsers.Add($usr.DistinguishedName, $usr.Value)
                continue
            }

            # Check if the user data is more recent, if so, replace the current value
            if($condensedUsers[$usr.DistinguishedName].lastLogon -lt $usr.lastLogon)
            {
                $condensedUsers[$usr.DistinguishedName] = $usr.Value
            }
        }
    }

    return $condensedUsers
}

# Set the manager values by extracting them from the 
function Set-ManagerValues{
  # Popullate manager display name and email address
  # Go through each server
  foreach ($usr in $condensedUsers.GetEnumerator())
  {
    # Check if manager exists
    if($condensedUsers.ContainsKey($usr.Manager))
    {
      Write-Host $usr.Manager
      # Get managers values
      $usr.ManagerDisplayName = $condensedUsers[$usr.Manager].DisplayName
      $usr.ManagerEmail = $condensedUsers[$usr.Manager].EmailAddress
    }
  }
}

# Get all the domain controllers
$dcs = Get-AllDomainControllers

# Get the users from each domain controller
$allUsers = Get-UsersFromAllServers -dcs $dcs

Write-Host "Number of values"
Write-Host $allUsers.Count

#Combine the users into a summary file
$condensedUsers = Set-CondensedUser -allUsers $allUsers

# Set the manager name and email address
Set-ManagerValues

# Output CSV Value
($dict.Values  | ConvertTo-csv -NoTypeInformation)

