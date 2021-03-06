#requires -version 2

<#
.DESCRIPTION
I'll proceed with the presumption that you are installing on your own laptop with single machine configuration. So here is what you need to do:
1. Prepare 3 certificates (I suspect you can get away with 2)
2. Assign certificates to DataLoad and Index services ports
3. Add the needed configuration entries to the settings.txt
4. Install and check
 
.PARAMETER <Parameter_Name>
    All the parameters must be recorded in the settigns.txt
    
.INPUTS
    N/A
    
.OUTPUTS
   Report will be created upon successful completion of the script
  
.NOTES
  Version:        1.0
  Author:         Anjana Rupasinghege
  Creation Date:  01/10/2015
  Purpose/Change: Initial script development
  

#>


#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Create-Cert(){
Write-host 
Write-host "Creating a Certificate" -ForegroundColor Green
Write-host 
.\makecert.exe -r -pe -n "CN=127.0.0.1" -b $settings.StartDate -e $settings.EndDate -ss my -sr localMachine -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12
}


function Load-settings(){
  
    $al=Get-Content "C:\Temp\ACA_Https_Prerequisites\settings.txt"
    foreach ($s in $al)
    { 
        $settings.add($s.split("=")[0].trim(),$s.split("=")[1].trim())
    }
    return $settings

}



function Confirm-Proceed()
{

    do { $answer = Read-Host "Confirm to Proceed Y/N" } 
    until ("Y","N" -ccontains $answer)

        If ($answer -eq "N") {
            exit
        }

}




function Find-cert() 
{

$cert     =  Get-ChildItem -Path Cert:\localMachine\My | Where-Object {$_.Subject -eq "CN=127.0.0.1"};
$keyName  = (($cert.PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
$keyPath  = $env:ProgramData + "\Microsoft\Crypto\RSA\MachineKeys\"
$fullPath = $keyPath+$keyName

return  $fullPath

}




function Del-cert([string] $location)
{

$Thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\$location | Where-Object {$_.Subject -match "CN=127.0.0.1"}).Thumbprint -join ';';
$path = "cert:\LocalMachine\$location\"+$Thumbprint
Remove-Item -Path $path


}



function copy-cert([string] $destinationStore)
{


$SourceStoreScope = 'LocalMachine'
$SourceStorename = 'My'

$SourceStore = New-Object  -TypeName System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList $SourceStorename, $SourceStoreScope
$SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

$cert = $SourceStore.Certificates | Where-Object  -FilterScript {
    $_.subject -like '*127.0.0.1'
}



$DestStoreScope = 'LocalMachine'
$DestStoreName =  $destinationStore
Write-Host "Adding the Certificate to " $DestStoreName 
$DestStore = New-Object  -TypeName System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList $DestStoreName, $DestStoreScope
$DestStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$DestStore.Add($cert)

$SourceStore.Close()
$DestStore.Close()


    if ([bool](dir cert:\LocalMachine\$destinationStore | ? { $_.subject -EQ "cn=127.0.0.1" }))
    {
    Write-host "Successful..." -ForegroundColor Green
    }

}


function assign-cert-index ([string] $certhash)
{
$indexserviceport = $settings.indexserviceport
netsh http add sslcert ipport=0.0.0.0:$indexserviceport certhash=$certhash appid='{3ede281c-3156-4106-800f-e82579b768f7}'
}


function assign-cert-monitor ([string] $certhash)
{
$monitorport = $settings.monitorport
netsh  http add sslcert ipport=0.0.0.0:$monitorport certhash=$certhash appid='{c03c7ef6-6b71-420a-8d8f-a22be1cf4ac4}'
}


function check-sslcert([string] $port)
{

    if ([bool](netsh http show sslcert  ipport=0.0.0.0:$port | where {$_ -match ":$port"}))
    {

    Write-host
    Write-host "ERROR: IP:Port already exits for port $port"  -ForegroundColor Red 

    Write-host "Un-Register the sslcert and proceed [NOT RECOMMEDED]" -ForegroundColor Yellow

    Confirm-Proceed

    netsh http delete sslcert ipport=0.0.0.0:$port

     if ([bool](netsh http show sslcert  ipport=0.0.0.0:$port | where {$_ -match ":$port"}))
     {
        Write-host "ERROR: Cannot Un-Register  IP:Port"  -ForegroundColor Red 
        Write-host "Please contact your Administrator"  -ForegroundColor Red 
        Write-host "Unsuccessful!!!"  -ForegroundColor Yellow 
        exit
     }


    }


}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator [Elevated Command Prompt]!"
    Break
}



$settings = @{}

Write-host "Please Validate your setting" -ForegroundColor Green

Load-settings 

Write-host

Confirm-Proceed

Write-host

Write-host "Validating current configuration...." -ForegroundColor Green 

Write-host

if ([bool](dir cert:\LocalMachine\My | ? { $_.subject -EQ "cn=127.0.0.1" }))
{
Write-host
Write-host "ERROR: Certificate already exits in Personal Store CN=127.0.0.1"  -ForegroundColor Red 

Write-host "Delete the Certificate and proceed [NOT RECOMMEDED]" -ForegroundColor Yellow

Confirm-Proceed

Del-cert("My")

    if ([bool](dir cert:\LocalMachine\My | ? { $_.subject -EQ "cn=127.0.0.1" }))
    {
    Write-host "ERROR: Cannot Delete Certificate CN=127.0.0.1 | More than one certificate exists"  -ForegroundColor Red 
    Write-host "Please contact your Administrator"  -ForegroundColor Red 
     Write-host "Unsuccessful!!!"  -ForegroundColor Yellow 
     exit
    }

    Write-Host 
    Write-host "Certificate Deleted from Personal Store"  -ForegroundColor Green 

}


if ([bool](dir cert:\LocalMachine\root | ? { $_.subject -EQ "cn=127.0.0.1" }))
{
Write-host
Write-host "ERROR: Certificate already exits in Trusted Root Certification Authorities CN=127.0.0.1"  -ForegroundColor Red 

Write-host "Delete the Certificate and proceed [NOT RECOMMEDED]" -ForegroundColor Yellow

Confirm-Proceed

Del-cert("root")

    if ([bool](dir cert:\LocalMachine\root | ? { $_.subject -EQ "cn=127.0.0.1" }))
    {
    Write-host
    Write-host "ERROR: Cannot Delete Certificate CN=127.0.0.1 | More than one certificate exists"  -ForegroundColor Red 
    Write-host "Please contact your Administrator"  -ForegroundColor Red 
     Write-host "Unsuccessful!!!"  -ForegroundColor Yellow 
     exit
    }

    Write-Host 
    Write-host "Certificate Deleted from Trusted Root Certification Authorities"  -ForegroundColor Green 

}



if ([bool](dir cert:\LocalMachine\TrustedPeople | ? { $_.subject -EQ "cn=127.0.0.1" }))
{
Write-host
Write-host "ERROR: Certificate already exits in Trusted People CN=127.0.0.1"  -ForegroundColor Red 
Write-host "Delete the Certificate and proceed [NOT RECOMMEDED]" -ForegroundColor Yellow

Confirm-Proceed

Del-cert("TrustedPeople")

    if ([bool](dir cert:\LocalMachine\TrustedPeople | ? { $_.subject -EQ "cn=127.0.0.1" }))
    {
    Write-host "ERROR: Cannot Delete Certificate CN=127.0.0.1 | More than one certificate exists"  -ForegroundColor Red 
    Write-host "Please contact your Administrator"  -ForegroundColor Red 
     Write-host "Unsuccessful!!!"  -ForegroundColor Yellow 
     exit
    }

    Write-Host 
    Write-host "Certificate Deleted from Trusted People"  -ForegroundColor Green 

}


Create-Cert

$certPath = Find-cert
Write-host
Write-host "Set Permission for IIS_IUSES" -ForegroundColor Green 
Write-host 

icacls $certPath /grant "IIS_IUSRS:(R)"


Write-host 
Write-host "Copying Certificate" -ForegroundColor Green 
Write-host 

copy-cert("root")

Write-host

copy-cert("TrustedPeople")


$Thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -match "CN=127.0.0.1"}).Thumbprint -join ';';
Write-host
Write-host "Validating current SSL Certificates...." -ForegroundColor Green 
Write-host
check-sslcert($settings.indexserviceport)
check-sslcert($settings.monitorport)

Write-host
Write-host "Register the certificate Indexing service" -ForegroundColor Green
assign-cert-index($Thumbprint)

Write-host
Write-host "Register the certificate Data Load service" -ForegroundColor Green
assign-cert-monitor($Thumbprint)

###################################################################################
## Report 
Clear-Host
for ($i = 1; $i -le 100; $i++ ) {write-progress -activity "Generating Reports" -status "$i% Complete:" -percentcomplete $i;}

write-host ************************************************************ -ForegroundColor Green 
write-host * Deployment pre-requisites are successfully completed!!!   * -ForegroundColor Green
write-host ************************************************************ -ForegroundColor Green

write-host 
write-host 

$SourceStoreScope = 'LocalMachine'
$SourceStorename = 'My'

$SourceStore = New-Object  -TypeName System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList $SourceStorename, $SourceStoreScope
$SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

$cert = $SourceStore.Certificates | Where-Object  -FilterScript {
    $_.subject -like '*127.0.0.1'
}


Write-Host $cert 
Write-Host


Write-Host "IP port where Indexing service will be listening"
$port=$settings.monitorport
netsh http show sslcert  ipport=0.0.0.0:$port 

Write-Host
Write-Host

Write-Host "IP port where Data Load service will be listening" 
$port=$settings.indexserviceport
netsh http show sslcert  ipport=0.0.0.0:$port 

###################################################################################
Write-Host
Write-Host

write-host "################################################################################################"
write-host 
write-host "The following settings are need to get the deploy script to do a secure install"
write-host
write-host "communications.protocol		Https" -ForegroundColor Yellow
write-host 'website.certificate.name		${https.hostname}' -ForegroundColor Yellow
write-host "website.certificate.selfsigned		true" -ForegroundColor Yellow

write-host "intelligenceService.client.certificate.thumbprint		$Thumbprint" -ForegroundColor Yellow
write-host "intelligenceService.service.certificate.thumbprint		$Thumbprint" -ForegroundColor Yellow

write-host
write-host "Also, disable the start-up of the Batch Processing Agent with setting:" 
write-host
write-host "batchProcessingAgent.service.start		false" -ForegroundColor Yellow
write-host 
write-host "################################################################################################"