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

  [Int64]$lastLogon = 0
}

# All domain controllers
$dcs = @()

# List of dictionaries used to store the users from each domain controller
$allUsers = @{}

# Single list of all users, created from the multiple lists of users recieved from all servers
$condensedUsers = @{}

# Create credentials to run the command as. Username and password - THESE ARE REPLACED IN ANSIBLE
$username = '$USERNAME$'
$password = ConvertTo-SecureString -String '$PASSWORD$' -AsPlainText -Force


#Return a list of domain controllers
function Get-AllDomainControllers {
    # Create user credential to run command as
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $password

    # Get all domain controllers and export list
    Get-ADDomainController -Filter * -Credential $credential | select hostname | % {
        $dcs += $_.Hostname
    }
}

#Query a single domain controller and get all user data from it
function Get-UserFromSingleServer{
    param (
        $dc
    )

    # Create dictionary to store data
    $usersFromDC = @{}

    # Create user credential to run command as
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $password

    # Get all users from DC and add to list
    Get-ADUser -Server $dc -Filter * -Credential $credential -Properties * | % {
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
        $ind.EmailAddress = $_.EmailAddress
        $ind.dc = $dc # Domain controller this value was taken from

        # Add the user to the main dictionary
        $usersFromDC.Add($ind.DistinguishedName, $ind)
    }

    # Add all users to the list of restuls
    $allUsers.Add($dc, $usersFromDC)
}

# Run a number of jobs in parallel to get all AD users values from all the domain controllers
function Get-UsersFromAllServers {
    # Go through each server and crate a job to get the information
    foreach ($dc in $dcs) {
        # Check connectivity to the server. If no connection, go to next server
        if (-Not (Test-Connection -ComputerName $dc -Quiet)) { continue }

        # Create job to get details
        start-job -ScriptBlock {
            #Run the job to get a single server
            Get-UserFromSingleServer -dc $dc
        } | Out-Null
    }

    # Wait 10 seconds to ensure that all jobs have started
    # sleep 10

    # Wait for all jobs to finish
    Get-Job | Wait-Job | Out-Null
}

# Combine all the records received from all the domain controllers and condense it to a single list of records
function Set-CondensedUser{
    # Go through each server
    foreach ($singleServer in $allUsers.Values)
    {
        # Go through each file from that server
        foreach ($usr in $singleServer.Values)
        {
            # If value doesnt exist add it
            if(-Not ($condensedUsers.ContainsKey($usr.DistinguishedName)))
            {
                # If the value doesnt exist, add it
                $condensedUsers.Add($usr.DistinguishedName, $usr)
                continue
            }

            # Check if the user data is more recent, if so, replace the current value
            if($condensedUsers[$usr.DistinguishedName].lastLogon -lt $usr.lastLogon)
            {
                $condensedUsers[$usr.DistinguishedName] = $usr.Value
            }
        }
    }
}

# Set the manager values by extracting them from the 
function Set-ManagerValues{
  # Popullate manager display name and email address
  # Go through each server
  foreach ($usr in $condensedUsers.Values)
  {
    #$usr | ConvertTo-Json

    # Check if manager exists
    if($condensedUsers.ContainsKey($usr.Manager))
    {
      # Get managers values
      $usr.ManagerDisplayName = $condensedUsers[$usr.Manager].DisplayName
      $usr.ManagerEmail = $condensedUsers[$usr.Manager].EmailAddress
    }
  }
}

# Check if module exists. If it does not, exit and return message
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) { return  "Module does not exist" }

# Get all the domain controllers
Get-AllDomainControllers

# Get the users from each domain controller
Get-UsersFromAllServers

# Write-Host "Number of values"
# Write-Host $allUsers.Count

#$allUsers | ConvertTo-Json

#foreach ($server in $allUsers.Values)
#{
#  $server.Values | ConvertTo-Json
#  
#  foreach ($rec in $server.Values)
#  {
#    Write-Host $rec.DistinguishedName
#  }  
#}

# Combine the users into a summary file
Set-CondensedUser

# Set the manager name and email address
Set-ManagerValues

# Output CSV Value
$condensedUsers.Values | ConvertTo-csv -NoTypeInformation

$condensedUsers.Values | ConvertTo-Json
