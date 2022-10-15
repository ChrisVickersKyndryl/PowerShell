
  # Get user that matches the folder name
  Get-ADUser -Filter "Name -eq '{{ user }}'" <#-SearchBase "DC=AppNC"#> |
  select lastLogon, EmailAddress, Enabled, UserPrincipleName
