$CertName = "newcert.contoso.com"
$CSRPath = "c:\temp\$($CertName)_.csr"
$INFPath = "c:\temp\$($CertName)_.inf"
$Signature = '$Windows NT$' 
$INF =
@"
[Version]
Signature= "$Signature" 
[NewRequest]
Subject = "CN=$CertName, OU=Contoso East Division, O=Contoso Inc, L=Boston, S=Massachusetts, C=US"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = False
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0
[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1 
"@

$INF | out-file -filepath $INFPath -force
certreq -new $INFPath $CSRPath

Write-Host $(Get-Content -Path $CSRPath)

Remove-Item $INFPath
Remove-Item $CSRPath
