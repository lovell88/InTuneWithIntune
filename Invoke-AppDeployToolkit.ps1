<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), NonInteractive (dialogs without prompts) mode, or Auto (shows dialogs if a user is logged on, device is not in the OOBE, and there's no running apps to close).

Silent mode is automatically set if it is detected that the process is not user interactive, no users are logged on, the device is in Autopilot mode, or there's specified processes to close that are currently running.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode = 'Interactive',

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

# Zero-Config MSI support is provided when "AppName" is null or empty.
# By setting the "AppName" property, Zero-Config MSI will be disabled.
$adtSession = @{
    # App variables.
    AppVendor = 'Autodesk'
    AppName = 'Autodesk Revit 2023'
    AppVersion = '2023.1.8'
    AppArch = 'x86'
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @()  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
    AppScriptVersion = '1.0.0'
    AppScriptDate = '11/03/2025'
    AppScriptAuthor = 'Lee Lovell'
    RequireAdmin = $true

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.5'
}

function Install-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    Show-ADTInstallationProgress -StatusMessage "Installation in progress...`n`nThe installation may take up to 45 minutes to an hour."

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    $sciptName = $MyInvocation.MyCommand.Name
    $myLocation = $MyInvocation.MyCommand.Source.Replace("$($sciptName)", "")
    
    cd $myLocation
    
    #Path for installation tool
    #Enter name of installation tool below
    $extractorFile = "Revit 2023.1.8 10-29-2025.exe"
    $deploymentCacheFolder = "C:\ai2io_it\revit\downloads"
    $productFolderName = "revit2023"
    
    if(Test-Path -Path "C:\Program Files\Autodesk_Temp\")
    {
        $copyResult = Copy-Item "files\$($extractorFile)" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force
    
    }else
    {
        New-Item -Path "C:\Program Files\Autodesk_Temp\" -ItemType Directory -Force
        $copyResult = Copy-Item "files\$($extractorFile)" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force
    }
    
    if(Test-Path -Path "C:\Program Files\Autodesk_Temp\$($extractorFile)")
    {
        Start-Process -FilePath "C:\Program Files\Autodesk_Temp\$($extractorFile)" -ArgumentList "-q" -Wait
    }
    
    $tempDeploymentDirectory = [System.IO.DirectoryInfo]::new("$($deploymentCacheFolder)\$($productFolderName)")
    $successLine = $null
    $installFile = $null
    
    do
    {
    
        foreach($file in $tempDeploymentDirectory.GetFiles())
        {
    
            if($file.Extension -eq ".log")
            {
                $log = Get-Content -Path $file.FullName
    
                $successLine = $log | Where-Object {$_ -match "The deployment image is created successfully"}
    
            }
    
            if($successLine -ne $null)
            {
                #Get the generated install batch file
                if($file.extension -eq ".bat")
                {
    
                    $installFile = Get-Content -Path $file.FullName
    
                }
    
            }
    
            
        }
    
    }Until($successLine -ne $null)
    
    if($successLine -ne $null)
    {
        #If deployment image has been created then all files have been extracted
        #Use silent installation command from the deployment.bat file 
        #If the package deployment fails check this section to make sure the batch file exists and the both parts of the command line are present.
        #if there are issues manually change part1 and part2 to the values from the install command like the line below
        #Start-Process -FilePath "C:\Temp\Autodesk_Deployments\Vehicle_Tracking\image\Installer.exe" -ArgumentList '-i deploy --offline_mode -q -o "C:\Temp\Autodesk_Deployments\Vehicle_Tracking\image\Collection.xml" --installer_version "1.41.0.249"'
        
        $part1 = ""
        $part2 = ""
        $installArgs = ""
    
        foreach($line in $installFile)
        {
            #We are looking for the silent install line so we can find that using this sub string
            if($line.Contains("-i deploy --offline_mode -q"))
            {            
                #we need to split the installation line into two parts so that it can be used by the Start-Process command
                $installParts = $line -split " -i "
                #We need to remove the "rem " part of the line
                $part1 = $installParts[0].Remove(0, 4)
                #We need to add back in the "-i" switch for the command line
                $part2 = "-i $($installParts[1])"
    
                $xmlPath = '"' + $part2.split('"')[1] + '"'
                $installerVersion = '"' + $part2.split('"')[3] + '"'
    
                $installArgs = @(
                "-i", "deploy", "--offline_mode", "-q", "-o", $xmlPath, "--installer_version", $installerVersion
    
                )
    
            }
        }    
    
        try
        {
            Start-ADTProcess -File $part1 -ArgumentList $installArgs -WaitForMsiExec -WaitForChildProcesses
        }
        catch
        {
    
            Write-Host $_
    
        }
    
    }
    
    Remove-Item -Path "C:\Program Files\Autodesk_Temp" -Recurse -Force
    Remove-Item -Path $deploymentCacheFolder -Recurse -Force

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## Master Wrapper detection
    Set-ADTRegistryKey -Key "HKLM\SOFTWARE\InstalledApps\Autodesk_Autodesk Revit 2023_2023.1.8"
}

function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    Show-ADTInstallationProgress

    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    $sciptName = $MyInvocation.MyCommand.Name
    $myLocation = $MyInvocation.MyCommand.Source.Replace("$($sciptName)", "")
    
    cd $myLocation
    
    #Path for installation tool
    #Enter name of installation tool below
    $extractorFile = "Revit 2023.1.8 10-29-2025.exe"
    $deploymentCacheFolder = "C:\ai2io_it\revit\downloads"
    $productFolderName = "revit2023"
    
    if(Test-Path -Path "C:\Program Files\Autodesk_Temp\")
    {
        $copyResult = Copy-Item "$($myLocation)\$($extractorFile)" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force
    
    }else
    {
        New-Item -Path "C:\Program Files\Autodesk_Temp\" -ItemType Directory -Force
        $copyResult = Copy-Item "$($myLocation)\$($extractorFile)" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force
    }
    
    if(Test-Path -Path "C:\Program Files\Autodesk_Temp\$($extractorFile)")
    {
        Start-Process -FilePath "C:\Program Files\Autodesk_Temp\$($extractorFile)" -ArgumentList "-q" -Wait
    }
    
    $tempDeploymentDirectory = [System.IO.DirectoryInfo]::new("$($deploymentCacheFolder)\$($productFolderName)")
    $successLine = $null
    $installFile = $null
    
    do
    {
    
        foreach($file in $tempDeploymentDirectory.GetFiles())
        {
    
            if($file.Extension -eq ".log")
            {
                $log = Get-Content -Path $file.FullName
    
                $successLine = $log | Where-Object {$_ -match "The deployment image is created successfully"}
    
            }
    
            if($successLine -ne $null)
            {
                #Get the generated install batch file
                if($file.extension -eq ".bat")
                {
    
                    $installFile = Get-Content -Path $file.FullName
    
                }
    
            }
    
            
        }
    
    }Until($successLine -ne $null)
    
    if($successLine -ne $null)
    {
        #If deployment image has been created then all files have been extracted
        #Use silent uninstall command from the deployment.bat file
        #Start-Process -FilePath "C:\Program Files\Autodesk Deployment Cache\AutoCad\image\Installer.exe" -ArgumentList '-i uninstall -q --manifest "C:\Program Files\Autodesk Deployment Cache\AutoCad\image\ACD_2022_en-US\setup.xml" --extension_manifest "C:\Program Files\Autodesk Deployment Cache\AutoCad\image\ACD_2022_en-US\setup_ext.xml"' -Wait
    
        $executable = ""
        $uninstallArgs = ""
    
        foreach($line in $installFile)
        {
            #We are looking for the silent install line so we can find that using this sub string
            if($line.Contains("-i uninstall -q"))
            {            
                #we need to split the installation line into two parts so that it can be used by the Start-Process command
                $installParts = $line -split " -i "
                #We need to remove the "rem " part of the line
                $executable = $installParts[0].Remove(0, 4)
    
                #Now we will split the line to get the manifest and extension manifest xml locations
                $xmlLocations = (($line -split "--manifest ")[1] -split "--extension_manifest ")
                $manifestXml = $xmlLocations[0]
                $extension_manifestXml = $xmlLocations[1]
                
                #We can now put it all together in an array for powershell to handle
                $uninstallArgs = @(
                "-i", "uninstall", "-q", "--manifest", $manifestXml, "--extension_manifest", $extension_manifestXml
    
                )
    
            }
        }    
    
        try
        {
            Start-ADTProcess -File $executable -ArgumentList $uninstallArgs -Wait
        }
        catch
        {
    
            Write-Host $_
    
        }
    }
    
    Remove-Item -Path "C:\Program Files\Autodesk_Temp" -Recurse -Force
    Remove-Item -Path $deploymentCacheFolder -Recurse -Force

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## Master Wrapper detection
    Remove-ADTRegistryKey -Key "HKLM\SOFTWARE\InstalledApps\Autodesk_Autodesk Revit 2023_2023.1.8"
}

function Repair-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## Master Wrapper detection
    Set-ADTRegistryKey -Key "HKLM\SOFTWARE\InstalledApps\Autodesk_Autodesk Revit 2023_2023.1.8"
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.5' } -Force
    }
    else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.5' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    # Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -MessageAlignment Left -ButtonRightText OK -Icon Error -NoWait

    Close-ADTSession -ExitCode 60001
}

