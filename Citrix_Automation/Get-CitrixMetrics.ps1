<#

Gathers connection & session API data from specified Ctrix Delivery Controllers and outputs the results to the console
            
    Version : 1.0
    Author  : Eshton Brogan & Sid Johnston
    Created : 08 June 2020

 .Synopsis
  Placeholder

 .Description
  Placeholder

 .Parameter X
  Placeholder

 .Example
  Placeholder

 .Example
  Placeholder

 .Example
  Placeholder
#>

function Get-CitrixMetrics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    begin {
        $nl = [Environment]::NewLine
        $error.Clear()
        $ErrorActionPreference = "Continue"
        function Set-HostFile {
            param (
                # Host IP
                [Parameter(Mandatory = $true)]
                [String]
                $IPaddr,
                # Hostname
                [Parameter(Mandatory = $true)]
                [String]
                $Hostname,
                # Check only for a hostname match
                [Parameter(Mandatory = $false)]
                [bool]
                $CheckOnlyHost = $false
            )
            # Set host file path and pull current host file.
            $hostFilePath = "$($env:windir)\system32\Drivers\etc\hosts"
            $hostFile = Get-Content $hostFilePath
            # Regex pattern initialization.
            $escapedHostName = [regex]::Escape($Hostname)
            $regPattern = if ($CheckOnlyHost) { ".*\s+$escapedHostName.*" } else { ".*$IPaddr\s+$escapedHostName.*" }
            # Match on Regex above and add host entries to current host file if required.
            if (($hostFile) -match $regPattern) {
                Write-Host $IPaddr.PadRight( 20, " " ) "$Hostname - not adding; already in hosts file" -ForegroundColor Red
            } else {
                Write-Host $IPaddr.PadRight( 20, " " ) "$Hostname - adding to hosts file..." -ForegroundColor Green -NoNewline
                Add-Content -Encoding UTF8 $hostFilePath ("$IPaddr".PadRight( 20, " " ) + "$Hostname" )
                Write-Host " done" -ForegroundColor Green
            }
        }

        $sites = ("Site Label 1", "Site Label 2")
        $metrics = @{}

        foreach ($site in $sites) {
            $metrics += @{
                $site = @{
                    Total_Connections_Last_24_HRS = ""
                    Total_Connections_Last_7_DAYS = ""
                    Peak_Sessions_Last_24_HRS = ""
                    Active_Sessions = ""
                }
            }
        }

        # Ensure hosts file is configured for connections to Delivery Controllers.
        Write-Host "======Validating host file entries for Delivery Controllers======" -ForegroundColor Cyan
        Set-HostFile -IPaddr "10.10.10.1" -Hostname "Site1DDC.FQDN"
        Set-HostFile -IPaddr "10.10.11.1" -Hostname "Site2DDC.FQDN"
        $nl
        # Set up DDC targets.
        $ddc01 = "Site1ddc.FQDN"
        $ddc02 = "Site2ddc.FQDN"
        $_ddcs = @($ddc01,$ddc02)
    }

    process {
        foreach ($ddc in $_ddcs) {
            
            Try {
                Write-Host "Testing that $ddc is online."
                Test-Connection -ComputerName $ddc -Count 1 -ErrorAction Stop | Out-Null

                Try {
                    $asp = ($ddc).Remove(5)
                    # Gathering raw API data from DDC
                    $sessionSum = Invoke-RestMethod -Uri "http://$ddc/Citrix/Monitor/OData/v1/Data/SessionActivitySummaries" -Credential $Credential -ErrorAction Stop
                    $connections = Invoke-RestMethod -Uri "http://$ddc/Citrix/Monitor/OData/v1/Data/Connections" -Credential $Credential -ErrorAction Stop
                    $sessions = Invoke-RestMethod -Uri "http://$ddc/Citrix/Monitor/OData/v1/Data/Sessions" -Credential $Credential -ErrorAction Stop
                    # Date formatting
                    $currentDate = Get-Date -Format "yyyy-MM-dd"
                    $currentDate = -join($currentDate, "*")
                    $lastWeek = (Get-Date).AddDays(-7)
                    $lastWeek = $lastWeek.ToString('yyyy-MM-dd')
                    $lastWeek = -join($lastWeek, "*")
                    $last24Hours = (Get-Date).AddHours(-24)
                    $last24Hours = $last24Hours.ToString('yyyy-MM-ddTHH')
                    $last24Hours = -join($last24Hours, "*")
                    # Extracting connection data over 24hour/7day
                    $connectionDate24 = $connections.Content.Properties | Where-Object { $_.LogonStartDate.InnerText -ge $last24Hours }
                    $connectionDateWeek = $connections.Content.Properties | Where-Object { $_.LogonStartDate.InnerText -ge $lastWeek }
                    # Setting counts for connections over 24hour/7day
                    $metrics.$asp.Total_Connections_Last_24_HRS = ($connectionDate24).count
                    $metrics.$asp.Total_Connections_Last_7_DAYS = ($connectionDateWeek).count
                    # Selecting latest Peak Concurrent Sessions count over last 24 Hours
                    $conSession24 = $sessionSum.Content.Properties | Where-Object { $_.Granularity.InnerText -eq 1440 }
                    $summaryDate = (Get-Date).AddDays(-1)
                    $summaryDate = $summaryDate.ToString('yyyy-MM-ddTHH')
                    $summaryDate = -join($summaryDate, "*")
                    $conSession24 = $conSession24 | Where-Object { $_.SummaryDate.InnerText -ge $summaryDate }
                    $peakCon24 = 0
                    foreach ($item in $conSession24) {
                        $peakCon24 += $item.ConcurrentSessionCount.InnerText
                    }
                    $metrics.$asp.Peak_Sessions_Last_24_HRS - $peakCon24
                    # Creating Active Session Count array to extract latest active sessions
                    $currentSessions = $sessions.Content.Properties | Where-Object { $_.ConnectionState.InnerText -eq 5 }
                    $metrics.$asp.Active_Sessions = $currentSessions.count
                }
                Catch {
                    Write-Host -ForegroundColor Yellow "Error retrieving data from $ddc. Please check credentials."
                }
            }
            Catch [System.Net.NetworkInformation.PingException] {
                Write-Warning "$ddc could not be contacted"
            }
        }
    }

    end {
        $nl
        foreach ($site in $sites) {
            Write-Host -ForegroundColor Green "$site"
            $metrics.$site | Format-Table
        }
    }
}
