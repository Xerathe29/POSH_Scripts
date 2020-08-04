<#
 .NOTES
    Version : 1.0
    Author  : Sid Johnston
    Created : 04 August 2020

 .SYNOPSIS
  Sets a new certificate to host the Citrix Broker Service on Citrix Delivery Controllers via netsh.

 .DESCRIPTION
  Given that a valid certificate has been installed to the local certificate store and a netsh binding exists on local machine,
  this function wil gather relevant information, remove the old netsh bindings, and set up bindings for the new certificate.
  Finally, the Citrix Broker Service will be restarted to apply the changes.

#>
function Set-Citrix_DDC_Certs {
    
    $currentCerts = Get-ChildItem -Path Cert:\LocalMachine\My
    $currentCertHash = netsh http show sslcert
    $currentAppIDs = [System.Collections.ArrayList]@()
    $currentIPBindings = [System.Collections.ArrayList]@()

    foreach ($item in $currentCertHash) {
        if ($item -match "Application") {
            $currentAppIDs += ($item.substring(($item.indexof("{")),($item.length - ($item.indexof("{"))))).trim()
        }
        if ($item -match "IP:Port") {
            $currentIPBindings += ($item.substring(($item.indexof(": ") + 1),($item.length - ($item.indexof(": ") + 1 )))).trim()
        }
    }

    foreach ($IP in $currentIPBindings) {
        netsh http delete sslcert ipport=($IP)
    }

    $index = $currentAppIDs.count
    $newCertHash = $currentCerts | Sort-Object -Property NotAfter | Select-Object -Last 1

    for ($i = 0; $i -lt $index; $i++) {
        netsh http add sslcert ipport=($currentIPBindings[$i]) certhash=($newCertHash.Thumbprint) appid="$($currentAppIDs[$i])"
    }

    Restart-Service "Citrix Broker Service"
    do {
        Start-Sleep -Seconds 5
        $BrokerService = Get-Service "Citrix Broker Service"
    } until ($BrokerService.Status -eq "Running")

}