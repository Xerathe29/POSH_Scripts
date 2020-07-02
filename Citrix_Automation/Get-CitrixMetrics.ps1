<#
 .NOTES
    Version  : 1.0
    Author   : Eshton Brogan & Sid Johnston
    Created  : 08 June 2020
 
 .SYNOPSIS
  Gathers connection & session API data from specified Citrix Delivery Controllers and outputs the results to the console.

 .DESCRIPTION
  Utilizing user-provided credentials and configuration CSV, this function first validates that the delivery controller(s) in the
  user-provided CSV have associated host file entries and applies them if they are missing. Then, the raw API data is pulled from
  each delivery controller and filtered. This filtered data is stored in a PSCustomObject for later use. If for whatever reason,
  a delivery controller is unreachable, a message will be displayed on the console. Finally, once all applicable delivery
  controllers have been contacted, the contents of each PSCustomObject created from the delivery controller data will be displayed
  on the console.

  NOTE: In order for host file validation to occur, the user must run this function in an elevated PowerShell session.

 .PARAMETER Credential
  Specifies the credentials used to connect to the delivery controller(s).

 .PARAMETER SiteConfig
  Specifies the path to the CSV which contains the site name, delivery controller FQDN, and delivery controller IP address data. The
  labels for this data must be name, ddc, and ip, respectively. All data must be in String format.
  
  EXAMPLE:
    name    ddc               ip
    site01  ddc01.site01.com  10.10.1.1
    site02  ddc01.site02.com  10.10.2.1 

 .EXAMPLE

  PS> Get-CitrixMetrics -Credential sa.first.last -SiteConfig 'C:\temp\Site_Config.csv'
  Windows PowerShell credential request
  Enter your credentials.
  Password for user sa.first.last: *****************

  ======Validating host file entries for Delivery Controllers======
  10.10.1.1      ddc01.site01.com - not adding; already in hosts file
  10.10.2.1      ddc01.site02.com - adding to hosts file...done

  Testing that ddc01.site01.com is online.
  Testing that ddc01.site02.com is online.

  site01

  Name                           Value
  ----                           -----
  Total_Connections_Last_24_HRS  23
  Total_Connections_Last_7_DAYS  432
  Active_Sessions                15
  Peak_Sessions_Last_24_HRS      21

  site02

  Name                           Value
  ----                           -----
  Total_Connections_Last_24_HRS  10
  Total_Connections_Last_7_DAYS  52
  Active_Sessions                5
  Peak_Sessions_Last_24_HRS      9
#>
function Get-CitrixMetrics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]
        $Credential,
        [Parameter(Mandatory=$true)]
        [String]
        $SiteConfig
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
                Add-Content -Encoding UTF8 $hostFilePath ( "`r`n" + "$IPaddr".PadRight( 20, " " ) + "$Hostname" )
                Write-Host " done" -ForegroundColor Green
            }
        }
        # Import data from CSV
        $SiteConfig = $PSBoundParameters.SiteConfig
        $sites = Import-Csv -Path "$SiteConfig"
        # Create object to store Citrix Metrics
        $metrics = @{}
        foreach ($site in $sites) {
            $metrics += @{
                $site.name = @{
                    Total_Connections_Last_24_HRS = ""
                    Total_Connections_Last_7_DAYS = ""
                    Peak_Sessions_Last_24_HRS = ""
                    Active_Sessions = ""
                    XenApp_Sessions_Last_24_HRS = ""
                }
            }
        }
        # Create object to store XenApp GUIDs
        $config = @{}
        foreach ($site in $sites) {
           $config += @{
              $site.name = @{
                 xenAppGUID = @(if($site.xenAppGUID -match ","){($site.xenAppGUID.Split(","))} else{$site.xenAppGUID})
              }
           }
        }
        $nl
        # Ensure hosts file is configured for connections to Delivery Controllers.
        Write-Host "======Validating host file entries for Delivery Controllers======" -ForegroundColor Cyan
        foreach ($site in $sites) {
            Set-HostFile -IPaddr $site.ip -Hostname $site.ddc
            Start-Sleep -Seconds 1
        }
        $nl        
    }

    process {
        foreach ($site in $sites) {
            
            Try {
                Write-Host "Testing that $($site.ddc) is online."
                (Test-Connection -ComputerName $site.ddc -Count 1 -ErrorAction Stop) | Out-Null

                Try {                    
                    # Gathering raw API data from DDC
                    $sessionSum = Invoke-RestMethod -Uri "http://$($site.ddc)/Citrix/Monitor/OData/v1/Data/SessionActivitySummaries" -Credential $Credential -ErrorAction Stop
                    $connections = Invoke-RestMethod -Uri "http://$($site.ddc)/Citrix/Monitor/OData/v1/Data/Connections" -Credential $Credential -ErrorAction Stop
                    $sessions = Invoke-RestMethod -Uri "http://$($site.ddc)/Citrix/Monitor/OData/v1/Data/Sessions" -Credential $Credential -ErrorAction Stop
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
                    $metrics.($site.name).Total_Connections_Last_24_HRS = ($connectionDate24).count
                    $metrics.($site.name).Total_Connections_Last_7_DAYS = ($connectionDateWeek).count
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
                    $metrics.($site.name).Peak_Sessions_Last_24_HRS = $peakCon24
                    # Creating Active Session Count array to extract latest active sessions
                    $currentSessions = $sessions.Content.Properties | Where-Object { $_.ConnectionState.InnerText -eq 5 }
                    $metrics.($site.name).Active_Sessions = $currentSessions.count
                    $xenApp24 = 0
                    if ($null eq ($config.($site.name).XenAppGUID)) {
                       Start-Sleep -Seconds 1
                    } else {
                       foreach ($guid in $config.($site.name).XenAppGUID) {
                          $XA = $conSession24 | Where-Object { $_.DesktopGroupId.InnerText -eq $guid }
                          $xenApp24 += $XA.TotalLogonCount.InnerText
                       }
                    }
                    $metrics.($site.name).XenApp_Sessions_Last_24_HRS = $xenApp24
                }
                Catch {
                    Write-Host -ForegroundColor Yellow "Error retrieving data from $($site.ddc). Please check credentials."
                }
            }
            Catch [System.Net.NetworkInformation.PingException] {
                Write-Warning "$($site.ddc) could not be contacted"
            }
        }
    }

    end {
        $nl
        foreach ($site in $sites) {
            Write-Host -ForegroundColor Green "$($site.name)"
            $metrics.($site.name) | Format-Table
        }
    }
}
