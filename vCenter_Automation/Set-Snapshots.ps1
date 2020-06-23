<#
 .NOTES
    Version  : 3.0
    Author   : Sid Johnston
    Company  : Concurrent Technologies Corporation
    Created  : 24 February 2020

 .SYNOPSIS
  Connects to a desired vCenter server and allows the user to create or delete snapshots en masse for patching and/or general vCenter Snapshot Management best practices.

 .DESCRIPTION
  Utilizing user-provided information and configuration CSV, this function first validates that the vCenter server(s) in the
  user-provided CSV have associated hsot file entries and applies them if they are missing. Then, the user is prompted to
  select a vCenter server with which to connect. On selection, the user will be prompted for vCenter credentials. If the Create
  Action was selected, the user will be required to enter a Name and Description for their snapshot(s) as parameters. If the
  Remove Action was selected, the user will be required to enter a desired maximum number of snapshost the user wishes to
  remain on each target VM. Next, the user will be prompted to select a vCenter Tag to filter which VMs are targeted. Upon
  selection of a Tag, snapshots will be either created or removed from the target VM(s).

  NOTE: In order for the host file validation to occur, the user must run this function in an elevated PowerShell session.

 .PARAMETER Action
  Specifies the user's intent to Create or Remove snapshots.

 .PARAMETER SnapshotName
  Dynamic parameter which specifies the name of the snapshot(s) if Create is selected for the Action parameter.

 .PARAMETER SnapshotDescription
  Dynamic parameter which specifies the description of the snapshot(s) if Create is selected for the Action parameter.

 .PARAMETER MaxSnapshotsRemaining
  Dynamic parameter which specifies the desired maximum number of snapshots the user wishes to remain on each target VM if
  Remove is selected for the Action parameter.

 .PARAMETER SiteConfig
  Specifies the path to the CSV which contains the site name, vCenter Server FQDN, vCenter Server IP address, and VMs which must
  be shut down prior to snapshot actions. The labels for this data must be name, vCenter, IP, and vmsToShutdown, respectively.
  All data must be in String format.

  EXAMPLE:
    name    vCenter            IP          vmsToShutdown
    site01  vcsa01.site01.com  10.10.1.1   SITE01_UNCLASS_DC01
    site02  vc01.site02.com    10.10.2.1   SITE02_UNCLASS_MAIL,SITE02_UNCLASS_SQL01

 .EXAMPLE

  PS> Set-Snapshots -Action Remove -SiteConfig 'C:\temp\Site_Config.csv' -MaxSnapshotsRemaining 3

  ======Validating host file entries for vCenter Servers======
  10.10.1.1      vcsa01.site01.com - not adding; already in hosts file
  10.10.2.1      vc01.site02.com - adding to hosts file...done

  ======Select a vCenter Server Connection======
  1. vcsa01.site01.com
  2. vc01.site02.com
  Your selection (1,2,3...): 2

  cmdlet Get-Credential at command pipeline position 1
  Supply values for the following parameters:
  Credential
  Connecting to vCenter: vc01.site02.com

  Name                           Port  User
  ----                           ----  ----
  vc01.site02.com                443   site02\sa.first.last

  ======Select a Tag to filter your VMs======
  1. Templates
  2. Core_VMs
  Your selection (1,2,3...): 2

  VM(s) which must be shut down prior to snapshot actions are included in your selection. Checking power state...
  Shutting down SITE02_UNCLASS_MAIL.
  Shutting down SITE02_UNCLASS_SQL01.

  Removing snapshot(s) from SITE02_UNCLASS_DC01.
  Removing snapshot(s) from SITE02_UNCLASS_DC02.
  Removing snapshot(s) from SITE02_UNCLASS_MAIL.
  Removing snapshot(s) from SITE02_UNCLASS_OWA.
  Removing snapshot(s) from SITE02_UNCLASS_MOSS.
  Removing snapshot(s) from SITE02_UNCLASS_SQL01.
  Removing snapshot(s) from SITE02_UNCLASS_SQL02.

  2 job(s) still running. Please wait: Message last updated 06/18/2020 20:00:21.
  2 job(s) still running. Please wait: Message last updated 06/18/2020 20:01:21.
  1 job(s) still running. Please wait: Message last updated 06/18/2020 20:02:21.
  1 job(s) still running. Please wait: Message last updated 06/18/2020 20:03:21.
  1 job(s) still running. Please wait: Message last updated 06/18/2020 20:04:21.

  Powering on SITE02_UNCLASS_MAIL.
  Powering on SITE02_UNCLASS_SQL01.

 .EXAMPLE

  PS> Set-Snapshots -Action Create -SiteConfig 'C:\temp\Site_Config.csv' -SnapshotName "Republishing 20200530" -SnapshotDescription "Fix for JRE compatibility issue."

  ======Validating host file entries for vCenter Servers======
  10.10.1.1      vcsa01.site01.com - not adding; already in hosts file
  10.10.2.1      vc01.site02.com - adding to hosts file...done

  ======Select a vCenter Server Connection======
  1. vcsa01.site01.com
  2. vc01.site02.com
  Your selection (1,2,3...): 2

  cmdlet Get-Credential at command pipeline position 1
  Supply values for the following parameters:
  Credential
  Connecting to vCenter: vc01.site02.com

  Name                           Port  User
  ----                           ----  ----
  vc01.site02.com                443   site02\sa.first.last

  ======Select a Tag to filter your VMs======
  1. Templates
  2. Core_VMs
  Your selection (1,2,3...): 1

  Creating snapshot for SITE02_UNCLASS_TMPLCLS.
  Creating snapshot for SITE02_UNCLASS_TMPLADM.

  Validating snapshot (Republishing 20200530) has been created.
  SITE02_UNCLASS_TMPLCLS : Success
  SITE02_UNCLASS_TMPLADM : Success
#>
function Set-Snapshots {
    [CmdletBinding()]
    param (
        # Create/Remove Choice
        [Parameter(Mandatory = $true)]
        [ValidateSet("Create","Remove")]
        [String[]]
        $Action,
        # Path to Config CSV
        [Parameter(Mandatory = $true)]
        [String[]]
        $SiteConfig
    )
    DynamicParam {
        if ($Action -eq "Create") {
            # Create SnapshotName parameter.
            $ParamName_snapName = 'SnapshotName'
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true
            $ParameterAttribute.Position = 1
            $Attributecollection.Add($ParameterAttribute)
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName_snapName, [string], $AttributeCollection)
            # Add SnapshotName parameter to parameter dictionary.
            $RuntimeParameterDictionary.Add($ParamName_snapName, $RuntimeParameter)
            # Create SnapshotDescription parameter.
            $ParamName_snapDesc = 'SnapshotDescription'
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true
            $ParameterAttribute.Position = 2
            $Attributecollection.Add($ParameterAttribute)
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName_snapDesc, [string], $AttributeCollection)
            # Add SnapshotDescription parameter to parameter dictionary.
            $RuntimeParameterDictionary.Add($ParamName_snapDesc, $RuntimeParameter)
            # Return parameter dictionary.
            return $RuntimeParameterDictionary
        } else {
            # Create MaxSnapshotsRemaining parameter.
            $ParamName_maxSnaps = 'MaxSnapshotsRemaining'
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true    
            $Attributecollection.Add($ParameterAttribute)
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName_maxSnaps, [int], $AttributeCollection)
            # Add MaxSnapshotsRemaining parameter to parameter dictionary.
            $RuntimeParameterDictionary.Add($ParamName_maxSnaps, $RuntimeParameter)
            # Return parameter dictionary.
            return $RuntimeParameterDictionary
        }
    }
    begin {
        $nl = [Environment]::NewLine
        $error.Clear()
        $ErrorActionPreference = "Continue"
        # Import contents of Site Configuration CSV.
        $SiteConfig = $PSBoundParameters.SiteConfig
        $sites = Import-Csv -Path "$SiteConfig"
        # Create object for Site Configuration Data.
        $config = @{}
        foreach ($site in $sites) {
            $config += @{
                $site.name = @{
                    vms = @(if($site.vmsToShutdown -match ","){($site.vmsToShutdown.Split(","))} else{$site.vmsToShutdown})
                }
            }
        }
        # Set required PowerCLI Configuration parameters.
        (Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $false Scope AllUsers -Confirm:$false) | Out-Null
        # Measures the number of snapshots which need to be removed and returns a value of Type Int32.
        function Measure-SnapsToRemove {
            param (
                [Parameter(Mandatory=$true)]
                [String[]]
                $Tag,
                [Parameter(Mandatory=$true)]
                [int]
                $MaxSnaps
            )
            $vms = 0
            $vms = Get-Vm -Tag $Tag
            $snapsToRemove = 0
            foreach ($vm in $vms) {
                $snaps = Get-Snapshot $vm
                if ( $snaps.count -gt $MaxSnaps ) { $snapsToRemove += ( $snaps.count - $MaxSnaps ) }
            }
            return $snapsToRemove
        }
        # Sets host file entries - Requires elevated PowerShell console.
        function Set-HostFile {
            param (
                # Host IP
                [Parameter(Mandatory=$true)]
                [String]
                $IPaddr,
                # Hostname
                [Parameter(Mandatory=$true)]
                [String]
                $Hostname,
                # Check only for a hostname match
                [Parameter(Mandatory=$false)]
                [bool]
                $CheckOnlyHost = $false
            )
            # Set host file path and pull current host file.
            $hostFilePath = "$($Env:windir)\system32\Drivers\etc\hosts"
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
        $nl
        # Ensure hosts file is configured for connections to vCenter Servers.
        Write-Host "======Validating host file entries for vCenter Servers======" -ForegroundColor Cyan
        foreach ($site in $sites) {
            Set-HostFile -IPaddr $site.IP -Hostname $site.vCenter
            Start-Sleep -Seconds 1
        }
        $nl
        Write-Host "======Select a vCenter Server Connection======" -ForegroundColor Cyan
        $menuNum = 1
        foreach ($site in $sites) {
            Write-Host "$menuNum. $($site.vCenter)"
            $menuNum++
        }
        $selection = Read-Host "Your selection (1,2,3...)"
        $vCenter = $sites[( $selection - 1 )].vCenter
        $selectedSite = $sites[( $selection - 1 )].name
        $nl
        # Prompt for vCenter credentials.
        $Credential = Get-Credential
        # Connect to desired vCenter with provided credentials.
        Write-Host "Connecting to vCenter: $vCenter" -ForegroundColor Cyan -BackgroundColor DarkGray
        Try {
            Connect-VIServer -Server "$vCenter" -Credential $Credential
        }
        Catch {
            Write-Warning "$($Error.exception.message)"
        }
    }
    process {
        switch ($Action) {
            "Create" {
                $snapName = $PSBoundParameters[$ParamName_snapName]
                $snapDesc = $PSBoundParameters[$ParamName_snapDesc]
                $nl
                # Concurrent task limit.
                $maxTasks = 10
                # Enumerate tags and prompt to select one.
                $tags = Get-Tag | Sort-Object
                $nl
                Write-Host "======Select a Tag to filter your VMs======" -ForegroundColor Cyan
                for ($t = 0; $t -lt $tags.Count; $t++) {
                    $menuNum = ( $t + 1 )
                    Write-Host "$menuNum. $($tags[$t].Name)"
                }
                $selectedTag = Read-Host "Your selection (1,2,3...)"
                $selectedTag = $tags[( $selectedTag - 1)].Name
                $nl
                # Get applicable VMs from vCenter.
                $vmsToWorkOn = Get-VM -Tag $selectedTag | Sort-Object
                # Determine whether a VM which must be shut down prior to snapshot actions is present in the selected tag.
                if ($config.$selectedSite.vms -eq "none") {
                    Start-Sleep -Seconds 1
                } elseif ($null -eq (Compare-Object -ReferenceObject (Get-VM $config.$selectedSite.vms) -DifferenceObject $vmsToWorkOn -IncludeEqual -ExcludeDifferent)) {
                    Start-Sleep -Seconds 1
                } else {
                    $includedVMs = Compare-Object -ReferenceObject (Get-VM $config.$selectedSite.vms) -DifferenceObject $vmsToWorkOn -IncludeEqual -ExcludeDifferent
                    Write-Host "VM(s) which must be shut down prior to snapshot actions are included in your selection. Checking power state..."
                    # Check power state of VM(s) and shut down if required.
                    $powerManagedVMs = Get-VM $includedVMs.InputObject.Name | Sort-Object
                    foreach ($vm in $powerManagedVMs) {
                        if ($vm.PowerState -notlike "PoweredOff") {
                            Write-Host "Shutting down $($vm.Name)."
                            (Get-VM -Name $vm.Name | Shutdown-VMGuest -Confirm:$false) | Out-Null
                            do {
                                Start-Sleep -Seconds 5
                            } until ((Get-VM $vm).PowerState -eq "PoweredOff")
                        } else { Write-Host "$($vm.Name) already shut down." }
                    }
                }
                $nl
                # Create snapshots on the target tag VMs.
                foreach ($vm in $vmsToWorkOn) {
                    Write-Host "Creating snapshot for $($vm.Name)."
                    ($vm | New-Snapshot -Name "$snapName" -Description "$snapDesc" -RunAsync -Confirm:$false) | Out-Null
                    $tasks = Get-Task -Status 'Running' | Where-Object {$_.Name -eq "CreateSnapshot_Task"}
                    while ($tasks.Count -ge $maxTasks) {
                        Start-Sleep -Seconds 10
                        $tasks = Get-Task -Status 'Running' | Where-Object {$_.Name -eq "CreateSnapshot_Task"}
                    }
                }
                # Reinit the VMs and determine if snapshots have been successfully created.
                $failedVMs = New-Object System.Collections.ArrayList
                $nl
                Write-Host "Validating snapshot ($($snapName)) has been created."
                Start-Sleep -Seconds 15
                $vmsToWorkOn = Get-VM -Tag $selectedTag | Sort-Object
                foreach ($vm in $vmsToWorkOn) {
                    $currentSnaps = Get-Snapshot $vm
                    if ($currentSnaps -match $snapName) {
                        Write-Host "$($vm.Name) : Success" -ForegroundColor Green
                    } else {
                        Write-Host "$($vm.Name) : Failed" -ForegroundColor Red
                        $failedVMs.Add($vm.Name)
                    }
                }
                $nl
                # If there are any VMs which have failed to create snapshots, prompt user to investigate cause and return to try again.
                if ($failedVMs.Count -gt 0) {
                    Write-Host "$($failedVMs.Count) VM(s) above failed to create a snapshot."
                    Write-Host "Investigate the cause, and return to this prompt when ready to attempt snapshot creation on the affected VMs."
                    Pause
                    foreach ($vm in $failedVMs) {
                        Write-Host "Creating snapshot for $($vm.Name)."
                        ($vm | New-Snapshot -Name "$snapName" -Description "$snapDesc" -RunAsync -Confirm:$false) | Out-Null
                    }
                }
            }
            "Remove" {
                $maxSnaps = $PSBoundParameters[$ParamName_maxSnaps]
                # Concurrent jobs limit.
                $maxJobs = 10
                # Enumerate tags and prompt to select one.
                $tags = Get-Tag | Sort-Object
                $nl
                Write-Host "======Select a Tag to filter your VMs======" -ForegroundColor Cyan
                for ($t = 0; $t -lt $tags.Count; $t++) {
                    $menuNum = ( $t + 1 )
                    Write-Host "$menuNum. $($tags[$t].Name)"
                }
                $selectedTag = Read-Host "Your selection (1,2,3...)"
                $selectedTag = $tags[( $selectedTag - 1 )].Name
                $nl
                $vmsToWorkOn = Get-VM -Tag $selectedTag | Where-Object {(Get-Snapshot $_.Name).Count -gt $maxSnaps}
                # Determine if there are any snapshots which meet the criteria of snapshot counts greater than the MaxSnapshotsRemaining parameter.
                if ((Measure-SnapsToRemove -Tag $selectedTag -MaxSnaps $maxSnaps) -eq 0) {
                    Write-Host "There are no excess snapshots at $($selectedSite)." -ForegroundColor Cyan -BackgroundColor DarkGray
                    Pause
                    Break
                }
                # Determine whether a VM which must be shut down prior to snapshot actions is present in the selected tag.
                if ($config.$selectedSite.vms -eq "none") {
                    Start-Sleep -Seconds 1
                } elseif ($null -eq (Compare-Object -ReferenceObject (Get-VM $config.$selectedSite.vms) -DifferenceObject $vmsToWorkOn -IncludeEqual -ExcludeDifferent)) {
                    Start-Sleep -Seconds 1
                } else {
                    $includedVMs = Compare-Object -ReferenceObject (Get-VM $config.$selectedSite.vms) -DifferenceObject $vmsToWorkOn -IncludeEqual -ExcludeDifferent
                    Write-Host "VM(s) which must be shut down prior to snapshot actions are included in your selection. Checking power state..."
                    # Check power state of VM(s) and shut down if required.
                    $powerManagedVMs = Get-VM $includedVMs.InputObject.Name | Sort-Object
                    foreach ($vm in $powerManagedVMs) {
                        if ($vm.PowerState -notlike "PoweredOff") {
                            Write-Host "Shutting down $($vm.Name)."
                            (Get-VM -Name $vm.Name | Shutdown-VMGuest -Confirm:$false) | Out-Null
                            do {
                                Start-Sleep -Seconds 5
                            } until ((Get-VM $vm).PowerState -eq "PoweredOff")
                        } else { Write-Host "$($vm.Name) already shut down." }
                    }
                }
                $nl
                # Generate Jobs for each VM with snapshots to remove with no more than 10 jobs running concurrently.
                foreach ($vm in $vmsToWorkOn) {
                    # Set up ScriptBlock and Details for Job object.
                    $Job_ScriptBlock = {
                        param (
                            [string]$Server,
                            [string]$SessionId,
                            [int]$MaximumSnaps,
                            [string]$VMName
                        )
                        Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false -Scope Session -Confirm:$false | Out-Null
                        Connect-VIServer -Server $Server -Session $SessionId
                        $snapShots = Get-Snapshot -VM $VMName
                        Get-VM -Name $VMName | Get-Snapshot | Select-Object -First ($snapShots.Count - $MaximumSnaps) | Remove-Snapshot -Confirm:$false
                    }
                    $vm_Name = $vm.Name
                    $Job_Details = @{
                        ScriptBlock = $Job_ScriptBlock
                        ArgumentList = $Global:DefaultVIServer.Name, $Global:DefaultVIServer.SessionId, $maxSnaps, $vm_Name
                    }
                    Write-Host "Removing snapshot(s) from $($vm_Name)."
                    (Start-Job -Name $vm_Name @Job_Details) | Out-Null
                    $jobs = Get-Job -State 'Running'
                        While ($jobs.Count -ge $maxJobs) {
                            Start-Sleep -Seconds 30
                            $jobs = Get-Job -State 'Running'
                        }
                }
                $nl
                $jobs = Get-Job -State 'Running'
                # While jobs are still running after passing through all the selected VMs, prompt the user to wait until those jobs are complete. Message will repeat every minute.
                while ($jobs.Count -gt 0) {
                    $time = Get-Date
                    Write-Host "$($jobs.Count) job(s) still running. Please wait: Message last updated $($time)."
                    Start-Sleep -Seconds 60
                    $jobs = Get-Job -State 'Running'
                }
            }
        }
    }
    end {
        $nl
        # Power on VM(s) that were shut down prior to snapshot actions if required.
        if ($null -eq $powerManagedVMs) {
            Start-Sleep -Seconds 1
        } else {
            foreach ($vm in $powerManagedVMs) {
                Write-Host "Powering on $($vm.Name)."
                (Start-VM -VM $vm.Name) | Out-Null
            }
        }
        # Clean up VIserver connections.
        Disconnect-VIServer * -Force -Confirm:$false | Out-Null
    }
}
