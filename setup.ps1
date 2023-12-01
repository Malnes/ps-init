param (
    [Parameter()]
    [bool]$forceReprocess = $false
)

# Make sure local.settings.json exists 
if(-not (Test-Path .\local.settings.json)) {
    new-item -Path .\ -Name "local.settings.json" -ItemType File
    $content = "// Example data`n"
    $content += @{
        upn = "first.last@upn.com"
        password = "Password"
    } | convertto-json

    Add-Content -Path .\local.settings.json -Value $content
}


# make sure this script is only executen on new sessions or when changes is made to dependencies
$hash = get-filehash -Path .\dependencies.psd1 | select -ExpandProperty Hash
if($Global:psDep -ne $hash -or $forceReprocess) {


    write-host "`nInitializing..." -f Green
    
    # Start checking dependencies and stuff
    Write-Host "`nChecking dependencies..." -ForegroundColor Green
    Write-Host "------------------------" -ForegroundColor Green


    # Path to the Dependencies.psd1 file
    $dependenciesFilePath = '.\Dependencies.psd1'

    # Load dependencies from the .psd1 file
    $dependencies = Import-PowerShellDataFile -Path $dependenciesFilePath

    # Create modules folder
    if(-not (test-path .\modules)){
        new-item -name modules -ItemType Directory
    }

    function Get-requiredModuleVersion {
        param (
            [string]$requiredVersion,
            [string]$moduleName
        )

        # Determine if requiredVersion has wildcards
        $hasWildcards = $requiredVersion -like "*[*?]*"

        # Get all available versions of the module
        $availableVersions = Find-Module -Name $moduleName -AllVersions | 
                            Select-Object -ExpandProperty Version

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
                    remove-item -Path .\modules\$name -Recurse -Force

                    write-host "Installing target version of module: `"$name`" Version `"$installedVersion`"" -f Green

                    Save-Module `
                        -Name $name `
                        -RequiredVersion $targetVersion `
                        -Path .\modules
                } else {
                    write-host "Target module already installed: `"$name`" Version `"$installedVersion`"" -f Green

                }

            } else {
                # No module exist. Install it
                write-host "Installing target version of module: `"$name`" Version `"$installedVersion`"" -f Green
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
        write-host "Removing unused module:`"$($unusedModule.inputObject)`"" -f Green
        remove-item -Path .\modules\$($unusedModule.inputObject) -Recurse -Force
    }

    write-host "Dependencies complete!`n`n" -f Green




    Write-Host "Importing modules..." -f Green
    write-host "--------------------" -f Green

    foreach ($installedModule in $installedModules) {
        write-host "Importing: $($installedModule.name)" -f Green
        # Check if- and remove previous imported module of same name
        if(get-module $($installedModule.name)) {
            Remove-Module $($installedModule.name)
        }

        #import module
        import-module .\modules\$($installedModule.name)
    }

    $Global:psDep = get-filehash -Path .\dependencies.psd1 | select -ExpandProperty Hash
    Write-Host "Modules imported!`n`n`n`n" -f Green

} else {
    # Dependencies has not changed.
    write-host "No changes to me made" -f Green
 
}