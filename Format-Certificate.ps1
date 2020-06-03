<#
    Connects to a specified certificate/key store and generates PFX and PEM files.

        Version   : 1.1
        Author    : Sid Johnston
        Company   : Concurrent Technologies Corporation
        Created   : 20 February 2020
        
 .Synopsis
  Connects to a specified certificate/key store and generates PFX and PEM files.
  
 .Description
  When the parameter paths are given, the user will be prompted to supply a password for PFX generation.
  Then, PFX and PEM files will be placed in respective folders created in the .CER source file directory.

 .Parameter CertPath
  Path to folder which contains the .CER source files.

 .Parameter KeyPath
  Path to folder which contains the .KEY source files.

 .Example   
   Format-Certificate -CertPath C:\temp\CER -KeyPath C:\temp\KEY
#>


function Format-Certificate {
    [CmdletBinding()]
    param(
        # Path containing .CER source files
        [Parameter(Mandatory = $true)]
        [System.String]
        $CertPath,
        #Path containing .KEY source files
        [Parameter(Mandatory = $true)]
        [System.String]
        $KeyPath
    )

    begin {
        $nl = [Environment]::NewLine
        function Set-PFX {
            param (
                # Object containing certificate file names
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.Object]
                $CertIn,
                # String containing password for output PFX
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.String]
                $Pwd,
                # String containing base certificate directory
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.String]
                $CertDir,
                # String containing base key directory
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.String]
                $KeyDir
            )

            # Change directory to openSSL executable path
            $openSSL = where.exe /R 'C:\Program Files' openssl.exe | Select-Object -First 1
            $openSSL = $openSSL.TrimEnd('openssl.exe')
            Set-Location -Path $openSSL

            # Sort input object
            $CertIn = $CertIn | Sort-Object

            # Check for PFX sub-directory and create it if required
            if ((Test-Path -Path "$($CertDir)\PFX") -eq $false) { New-Item -ItemType Directory -Path "$($CertDir)\PFX" -Force }

            # Generate PFX files
            foreach ( $cert in $CertIn ) { .\openssl.exe pkcs12 -export -inkey "$($KeyDir)\$($cert).key" -in "$($CertDir)\$($cert).cer" -out "$($CertDir)\PFX\$($cert).pfx" -password pass:$($Pwd) }
        }
        function Set-PEM {
            param (
                # Object containing certificate file names
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.Object]
                $CertIn,
                # String containing base certificate directory
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.String]
                $CertDir,
                # String containing base key directory
                [Parameter(Mandatory = $true,
                ValueFromPipeline = $true)]
                [System.String]
                $KeyDir
            )

            # Sort input object
            $CertIn = $CertIn | Sort-Object

            # Check for PEM sub-directory and create it if required
            if ((Test-Path -Path "$($CertDir)\PEM") -eq $false) { New-Item -ItemType Directory -Path "$($CertDir)\PEM" -Force }

            # Generate PEM files
            foreach ( $cert in $CertIn ) { Get-Content "$($CertDir)\$($cert).cer","$($KeyDir)\$($cert).key" | Out-File "$($CertDir)\PEM\$($cert).pem" }
        }
    }

    process {
        # Collect password for PFX
        $password = Read-Host "Enter a password to be used for PFX certficate generation"

        # Gather certificate file name object contents
        $Certificates = (Get-ChildItem -Path $CertPath | Where-Object { $_.Name.EndsWith('.cer') -eq $true}).BaseName

        # Generate PFX files
        Write-Host "Generating PFX files."
        Set-PFX -CertIn $Certificates -Pwd $password -CertDir $CertPath -KeyDir $KeyPath

        $nl

        # Generate PEM files
        Write-Host "Generating PEM files."
        Set-PEM -CertIn $Certificates -CertDir $CertPath -KeyDir $KeyPath
    }

    end {
        Write-Host "New PFX & PEM files generated."
        Pause
    }
}

<#
######################################CHANGELOG######################################
20 Feb 2020 - v1.0 created
30 Mar 2020 - v1.1
    Feature Improvements: None
    Bug Fixes:  Removed '-AsSecureString' parameter from Read-Host cmdlet that
                prompts user to provide a password for PFX generation in order
                to allow proper password application to generated PFX files.
######################################CHANGELOG######################################
#>
