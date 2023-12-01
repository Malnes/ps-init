# Ps-Init

This repo contains the base files for a new PowerShell project. Only projects that is intended to be executed manually or automated to run on a client/server should use this template. Deployment scenarios like azure funcitons or runbooks should not user this template

## Files

| File/Folder name | Description  |
|---|---|
| .vscode\launch.json | Instructions for debug execution in vscode. Generally, dont touch,  |
| app\main.ps1 | Write your code here! |
| modules | Auto-generated folder containing all dependency-installed modules. Do not touch!  |
| dependencies.psd1 | Edit this file to add dependencies on powershell modules |
| local.settings.json | Declaration of enviroment variables. Put stuff you dont want to push to git here. The values can be accessed in your script from the **$var** object |
| setup.ps1 | main script for processing depencendies and other stuff for your project. Do not touch |


## How to get started

1. First, clone the repo (the "." at the end must be included!)

``` console
git clone https://github.com/Malnes/ps-init .
```

2. (Optinal) Open the **depencencies.psd1** file and add your module depenencies.
3. Run debug (or manually execute content of .\app\main.ps1) to initialize

[!Note]
asd