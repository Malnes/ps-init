# Ps-Init

This repo contains the base files for a new PowerShell project. Only projects that is intended to be executed manually or automated to run on a client/server should use this template. Deployment scenarios like azure funcitons or runbooks should not user this template.

## Content

| File/Folder name | Description  |
|---|---|
| .vscode\launch.json | Instructions for debug execution in vscode. Generally, dont touch,  |
| app\main.ps1 | Write your code here! |
| modules | Auto-generated folder containing all dependency-installed modules. Do not touch!  |
| dependencies.psd1 | Edit this file to add dependencies on powershell modules |
| local.settings.json | This file is created on first setup. Used to declaration variables. Put stuff you dont want to push to git here. The values can be accessed in your script from the **$var** object |
| setup.ps1 | main script for processing depencendies and other stuff for your project. Do not touch |


## How to use

1. First, clone the repo. Choose alternative 1 or 2, copy the code and execute i terminal

``` PowerShell
# Alternative 1  - Download latest release (recommended)
$releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/Malnes/ps-init/releases/latest"
mkdir tempDir
Invoke-WebRequest -Uri $releaseInfo.zipball_url -OutFile "temp.zip"
Expand-Archive -LiteralPath "temp.zip" -DestinationPath .\tempDir
Get-ChildItem -Path ((Get-ChildItem -Path .\tempDir)[0].FullName) -Recurse | Move-Item -Destination .
Remove-Item .\tempDir -Recurse
Remove-Item "temp.zip"
```

``` PowerSHell
# Alternative 2 - Download latest files from master (the "." at the end must be included!)
git clone https://github.com/Malnes/ps-init .
```

2. (Optinal) Open the **depencencies.psd1** file and add your module depenencies.
3. Run debug (or manually execute content of .\app\main.ps1) to initialize
4. (Optional) Populate local variables in the **local.settings.json** file.

> [!NOTE]  
> If you want manually execute the setup, run ```.\setup.ps1 -forceReprocess:$true```
