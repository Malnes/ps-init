
<#PSScriptInfo

.VERSION 0.2.0

.GUID 18038e71-ec43-4ebc-9155-8088908216f1

.AUTHOR Malnes

.COMPANYNAME SomeComp

.COPYRIGHT All rights reserved SomeComp

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Small script that creates a povershell project 

#> 

param (
    [Parameter()]
    [bool]$forceReprocess = $true
)

# CREATE local.settings.json
if(-not (Test-Path .\local.settings.json)) {
    write-host "Creating local.settings.json as its missing" -f Green
    new-item -Path .\ -Name "local.settings.json" -ItemType File  | out-null
    $content = "// Example data`n"
    $content += @{
        upn = "first.last@upn.com"
        password = "Password"
    } | convertto-json

    Add-Content -Path .\local.settings.json -Value $content
}

# CREATE gitignore 
if(-not (Test-Path .\.gitignore)) {
    write-host "Creating gitignore" -f Green
    new-item -Path .\ -name ".gitignore" -ItemType File  | out-null
    Add-Content .\.gitignore "modules`nlocal.settings.json"
}

# CREATE app/main
if(-not (Test-Path .\app\main.ps1)) {
    write-host "Creating main.ps1" -f Green
    new-item -Path .\ -name "app" -ItemType Directory | Out-Null
    new-item -Path .\app -name "main.ps1" -ItemType File  | out-null
    Add-Content .\app\main.ps1 -Value @"
# process module dependencies. Run with -forceReprocess if nessesary
ps-init -forceReprocess:`$false
`$var = Get-Content .\local.settings.json | ConvertFrom-Json

# Write you code below
"@
}

# CREATE dependencies.psd1
if(-not (Test-Path .\dependencies.psd1)) {
    write-host "Creating dependencies.psd1" -f Green
    new-item -Path .\ -name "dependencies.psd1" -ItemType File | Out-Null
    Add-Content .\dependencies.psd1 -Value @"
@{

    #'pnp.powershell' = '*'
    # 'microsoft.Graph.authentication' = '2.2.*'
    # 'microsoft.Graph.users' = '2.2.*'
    
}
"@
}

# CREATE modules
if(-not (test-path .\modules)){
    write-host "Creating modules folder" -f Green
    new-item -name modules -ItemType Directory | Out-Null
}


# CREATE .vscode\launch.json
if(-not (Test-Path .\.vscode\launch.json)) {
    write-host "Creating launch.json" -f Green
    new-item -Path .\ -name ".vscode" -ItemType Directory | Out-Null
    new-item -Path .\.vscode -name "launch.json" -ItemType File  | out-null
    Add-Content .\.vscode\launch.json -Value @"
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "PowerShell: Launch Script",
            "type": "PowerShell",
            "request": "launch",
            "script": "${workspaceFolder}/app/main.ps1",
            "args": []
        }
    ]
}
"@
}


# Only process modules if new or changes has been made
$hash = get-filehash -Path .\dependencies.psd1 | select -ExpandProperty Hash
if($Global:psDep -ne $hash -or $forceReprocess) {


    write-host "`nInitializing..." -f Green
    
    # Start checking dependencies and stuff
    Write-Host "`nChecking dependencies..." -ForegroundColor Green


    # Path to the Dependencies.psd1 file
    $dependenciesFilePath = '.\Dependencies.psd1'

    # Load dependencies from the .psd1 file
    $dependencies = Import-PowerShellDataFile -Path $dependenciesFilePath

    # Get the latest available module version according to the requirement in dependencies.psd1
    function Get-requiredModuleVersion {
        param (
            [string]$requiredVersion,
            [string]$moduleName
        )

        # Determine if requiredVersion has wildcards
        $hasWildcards = $requiredVersion -like "*[*?]*"

        # Get all available versions of the module
        $availableVersions = Find-Module -Name $moduleName -AllVersions | Select-Object -ExpandProperty Version

        # Filter and sort available versions based on the requiredVersion
        $filteredVersions = $availableVersions | Where-Object {
            if ($hasWildcards) {
                $pattern = New-Object System.Management.Automation.WildcardPattern($requiredVersion, [System.Management.Automation.WildcardOptions]::IgnoreCase)
                $pattern.IsMatch($_.ToString())
            } else {
                $_ -ge [Version]$requiredVersion
            }
        } | Sort-Object {[Version]$_} -Descending

        # Determine the latest available version that matches the requirement
        $latestAvailableVersion = $filteredVersions | Select-Object -First 1

        return $latestAvailableVersion
    }


    # Downlaod modules
    foreach ($name in $dependencies.keys) {
        try {
            # Get our target version
            [version]$targetVersion = Get-requiredModuleVersion -moduleName $name -requiredVersion $dependencies[$name]

            # Check if module is installed
            if(test-path .\modules\$name) {

                #Check which version is installed
                [version]$installedVersion = Get-ChildItem .\modules\$name | select -ExpandProperty Name

                # Check if installed version is not the same as required version
                if ($targetVersion -ne $installedVersion) {

                    #Remove old and download new
                    write-host "Removing module with unwanted verison: `"$name`" Version `"$installedVersion`"" -f Yellow
                    remove-item -Path .\modules\$name -Recurse -Force | out-null

                    write-host "- Installing target version of module: `"$name`" Version `"$targetVersion`"" -f Green

                    Save-Module `
                        -Name $name `
                        -RequiredVersion $targetVersion `
                        -Path .\modules
                } else {
                    write-host "- Target module already installed: `"$name`" Version `"$installedVersion`"" -f Green

                }

            } else {
                # No module exist. Install it
                write-host "- Installing target version of module: `"$name`" Version `"$targetVersion`"" -f Green
                Save-Module `
                    -Name $name `
                    -RequiredVersion $targetVersion `
                    -Path .\modules
            }
        } catch {
            $_
            read-host "Press ENTER to continue..."
        }
    }

    # Remove unwanted modules
    [array]$installedModules   = Get-ChildItem -Path .\modules
    [array]$requiredModules    = $dependencies.keys

    if($null -ne $requiredModules -and $null -ne $installedModules) {
        # Do a normal check
        $unusedModules = Compare-Object -ReferenceObject $installedModules.Name -DifferenceObject $requiredModules

    } elseif( $null -eq $requiredModules -and $null -ne $installedModules) {
        # No modules are required, but some modules are installed.
        $unusedModules = $installedModules

    } else {
        #do nothing
    }

    foreach ($unusedModule in $unusedModules) {
        write-host "- Removing unused module:`"$($unusedModule.inputObject)`"" -f Green
        remove-item -Path .\modules\$($unusedModule.inputObject) -Recurse -Force | out-null
    }
    write-host "Dependencies complete!`n`n" -f Green


    # Import modules
    Write-Host "Importing modules..." -f Green
    foreach ($installedModule in $installedModules) {
        write-host "- Importing: $($installedModule.name)" -f Green
        # Check if- and remove previous imported module of same name
        if(get-module $($installedModule.name)) {
            Remove-Module $($installedModule.name)
        }

        #import module
        import-module .\modules\$($installedModule.name)
    }

    $Global:psDep = get-filehash -Path .\dependencies.psd1 | select -ExpandProperty Hash
    Write-Host "Modules imported!`n" -f Green

} else {
    # Dependencies has not changed.
    write-host "No changes to me made" -f Green
 
}


write-host "Complete!" -ForegroundColor Green



