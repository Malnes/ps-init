
<#PSScriptInfo

.VERSION 0.3.1

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
function new-ItemWithContent {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ItemType,
        [string]$Content
    )

    if (-not (Test-Path $Path)) {
        Write-Host "Creating $Path as it's missing" -ForegroundColor Green
        $item = New-Item -Path $Path -ItemType $ItemType -Force | Out-Null

        if ($ItemType -eq "File" -and $Content) {
            Add-Content -Path $Path -Value $Content
        }
    }
}


# CREATE local.settings.json
$content = @{upn = "example@upn.com"; password = "Password"} | ConvertTo-Json
new-ItemWithContent -Path ".\local.settings.json" -ItemType "File" -Content $content

# CREATE project.settings.json
$content = @{url = "example.com"; guid = "0000000-0000-00000-00000000"} | ConvertTo-Json
new-ItemWithContent -Path ".\project.settings.json" -ItemType "File" -Content $content
    
# CREATE gitignore 
new-ItemWithContent -Path ".\.gitignore" -ItemType "File" -Content "modules`nlocal.settings.json"

# CREATE app/main
$content = @"
# process module dependencies. Run with -forceReprocess if necessary
ps-init -forceReprocess:`$false
`$LS = Get-Content .\local.settings.json | ConvertFrom-Json -Depth 10 -AsHashtable
`$PS = Get-Content .\project.settings.json | ConvertFrom-Json -Depth 10 -AsHashtable
`$var = `$LS + `$PS

# Write your code below
"@
new-ItemWithContent -Path ".\app" -ItemType "Directory"
new-ItemWithContent -Path ".\app\main.ps1" -ItemType "File" -Content $content

# CREATE dependencies.psd1
$content = @"
@{
    # 'pnp.powershell' = '*'
    # 'microsoft.Graph.authentication' = '2.2.*'
    # 'microsoft.Graph.users' = '2.2.*'
}
"@
new-ItemWithContent -Path ".\dependencies.psd1" -ItemType "File" -Content $content

# CREATE modules
new-ItemWithContent -Path ".\modules" -ItemType "Directory"

# CREATE .vscode\launch.json
$content = @"
{
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
new-ItemWithContent -Path ".\.vscode" -ItemType "Directory"
new-ItemWithContent -Path ".\.vscode\launch.json" -ItemType "File" -Content $content



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

    function Sort-PartsByDependencies {
        param (
            [Parameter(Mandatory=$true)]
            [array]$parts
        )
    
        # Convert JSON parts to a hashtable for easier access
        $dependencyGraph = @{}
        foreach ($part in $parts) {
            $dependencyGraph[$part.part] = $part.dependsOn
        }
    
        # Hashtable to keep track of whether a part is visited
        $visited = @{}
    
        # List to store the sorted parts
        $sortedParts = New-Object System.Collections.Generic.List[Object]
    
        # Recursive function to apply topological sorting
        function TopologicalSort($currentPart) {
            if ($visited[$currentPart] -eq $true) {
                return
            }
    
            if ($visited[$currentPart] -eq 'temp') {
                throw "Circular dependency detected."
            }
    
            # Mark this part as temporarily visited
            $visited[$currentPart] = 'temp'
    
            # Recursively visit all the dependencies first
            foreach ($dependency in $dependencyGraph[$currentPart]) {
                TopologicalSort $dependency
            }
    
            # Mark as permanently visited and add to sorted list
            $visited[$currentPart] = $true
            $sortedParts.Add($currentPart)
        }
    
        # Apply topological sort to each part
        foreach ($part in $dependencyGraph.Keys) {
            if (-not $visited.ContainsKey($part)) {
                TopologicalSort $part
            }
        }
    
        # Return the sorted list of parts
        return $sortedParts
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


    # Sort modules for import after dependencies
    $moduleArr = @()
    foreach ($mod in $installedModules) {
        $obj = [PSCustomObject]@{
            part = $mod.name
            dependsOn = (get-module -name ".\modules\$($mod.name)" -ListAvailable).requiredModules | select -ExpandProperty name
        }
        $moduleArr += $obj
    }
    
    if($moduleArr) {
        $orderedImportList = Sort-PartsByDependencies -parts $moduleArr

        # Check for missing dependencies
        $missingModules = Compare-Object -ReferenceObject $orderedImportList -DifferenceObject $installedModules.name 
        if($missingModules) {
            write-host "ERROR: Missing dependencies:" -F Red

            foreach ($missingModule in $missingModules) {
                write-host "ERROR: - $($missingModules.inputObject)" -F Red
            }

            write-host "`nERROR: Add the missing module(s) to `"dependencies.psd1`" and try again"-F Red
            BREAK
        }
    }

    # Import modules
    Write-Host "Importing modules..." -f Green
    foreach ($installedModule in $installedModules) {
        write-host "- Importing: $($installedModule.name)" -f Green
        # Check if- and remove previous imported module of same name
        if(get-module $($installedModule.name)) {
            try {
                Remove-Module $($installedModule.name) -force -ErrorAction Stop
            } catch {
                Write-Host "WARNING: Unable to reload `"$($installedModule.name)`". If this causes any issues, try running the script in a new terminal." -f Yellow
            }
        }

        #import module
        try {
            import-module .\modules\$($installedModule.name)
        } catch {
            if ($_.Exception.Message -eq "Assembly with same name is already loaded") {
                write-host "Warning: Assembly already loaded for $($installedModule.name). If the module is not working properly, you can try running the script in a new terminal." -ForegroundColor Yellow
            }
        }
    }


    $Global:psDep = get-filehash -Path .\dependencies.psd1 | select -ExpandProperty Hash
    Write-Host "`nModules imported!`n" -f Green

} else {
    # Dependencies has not changed.
    write-host "No changes to me made" -f Green
 
}

# Final check to see if all modules are loaded
$loadedModules = get-module | select -ExpandProperty name
$unloadedModules = @()
foreach ($m in $installedModules.name) {
    if ($loadedModules -notcontains $m) {
        $unloadedModules += $m
    }
}

if ($unloadedModules) {
    write-host "ERROR: Some required module(s) could not be loaded" -f Red
    foreach ($unM in $unloadedModules) {
        write-host "ERROR: - $unM" -f Red
    }
    write-host "`nERROR: Try rerunning the script, manually loading the module(s) or executing in a new terminal" -f Red
    write-host "Completed with errors" -f Yellow
} else {
    write-host "Complete!" -ForegroundColor Green

}




